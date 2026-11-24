package state

import (
	"slices"
	"testing"
)

func TestAndroidSystemDNSServersExcludesVPNStub(t *testing.T) {
	got := AndroidSystemDNSServers("172.19.100.2:53,[::ffff:172.19.100.2]:53,,invalid,192.0.2.1:0, 192.0.2.1:53,[fd00::53]:53")
	want := []string{"192.0.2.1:53", "[fd00::53]:53"}
	if !slices.Equal(got, want) {
		t.Fatalf("system DNS = %v, want %v", got, want)
	}
}

func TestAndroidDNSHijackUsesProfileWhenResolverEnabled(t *testing.T) {
	configured := []string{"any:53", "tcp://192.0.2.53:53"}
	want := []string{"172.19.100.2:53", "any:53", "tcp://192.0.2.53:53"}
	if got := AndroidDNSHijackAddresses(configured, true); !slices.Equal(got, want) {
		t.Fatalf("DNS hijack = %v, want %v", got, want)
	}
	if got := AndroidDNSHijackAddresses(configured, false); !slices.Equal(got, want[:1]) {
		t.Fatalf("disabled DNS hijack = %v, want %v", got, want[:1])
	}
}
