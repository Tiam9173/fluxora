package main

import (
	"sync/atomic"
	"testing"
	"time"
)

func awaitTunCallback(t *testing.T, done <-chan struct{}) {
	t.Helper()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("TUN callback shutdown did not finish")
	}
}

func TestTunCallbacksCloseAllowsListenerToDrain(t *testing.T) {
	gate := newTunCallbackGate()
	done := make(chan struct{})
	var callbacks, releases atomic.Int32
	go func() {
		defer close(done)
		gate.close(func() {
			// A listener waiting on process lookup during shutdown must not
			// deadlock on a slot held by its own Close caller.
			if gate.enter() {
				callbacks.Add(1)
				gate.leave()
			}
		}, func() { releases.Add(1) })
	}()
	awaitTunCallback(t, done)
	gate.close(func() { t.Fatal("listener closed twice") }, func() { releases.Add(1) })
	if callbacks.Load() != 0 || releases.Load() != 1 {
		t.Fatalf("late callbacks=%d releases=%d", callbacks.Load(), releases.Load())
	}
}

func TestTunCallbacksWaitForActiveUsersAndCancelQueuedUsers(t *testing.T) {
	gate := newTunCallbackGate()
	for i := 0; i < 4; i++ {
		if !gate.enter() {
			t.Fatal("callback rejected before shutdown")
		}
	}
	queued := make(chan struct{})
	go func() {
		defer close(queued)
		if gate.enter() {
			gate.leave()
			t.Error("queued callback accepted after shutdown")
		}
	}()
	listenerStopped := make(chan struct{})
	released := make(chan struct{})
	go gate.close(func() { close(listenerStopped) }, func() { close(released) })
	awaitTunCallback(t, listenerStopped)
	awaitTunCallback(t, queued)
	select {
	case <-released:
		t.Fatal("native callback released while still in use")
	default:
	}
	for i := 0; i < 4; i++ {
		gate.leave()
	}
	awaitTunCallback(t, released)
	if gate.enter() {
		gate.leave()
		t.Fatal("callback accepted after release")
	}
}
