package provider

import (
	"fmt"
	"net/netip"
	"strings"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/stretchr/testify/require"
)

type recordingCIDRs struct {
	*ipcidrStrategy
	rules []string
}

func (r *recordingCIDRs) Insert(rule string) {
	r.rules = append(r.rules, rule)
	r.ipcidrStrategy.Insert(rule)
}

func TestCIDRYamlRuleParseCompatibility(t *testing.T) {
	for _, header := range []string{
		"payload:", "rules:", "payload: # comment", `"rules":`,
		`"payload": # comment`, "'rules':\t# comment",
	} {
		for _, eol := range []string{"\n", "\r\n"} {
			t.Run(fmt.Sprintf("%s/%q", header, eol), func(t *testing.T) {
				buf := []byte(strings.Join([]string{
					"# leading comment", header,
					"  - 192.0.2.4/24", "  - '2001:db8:1::/48'", "  - 198.51.100.0/24 # inline comment",
					"  - *unresolved", "  - &net 2001:db8:2::/48", `  - "not-a-prefix"`,
					"  - [malformed", "  - 192.0.2.4/24", "  - ::ffff:203.0.113.0/120",
				}, eol))
				strategy := &recordingCIDRs{ipcidrStrategy: NewIPCidrStrategy()}
				parsed, err := rulesParse(buf, strategy, P.YamlRule)
				require.NoError(t, err)
				require.Same(t, strategy, parsed)
				require.Equal(t, []string{
					"192.0.2.4/24", "2001:db8:1::/48", "198.51.100.0/24", "2001:db8:2::/48",
					"not-a-prefix", "192.0.2.4/24", "::ffff:203.0.113.0/120",
				}, strategy.rules)
				require.Equal(t, 6, strategy.Count())
				for _, ip := range []string{"192.0.2.200", "198.51.100.14", "2001:db8:1::cafe", "2001:db8:2::1"} {
					require.True(t, strategy.Match(&C.Metadata{DstIP: netip.MustParseAddr(ip)}, C.RuleMatchHelper{}), ip)
				}
				for _, ip := range []string{"192.0.3.1", "2001:db8:3::1"} {
					require.False(t, strategy.Match(&C.Metadata{DstIP: netip.MustParseAddr(ip)}, C.RuleMatchHelper{}), ip)
				}
			})
		}
	}
	_, err := rulesParse([]byte("  - 192.0.2.0/24"), NewIPCidrStrategy(), P.YamlRule)
	require.ErrorIs(t, err, ErrNoPayload)

	strategy := &recordingCIDRs{ipcidrStrategy: NewIPCidrStrategy()}
	_, err = rulesParse([]byte("rules:\n  - 192.0.2.0/24\npayload: [198.51.100.0/24]\n  - 203.0.113.0/24"), strategy, P.YamlRule)
	require.NoError(t, err)
	require.Equal(t, []string{"192.0.2.0/24", "198.51.100.0/24", "198.51.100.0/24"}, strategy.rules)
}

func BenchmarkCIDRYamlRuleParse(b *testing.B) {
	var rules strings.Builder
	rules.WriteString("payload:\n")
	for i := 0; i < 10_000; i++ {
		fmt.Fprintf(&rules, "  - 198.18.%d.%d/32\n", i/256, i%256)
	}
	buf := []byte(rules.String())
	b.SetBytes(int64(len(buf)))
	b.ReportAllocs()
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		strategy, err := rulesParse(buf, NewIPCidrStrategy(), P.YamlRule)
		if err != nil || strategy.Count() != 10_000 {
			b.Fatalf("parsing 10,000 CIDRs: %v, %v", strategy, err)
		}
	}
}
