package adapter

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/utils"
	C "github.com/metacubex/mihomo/constant"
)

type delayedProbeAdapter struct {
	C.ProxyAdapter
	calls   atomic.Int32
	started chan struct{}
	release chan struct{}
	fail    bool
}

func (p *delayedProbeAdapter) DialContext(ctx context.Context, metadata *C.Metadata) (C.Conn, error) {
	if p.calls.Add(1) == 1 {
		close(p.started)
		select {
		case <-p.release:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
		if p.fail {
			return nil, errors.New("older probe failed")
		}
	}
	return p.ProxyAdapter.DialContext(ctx, metadata)
}

func TestURLTestIgnoresOlderCompletion(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	for _, fail := range []bool{false, true} {
		t.Run(map[bool]string{false: "old-success", true: "old-failure"}[fail], func(t *testing.T) {
			adapter := &delayedProbeAdapter{
				ProxyAdapter: outbound.NewDirectWithOption(outbound.DirectOption{Name: "node"}),
				started:      make(chan struct{}), release: make(chan struct{}), fail: fail,
			}
			p := NewProxy(adapter)
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			var notifications []uint16
			previousHook := UrlTestHook
			UrlTestHook = func(_ string, _ string, delay uint16) { notifications = append(notifications, delay) }
			defer func() { UrlTestHook = previousHook }()
			done := make(chan struct{})
			go func() {
				defer close(done)
				_, _ = p.URLTest(ctx, server.URL, nil)
			}()
			select {
			case <-adapter.started:
			case <-ctx.Done():
				t.Fatal(ctx.Err())
			}
			delay, err := p.URLTest(ctx, server.URL, nil)
			close(adapter.release)
			<-done
			if err != nil || delay == 0 {
				t.Fatalf("new probe: delay=%d err=%v", delay, err)
			}
			if !p.AliveForTestUrl(server.URL) || p.LastDelayForTestUrl(server.URL) != delay {
				t.Fatal("older result replaced the latest health result")
			}
			if len(notifications) != 1 || notifications[0] != delay ||
				len(p.DelayHistoryForTestUrl(server.URL)) != 1 {
				t.Fatalf("stale completion published: %v", notifications)
			}
		})
	}
}

func TestURLTestHookRespectsExpectedStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer server.Close()
	p := NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: "node"}))
	expected, err := utils.NewUnsignedRanges[uint16]("204")
	if err != nil {
		t.Fatal(err)
	}
	previousHook := UrlTestHook
	defer func() { UrlTestHook = previousHook }()
	notified := uint16(99)
	UrlTestHook = func(_ string, _ string, delay uint16) { notified = delay }
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err = p.URLTest(ctx, server.URL, expected)
	if err != nil {
		t.Fatal(err)
	}
	if notified != 0 || p.AliveForTestUrl(server.URL) {
		t.Fatalf("unexpected HTTP status reported as healthy: delay=%d", notified)
	}
	if !p.AliveForTestUrl("") {
		t.Fatal("a working transport was incorrectly marked dead for all URLs")
	}
}

func TestURLTestConcurrentAcrossDifferentURLs(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	p := NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: "node"}))
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	const workers = 8
	const requestsPerWorker = 4
	var workersDone sync.WaitGroup
	errs := make(chan error, workers*requestsPerWorker)
	for worker := 0; worker < workers; worker++ {
		workersDone.Add(1)
		go func(worker int) {
			defer workersDone.Done()
			for request := 0; request < requestsPerWorker; request++ {
				url := fmt.Sprintf("%s/%d/%d", server.URL, worker, request)
				if _, err := p.URLTest(ctx, url, nil); err != nil {
					errs <- err
				}
			}
		}(worker)
	}
	workersDone.Wait()
	close(errs)
	for err := range errs {
		t.Errorf("URLTest failed: %v", err)
	}
	if got := len(p.DelayHistory()); got > defaultHistoriesNum {
		t.Fatalf("aggregate history exceeded its cap: %d", got)
	}
}
