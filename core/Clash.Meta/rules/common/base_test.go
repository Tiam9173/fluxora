package common

import (
	"reflect"
	"testing"
)

func TestParseRulePayload(t *testing.T) {
	for _, tc := range []struct {
		in                  string
		needTarget          bool
		tp, payload, target string
		params              []string
	}{
		{"", true, "", "", "", nil},
		{" match , DIRECT , ignored", true, "MATCH", "", "DIRECT", nil},
		{"domain, example.test, DIRECT", true, "DOMAIN", "example.test", "DIRECT", nil},
		{"IP-CIDR, 192.0.2.0/24, DIRECT, no-resolve", true, "IP-CIDR", "192.0.2.0/24", "DIRECT", []string{"no-resolve"}},
		{"IP-CIDR, 192.0.2.0/24, no-resolve", false, "IP-CIDR", "192.0.2.0/24", "", []string{"no-resolve"}},
		{"DOMAIN-REGEX, ^a{1, 2}$, PROXY", true, "DOMAIN-REGEX", "^a{1,2}$", "PROXY", nil},
		{"DOMAIN-REGEX, ^a{1, 2}$", false, "DOMAIN-REGEX", "^a{1,2}$", "", nil},
		{"AND, ((DOMAIN, a.test), (DST-PORT, 443)), DIRECT", true, "AND", "((DOMAIN,a.test),(DST-PORT,443))", "DIRECT", nil},
		{"SUB-RULE, (DOMAIN, a.test), branch", true, "SUB-RULE", "(DOMAIN,a.test)", "branch", nil},
	} {
		tp, payload, target, params := ParseRulePayload(tc.in, tc.needTarget)
		if tp != tc.tp || payload != tc.payload || target != tc.target || !reflect.DeepEqual(params, tc.params) {
			t.Errorf("ParseRulePayload(%q, %t) = (%q, %q, %q, %v)", tc.in, tc.needTarget, tp, payload, target, params)
		}
	}
}

func BenchmarkParseRulePayload(b *testing.B) {
	for _, rule := range []string{
		"DOMAIN-SUFFIX, example.test, DIRECT",
		"IP-CIDR, 192.0.2.0/24, DIRECT, no-resolve",
		"AND, ((DOMAIN, a.test), (DST-PORT, 443)), DIRECT",
	} {
		b.Run(rule, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				ParseRulePayload(rule, true)
			}
		})
	}
}
