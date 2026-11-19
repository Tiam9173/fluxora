package smux

import (
	"testing"
	"time"
)

func TestWriteDeadlineKeepsQueuedPayload(t *testing.T) {
	session := &Session{shaper: make(chan writeRequest)}
	deadline := make(chan time.Time)
	done := make(chan error, 1)
	payload := []byte("original")
	go func() {
		frame := newFrame(1, cmdPSH, 1)
		frame.data = payload
		_, err := session.writeFrameInternal(frame, deadline, CLSDATA)
		done <- err
	}()

	var request writeRequest
	select {
	case request = <-session.shaper:
	case <-time.After(time.Second):
		t.Fatal("frame did not reach the write queue")
	}
	close(deadline)
	select {
	case err := <-done:
		if err != ErrTimeout {
			t.Fatalf("write error = %v, want %v", err, ErrTimeout)
		}
	case <-time.After(time.Second):
		t.Fatal("write deadline did not release the caller")
	}
	payload[0] = 'X'
	if got := string(request.frame.data); got != "original" {
		t.Fatalf("queued payload = %q, want original", got)
	}
}
