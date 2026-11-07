package main

import (
	"context"
	"net/http"
	"strings"
	"testing"
)

func TestSpeedClientDoesNotFallBackToDirectOnUnknownOutbound(t *testing.T) {
	client := newSpeedClient("missing-speed-test-outbound")
	defer client.CloseIdleConnections()
	transport := client.Transport.(*http.Transport)
	// This must reject the route before resolving or dialing the address.
	conn, err := transport.DialContext(context.Background(), "tcp", "invalid-address")
	if conn != nil || err == nil || !strings.Contains(err.Error(), "missing-speed-test-outbound") {
		t.Fatalf("expected a route rejection without a direct dial, got conn=%v err=%v", conn, err)
	}
}
