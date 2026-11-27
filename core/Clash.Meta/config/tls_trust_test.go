package config_test

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	_ "github.com/metacubex/mihomo/hub/executor"
)

func TestTLSRootsFollowConfiguration(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	host, portText, err := net.SplitHostPort(server.Listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		t.Fatal(err)
	}
	cert := string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: server.Certificate().Raw}))
	proxy := map[string]any{"name": "fixture", "type": "http", "server": host, "port": port, "tls": true}

	parse := func(t *testing.T, certs []string) *config.Config {
		t.Helper()
		raw, err := json.Marshal(map[string]any{
			"tls":     map[string]any{"custom-certifactes": certs},
			"proxies": []any{proxy},
			"proxy-providers": map[string]any{
				"fixture-provider": map[string]any{"type": "inline", "payload": []any{proxy}},
			},
		})
		if err != nil {
			t.Fatal(err)
		}
		cfg, err := config.Parse(raw)
		if err != nil {
			t.Fatal(err)
		}
		return cfg
	}

	original := ca.GetCertPool()
	t.Cleanup(func() { ca.SetCertPool(original) })
	withTrust := parse(t, []string{cert})
	if ca.GetCertPool() != original {
		t.Fatal("parsing changed the active trust pool")
	}

	check := func(cfg *config.Config, trusted bool) {
		t.Helper()
		for _, proxy := range []C.Proxy{cfg.Proxies["fixture"], cfg.Providers["fixture-provider"].Proxies()[0]} {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			conn, err := proxy.DialContext(ctx, &C.Metadata{Host: "fixture.test", DstPort: 80})
			cancel()
			if conn != nil {
				_ = conn.Close()
			}
			if trusted {
				if err != nil {
					t.Fatal(err)
				}
				continue
			}
			var unknown x509.UnknownAuthorityError
			if !errors.As(err, &unknown) {
				t.Fatalf("expected removed CA to be untrusted, got %v", err)
			}
		}
	}
	check(withTrust, true)
	ca.SetCertPool(withTrust.TLS.RootCAs)
	withoutTrust := parse(t, nil)
	check(withoutTrust, false)
	check(withTrust, true)
	if ca.GetCertPool() != withTrust.TLS.RootCAs {
		t.Fatal("parsing the replacement changed the active configuration")
	}
	if _, err := config.Parse([]byte("rules: [INVALID,REJECT]")); err == nil || !strings.Contains(err.Error(), "rule") {
		t.Fatalf("expected an invalid rule, got %v", err)
	}
	if ca.GetCertPool() != withTrust.TLS.RootCAs {
		t.Fatal("rejected configuration changed the active trust pool")
	}
}
