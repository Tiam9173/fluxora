//go:build !cgo

package main

import (
	"encoding/json"
	"net"
	"testing"
	"time"
)

func TestProviderSnapshotActionReply(t *testing.T) {
	client, peer := net.Pipe()
	previous := conn
	conn = client
	t.Cleanup(func() {
		_ = client.Close()
		_ = peer.Close()
		connMu.Lock()
		conn = previous
		connMu.Unlock()
	})
	_ = peer.SetDeadline(time.Now().Add(5 * time.Second))
	for _, tc := range []struct {
		name string
		data any
		code int
	}{
		{"invalidType", 42, -1},
		{"invalidJSON", "{", -1},
		{"inline", `{"type":"inline","payload":[{"name":"node","type":"trojan","server":"tls.example.test","sni":"tls.example.test","skip-cert-verify":false}]}`, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			handleAction(&Action{Method: readProviderNodesMethod, Data: tc.data}, ActionResult{Id: tc.name, Method: readProviderNodesMethod})
			payload, err := readFrame(peer)
			if err != nil {
				t.Fatal(err)
			}
			var response ActionResult
			if err := json.Unmarshal(payload, &response); err != nil {
				t.Fatal(err)
			}
			if response.Code != tc.code || response.Id != tc.name || response.Method != readProviderNodesMethod {
				t.Fatal("incorrect bridge response")
			}
			if tc.code == 0 {
				node := response.Data.([]any)[0].(map[string]any)
				if node["server"] != "tls.example.test" || node["sni"] != "tls.example.test" || node["skip-cert-verify"] != false {
					t.Fatal("bridge changed TLS identity")
				}
			}
		})
	}
}
