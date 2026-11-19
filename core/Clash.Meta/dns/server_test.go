package dns

import (
	"context"
	"net"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

type testDNSListenerService struct{}

func (testDNSListenerService) ServeMsg(_ context.Context, msg *D.Msg) (*D.Msg, error) {
	return new(D.Msg).SetReply(msg), nil
}

func TestDNSListenerRetriesMissingProtocol(t *testing.T) {
	occupied, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	t.Cleanup(func() { ReCreateServer("", nil, nil) })

	addr := occupied.Addr().String()
	lc := &net.ListenConfig{}
	service := testDNSListenerService{}
	ReCreateServer(addr, lc, service)
	msg := new(D.Msg).SetQuestion("listener.test.", D.TypeA)

	query := func(network string) {
		t.Helper()
		client := &D.Client{Net: network, Timeout: time.Second}
		reply, _, err := client.Exchange(msg, addr)
		if err != nil {
			t.Fatalf("%s: %v", network, err)
		}
		if !reply.Response || reply.Id != msg.Id {
			t.Fatalf("%s: unexpected reply %v", network, reply)
		}
	}

	query("udp")
	if err := occupied.Close(); err != nil {
		t.Fatal(err)
	}
	ReCreateServer(addr, lc, service)
	query("tcp")
	query("udp")
}
