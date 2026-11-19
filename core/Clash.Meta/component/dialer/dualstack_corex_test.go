package dialer

import (
	"context"
	"errors"
	"io"
	"net"
	"net/netip"
	"sync"
	"testing"
	"time"
)

func TestDualStackCoreX(t *testing.T) {
	ipv4 := netip.MustParseAddr("127.0.0.1")
	ipv6 := netip.MustParseAddr("::1")
	for _, scenario := range []string{"preferred-v6", "stalled-v6", "failed-v6", "only-v6"} {
		t.Run(scenario, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			listeners := make(map[netip.Addr]net.Listener)
			peers := make(chan net.Conn, 2)
			var acceptors sync.WaitGroup
			for _, ip := range []netip.Addr{ipv4, ipv6} {
				l, err := net.Listen("tcp", net.JoinHostPort(ip.String(), "0"))
				if err != nil {
					t.Skipf("loopback %s unavailable: %v", ip, err)
				}
				defer l.Close()
				listeners[ip] = l
				acceptors.Add(1)
				go func() {
					defer acceptors.Done()
					if c, err := l.Accept(); err == nil {
						peers <- c
					}
				}()
			}
			defer func() {
				for _, l := range listeners {
					l.Close()
				}
				acceptors.Wait()
				for len(peers) > 0 {
					(<-peers).Close()
				}
			}()
			want := ipv6
			ips := []netip.Addr{ipv4, ipv6}
			if scenario == "only-v6" {
				ips = []netip.Addr{ipv6}
			} else if scenario != "preferred-v6" {
				want = ipv4
			}
			stalledDone := make(chan struct{})
			start := time.Now()
			c, err := dualStackDialContext(ctx, func(ctx context.Context, _ string, ips []netip.Addr, _ string, _ option) (net.Conn, error) {
				ip := ips[0]
				if ip == ipv6 && scenario == "stalled-v6" {
					defer close(stalledDone)
					<-ctx.Done()
					return nil, ctx.Err()
				}
				if ip == ipv6 && scenario == "failed-v6" {
					return nil, errors.New("fixture IPv6 unavailable")
				}
				var d net.Dialer
				return d.DialContext(ctx, "tcp", listeners[ip].Addr().String())
			}, "tcp", ips, "", option{prefer: 6})
			elapsed := time.Since(start)
			if err != nil {
				t.Fatal(err)
			}
			defer c.Close()
			if got := c.RemoteAddr().(*net.TCPAddr).AddrPort().Addr().Unmap(); got != want {
				t.Fatalf("winner %s, want %s", got, want)
			}
			if scenario == "preferred-v6" {
				for i := 0; i < 2; i++ {
					select {
					case p := <-peers:
						defer p.Close()
						if p.LocalAddr().(*net.TCPAddr).AddrPort().Addr().Unmap() == ipv4 {
							p.SetReadDeadline(time.Now().Add(time.Second))
							if _, err := p.Read(make([]byte, 1)); err != io.EOF {
								t.Fatalf("losing socket was not closed: %v", err)
							}
						}
					case <-ctx.Done():
						t.Fatal("racing loopback socket did not connect")
					}
				}
			}
			if scenario == "stalled-v6" {
				if elapsed < 250*time.Millisecond || elapsed >= 1500*time.Millisecond {
					t.Fatalf("unexpected alternate address timing: %v", elapsed)
				}
				cancel()
				select {
				case <-stalledDone:
				case <-time.After(time.Second):
					t.Fatal("cancelled connector did not return")
				}
			}
			t.Logf("winner=%s elapsed=%v", want, elapsed)
		})
	}
}
