package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

// tracker mirrors the router's model statuses and keeps the alias target
// precomputed, so the request path is a single atomic load.
type tracker struct {
	upstream   string
	candidates []string
	fallback   string
	client     *http.Client

	mu      sync.Mutex
	status  map[string]string
	changed chan struct{} // closed and replaced on every status change

	target atomic.Pointer[string]
	gate   atomic.Pointer[chan struct{}] // non-nil while a switch is unloading
}

func newTracker(upstream string, candidates []string, fallback string) *tracker {
	t := &tracker{
		upstream:   upstream,
		candidates: candidates,
		fallback:   fallback,
		client:     &http.Client{},
		status:     map[string]string{},
		changed:    make(chan struct{}),
	}
	t.target.Store(&fallback)
	return t
}

// resolve picks the best candidate: loaded, then loading, then sleeping,
// in priority order within each tier. With none up, it uses the fallback.
func resolve(candidates []string, status map[string]string, fallback string) string {
	for _, tier := range []string{"loaded", "loading", "sleeping"} {
		for _, c := range candidates {
			if status[c] == tier {
				return c
			}
		}
	}
	return fallback
}

// resolveTarget returns the current alias target, first waiting out any
// switch in progress so requests never revive the model being unloaded.
func (t *tracker) resolveTarget(ctx context.Context) (string, error) {
	if g := t.gate.Load(); g != nil {
		select {
		case <-*g:
		case <-ctx.Done():
			return "", ctx.Err()
		}
	}
	return *t.target.Load(), nil
}

// update applies fn to the status map under the lock, then recomputes the
// target and wakes anyone waiting on a status change.
func (t *tracker) update(fn func(map[string]string)) {
	t.mu.Lock()
	fn(t.status)
	next := resolve(t.candidates, t.status, t.fallback)
	prev := *t.target.Load()
	t.target.Store(&next)
	close(t.changed)
	t.changed = make(chan struct{})
	t.mu.Unlock()
	if next != prev {
		log.Printf("alias now routes to %q (was %q)", next, prev)
	}
}

func (t *tracker) snapshotStatus() (map[string]string, <-chan struct{}) {
	t.mu.Lock()
	defer t.mu.Unlock()
	out := make(map[string]string, len(t.status))
	for k, v := range t.status {
		out[k] = v
	}
	return out, t.changed
}

// waitFor blocks until cond holds for the current statuses, or ctx ends.
func (t *tracker) waitFor(ctx context.Context, cond func(map[string]string) bool) error {
	for {
		status, changed := t.snapshotStatus()
		if cond(status) {
			return nil
		}
		select {
		case <-changed:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}

type modelList struct {
	Data []struct {
		ID     string `json:"id"`
		Status struct {
			Value string `json:"value"`
		} `json:"status"`
	} `json:"data"`
}

func (t *tracker) snapshot(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, t.upstream+"/models", nil)
	if err != nil {
		return err
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET /models: %s", resp.Status)
	}
	var list modelList
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return fmt.Errorf("GET /models: %w", err)
	}
	t.update(func(s map[string]string) {
		clear(s)
		for _, m := range list.Data {
			s[m.ID] = m.Status.Value
		}
	})
	return nil
}

type routerEvent struct {
	Model string `json:"model"`
	Event string `json:"event"`
	Data  struct {
		Status string `json:"status"`
	} `json:"data"`
}

// watch follows the router's /models/sse stream for the life of ctx,
// reconnecting with backoff. Each (re)connect takes a fresh snapshot.
func (t *tracker) watch(ctx context.Context) {
	backoff := time.Second
	for ctx.Err() == nil {
		started := time.Now()
		err := t.follow(ctx)
		if ctx.Err() != nil {
			return
		}
		if time.Since(started) > time.Minute {
			backoff = time.Second
		}
		log.Printf("router event stream lost: %v; retrying in %s", err, backoff)
		select {
		case <-time.After(backoff):
		case <-ctx.Done():
			return
		}
		backoff = min(backoff*2, 30*time.Second)
	}
}

func (t *tracker) follow(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, t.upstream+"/models/sse", nil)
	if err != nil {
		return err
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET /models/sse: %s", resp.Status)
	}
	// Subscribe first, then snapshot, so no change slips through the gap.
	if err := t.snapshot(ctx); err != nil {
		return err
	}
	log.Printf("following router events at %s", t.upstream)
	return t.consume(ctx, resp.Body)
}

func (t *tracker) consume(ctx context.Context, r io.Reader) error {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 16*1024*1024)
	for sc.Scan() {
		line, ok := bytes.CutPrefix(sc.Bytes(), []byte("data:"))
		if !ok {
			continue
		}
		var ev routerEvent
		if err := json.Unmarshal(bytes.TrimSpace(line), &ev); err != nil {
			log.Printf("skipping unreadable router event: %v", err)
			continue
		}
		switch ev.Event {
		case "status_change", "model_status":
			if ev.Data.Status != "" {
				t.update(func(s map[string]string) { s[ev.Model] = ev.Data.Status })
			}
		case "model_remove":
			t.update(func(s map[string]string) { delete(s, ev.Model) })
		case "models_reload":
			if err := t.snapshot(ctx); err != nil {
				return err
			}
		}
	}
	if err := sc.Err(); err != nil {
		return err
	}
	return io.EOF
}

func isUp(status string) bool {
	return status == "loaded" || status == "loading" || status == "sleeping"
}

func (t *tracker) routerCall(ctx context.Context, path, model string) error {
	body, _ := json.Marshal(map[string]string{"model": model})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.upstream+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("POST %s %s: %s: %s", path, model, resp.Status, bytes.TrimSpace(msg))
	}
	return nil
}

var switchMu sync.Mutex

// switchTo unloads every other candidate, waits until they are gone, then
// asks the router to load the chosen one. Alias requests that arrive in the
// meantime wait, rather than reloading a model on its way out.
func (t *tracker) switchTo(ctx context.Context, model string) error {
	switchMu.Lock()
	defer switchMu.Unlock()

	gate := make(chan struct{})
	t.gate.Store(&gate)
	defer func() {
		t.gate.Store(nil)
		close(gate)
	}()

	status, _ := t.snapshotStatus()
	for _, c := range t.candidates {
		if c != model && isUp(status[c]) {
			log.Printf("switch: unloading %q", c)
			if err := t.routerCall(ctx, "/models/unload", c); err != nil {
				return err
			}
		}
	}
	err := t.waitFor(ctx, func(s map[string]string) bool {
		for _, c := range t.candidates {
			if c != model && isUp(s[c]) {
				return false
			}
		}
		return true
	})
	if err != nil {
		return fmt.Errorf("waiting for other models to unload: %w", err)
	}

	if !isUp(status[model]) {
		log.Printf("switch: loading %q", model)
		if err := t.routerCall(ctx, "/models/load", model); err != nil {
			return err
		}
		// The router's own event can trail the gate opening; mark it now so
		// waiting requests go to the new model, not the fallback.
		t.update(func(s map[string]string) {
			if !isUp(s[model]) {
				s[model] = "loading"
			}
		})
	}
	return nil
}
