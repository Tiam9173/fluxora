//go:build android

package dns

import (
	"sync/atomic"

	"github.com/metacubex/mihomo/component/resolver"
)

var systemResolver atomic.Value

func FlushCacheWithDefaultResolver() {
	resolver.ClearCache()
	resolver.ResetConnection()
}

func UpdateSystemDNS(addr []string) {
	ns := make([]NameServer, 0, len(addr))
	for _, d := range addr {
		ns = append(ns, NameServer{Addr: d})
	}

	systemResolver.Store(transform(ns, nil))
}

func (c *systemClient) getDnsClients() ([]dnsClient, error) {
	clients, _ := systemResolver.Load().([]dnsClient)
	return clients, nil
}

func (c *systemClient) ResetConnection() {
	clients, _ := c.getDnsClients()
	for _, r := range clients {
		r.ResetConnection()
	}
}
