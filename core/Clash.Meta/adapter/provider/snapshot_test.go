package provider

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

const snapshotFixture = "proxies:\n  - {name: HK-1, type: trojan, server: tls.example.test, port: 443, password: fixture, sni: tls.example.test}\n  - {name: US-1, type: socks5, server: socks.example.test, port: 1080}\n"

func snapshotHome(t *testing.T) string {
	t.Helper()
	old := C.Path.HomeDir()
	home := t.TempDir()
	C.SetHomeDir(home)
	t.Cleanup(func() { C.SetHomeDir(old) })
	return home
}

func TestProviderSnapshotFiltersOverridesAndTLSIdentity(t *testing.T) {
	home := snapshotHome(t)
	if err := os.WriteFile(filepath.Join(home, "nodes.yaml"), []byte(snapshotFixture), 0600); err != nil {
		t.Fatal(err)
	}
	nodes, err := ReadProxyMappings(context.Background(), map[string]any{
		"type": "file", "path": "nodes.yaml", "filter": "HK`HK", "exclude-type": "socks5",
		"override": map[string]any{"additional-prefix": "[A] ", "udp": true, "dialer-proxy": "entrance"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(nodes) != 1 {
		t.Fatalf("expected one filtered node, got %d", len(nodes))
	}
	node := nodes[0]
	if node["name"] != "[A] HK-1" || node["server"] != "tls.example.test" || node["sni"] != "tls.example.test" || node["udp"] != true || node["dialer-proxy"] != "entrance" {
		t.Fatal("node fields changed incorrectly")
	}
	if node["skip-cert-verify"] == true {
		t.Fatal("TLS verification weakened")
	}
}

func TestProviderSnapshotRefreshIsolationCancellationAndOffline(t *testing.T) {
	snapshotHome(t)
	content := snapshotFixture
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "fixture" {
			w.WriteHeader(401)
			return
		}
		_, _ = w.Write([]byte(content))
	}))
	defer server.Close()
	mapping := map[string]any{"type": "http", "url": server.URL, "path": "shared.yaml", "header": map[string][]string{"Authorization": {"fixture"}}}
	first, err := ReadProxyMappings(context.Background(), mapping)
	if err != nil || len(first) != 2 {
		t.Fatal("initial read failed", err)
	}
	content = strings.ReplaceAll(snapshotFixture, "HK-1", "HK-2")
	next, err := ReadProxyMappings(context.Background(), mapping)
	if err != nil || next[0]["name"] != "HK-2" {
		t.Fatal("explicit reapply did not refresh nodes", err)
	}
	mapping["header"] = map[string][]string{"Authorization": {"other"}}
	if _, err := ReadProxyMappings(context.Background(), mapping); err == nil {
		t.Fatal("different credentials reused cache")
	}
	mapping["header"] = map[string][]string{"Authorization": {"fixture"}}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := ReadProxyMappings(ctx, mapping); err != context.Canceled {
		t.Fatal("cancel ignored", err)
	}
	server.Close()
	offline, err := ReadProxyMappings(context.Background(), mapping)
	if err != nil || offline[0]["name"] != "HK-2" {
		t.Fatal("offline cache missing", err)
	}
}

func TestProviderSnapshotRejectsMalformedOversizeAndUntrustedTLS(t *testing.T) {
	snapshotHome(t)
	body := snapshotFixture
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(body)) }))
	defer server.Close()
	mapping := map[string]any{"type": "http", "url": server.URL, "size-limit": len(body)}
	if _, err := ReadProxyMappings(context.Background(), mapping); err != nil {
		t.Fatal("exact limit rejected", err)
	}
	body += " "
	if _, err := ReadProxyMappings(context.Background(), mapping); err == nil {
		t.Fatal("oversize accepted")
	}
	body = "proxies: [broken"
	if _, err := ReadProxyMappings(context.Background(), mapping); err == nil {
		t.Fatal("invalid response accepted")
	}
	tls := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(snapshotFixture)) }))
	defer tls.Close()
	mapping["url"] = tls.URL
	if _, err := ReadProxyMappings(context.Background(), mapping); err == nil {
		t.Fatal("untrusted TLS accepted")
	}
}

func TestProviderSnapshot64MiBLimit(t *testing.T) {
	home := snapshotHome(t)
	path := filepath.Join(home, "large.yaml")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = file.WriteString(snapshotFixture + "#")
	padding := strings.Repeat("x", 1<<20)
	remaining := MaxSnapshotBytes - int64(len(snapshotFixture)+1)
	for remaining > 0 {
		n := remaining
		if n > int64(len(padding)) {
			n = int64(len(padding))
		}
		_, _ = file.WriteString(padding[:n])
		remaining -= n
	}
	_ = file.Close()
	mapping := map[string]any{"type": "file", "path": "large.yaml"}
	if nodes, err := ReadProxyMappings(context.Background(), mapping); err != nil || len(nodes) != 2 {
		t.Fatal("64 MiB rejected", err)
	}
	file, err = os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = file.WriteString("x")
	_ = file.Close()
	if _, err := ReadProxyMappings(context.Background(), mapping); err == nil {
		t.Fatal("64 MiB + 1 accepted")
	}
}

func TestProviderSnapshotInlineAndSafePath(t *testing.T) {
	snapshotHome(t)
	nodes, err := ReadProxyMappings(context.Background(), map[string]any{"type": "inline", "payload": []map[string]any{{"name": "inline", "type": "direct"}}})
	if err != nil || len(nodes) != 1 {
		t.Fatal("inline rejected", err)
	}
	if _, err := ReadProxyMappings(context.Background(), map[string]any{"type": "file", "path": "../outside.yaml"}); err == nil {
		t.Fatal("unsafe path accepted")
	}
}
