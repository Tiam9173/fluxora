package config

import (
	"testing"

	"github.com/metacubex/mihomo/common/yaml"
	C "github.com/metacubex/mihomo/constant"
	"github.com/stretchr/testify/require"
)

func TestParseFakeIPFilterBypass(t *testing.T) {
	raw := DefaultRawConfig()
	require.NoError(t, yaml.Unmarshal([]byte("dns:\n  enable: true\n  enhanced-mode: fake-ip\n  fake-ip-filter-bypass:\n    - private-dns.example\n"), raw))
	require.Equal(t, C.DNSFakeIP, raw.DNS.EnhancedMode)

	dnsConfig, err := parseDNS(raw, nil)
	require.NoError(t, err)
	require.True(t, dnsConfig.FakeIPSkipper.ShouldSkipped("private-dns.example"))
}
