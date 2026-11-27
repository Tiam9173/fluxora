package dns

import (
	"io"
	"net"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

func TestResetConnectionClosesPolicyTransports(t *testing.T) {
	main := NameServer{Net: "tls", Addr: "192.0.2.1:853"}
	policy := NameServer{Net: "tls", Addr: "192.0.2.2:853"}
	proxyPolicy := NameServer{Net: "tls", Addr: "192.0.2.3:853"}
	rs := NewResolver(Config{
		Main:               []NameServer{main},
		ProxyServer:        []NameServer{main},
		DirectServer:       []NameServer{main},
		Policy:             []Policy{{Domain: "policy.test", NameServers: []NameServer{policy}}},
		ProxyServerPolicy:  []Policy{{Domain: "proxy.test", NameServers: []NameServer{proxyPolicy}}},
		DirectFollowPolicy: true,
	})

	question := new(D.Msg).SetQuestion("policy.test.", D.TypeA)
	policyClient := rs.matchPolicy(question)[0]
	if rs.DirectResolver.matchPolicy(question)[0] != policyClient {
		t.Fatal("direct resolver does not share the main DNS policy")
	}

	question.SetQuestion("proxy.test.", D.TypeA)
	clients := map[string]dnsClient{
		"main":         rs.main[0],
		"policy":       policyClient,
		"proxy policy": rs.ProxyResolver.matchPolicy(question)[0],
	}
	peers := make(map[string]net.Conn, len(clients))
	for name, client := range clients {
		conn, peer := net.Pipe()
		t.Cleanup(func() {
			_ = conn.Close()
			_ = peer.Close()
		})
		client.(*dnsOverTLS).connections.PushBack(conn)
		peers[name] = peer
		if err := peer.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}

	rs.ResetConnection()
	for name, peer := range peers {
		if _, err := peer.Read(make([]byte, 1)); err != io.EOF {
			t.Errorf("%s: read error = %v, want EOF", name, err)
		}
	}
}
