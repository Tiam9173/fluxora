package main

import (
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"net/url"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/tunnel"
)

func TestStartListenerRejectsUnconfiguredAndOccupiedPort(t *testing.T) {
	previous := currentConfig
	proxies, providers, mode := tunnel.Proxies(), tunnel.Providers(), tunnel.Mode()
	status := tunnel.Status()
	allowed, denied, skipAuth := inbound.AllowedIPs(), inbound.DisAllowedIPs(), inbound.SkipAuthPrefixes()
	t.Cleanup(func() {
		handleStopListener()
		currentConfig = previous
		tunnel.UpdateProxies(proxies, providers)
		tunnel.SetMode(mode)
		inbound.SetAllowedIPs(allowed)
		inbound.SetDisAllowedIPs(denied)
		inbound.SetSkipAuthPrefixes(skipAuth)
		switch status {
		case tunnel.Inner:
			tunnel.OnInnerLoading()
		case tunnel.Running:
			tunnel.OnRunning()
		default:
			tunnel.OnSuspend()
		}
	})
	currentConfig = nil
	if handleStartListener() || isRunning {
		t.Fatal("unconfigured core reported running")
	}
	blocker, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer blocker.Close()
	port := blocker.Addr().(*net.TCPAddr).Port
	currentConfig = &config.Config{General: &config.General{
		Inbound: config.Inbound{
			MixedPort: port, BindAddress: "127.0.0.1",
			LanAllowedIPs: []netip.Prefix{netip.MustParsePrefix("127.0.0.1/32")},
		},
	}}
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"DIRECT": adapter.NewProxy(outbound.NewDirect()),
	}, nil)
	tunnel.SetMode(tunnel.Direct)
	tunnel.OnRunning()
	if handleStartListener() || isRunning {
		t.Fatal("core reported running with an occupied mixed port")
	}
	if err := blocker.Close(); err != nil {
		t.Fatal(err)
	}
	if !handleStartListener() || listener.GetPorts().MixedPort != port {
		t.Fatal("core could not start after the port became available")
	}

	origin := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer origin.Close()
	proxy := &url.URL{Scheme: "http", Host: blocker.Addr().String()}
	client := origin.Client()
	transport := client.Transport.(*http.Transport)
	transport.Proxy = http.ProxyURL(proxy)
	defer transport.CloseIdleConnections()
	client.Timeout = 5 * time.Second
	response, err := client.Get(origin.URL)
	if err != nil {
		t.Fatalf("HTTPS through the restarted mixed listener: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("HTTPS through the mixed listener returned %s", response.Status)
	}
}
