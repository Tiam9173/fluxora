package main

import (
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestAsyncDelayReportsDeadlineWithoutChangingNumericResult(t *testing.T) {
	proxies, providers := tunnel.Proxies(), tunnel.Providers()
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"DIRECT": adapter.NewProxy(outbound.NewDirect()),
	}, nil)
	t.Cleanup(func() { tunnel.UpdateProxies(proxies, providers) })

	origin := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/wait" {
			<-req.Context().Done()
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(origin.Close)
	untrustedTLS := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(untrustedTLS.Close)
	closed, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	refusedURL := "http://" + closed.Addr().String()
	if err := closed.Close(); err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		name, url string
		timeout   int64
		success   bool
		timedOut  bool
	}{
		{"success", origin.URL, 2000, true, false},
		{"refused", refusedURL, 2000, false, false},
		{"certificateRejected", untrustedTLS.URL, 2000, false, false},
		{"timeout", origin.URL + "/wait", 200, false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			payload, err := json.Marshal(TestDelayParams{ProxyName: "DIRECT", TestUrl: tc.url, Timeout: tc.timeout})
			if err != nil {
				t.Fatal(err)
			}
			result := make(chan string, 1)
			handleAsyncTestDelay(string(payload), func(data string) { result <- data })
			select {
			case response := <-result:
				var got struct {
					Value    int32 `json:"value"`
					TimedOut *bool `json:"timedOut"`
				}
				if err := json.Unmarshal([]byte(response), &got); err != nil {
					t.Fatal(err)
				}
				if (tc.success && got.Value <= 0) || (!tc.success && got.Value != -1) {
					t.Fatalf("unexpected numeric result %s", response)
				}
				if (tc.timedOut && (got.TimedOut == nil || !*got.TimedOut)) || (!tc.timedOut && got.TimedOut != nil) {
					t.Fatalf("unexpected timeout field %s", response)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("no delay callback")
			}
		})
	}
}
