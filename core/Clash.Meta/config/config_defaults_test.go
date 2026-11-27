package config

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDefaultRawConfigFakeIPFilterIncludesWindowsConnectivityChecks(t *testing.T) {
	filter := DefaultRawConfig().DNS.FakeIPFilter
	require.Contains(t, filter, "dns.msftncsi.com")
	require.Contains(t, filter, "www.msftncsi.com")
	require.Contains(t, filter, "www.msftconnecttest.com")
}
