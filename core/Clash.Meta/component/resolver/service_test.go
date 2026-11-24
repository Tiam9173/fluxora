package resolver

import (
	"context"
	"errors"
	"testing"

	D "github.com/miekg/dns"
)

type systemServiceProbe struct {
	Resolver
	calls int
}

func (p *systemServiceProbe) ExchangeContext(_ context.Context, msg *D.Msg) (*D.Msg, error) {
	p.calls++
	return new(D.Msg).SetRcode(msg, D.RcodeNameError), nil
}

type failingDNSService struct{}

func (failingDNSService) ServeMsg(context.Context, *D.Msg) (*D.Msg, error) {
	return nil, ErrIPNotFound
}

func TestServeMsgUsesSystemWhenDNSServiceDisabled(t *testing.T) {
	savedService, savedSystem := DefaultService, SystemResolver
	t.Cleanup(func() {
		DefaultService, SystemResolver = savedService, savedSystem
	})

	ctx := context.Background()
	query := new(D.Msg).SetQuestion("test.invalid.", D.TypeHTTPS)
	system := &systemServiceProbe{}
	DefaultService, SystemResolver = nil, system
	response, err := ServeMsg(ctx, query)
	if err != nil || response == nil || response.Rcode != D.RcodeNameError || response.Id != query.Id {
		t.Fatalf("system DNS response = %v, error = %v", response, err)
	}
	if system.calls != 1 {
		t.Fatalf("system DNS calls = %d, want 1", system.calls)
	}

	DefaultService = failingDNSService{}
	if _, err := ServeMsg(ctx, query); !errors.Is(err, ErrIPNotFound) || system.calls != 1 {
		t.Fatalf("configured DNS error = %v, system DNS calls = %d", err, system.calls)
	}
}
