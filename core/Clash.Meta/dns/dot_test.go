package dns

import (
	"context"
	"io"
	"net"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

func TestDoTResetDuringExchange(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, peer := net.Pipe()
	defer conn.Close()
	defer peer.Close()
	deadline, _ := ctx.Deadline()
	if err := peer.SetDeadline(deadline); err != nil {
		t.Fatal(err)
	}

	client := &dnsOverTLS{}
	client.connections.PushBack(conn)
	server := &D.Conn{Conn: peer}
	serverErr := make(chan error, 1)
	go func() {
		req, err := server.ReadMsg()
		if err == nil {
			client.ResetConnection()
			err = server.WriteMsg(new(D.Msg).SetReply(req))
		}
		serverErr <- err
	}()

	request := new(D.Msg).SetQuestion("dot-reset.test.", D.TypeAAAA)
	reply, err := client.ExchangeContext(ctx, request)
	if err != nil {
		t.Fatal(err)
	}
	if err := <-serverErr; err != nil {
		t.Fatal(err)
	}
	if !reply.Response || reply.Id != request.Id {
		t.Fatalf("unexpected reply: %v", reply)
	}
	var buf [1]byte
	if _, err := peer.Read(buf[:]); err != io.EOF {
		t.Fatalf("connection active at reset returned to the pool: read error = %v", err)
	}
}
