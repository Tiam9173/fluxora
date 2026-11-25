package tunnel

import (
	"errors"
	"net/netip"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	"github.com/stretchr/testify/require"
)

func TestConfigReloadTCPAdmission(t *testing.T) {
	for _, suspend := range []bool{false, true} {
		name := "config applied"
		if suspend {
			name = "explicit suspend"
		}
		t.Run(name, func(t *testing.T) {
			original := Status()
			t.Cleanup(func() { status.Store(original) })
			OnRunning()
			finish := BeginConfigReload()
			t.Cleanup(finish)
			OnConfigApplying()
			OnInnerLoading()
			require.True(t, waitForTCPReady(C.INNER))

			ready := make(chan bool, 1)
			go func() { ready <- waitForTCPReady(C.SOCKS5) }()
			require.Eventually(t, func() bool {
				return len(configReloadTCPWait) == 1
			}, time.Second, time.Millisecond)

			if suspend {
				OnSuspend()
				OnRunning() // Resume must not admit a waiter cancelled by suspend.
			} else {
				OnRunning()
				select {
				case <-ready:
					t.Fatal("TCP connection advanced before the app finished applying the configuration")
				default:
				}
				finish()
			}
			select {
			case usable := <-ready:
				require.Equal(t, !suspend, usable)
			case <-time.After(time.Second):
				t.Fatal("TCP connection still waiting after configuration transition")
			}
		})
	}
}

func TestConfigReloadTCPWaitIsBounded(t *testing.T) {
	original := Status()
	t.Cleanup(func() { status.Store(original) })
	OnRunning()
	finish := BeginConfigReload()
	t.Cleanup(finish)
	OnConfigApplying()

	for i := 0; i < cap(configReloadTCPWait); i++ {
		configReloadTCPWait <- struct{}{}
	}
	require.False(t, waitForTCPReady(C.SOCKS5), "reject when the wait slots are full")
	for len(configReloadTCPWait) > 0 {
		<-configReloadTCPWait
	}

	require.False(t, waitForTCPReady(C.SOCKS5), "reject after the reload deadline")
	require.Empty(t, configReloadTCPWait)
}

type reloadTestPacket struct {
	C.PacketAdapter
	metadata  C.Metadata
	drops     atomic.Int32
	rejects   atomic.Int32
	rejectErr error
}

func (p *reloadTestPacket) Metadata() *C.Metadata { return &p.metadata }
func (p *reloadTestPacket) Key() string           { return "reload-test-packet" }
func (p *reloadTestPacket) Drop()                 { p.drops.Add(1) }
func (p *reloadTestPacket) Reject() error         { p.rejects.Add(1); return p.rejectErr }

type noRejectTestPacket struct {
	C.PacketAdapter
	metadata C.Metadata
	drops    atomic.Int32
}

func (p *noRejectTestPacket) Metadata() *C.Metadata { return &p.metadata }
func (p *noRejectTestPacket) Key() string           { return "no-reject-test-packet" }
func (p *noRejectTestPacket) Drop()                 { p.drops.Add(1) }

func TestRejectDisabledIPv6TUNUDP(t *testing.T) {
	original := resolver.DisableIPv6.Load()
	t.Cleanup(func() { resolver.DisableIPv6.Store(original) })

	tests := []struct {
		name        string
		disabled    bool
		inbound     C.Type
		destination string
		wantDrop    bool
	}{
		{name: "global IPv6 TUN", disabled: true, inbound: C.TUN, destination: "2606:4700:4700::1111", wantDrop: true},
		{name: "IPv6 enabled", disabled: false, inbound: C.TUN, destination: "2606:4700:4700::1111"},
		{name: "non-TUN inbound", disabled: true, inbound: C.SOCKS5, destination: "2606:4700:4700::1111"},
		{name: "IPv4", disabled: true, inbound: C.TUN, destination: "8.8.8.8"},
		{name: "IPv4-mapped IPv6", disabled: true, inbound: C.TUN, destination: "::ffff:8.8.8.8"},
		{name: "private IPv6", disabled: true, inbound: C.TUN, destination: "fd00::1"},
		{name: "link-local IPv6", disabled: true, inbound: C.TUN, destination: "fe80::1"},
		{name: "multicast IPv6", disabled: true, inbound: C.TUN, destination: "ff02::1"},
		{name: "loopback IPv6", disabled: true, inbound: C.TUN, destination: "::1"},
		{name: "unspecified IPv6", disabled: true, inbound: C.TUN, destination: "::"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resolver.DisableIPv6.Store(tt.disabled)
			packet := &reloadTestPacket{metadata: C.Metadata{
				Type:  tt.inbound,
				DstIP: netip.MustParseAddr(tt.destination),
			}}

			rejected := rejectDisabledIPv6TUNUDP(packet, &packet.metadata)

			require.Equal(t, tt.wantDrop, rejected)
			if tt.wantDrop {
				require.EqualValues(t, 1, packet.drops.Load())
				require.EqualValues(t, 1, packet.rejects.Load())
			} else {
				require.Zero(t, packet.drops.Load())
				require.Zero(t, packet.rejects.Load())
			}
		})
	}
}

func TestRejectDisabledIPv6TUNUDPWithoutRejectSupport(t *testing.T) {
	original := resolver.DisableIPv6.Load()
	resolver.DisableIPv6.Store(true)
	t.Cleanup(func() { resolver.DisableIPv6.Store(original) })
	packet := &noRejectTestPacket{metadata: C.Metadata{
		Type: C.TUN, DstIP: netip.MustParseAddr("2606:4700:4700::1111"),
	}}

	require.True(t, rejectDisabledIPv6TUNUDP(packet, &packet.metadata))
	require.EqualValues(t, 1, packet.drops.Load())
}

func TestRejectDisabledIPv6TUNUDPStillDropsWhenRejectFails(t *testing.T) {
	original := resolver.DisableIPv6.Load()
	resolver.DisableIPv6.Store(true)
	t.Cleanup(func() { resolver.DisableIPv6.Store(original) })
	packet := &reloadTestPacket{
		metadata:  C.Metadata{Type: C.TUN, DstIP: netip.MustParseAddr("2606:4700:4700::1111")},
		rejectErr: errors.New("reject unsupported by packet transport"),
	}

	require.True(t, rejectDisabledIPv6TUNUDP(packet, &packet.metadata))
	require.EqualValues(t, 1, packet.rejects.Load())
	require.EqualValues(t, 1, packet.drops.Load())
}

func TestConfigReloadUDPAdmission(t *testing.T) {
	for _, suspend := range []bool{false, true} {
		name := "replay after activation"
		if suspend {
			name = "explicit suspend discards pending packets"
		}
		t.Run(name, func(t *testing.T) {
			original := Status()
			t.Cleanup(func() { status.Store(original) })
			OnRunning()
			finish := BeginConfigReload()
			t.Cleanup(finish)
			OnConfigApplying()
			OnInnerLoading()
			ready := configReloadDone.Load()

			internal := &reloadTestPacket{metadata: C.Metadata{Type: C.INNER}}
			require.False(t, deferUDPForReload(udpWork{packet: internal}))
			require.Zero(t, internal.drops.Load())
			packet := &reloadTestPacket{metadata: C.Metadata{Type: C.SOCKS5}}
			enqueueUDP(udpWork{packet: packet})
			require.Eventually(t, func() bool {
				ready.udpMu.Lock()
				defer ready.udpMu.Unlock()
				return len(ready.udpPackets) == 1
			}, 500*time.Millisecond, time.Millisecond)
			require.Zero(t, packet.drops.Load())

			if suspend {
				OnSuspend()
				require.EqualValues(t, 1, packet.drops.Load())
				OnRunning()
			} else {
				OnRunning()
				require.Zero(t, packet.drops.Load())
				finish()
			}
			// The replay reaches the real worker, which drops the invalid metadata.
			require.Eventually(t, func() bool { return packet.drops.Load() == 1 },
				500*time.Millisecond, time.Millisecond)
		})
	}
}

func TestConfigReloadUDPBounds(t *testing.T) {
	original := Status()
	t.Cleanup(func() { status.Store(original) })
	OnRunning()
	finish := BeginConfigReload()
	t.Cleanup(finish)
	ready := configReloadDone.Load()

	packets := make([]*reloadTestPacket, queueCapacity+1)
	for i := range packets {
		packets[i] = &reloadTestPacket{metadata: C.Metadata{Type: C.SOCKS5}}
		require.True(t, deferUDPForReload(udpWork{packet: packets[i]}))
	}
	for _, packet := range packets[:queueCapacity] {
		require.Zero(t, packet.drops.Load())
	}
	require.EqualValues(t, 1, packets[queueCapacity].drops.Load())

	replay := &reloadTestPacket{metadata: C.Metadata{Type: C.SOCKS5}}
	require.True(t, deferUDPForReload(udpWork{packet: replay, reload: ready}))
	require.EqualValues(t, 1, replay.drops.Load(), "a second window cannot retain a replay")

	require.Eventually(t, func() bool {
		for _, packet := range packets {
			if packet.drops.Load() != 1 {
				return false
			}
		}
		return true
	}, 2*time.Second, time.Millisecond)
	require.Same(t, ready, configReloadDone.Load(), "expiry must free packets before reload closes")
	late := &reloadTestPacket{metadata: C.Metadata{Type: C.SOCKS5}}
	require.True(t, deferUDPForReload(udpWork{packet: late}))
	require.EqualValues(t, 1, late.drops.Load())
}
