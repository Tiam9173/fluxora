package rules

import (
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestPrivateDNSDirectRuleIsLimitedToConfiguredDoT(t *testing.T) {
	rule, err := ParseRule("AND",
		"((DOMAIN,resolver.private.example),(NETWORK,TCP),(DST-PORT,853))",
		"DIRECT", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		host    string
		network C.NetWork
		port    uint16
		want    bool
	}{
		{"resolver.private.example", C.TCP, 853, true},
		{"resolver.private.example", C.TCP, 443, false},
		{"resolver.private.example", C.UDP, 853, false},
		{"other.example", C.TCP, 853, false},
		{"", C.TCP, 853, false},
	} {
		match, _ := rule.Match(&C.Metadata{
			Host: tc.host, NetWork: tc.network, DstPort: tc.port,
		}, C.RuleMatchHelper{})
		if match != tc.want {
			t.Errorf("%q/%s/%d: match=%v, want %v", tc.host, tc.network, tc.port, match, tc.want)
		}
	}
}
