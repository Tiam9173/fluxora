package main

import (
	"crypto/tls"
	"net/http"
	"net/url"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/component/proxydialer"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// The mixed-port check already exercised the normal rules for the test URL.
// Check the first enabled catch-all separately, since the URL may match an
// earlier rule. Explicit block/direct policies do not require a proxy probe.
func checkDefaultRoute(target string) bool {
	u, err := url.Parse(target)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" {
		return false
	}
	runLock.Lock()
	mode, rules, proxies := tunnel.Mode(), tunnel.Rules(), tunnel.Proxies()
	runLock.Unlock()
	if mode != tunnel.Rule {
		return true
	}
	for _, rule := range rules {
		if rule.RuleType() != C.MATCH {
			continue
		}
		if wrapped, ok := rule.(C.RuleWrapper); ok && wrapped.IsDisabled() {
			continue
		}
		proxy := proxies[rule.Adapter()]
		if proxy == nil {
			return false
		}
		switch proxy.Type() {
		case C.Direct, C.Reject, C.RejectDrop, C.Pass, C.PassRule:
			return true
		}
		transport := &http.Transport{
			DialContext:       proxydialer.New(proxy, false).DialContext,
			DisableKeepAlives: true,
			TLSClientConfig:   &tls.Config{RootCAs: ca.GetCertPool()},
		}
		client := http.Client{
			Transport:     transport,
			Timeout:       5 * time.Second,
			CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
		}
		resp, err := client.Get(target)
		if err != nil {
			return false
		}
		defer resp.Body.Close()
		return resp.StatusCode >= 200 && resp.StatusCode < 300
	}
	return true
}
