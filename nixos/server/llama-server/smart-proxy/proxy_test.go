package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeRouter imitates the llama-server router endpoints the proxy relies on.
type fakeRouter struct {
	mu        sync.Mutex
	status    map[string]string
	subs      []chan string
	lastBody  []byte
	lastQuery string
	unloadLag time.Duration
}

func (f *fakeRouter) set(model, status string) {
	f.mu.Lock()
	f.status[model] = status
	subs := f.subs
	f.mu.Unlock()
	ev := fmt.Sprintf(`{"model":%q,"event":"status_change","data":{"status":%q}}`, model, status)
	for _, s := range subs {
		s <- ev
	}
}

func (f *fakeRouter) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/models":
		f.mu.Lock()
		var list modelList
		for id, st := range f.status {
			m := list.Data
			m = append(m, struct {
				ID     string `json:"id"`
				Status struct {
					Value string `json:"value"`
				} `json:"status"`
			}{ID: id})
			m[len(m)-1].Status.Value = st
			list.Data = m
		}
		f.mu.Unlock()
		json.NewEncoder(w).Encode(list)
	case "/models/sse":
		ch := make(chan string, 16)
		f.mu.Lock()
		f.subs = append(f.subs, ch)
		f.mu.Unlock()
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		for {
			select {
			case ev := <-ch:
				fmt.Fprintf(w, "data: %s\n\n", ev)
				w.(http.Flusher).Flush()
			case <-r.Context().Done():
				return
			}
		}
	case "/models/unload", "/models/load":
		var req struct{ Model string }
		json.NewDecoder(r.Body).Decode(&req)
		if r.URL.Path == "/models/load" {
			go f.set(req.Model, "loading")
		} else {
			go func() { time.Sleep(f.unloadLag); f.set(req.Model, "unloaded") }()
		}
		io.WriteString(w, `{"success":true}`)
	default:
		body, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.lastBody, f.lastQuery = body, r.URL.RawQuery
		f.mu.Unlock()
		w.Write(body)
	}
}

func setup(t *testing.T, status map[string]string) (*fakeRouter, *tracker, *httptest.Server) {
	t.Helper()
	fr := &fakeRouter{status: status}
	router := httptest.NewServer(fr)
	t.Cleanup(router.Close)

	u, _ := url.Parse(router.URL)
	tr := newTracker(router.URL, []string{"smart", "medium"}, "medium")
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go tr.watch(ctx)

	front := httptest.NewServer(newProxy(u, "smart", tr, testParams))
	t.Cleanup(front.Close)
	waitTarget(t, tr, resolve(tr.candidates, status, "medium"))
	return fr, tr, front
}

func waitTarget(t *testing.T, tr *tracker, want string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		tr.mu.Lock()
		synced := len(tr.status) > 0
		tr.mu.Unlock()
		if synced && *tr.target.Load() == want {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("target = %q, want %q", *tr.target.Load(), want)
}

func post(t *testing.T, base, path, body string) {
	t.Helper()
	resp, err := http.Post(base+path, "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
}

func modelOf(t *testing.T, body []byte) string {
	t.Helper()
	var m struct{ Model string }
	if err := json.Unmarshal(body, &m); err != nil {
		t.Fatalf("bad body %q: %v", body, err)
	}
	return m.Model
}

func TestResolvePriority(t *testing.T) {
	c := []string{"smart", "medium"}
	cases := []struct {
		status map[string]string
		want   string
	}{
		{map[string]string{}, "medium"},
		{map[string]string{"smart": "loaded", "medium": "loaded"}, "smart"},
		{map[string]string{"smart": "unloaded", "medium": "loaded"}, "medium"},
		{map[string]string{"smart": "loading", "medium": "unloaded"}, "smart"},
		{map[string]string{"smart": "loading", "medium": "loaded"}, "medium"},
		{map[string]string{"smart": "sleeping"}, "smart"},
		{map[string]string{"smart": "unloaded", "medium": "unloaded"}, "medium"},
	}
	for _, tc := range cases {
		if got := resolve(c, tc.status, "medium"); got != tc.want {
			t.Errorf("resolve(%v) = %q, want %q", tc.status, got, tc.want)
		}
	}
}

func TestOtherModelsPassVerbatim(t *testing.T) {
	fr, _, front := setup(t, map[string]string{"smart": "unloaded", "medium": "loaded"})
	body := `{"model":"fast",  "messages":[{"role":"user","content":"say \"smart\" <b>"}]}`
	post(t, front.URL, "/v1/chat/completions", body)
	if string(fr.lastBody) != body {
		t.Fatalf("body changed:\n got %s\nwant %s", fr.lastBody, body)
	}
}

func TestAliasFollowsLoadedModel(t *testing.T) {
	fr, tr, front := setup(t, map[string]string{"smart": "unloaded", "medium": "loaded"})
	req := `{"model":"smart","messages":[{"role":"user","content":"<hi>"}]}`

	post(t, front.URL, "/v1/chat/completions", req)
	if got := modelOf(t, fr.lastBody); got != "medium" {
		t.Fatalf("routed to %q, want medium", got)
	}
	if !bytes.Contains(fr.lastBody, []byte(`"<hi>"`)) {
		t.Fatalf("content was HTML-escaped: %s", fr.lastBody)
	}

	fr.set("medium", "unloaded")
	fr.set("smart", "loaded")
	waitTarget(t, tr, "smart")
	post(t, front.URL, "/v1/chat/completions", req)
	if got := modelOf(t, fr.lastBody); got != "smart" {
		t.Fatalf("routed to %q, want smart", got)
	}
}

func TestQueryParamRewritten(t *testing.T) {
	fr, _, front := setup(t, map[string]string{"medium": "loaded"})
	resp, err := http.Get(front.URL + "/props?model=smart")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if fr.lastQuery != "model=medium" {
		t.Fatalf("query = %q, want model=medium", fr.lastQuery)
	}
}

func TestManagementCallsUntouched(t *testing.T) {
	fr, tr, front := setup(t, map[string]string{"smart": "unloaded", "medium": "loaded"})
	post(t, front.URL, "/models/load", `{"model":"smart"}`)
	fr.set("medium", "unloaded")
	waitTarget(t, tr, "smart")
}

func TestSwitchUnloadsThenLoads(t *testing.T) {
	fr, tr, front := setup(t, map[string]string{"smart": "unloaded", "medium": "loaded"})
	fr.unloadLag = 200 * time.Millisecond

	done := make(chan struct{})
	go func() {
		post(t, front.URL, "/smart-proxy/switch", `{"model":"smart"}`)
		close(done)
	}()

	// A request arriving mid-switch must wait, then go to the new model.
	time.Sleep(50 * time.Millisecond)
	if tr.gate.Load() == nil {
		t.Fatal("expected a switch in progress")
	}
	post(t, front.URL, "/v1/chat/completions", `{"model":"smart"}`)
	if got := modelOf(t, fr.lastBody); got != "smart" {
		t.Fatalf("mid-switch request routed to %q, want smart", got)
	}
	<-done

	fr.mu.Lock()
	defer fr.mu.Unlock()
	if fr.status["medium"] != "unloaded" || fr.status["smart"] != "loading" {
		t.Fatalf("router status after switch: %v", fr.status)
	}
}

var testParams = paramMap{
	"smart": {
		"chat_template_kwargs.reasoning_effort": {"minimal": json.RawMessage(`"low"`)},
	},
	"medium": {
		"reasoning_effort": {"xhigh": json.RawMessage(`"high"`), "max": json.RawMessage(`"high"`)},
		"reasoning.effort": {"xhigh": json.RawMessage(`"high"`)},
		"temperature":      {"1.5": json.RawMessage(`1.0`)},
	},
}

func TestParamMapAppliesToAliasOnTarget(t *testing.T) {
	fr, _, front := setup(t, map[string]string{"smart": "unloaded", "medium": "loaded"})

	post(t, front.URL, "/v1/chat/completions", `{"model":"smart","reasoning_effort":"xhigh","temperature":1.5}`)
	var got struct {
		Model           string
		ReasoningEffort string  `json:"reasoning_effort"`
		Temperature     float64 `json:"temperature"`
	}
	json.Unmarshal(fr.lastBody, &got)
	if got.Model != "medium" || got.ReasoningEffort != "high" || got.Temperature != 1.0 {
		t.Fatalf("chat body = %s", fr.lastBody)
	}

	post(t, front.URL, "/v1/responses", `{"model":"smart","reasoning":{"effort":"xhigh","summary":"auto"}}`)
	var resp struct {
		Reasoning struct{ Effort, Summary string }
	}
	json.Unmarshal(fr.lastBody, &resp)
	if resp.Reasoning.Effort != "high" || resp.Reasoning.Summary != "auto" {
		t.Fatalf("responses body = %s", fr.lastBody)
	}

	post(t, front.URL, "/v1/chat/completions", `{"model":"smart","reasoning_effort":"low"}`)
	if !bytes.Contains(fr.lastBody, []byte(`"reasoning_effort":"low"`)) {
		t.Fatalf("unmapped value changed: %s", fr.lastBody)
	}
}

func TestParamMapSkipsOtherTargetsAndNamedModels(t *testing.T) {
	fr, tr, front := setup(t, map[string]string{"smart": "loaded", "medium": "unloaded"})
	waitTarget(t, tr, "smart")

	post(t, front.URL, "/v1/chat/completions", `{"model":"smart","reasoning_effort":"xhigh"}`)
	if !bytes.Contains(fr.lastBody, []byte(`"xhigh"`)) {
		t.Fatalf("mapping for medium applied to smart: %s", fr.lastBody)
	}

	post(t, front.URL, "/v1/chat/completions", `{"model":"smart","chat_template_kwargs":{"enable_thinking":true,"reasoning_effort":"minimal","preserve_thinking":true}}`)
	var chatKwargs struct {
		ChatTemplateKwargs struct {
			EnableThinking   bool   `json:"enable_thinking"`
			ReasoningEffort  string `json:"reasoning_effort"`
			PreserveThinking bool   `json:"preserve_thinking"`
		} `json:"chat_template_kwargs"`
	}
	json.Unmarshal(fr.lastBody, &chatKwargs)
	if chatKwargs.ChatTemplateKwargs.ReasoningEffort != "low" || !chatKwargs.ChatTemplateKwargs.EnableThinking || !chatKwargs.ChatTemplateKwargs.PreserveThinking {
		t.Fatalf("chat_template_kwargs body = %s", fr.lastBody)
	}

	body := `{"model":"medium","reasoning_effort":"xhigh"}`
	post(t, front.URL, "/v1/chat/completions", body)
	if string(fr.lastBody) != body {
		t.Fatalf("named-model request changed: %s", fr.lastBody)
	}
}

func TestAdminUIAndStatus(t *testing.T) {
	_, _, front := setup(t, map[string]string{"fast": "loaded", "smart": "unloaded", "medium": "loaded"})

	client := &http.Client{
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	resp, err := client.Get(front.URL + "/smart-proxy")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusFound || resp.Header.Get("Location") != "/smart-proxy/" {
		t.Fatalf("redirect = %d %q, want 302 /smart-proxy/", resp.StatusCode, resp.Header.Get("Location"))
	}

	resp, err = http.Get(front.URL + "/smart-proxy/")
	if err != nil {
		t.Fatal(err)
	}
	html, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !strings.Contains(resp.Header.Get("Content-Type"), "text/html") {
		t.Fatalf("ui = %d %q", resp.StatusCode, resp.Header.Get("Content-Type"))
	}
	if !bytes.Contains(html, []byte("/smart-proxy/switch")) {
		t.Fatalf("ui missing switch endpoint")
	}

	resp, err = http.Get(front.URL + "/smart-proxy/status")
	if err != nil {
		t.Fatal(err)
	}
	var st struct {
		Alias        string            `json:"alias"`
		Target       string            `json:"target"`
		Order        []string          `json:"order"`
		Candidates   map[string]string `json:"candidates"`
		Models       map[string]string `json:"models"`
		UpstreamPort string            `json:"upstream_port"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&st); err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if st.Alias != "smart" || st.Target != "medium" {
		t.Fatalf("status alias/target = %q/%q", st.Alias, st.Target)
	}
	if len(st.Order) != 2 || st.Order[0] != "smart" || st.Order[1] != "medium" {
		t.Fatalf("status order = %v", st.Order)
	}
	if st.Models["fast"] != "loaded" || st.Candidates["medium"] != "loaded" {
		t.Fatalf("status models = %v, candidates = %v", st.Models, st.Candidates)
	}
	if st.UpstreamPort == "" {
		t.Fatal("expected upstream_port to be set")
	}
}
