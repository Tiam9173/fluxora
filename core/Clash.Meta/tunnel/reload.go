package tunnel

import (
	"sync"
	"sync/atomic"
	"time"

	C "github.com/metacubex/mihomo/constant"
)

const configReloadWaitLimit = time.Second

type reloadWindow struct {
	done      chan struct{}
	cancelled bool // published by closing done

	udpMu       sync.Mutex
	udpDeadline time.Time
	udpTimer    *time.Timer
	udpPackets  []C.PacketAdapter
}

var (
	configReloadDone    atomic.Pointer[reloadWindow]
	configReloadTCPWait = make(chan struct{}, queueCapacity)
)

// BeginConfigReload defers external traffic until the app has applied the
// configuration, restored its selections, and updated listeners.
func BeginConfigReload() func() {
	// The app may already hold the gate until it restores selections.
	if Status() != Running || configReloadDone.Load() != nil {
		return func() {}
	}
	ready := &reloadWindow{
		done:        make(chan struct{}),
		udpDeadline: time.Now().Add(configReloadWaitLimit),
	}
	if !configReloadDone.CompareAndSwap(nil, ready) {
		return func() {}
	}
	if Status() != Running {
		ready.finish(true)
	}
	return func() { ready.finish(false) }
}

func (w *reloadWindow) finish(cancelled bool) {
	w.udpMu.Lock()
	if !configReloadDone.CompareAndSwap(w, nil) {
		w.udpMu.Unlock()
		return
	}
	w.cancelled = cancelled
	close(w.done)
	if w.udpTimer != nil {
		w.udpTimer.Stop()
	}
	packets := w.udpPackets
	w.udpPackets = nil
	w.udpMu.Unlock()
	for _, packet := range packets {
		if cancelled || Status() != Running || !time.Now().Before(w.udpDeadline) {
			packet.Drop()
			continue
		}
		enqueueUDP(udpWork{packet: packet, reload: w})
	}
}

// deferUDPForReload owns the packet when it returns true.
func deferUDPForReload(work udpWork) bool {
	for ready := configReloadDone.Load(); ready != nil; ready = configReloadDone.Load() {
		if work.packet.Metadata().Type == C.INNER {
			return false
		}
		ready.udpMu.Lock()
		if configReloadDone.Load() != ready {
			ready.udpMu.Unlock()
			continue
		}
		remaining := time.Until(ready.udpDeadline)
		if work.reload != nil || remaining <= 0 || len(ready.udpPackets) == queueCapacity {
			ready.udpMu.Unlock()
			work.packet.Drop()
			return true
		}
		if ready.udpTimer == nil {
			ready.udpPackets = make([]C.PacketAdapter, 0, queueCapacity)
			ready.udpTimer = time.AfterFunc(remaining, ready.expireUDP)
		}
		ready.udpPackets = append(ready.udpPackets, work.packet)
		ready.udpMu.Unlock()
		return true
	}
	return false
}

func (w *reloadWindow) expireUDP() {
	w.udpMu.Lock()
	packets := w.udpPackets
	w.udpPackets = nil
	w.udpMu.Unlock()
	for _, packet := range packets {
		packet.Drop()
	}
}

func waitForTCPReady(typ C.Type) bool {
	ready := configReloadDone.Load()
	if ready == nil || typ == C.INNER {
		return isHandle(typ)
	}
	select {
	case configReloadTCPWait <- struct{}{}:
		defer func() { <-configReloadTCPWait }()
	default:
		return false
	}
	timer := time.NewTimer(configReloadWaitLimit)
	defer timer.Stop()
	for ready != nil {
		select {
		case <-ready.done:
			if ready.cancelled {
				return false
			}
			ready = configReloadDone.Load()
		case <-timer.C:
			return false
		}
	}
	return isHandle(typ)
}
