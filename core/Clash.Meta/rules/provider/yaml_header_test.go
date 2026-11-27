package provider

import (
	"testing"

	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/stretchr/testify/require"
)

func TestYamlRuleRequiresPayload(t *testing.T) {
	for _, input := range []string{
		"", "\n", "# comment only\n", "  - 192.0.2.0/24", "  - 192.0.2.0/24\n",
		"bad-header:\n  - 192.0.2.0/24\n", "bad-header:\r\n  - 192.0.2.0/24\r\n",
		"unrelated: []\n", "payload: not-a-list\n", "payload: [malformed\n",
	} {
		t.Run(input, func(t *testing.T) {
			strategy, err := rulesParse([]byte(input), NewIPCidrStrategy(), P.YamlRule)
			require.ErrorIs(t, err, ErrNoPayload)
			require.Nil(t, strategy)
		})
	}
}

func TestYamlRuleFlowPayload(t *testing.T) {
	strategy := &recordingCIDRs{ipcidrStrategy: NewIPCidrStrategy()}
	_, err := rulesParse([]byte("rules: [198.51.100.0/24]\npayload: [192.0.2.0/24, '2001:db8::/32']"), strategy, P.YamlRule)
	require.NoError(t, err)
	require.Equal(t, []string{"192.0.2.0/24", "2001:db8::/32"}, strategy.rules)
}

func TestYamlRuleExplicitEmptyPayload(t *testing.T) {
	for _, input := range []string{"payload:\n", "payload:", "rules: []", "\"payload\": [ ] # empty\r\n", "rules: []\n"} {
		t.Run(input, func(t *testing.T) {
			strategy, err := rulesParse([]byte(input), NewIPCidrStrategy(), P.YamlRule)
			require.NoError(t, err)
			require.Zero(t, strategy.Count())
		})
	}
}
