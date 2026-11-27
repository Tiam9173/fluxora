package provider_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/resource"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/rules"
	R "github.com/metacubex/mihomo/rules/provider"
)

type httpBenchmarkTunnel struct {
	P.Tunnel
	updates *utils.Callback[P.RuleProvider]
}

func (t httpBenchmarkTunnel) RuleUpdateCallback() *utils.Callback[P.RuleProvider] {
	return t.updates
}

func BenchmarkHTTPRuleProviderInitial(b *testing.B) {
	var requests atomic.Int64
	var body strings.Builder
	body.WriteString("payload:\n  - target.rule-bench.test\n")
	for i := 0; i < 3000; i++ {
		fmt.Fprintf(&body, "  - node-%04d.rule-bench.test\n", i)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		time.Sleep(25 * time.Millisecond)
		_, _ = w.Write([]byte(body.String()))
	}))
	defer server.Close()

	R.SetTunnel(httpBenchmarkTunnel{updates: utils.NewCallback[P.RuleProvider]()})

	for _, warm := range []bool{false, true} {
		name := "cold-http"
		if warm {
			name = "warm-cache"
		}
		b.Run(name, func(b *testing.B) {
			path := filepath.Join(b.TempDir(), "rules.yaml")
			if warm {
				if err := os.WriteFile(path, []byte(body.String()), 0o600); err != nil {
					b.Fatal(err)
				}
			}
			vehicle := resource.NewHTTPVehicle(server.URL, path, "", nil, resource.DefaultHttpTimeout, 0)
			metadata := &C.Metadata{Host: "target.rule-bench.test", DstIP: netip.MustParseAddr("192.0.2.1")}
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if !warm {
					if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
						b.Fatal(err)
					}
				}
				rp := R.NewRuleSetProvider(
					"bench",
					P.Domain,
					P.YamlRule,
					24*time.Hour,
					vehicle,
					nil,
					nil,
					rules.ParseRule,
				)
				if err := rp.Initial(); err != nil {
					b.Fatal(err)
				}
				b.StopTimer()
				if !rp.Match(metadata, C.RuleMatchHelper{}) || rp.Count() != 3001 {
					b.Fatalf("provider rules were not ready after Initial: count=%d", rp.Count())
				}
				closer, ok := rp.(interface{ Close() error })
				if !ok {
					b.Fatal("rule provider does not expose cleanup")
				}
				if err := closer.Close(); err != nil {
					b.Fatal(err)
				}
				b.StartTimer()
			}
		})
	}
	if got := requests.Load(); got == 0 {
		b.Fatal("cold provider fixture made no HTTP requests")
	}
}
