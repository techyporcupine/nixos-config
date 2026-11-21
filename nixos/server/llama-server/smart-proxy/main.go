// smart-proxy sits in front of a llama-server router and passes every
// request through untouched, except those naming the alias model (e.g.
// "smart"). Those are sent to whichever candidate model is already loaded,
// so clients never force a slow model swap.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const adminPrefix = "/smart-proxy/"

// paramMap holds, per target model, a value substitution table for each
// parameter path: model -> "reasoning.effort" -> {"xhigh": "high"}.
type paramMap map[string]map[string]map[string]json.RawMessage

type proxy struct {
	alias       string
	aliasQuoted []byte
	tracker     *tracker
	params      paramMap
	rp          *httputil.ReverseProxy
}

func newProxy(upstream *url.URL, alias string, t *tracker, params paramMap) *proxy {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConnsPerHost = 64
	return &proxy{
		alias:       alias,
		aliasQuoted: []byte(strconv.Quote(alias)),
		tracker:     t,
		params:      params,
		rp: &httputil.ReverseProxy{
			Rewrite: func(r *httputil.ProxyRequest) {
				r.SetURL(upstream)
				r.Out.Host = r.In.Host
			},
			Transport:     transport,
			FlushInterval: -1, // stream tokens as they arrive
		},
	}
}

// The router's own model management endpoints always pass through verbatim,
// so loading or unloading the alias's namesake preset still works.
func isManagementPath(path string) bool {
	return path == "/models" || strings.HasPrefix(path, "/models/") || path == "/v1/models"
}

func (p *proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, adminPrefix) {
		p.admin(w, r)
		return
	}
	if !isManagementPath(r.URL.Path) {
		if err := p.rewrite(r); err != nil {
			if r.Context().Err() != nil {
				return
			}
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
	}
	p.rp.ServeHTTP(w, r)
}

// rewrite swaps the alias for its current target in the query string and in
// a JSON body's top-level "model". Any other request is left byte-for-byte.
func (p *proxy) rewrite(r *http.Request) error {
	if strings.Contains(r.URL.RawQuery, "model=") {
		q := r.URL.Query()
		if q.Get("model") == p.alias {
			target, err := p.tracker.resolveTarget(r.Context())
			if err != nil {
				return err
			}
			q.Set("model", target)
			r.URL.RawQuery = q.Encode()
		}
	}

	if r.Method != http.MethodPost || r.Body == nil {
		return nil
	}
	body, err := io.ReadAll(r.Body)
	r.Body.Close()
	if err != nil {
		return err
	}
	if bytes.Contains(body, p.aliasQuoted) {
		if out, ok, err := p.rewriteBody(r.Context(), body); err != nil {
			return err
		} else if ok {
			body = out
		}
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	r.ContentLength = int64(len(body))
	r.Header.Set("Content-Length", strconv.Itoa(len(body)))
	return nil
}

func (p *proxy) rewriteBody(ctx context.Context, body []byte) ([]byte, bool, error) {
	var fields map[string]json.RawMessage
	if json.Unmarshal(body, &fields) != nil {
		return nil, false, nil
	}
	var model string
	if json.Unmarshal(fields["model"], &model) != nil || model != p.alias {
		return nil, false, nil
	}
	target, err := p.tracker.resolveTarget(ctx)
	if err != nil {
		return nil, false, err
	}
	fields["model"], _ = json.Marshal(target)
	for path, values := range p.params[target] {
		mapParam(fields, strings.Split(path, "."), values)
	}
	out, err := marshal(fields)
	return out, err == nil, err
}

// mapParam replaces the value at path when it matches a key in values.
// It reports whether anything changed, so parents re-encode only when needed.
func mapParam(fields map[string]json.RawMessage, path []string, values map[string]json.RawMessage) bool {
	raw, ok := fields[path[0]]
	if !ok {
		return false
	}
	if len(path) == 1 {
		repl, ok := values[valueKey(raw)]
		if ok {
			fields[path[0]] = repl
		}
		return ok
	}
	var sub map[string]json.RawMessage
	if json.Unmarshal(raw, &sub) != nil || !mapParam(sub, path[1:], values) {
		return false
	}
	out, err := marshal(sub)
	if err != nil {
		return false
	}
	fields[path[0]] = out
	return true
}

// valueKey gives the lookup key for a JSON value: a string's text, or the
// compact JSON of anything else (so 0.7, true and null are matchable too).
func valueKey(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s
	}
	var buf bytes.Buffer
	if json.Compact(&buf, raw) != nil {
		return string(raw)
	}
	return buf.String()
}

func marshal(v any) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

func loadParamMap(path string) (paramMap, error) {
	if path == "" {
		return nil, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m paramMap
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return m, nil
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func (p *proxy) admin(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case adminPrefix + "status":
		status, _ := p.tracker.snapshotStatus()
		candidates := map[string]string{}
		for _, c := range p.tracker.candidates {
			candidates[c] = status[c]
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"alias":      p.alias,
			"target":     *p.tracker.target.Load(),
			"fallback":   p.tracker.fallback,
			"candidates": candidates,
			"switching":  p.tracker.gate.Load() != nil,
		})

	case adminPrefix + "switch":
		if r.Method != http.MethodPost {
			http.Error(w, "use POST", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Model string `json:"model"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "body must be {\"model\": \"<candidate>\"}", http.StatusBadRequest)
			return
		}
		if !slices.Contains(p.tracker.candidates, req.Model) {
			http.Error(w, "not a candidate: "+req.Model, http.StatusBadRequest)
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		if err := p.tracker.switchTo(ctx, req.Model); err != nil {
			log.Printf("switch to %q failed: %v", req.Model, err)
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"target": *p.tracker.target.Load()})

	default:
		http.NotFound(w, r)
	}
}

func main() {
	listen := flag.String("listen", "0.0.0.0:5349", "address to listen on")
	upstreamFlag := flag.String("upstream", "http://127.0.0.1:5350", "llama-server router URL")
	alias := flag.String("alias", "smart", "model name that follows whichever candidate is loaded")
	candidatesFlag := flag.String("candidates", "", "comma-separated candidate models, most preferred first")
	fallback := flag.String("fallback", "", "model to use when no candidate is up (default: last candidate)")
	paramMapFile := flag.String("param-map", "", `JSON file of per-model value substitutions, e.g. {"medium": {"reasoning_effort": {"xhigh": "high"}}}`)
	flag.Parse()

	params, err := loadParamMap(*paramMapFile)
	if err != nil {
		log.Fatalf("bad -param-map: %v", err)
	}

	var candidates []string
	for _, c := range strings.Split(*candidatesFlag, ",") {
		if c = strings.TrimSpace(c); c != "" {
			candidates = append(candidates, c)
		}
	}
	if len(candidates) == 0 {
		log.Fatal("-candidates is required")
	}
	if *fallback == "" {
		*fallback = candidates[len(candidates)-1]
	}
	upstream, err := url.Parse(strings.TrimRight(*upstreamFlag, "/"))
	if err != nil {
		log.Fatalf("bad -upstream: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	t := newTracker(upstream.String(), candidates, *fallback)
	go t.watch(ctx)

	srv := &http.Server{Addr: *listen, Handler: newProxy(upstream, *alias, t, params)}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(shutdown)
	}()
	log.Printf("listening on %s, alias %q over %v (fallback %q) -> %s",
		*listen, *alias, candidates, *fallback, upstream)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
