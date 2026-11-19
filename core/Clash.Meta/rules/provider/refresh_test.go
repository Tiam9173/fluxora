package provider

import (
	"net/netip"
	"path/filepath"
	"sync"
	"testing"

	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/resource"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/stretchr/testify/require"
)

type ruleUpdateTunnel struct {
	P.Tunnel
	updates *utils.Callback[P.RuleProvider]
}

func (t ruleUpdateTunnel) RuleUpdateCallback() *utils.Callback[P.RuleProvider] { return t.updates }

func TestRuleRefreshConcurrentReaders(t *testing.T) {
	previous := tunnel
	SetTunnel(ruleUpdateTunnel{updates: utils.NewCallback[P.RuleProvider]()})
	t.Cleanup(func() { SetTunnel(previous) })
	path := filepath.Join(t.TempDir(), "rules.yaml")
	rp := NewRuleSetProvider("local", P.IPCIDR, P.YamlRule, 0, resource.NewFileVehicle(path),
		[]string{"192.0.2.0/24"}, nil, nil).(*RuleSetProvider)
	t.Cleanup(func() { require.NoError(t, rp.Close()) })

	dst := C.Metadata{DstIP: netip.MustParseAddr("192.0.2.4")}
	begin := make(chan struct{})
	var readers sync.WaitGroup
	readers.Add(1)
	go func() {
		defer readers.Done()
		<-begin
		for i := 0; i < 300; i++ {
			if !rp.Match(&dst, C.RuleMatchHelper{}) {
				t.Error("rule common to both snapshots disappeared")
			}
			if n := rp.Count(); n != 1 && n != 2 {
				t.Errorf("unexpected rule count: %d", n)
			}
			if _, err := rp.MarshalJSON(); err != nil {
				t.Error(err)
			}
		}
	}()

	close(begin)
	defer readers.Wait()
	for i := 0; i < 30; i++ {
		buf := "payload:\n  - 192.0.2.0/24\n"
		if i%2 == 0 {
			buf += "  - 2001:db8::/32\n"
		}
		_, same, err := rp.SideUpdate([]byte(buf))
		require.NoError(t, err)
		require.False(t, same)
	}
}
