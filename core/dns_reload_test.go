package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"

	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
)

func TestDNSOnlyReloadKeepsRuleProvider(t *testing.T) {
	previousConfig, previousRaw, previousRunning := currentConfig, currentRawConfig, isRunning
	previousHome := constant.Path.HomeDir()
	previousTestURL := constant.DefaultTestURL
	home := t.TempDir()
	constant.SetHomeDir(home)
	isRunning = false
	t.Cleanup(func() {
		if currentConfig != nil {
			if provider := currentConfig.RuleProviders["fixture"]; provider != nil {
				_ = provider.(interface{ Close() error }).Close()
			}
		}
		var previousDNS config.DNS
		var ipv6 bool
		if previousConfig != nil && previousConfig.DNS != nil {
			previousDNS, ipv6 = *previousConfig.DNS, previousConfig.General.IPv6
		}
		executor.ReloadDNS(&previousDNS, ipv6)
		currentConfig, currentRawConfig, isRunning = previousConfig, previousRaw, previousRunning
		constant.SetHomeDir(previousHome)
		constant.DefaultTestURL = previousTestURL
	})

	var downloads int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&downloads, 1)
		_, _ = fmt.Fprintln(w, "payload: ['example.org']")
	}))
	defer server.Close()
	writeConfig := func(nameserver string, ipv6 bool) {
		t.Helper()
		data := fmt.Sprintf(`
ipv6: %t
etag-support: false
profile: {store-selected: false}
dns:
  enable: true
  enhanced-mode: redir-host
  nameserver: %s
rule-providers:
  fixture:
    type: http
    behavior: domain
    url: %s
    path: ./fixture.yaml
    proxy: DIRECT
rules: ['RULE-SET,fixture,DIRECT']
`, ipv6, nameserver, server.URL)
		if err := os.WriteFile(filepath.Join(home, constant.Path.Config()), []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}

	writeConfig("[127.0.0.1:15301]", true)
	if err := setupConfig(defaultSetupParams()); err != nil {
		t.Fatal(err)
	}
	provider := currentConfig.RuleProviders["fixture"]
	originalResolver := resolver.DefaultResolver
	if atomic.LoadInt32(&downloads) != 1 {
		t.Fatal("initial setup did not download the fixture")
	}
	if err := os.Remove(filepath.Join(home, "fixture.yaml")); err != nil {
		t.Fatal(err)
	}
	isRunning = true

	writeConfig("[]", true)
	if err := setupConfig(defaultSetupParams()); err == nil || resolver.DefaultResolver != originalResolver {
		t.Fatalf("invalid DNS changed the live resolver: %v", err)
	}
	writeConfig("[127.0.0.1:15302]", true)
	if err := setupConfig(defaultSetupParams()); err != nil {
		t.Fatal(err)
	}
	if currentConfig.RuleProviders["fixture"] != provider || atomic.LoadInt32(&downloads) != 1 {
		t.Fatal("DNS-only reload rebuilt or downloaded the rule provider")
	}
	if resolver.DefaultResolver == originalResolver || currentConfig.DNS.NameServer[0].Addr != "127.0.0.1:15302" {
		t.Fatal("DNS-only reload did not install the new resolver")
	}

	writeConfig("[127.0.0.1:15303]", false)
	if err := setupConfig(defaultSetupParams()); err != nil {
		t.Fatal(err)
	}
	if currentConfig.General.IPv6 || currentConfig.RuleProviders["fixture"] == provider || atomic.LoadInt32(&downloads) != 2 {
		t.Fatal("an IPv6 change must apply the entire configuration")
	}
}
