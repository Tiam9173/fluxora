package socks5

import (
	"bytes"
	"testing"
)

func TestEncodeUDPPacketTo(t *testing.T) {
	for _, target := range []string{"127.0.0.1:53", "[::1]:53", "example.test:53"} {
		addr := ParseAddr(target)
		for _, payload := range [][]byte{nil, []byte("payload"), bytes.Repeat([]byte{42}, 65500)} {
			want := append([]byte{0, 0, 0}, addr...)
			want = append(want, payload...)
			for _, buffer := range [][]byte{nil, bytes.Repeat([]byte{255}, len(want)+3)} {
				got, err := EncodeUDPPacketTo(buffer, addr, payload)
				if err != nil || !bytes.Equal(got, want) {
					t.Fatalf("encode %s with %d payload bytes: %v", target, len(payload), err)
				}
				if len(buffer) != 0 && &got[0] != &buffer[0] {
					t.Fatal("did not reuse buffer with enough capacity")
				}
			}
		}
	}
	if got, err := EncodeUDPPacketTo(make([]byte, 16), nil, nil); err == nil || got != nil {
		t.Fatal("accepted missing address")
	}
}
