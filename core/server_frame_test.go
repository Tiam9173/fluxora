//go:build !cgo

package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"testing"
	"time"
)

type frameFailWriter struct {
	calls, failAt int
	short         bool
}

func (w *frameFailWriter) Write(data []byte) (int, error) {
	w.calls++
	if w.calls == w.failAt {
		if w.short {
			return len(data) - 1, nil
		}
		return 0, io.ErrClosedPipe
	}
	return len(data), nil
}

func TestWriteFrameWireFormatAndErrors(t *testing.T) {
	for _, payload := range [][]byte{nil, []byte("节点\x00\xff"), bytes.Repeat([]byte("large"), 300000)} {
		original := bytes.Clone(payload)
		var wire bytes.Buffer
		if err := writeFrame(&wire, payload); err != nil {
			t.Fatal(err)
		}
		if int(binary.LittleEndian.Uint32(wire.Bytes()[:4])) != len(payload) || !bytes.Equal(wire.Bytes()[4:], payload) {
			t.Fatal("frame length, byte order or payload changed")
		}
		got, err := readFrame(&wire)
		if err != nil || !bytes.Equal(got, payload) || !bytes.Equal(payload, original) {
			t.Fatalf("roundtrip or caller buffer changed: %v", err)
		}
	}
	for _, tc := range []struct {
		name   string
		writer frameFailWriter
		want   error
	}{
		{"header error", frameFailWriter{failAt: 1}, io.ErrClosedPipe},
		{"payload error", frameFailWriter{failAt: 2}, io.ErrClosedPipe},
		{"short header", frameFailWriter{failAt: 1, short: true}, io.ErrShortWrite},
		{"short payload", frameFailWriter{failAt: 2, short: true}, io.ErrShortWrite},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := writeFrame(&tc.writer, []byte("payload")); !errors.Is(err, tc.want) {
				t.Fatalf("write error = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestSendConcurrentFramesOverTCP(t *testing.T) {
	testConcurrentFrames(t, "tcp", "127.0.0.1:0")
}

func TestSendConcurrentFramesOverUnix(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Windows desktop bridge uses TCP")
	}
	// macOS has a short AF_UNIX path limit; t.TempDir includes the test name.
	dir, err := os.MkdirTemp("", "fx-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	testConcurrentFrames(t, "unix", filepath.Join(dir, "bridge.sock"))
}

func testConcurrentFrames(t *testing.T, network, address string) {
	t.Helper()
	listener, err := net.Listen(network, address)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	client, err := net.Dial(network, listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	peer, err := listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer peer.Close()
	if err := client.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if err := peer.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	previous := conn
	conn = client
	var writers sync.WaitGroup
	defer func() {
		_ = client.Close()
		writers.Wait()
		conn = previous
	}()
	for i := 0; i < 24; i++ {
		writers.Add(1)
		go func(i int) {
			defer writers.Done()
			send(bytes.Repeat([]byte{byte(i)}, 65536))
		}(i)
	}
	seen := make(map[byte]bool)
	for i := 0; i < 24; i++ {
		payload, err := readFrame(peer)
		if err != nil {
			t.Fatal(err)
		}
		if len(payload) != 65536 || seen[payload[0]] || !bytes.Equal(payload, bytes.Repeat(payload[:1], 65536)) {
			t.Fatal("concurrent frames interleaved or missing")
		}
		seen[payload[0]] = true
	}
	writers.Wait()
}

func writeFrameContiguous(w io.Writer, data []byte) error {
	frame := make([]byte, 4+len(data))
	binary.LittleEndian.PutUint32(frame, uint32(len(data)))
	copy(frame[4:], data)
	_, err := w.Write(frame)
	return err
}

func BenchmarkWriteFrame(b *testing.B) {
	for _, size := range []int{128, 1 << 20} {
		b.Run(fmt.Sprint(size), func(b *testing.B) {
			payload := make([]byte, size)
			for _, implementation := range []struct {
				name  string
				write func(io.Writer, []byte) error
			}{
				{name: "contiguous", write: writeFrameContiguous},
				{name: "segmented", write: writeFrame},
			} {
				b.Run(implementation.name, func(b *testing.B) {
					b.ReportAllocs()
					b.SetBytes(int64(size))
					b.ResetTimer()
					for i := 0; i < b.N; i++ {
						if err := implementation.write(io.Discard, payload); err != nil {
							b.Fatal(err)
						}
					}
					runtime.KeepAlive(payload)
				})
			}
		})
	}
}
