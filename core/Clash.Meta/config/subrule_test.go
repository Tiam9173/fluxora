package config

import (
	"fmt"
	"strings"
	"testing"
)

func TestVerifySubRule(t *testing.T) {
	const prefix = "SUB-RULE,(DOMAIN,example.test),"
	for _, tc := range []struct {
		name  string
		graph map[string][]string
		want  string
	}{
		{"shared branch", map[string][]string{"a": {prefix + "b", prefix + "c"}, "b": {prefix + "c"}, "c": {}}, ""},
		{"missing branch", map[string][]string{"a": {prefix + "missing"}}, "sub-rule [missing] not found"},
		{"self reference", map[string][]string{"a": {prefix + "a"}}, "circular references [a->a]"},
		{"indirect cycle", map[string][]string{"a": {prefix + "b"}, "b": {prefix + "c"}, "c": {prefix + "a"}}, "circular references"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseSubRules(&RawConfig{SubRules: tc.graph}, nil, nil)
			if tc.want == "" {
				if err != nil {
					t.Fatal(err)
				}
			} else if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("got %v, want error containing %q", err, tc.want)
			}
		})
	}
}

func BenchmarkVerifySubRule(b *testing.B) {
	for _, depth := range []int{8, 14} {
		b.Run(fmt.Sprint(depth), func(b *testing.B) {
			raw := &RawConfig{SubRules: make(map[string][]string)}
			previous := []string{"leaf"}
			raw.SubRules[previous[0]] = nil
			for level := 0; level < depth; level++ {
				var references []string
				for _, name := range previous {
					references = append(references, "SUB-RULE,(DOMAIN,example.test),"+name)
				}
				previous = []string{fmt.Sprintf("%d-a", level), fmt.Sprintf("%d-b", level)}
				for _, name := range previous {
					raw.SubRules[name] = references
				}
			}
			subRules, err := parseSubRules(raw, nil, nil)
			if err != nil {
				b.Fatal(err)
			}
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if err := verifySubRule(subRules); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}
