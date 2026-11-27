package outbound

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"net/netip"
	"strings"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
	wgconn "github.com/metacubex/wireguard-go/conn"
	"github.com/metacubex/wireguard-go/device"
)

func TestWireGuardCoreX(t *testing.T) {
	for _, stackMode := range []string{ipStackMips, ipStackGVisor} {
		t.Run(stackMode, func(t *testing.T) {
			curve := ecdh.X25519()
			clientKey, err := curve.GenerateKey(rand.Reader)
			if err != nil {
				t.Fatal(err)
			}
			serverKey, err := curve.GenerateKey(rand.Reader)
			if err != nil {
				t.Fatal(err)
			}
			ip := netip.MustParseAddr("10.55.0.2")
			stack, err := newIPStack(IPStackOption{Mode: stackMode}, []netip.Prefix{netip.PrefixFrom(ip, 24)}, 1280)
			if err != nil {
				t.Fatal(err)
			}
			tunDevice, err := newWireguardDevice(stack)
			if err != nil {
				stack.Close()
				t.Fatal(err)
			}
			peer := device.NewDevice(tunDevice, wgconn.NewStdNetBind(), device.NewLogger(device.LogLevelSilent, ""), 2)
			defer peer.Close()
			conf := fmt.Sprintf("private_key=%x\nlisten_port=0\npublic_key=%x\nallowed_ip=10.55.0.1/32\n",
				serverKey.Bytes(), clientKey.PublicKey().Bytes())
			if err := peer.IpcSet(conf); err != nil {
				t.Fatal(err)
			}
			if err := peer.Up(); err != nil {
				t.Fatal(err)
			}
			boundPort := func() int {
				snapshot, err := peer.IpcGet()
				if err != nil {
					t.Fatal(err)
				}
				for _, line := range strings.Split(snapshot, "\n") {
					var port int
					if _, err := fmt.Sscanf(line, "listen_port=%d", &port); err == nil && port > 0 {
						return port
					}
				}
				t.Fatal("WireGuard peer did not bind UDP")
				return 0
			}
			port := boundPort()
			ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
			defer cancel()
			origin, err := stack.ListenTCP(ctx, "tcp4", netip.AddrPortFrom(ip, 19222))
			if err != nil {
				t.Fatal(err)
			}
			defer origin.Close()
			go func() {
				for {
					c, err := origin.Accept()
					if err != nil {
						return
					}
					c.SetDeadline(time.Now().Add(time.Second))
					io.CopyN(c, c, 5)
					c.Close()
				}
			}()
			for i := 0; i < 2; i++ {
				if i == 1 {
					if err := peer.IpcSet("listen_port=0\n"); err != nil {
						t.Fatal(err)
					}
					if updated := boundPort(); updated != port {
						port = updated
					} else {
						t.Fatal("fixture peer port did not change")
					}
				}
				client, err := NewWireGuard(WireGuardOption{
					Name: "corex-fixture", Ip: "10.55.0.1", Workers: 2, MTU: 1280,
					PrivateKey: base64.StdEncoding.EncodeToString(clientKey.Bytes()),
					IPStack:    IPStackOption{Mode: stackMode},
					WireGuardPeerOption: WireGuardPeerOption{
						Server: "127.0.0.1", Port: port, AllowedIPs: []string{"10.55.0.2/32"},
						PublicKey: base64.StdEncoding.EncodeToString(serverKey.PublicKey().Bytes()),
					},
				})
				if err != nil {
					t.Fatal(err)
				}
				defer client.Close()
				start := time.Now()
				c, err := client.DialContext(ctx, &C.Metadata{DstIP: ip, DstPort: 19222})
				if err != nil {
					t.Fatal(err)
				}
				c.SetDeadline(time.Now().Add(time.Second))
				if _, err := io.WriteString(c, "probe"); err != nil {
					c.Close()
					t.Fatal(err)
				}
				reply := make([]byte, 5)
				_, err = io.ReadFull(c, reply)
				c.Close()
				if err != nil || string(reply) != "probe" {
					t.Fatalf("WireGuard echo failed: %q %v", reply, err)
				}
				snapshot, err := peer.IpcGet()
				if err != nil || !strings.Contains(snapshot, "public_key="+hex.EncodeToString(clientKey.PublicKey().Bytes())) ||
					strings.Contains(snapshot, "last_handshake_time_sec=0\n") ||
					!strings.Contains(snapshot, "last_handshake_time_sec=") {
					t.Fatal("encrypted exchange did not produce a verified peer handshake")
				}
				t.Logf("attempt %d first echo %v", i+1, time.Since(start))
				client.Close()
			}
		})
	}
}
