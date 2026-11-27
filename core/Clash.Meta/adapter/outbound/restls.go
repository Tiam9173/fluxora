package outbound

import (
	"crypto/x509"

	"github.com/metacubex/mihomo/transport/restls"
)

type RestlsOptions struct {
	Password     string `proxy:"password,omitempty"`
	VersionHint  string `proxy:"version-hint,omitempty"`
	RestlsScript string `proxy:"restls-script,omitempty"`
}

func (o RestlsOptions) Parse(serverName, clientFingerprint string, roots ...*x509.CertPool) (*restls.Config, error) {
	if o.Password == "" && o.VersionHint == "" && o.RestlsScript == "" {
		return nil, nil
	}
	return restls.NewRestlsConfig(serverName, o.Password, o.VersionHint, o.RestlsScript, clientFingerprint, roots...)
}
