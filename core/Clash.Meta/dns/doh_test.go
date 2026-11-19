package dns

import (
	"context"
	"errors"
	"net/url"
	"testing"
	"time"

	"github.com/metacubex/http"
	D "github.com/miekg/dns"
)

type blockingDoHTransport struct {
	started chan struct{}
	closed  chan struct{}
}

func (tr *blockingDoHTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	close(tr.started)
	<-req.Context().Done()
	return nil, req.Context().Err()
}

func (tr *blockingDoHTransport) CloseIdleConnections() {
	close(tr.closed)
}

func TestDoHResetRetiresClientAfterInFlightRequest(t *testing.T) {
	tr := &blockingDoHTransport{started: make(chan struct{}), closed: make(chan struct{})}
	old := &dohHTTPClient{Client: &http.Client{Transport: tr}}
	upstream := &dnsOverHTTPS{client: old, url: &url.URL{Scheme: "http", Host: "example.test"}}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	done := make(chan error, 1)
	go func() {
		query := new(D.Msg).SetQuestion("example.test.", D.TypeA)
		_, err := upstream.ExchangeContext(ctx, query)
		done <- err
	}()
	select {
	case <-tr.started:
	case <-ctx.Done():
		t.Fatal("old client never started the request")
	}

	upstream.ResetConnection()
	next, cached, err := upstream.getClient(ctx)
	if err != nil || next == old || cached {
		t.Fatalf("new client = %p, cached = %v, err = %v", next, cached, err)
	}
	next.active.Done()
	defer upstream.Close()

	if current, err := upstream.resetClient(ctx, old, errors.New("retired client failed"), false); err != nil || current != next {
		t.Fatalf("late failure replaced the current client: %p, %v", current, err)
	}
	select {
	case <-tr.closed:
		t.Fatal("old client closed before the request drained")
	default:
	}

	cancel()
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Fatalf("request error = %v, want canceled", err)
	}
	select {
	case <-tr.closed:
	case <-time.After(3 * time.Second):
		t.Fatal("old client was not closed after the request drained")
	}
}
