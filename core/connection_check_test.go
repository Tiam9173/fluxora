package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/tunnel"
)

func TestCheckDefaultRouteUsesCatchAllAndRequiresSuccess(t *testing.T) {
	var status atomic.Int32
	status.Store(http.StatusNoContent)
	origin := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(int(status.Load()))
	}))
	defer origin.Close()
	if err := ca.AddCertificate(string(origin.Certificate().Raw)); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(ca.ResetCertificate)
	hop, hits := routeTestHop(t, origin.Listener.Addr().String())
	cfg, err := config.Parse([]byte(fmt.Sprintf("proxies:\n  - {name: exit, type: http, server: 127.0.0.1, port: %d}\nrules: ['IP-CIDR,127.0.0.1/32,DIRECT', 'MATCH,exit']\n", hop)))
	if err != nil {
		t.Fatal(err)
	}
	proxies, providers, mode := tunnel.Proxies(), tunnel.Providers(), tunnel.Mode()
	rules, rp := tunnel.Rules(), tunnel.RuleProviders()
	t.Cleanup(func() {
		tunnel.UpdateProxies(proxies, providers)
		tunnel.UpdateRules(rules, nil, rp)
		tunnel.SetMode(mode)
	})
	tunnel.UpdateProxies(cfg.Proxies, cfg.Providers)
	tunnel.UpdateRules(cfg.Rules, nil, cfg.RuleProviders)
	tunnel.SetMode(tunnel.Rule)
	if !checkDefaultRoute(origin.URL) || hits.Load() != 1 {
		t.Fatal("healthy catch-all was not reached through the configured hop")
	}
	for _, code := range []int{http.StatusFound, http.StatusBadGateway} {
		status.Store(int32(code))
		if checkDefaultRoute(origin.URL) {
			t.Fatalf("catch-all returned %d but was marked healthy", code)
		}
	}
	status.Store(http.StatusNoContent)
	if !checkDefaultRoute(origin.URL) {
		t.Fatal("recovered route was not recognized")
	}
}

func routeTestHop(t *testing.T, destination string) (int, *atomic.Int32) {
	t.Helper()
	count := new(atomic.Int32)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect || r.Host != destination {
			http.Error(w, "wrong hop", http.StatusBadRequest)
			return
		}
		next, err := net.DialTimeout("tcp", destination, 2*time.Second)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		defer next.Close()
		client, buf, err := w.(http.Hijacker).Hijack()
		if err != nil {
			return
		}
		defer client.Close()
		count.Add(1)
		fmt.Fprint(buf, "HTTP/1.1 200 Connection established\r\n\r\n")
		buf.Flush()
		go func() { io.Copy(next, buf); next.Close() }()
		io.Copy(client, next)
	}))
	t.Cleanup(server.Close)
	return server.Listener.Addr().(*net.TCPAddr).Port, count
}
