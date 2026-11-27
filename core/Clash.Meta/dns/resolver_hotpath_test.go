package dns

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

func startTestDNS(tb testing.TB, beforeReply func()) (string, *atomic.Int64) {
	tb.Helper()
	conn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		tb.Fatal(err)
	}
	var calls atomic.Int64
	server := &D.Server{PacketConn: conn, Handler: D.HandlerFunc(func(w D.ResponseWriter, req *D.Msg) {
		calls.Add(1)
		if beforeReply != nil {
			beforeReply()
		}
		reply := new(D.Msg).SetReply(req)
		question := req.Question[0]
		h := D.RR_Header{Name: question.Name, Rrtype: question.Qtype, Class: question.Qclass, Ttl: 600}
		switch question.Qtype {
		case D.TypeA:
			reply.Answer = []D.RR{&D.A{Hdr: h, A: net.IPv4(192, 0, 2, 1)}}
		case D.TypeAAAA:
			reply.Answer = []D.RR{&D.AAAA{Hdr: h, AAAA: net.ParseIP("2001:db8::1")}}
		case D.TypeTXT:
			reply.Answer = []D.RR{&D.TXT{Hdr: h, Txt: []string{"value"}}}
		}
		_ = w.WriteMsg(reply)
	})}
	ready := make(chan struct{})
	server.NotifyStartedFunc = func() { close(ready) }
	done := make(chan error, 1)
	go func() { done <- server.ActivateAndServe() }()
	select {
	case <-ready:
	case err := <-done:
		tb.Fatal(err)
	}
	tb.Cleanup(func() {
		_ = server.Shutdown()
		if err := <-done; err != nil {
			tb.Error(err)
		}
	})
	return conn.LocalAddr().String(), &calls
}

func testResolver(addr, cache string) *Resolver {
	return NewResolver(Config{Main: []NameServer{{Net: "udp", Addr: addr}}, IPv6: true, CacheAlgorithm: cache}).Resolver
}

func queryTestDNS(t testing.TB, r *Resolver, m *D.Msg) *D.Msg {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	reply, err := r.ExchangeContext(ctx, m)
	if err != nil || reply == nil || len(reply.Answer) != 1 {
		t.Fatalf("DNS reply=%v error=%v", reply, err)
	}
	return reply
}

func TestDNSCacheIsolation(t *testing.T) {
	addr, calls := startTestDNS(t, nil)
	for _, kind := range []string{"lru", "arc"} {
		t.Run(kind, func(t *testing.T) {
			r := testResolver(addr, kind)
			other := testResolver(addr, kind)
			first := calls.Load()
			for _, typ := range []uint16{D.TypeA, D.TypeAAAA, D.TypeTXT} {
				m := new(D.Msg).SetQuestion("isolation.example.", typ)
				reply := queryTestDNS(t, r, m)
				reply.Answer[0].Header().Rrtype = D.TypeNULL
				if got := queryTestDNS(t, r, m).Answer[0].Header().Rrtype; got != typ {
					t.Fatalf("cache mutated or confused type: %d != %d", got, typ)
				}
			}
			m := new(D.Msg).SetQuestion("isolation.example.", D.TypeTXT)
			m.Question[0].Qclass = D.ClassCHAOS
			if got := queryTestDNS(t, r, m).Answer[0].Header().Class; got != D.ClassCHAOS {
				t.Fatalf("cache confused class: %d", got)
			}
			queryTestDNS(t, other, m)
			if count := calls.Load() - first; count != 5 {
				t.Fatalf("upstream calls=%d, want 5", count)
			}
		})
	}
}

func TestDNSSharedQueryCancellationAndExpiry(t *testing.T) {
	release := make(chan struct{})
	var once sync.Once
	unblock := func() { once.Do(func() { close(release) }) }
	addr, calls := startTestDNS(t, func() { <-release })
	defer unblock()
	r := testResolver(addr, "lru")
	m := new(D.Msg).SetQuestion("concurrent.example.", D.TypeA)
	var wg sync.WaitGroup
	ready := make(chan struct{})
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-ready
			reply, err := r.ExchangeContext(context.Background(), m)
			if err != nil || reply == nil || len(reply.Answer) != 1 {
				t.Errorf("shared reply=%v error=%v", reply, err)
			}
		}()
	}
	close(ready)
	deadline := time.Now().Add(time.Second)
	for calls.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if calls.Load() == 0 {
		t.Fatal("upstream did not receive the shared request")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := r.ExchangeContext(ctx, m); !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation, got %v", err)
	}
	ctx, cancel = context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()
	if _, err := r.ExchangeContext(ctx, m); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline, got %v", err)
	}
	unblock()
	wg.Wait()
	queryTestDNS(t, r, m)
	if got := calls.Load(); got != 1 {
		t.Fatalf("shared requests reached upstream %d times", got)
	}
	stale := queryTestDNS(t, r, m)
	r.cache.SetWithExpire(m.Question[0].String(), stale, time.Now().Add(-time.Minute))
	if ttl := queryTestDNS(t, r, m).Answer[0].Header().Ttl; ttl != 1 {
		t.Fatalf("stale TTL=%d, want 1", ttl)
	}
	limit := time.Now().Add(time.Second)
	for calls.Load() < 2 && time.Now().Before(limit) {
		time.Sleep(time.Millisecond)
	}
	if calls.Load() != 2 {
		t.Fatalf("expired response failed to refresh once: %d", calls.Load())
	}
}

func BenchmarkDNSQuery(b *testing.B) {
	addr, _ := startTestDNS(b, nil)
	for _, mode := range []string{"cached", "udp"} {
		b.Run(mode, func(b *testing.B) {
			r := testResolver(addr, "lru")
			m := new(D.Msg).SetQuestion("load.example.", D.TypeA)
			queryTestDNS(b, r, m)
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if mode == "udp" {
					m.SetQuestion(fmt.Sprintf("load-%d.example.", i), D.TypeA)
				}
				msg, err := r.ExchangeContext(context.Background(), m)
				if err != nil || msg == nil || len(msg.Answer) != 1 {
					b.Fatalf("reply=%v error=%v", msg, err)
				}
			}
		})
	}
}
