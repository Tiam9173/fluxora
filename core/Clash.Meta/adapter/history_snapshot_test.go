package adapter

import (
	"encoding/json"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/common/queue"
	C "github.com/metacubex/mihomo/constant"
)

func historyFixture(name string, count int) *Proxy {
	p := NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: name}))
	state := &internalProxyState{alive: atomic.NewBool(true), history: queue.New[C.DelayHistory](10)}
	for i := 0; i < count; i++ {
		item := C.DelayHistory{Time: time.Unix(int64(i), 0).UTC(), Delay: uint16(20 + i)}
		p.history.Put(item)
		state.history.Put(item)
	}
	p.extra.Store("https://fixture.invalid/", state)
	return p
}

func TestHistorySnapshotIsolation(t *testing.T) {
	p := historyFixture("fixture", 2)
	for _, snapshot := range [][]C.DelayHistory{
		p.DelayHistory(), p.DelayHistoryForTestUrl("https://fixture.invalid/"),
		p.ExtraDelayHistories()["https://fixture.invalid/"].History,
	} {
		snapshot[0].Delay = 999
	}
	if p.DelayHistory()[0].Delay != 20 ||
		p.DelayHistoryForTestUrl("https://fixture.invalid/")[0].Delay != 20 ||
		p.ExtraDelayHistories()["https://fixture.invalid/"].History[0].Delay != 20 {
		t.Fatal("snapshot mutation changed the source history")
	}
	data, err := json.Marshal(p)
	if err != nil {
		t.Fatal(err)
	}
	var decoded map[string]json.RawMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	if string(decoded["name"]) != `"fixture"` {
		t.Fatalf("lost proxy metadata: %s", data)
	}
}

func TestHistorySnapshotEmptyJSON(t *testing.T) {
	p := historyFixture("empty", 0)
	for _, snapshot := range [][]C.DelayHistory{
		p.DelayHistory(), p.DelayHistoryForTestUrl("missing"),
		p.DelayHistoryForTestUrl("https://fixture.invalid/"),
	} {
		data, err := json.Marshal(snapshot)
		if err != nil || string(data) != "[]" {
			t.Fatalf("public history changed shape: %s, %v", data, err)
		}
	}
	data, err := json.Marshal(p.ExtraDelayHistories()["https://fixture.invalid/"].History)
	if err != nil || string(data) != "null" {
		t.Fatalf("extra history changed shape: %s, %v", data, err)
	}
}

func TestHistorySnapshotConcurrentUpdates(t *testing.T) {
	p := historyFixture("concurrent", 1)
	state, _ := p.extra.Load("https://fixture.invalid/")
	var writers sync.WaitGroup
	writers.Add(1)
	go func() {
		defer writers.Done()
		for i := 0; i < 128; i++ {
			item := C.DelayHistory{Delay: uint16(i)}
			p.history.Put(item)
			state.history.Put(item)
		}
	}()
	for i := 0; i < 128; i++ {
		if _, err := json.Marshal(p); err != nil {
			t.Fatal(err)
		}
	}
	writers.Wait()
}

func BenchmarkProxySnapshotJSON(b *testing.B) {
	for _, historyCount := range []int{0, 10} {
		b.Run(fmt.Sprintf("1000/history-%d", historyCount), func(b *testing.B) {
			proxies := make(map[string]C.Proxy, 1000)
			for i := 0; i < 1000; i++ {
				name := fmt.Sprintf("node-%04d", i)
				proxies[name] = historyFixture(name, historyCount)
			}
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if _, err := json.Marshal(proxies); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}
