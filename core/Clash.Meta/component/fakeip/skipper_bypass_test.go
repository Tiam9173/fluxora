package fakeip

import (
	"testing"

	"github.com/metacubex/mihomo/component/trie"
	C "github.com/metacubex/mihomo/constant"
	"github.com/stretchr/testify/require"
)

func TestSkipper_BypassWinsAcrossFilterModes(t *testing.T) {
	for _, mode := range []C.FilterMode{
		C.FilterBlackList,
		C.FilterWhiteList,
		C.FilterRule,
	} {
		var builder trie.DomainSetBuilder
		require.NoError(t, builder.Insert("private-dns.example"))
		skipper := &Skipper{
			Bypass: []C.DomainMatcher{builder.Build()},
			Mode:   mode,
		}
		require.Truef(t, skipper.ShouldSkipped("private-dns.example"), "mode=%s", mode)
	}
}
