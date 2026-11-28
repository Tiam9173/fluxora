package main

import (
	"context"
	"sync"

	"golang.org/x/sync/semaphore"
)

// tunCallbackGate keeps the native callback alive until its last user returns.
// Cancellation also releases callbacks queued behind the concurrency limit.
type tunCallbackGate struct {
	ctx    context.Context
	cancel context.CancelFunc
	limit  *semaphore.Weighted
	once   sync.Once
}

func newTunCallbackGate() *tunCallbackGate {
	ctx, cancel := context.WithCancel(context.Background())
	return &tunCallbackGate{ctx: ctx, cancel: cancel, limit: semaphore.NewWeighted(4)}
}

func (g *tunCallbackGate) enter() bool {
	if g.limit.Acquire(g.ctx, 1) != nil {
		return false
	}
	if g.ctx.Err() != nil {
		g.limit.Release(1)
		return false
	}
	return true
}

func (g *tunCallbackGate) leave() { g.limit.Release(1) }

func (g *tunCallbackGate) close(stopListener, releaseCallback func()) {
	g.once.Do(func() {
		g.cancel()
		// Listener shutdown may wait for a callback. Never hold all slots here.
		stopListener()
		_ = g.limit.Acquire(context.Background(), 4)
		defer g.limit.Release(4)
		releaseCallback()
	})
}
