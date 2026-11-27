package ca

import (
	"crypto/x509"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"strconv"
	"sync"

	"github.com/metacubex/mihomo/common/once"
	"github.com/metacubex/mihomo/ntp"

	"github.com/metacubex/tls"
)

var globalCertPool *x509.CertPool
var mutex sync.RWMutex
var errNotMatch = errors.New("certificate fingerprints do not match")

//go:embed ca-certificates.crt
var _CaCertificates []byte
var DisableEmbedCa, _ = strconv.ParseBool(os.Getenv("DISABLE_EMBED_CA"))
var DisableSystemCa, _ = strconv.ParseBool(os.Getenv("DISABLE_SYSTEM_CA"))

func AddCertificate(certificate string) error {
	mutex.Lock()
	defer mutex.Unlock()

	if globalCertPool == nil {
		globalCertPool = newSystemCertPool()
	}
	return addCertificate(globalCertPool, certificate)
}

func addCertificate(pool *x509.CertPool, certificate string) error {
	if certificate == "" {
		return fmt.Errorf("certificate is empty")
	}
	if pool.AppendCertsFromPEM([]byte(certificate)) {
		return nil
	} else if cert, err := x509.ParseCertificate([]byte(certificate)); err == nil {
		pool.AddCert(cert)
		return nil
	} else {
		return fmt.Errorf("add certificate failed")
	}
}

func newSystemCertPool() (pool *x509.CertPool) {
	var err error
	if DisableSystemCa {
		pool = x509.NewCertPool()
	} else {
		pool, err = x509.SystemCertPool()
		if err != nil {
			pool = x509.NewCertPool()
		}
	}
	if !DisableEmbedCa {
		pool.AppendCertsFromPEM(_CaCertificates)
	}
	return pool
}

func ResetCertificate() {
	SetCertPool(newSystemCertPool())
}

// NewCertPool builds a configuration's trust before its proxies are constructed.
func NewCertPool(certificates []string) (*x509.CertPool, []error) {
	pool := newSystemCertPool()
	var invalid []error
	for i, certificate := range certificates {
		if err := addCertificate(pool, certificate); err != nil {
			invalid = append(invalid, fmt.Errorf("custom CA %d: %w", i+1, err))
		}
	}
	return pool, invalid
}

func SetCertPool(pool *x509.CertPool) {
	mutex.Lock()
	defer mutex.Unlock()
	globalCertPool = pool
}

func GetCertPool() *x509.CertPool {
	mutex.Lock()
	defer mutex.Unlock()
	if globalCertPool == nil {
		globalCertPool = newSystemCertPool()
	}
	return globalCertPool
}

type Option struct {
	TLSConfig      *tls.Config
	Fingerprint    string
	NameCertVerify string
	ZeroTrust      bool
	Certificate    string
	PrivateKey     string
}

func GetTLSConfig(opt Option) (tlsConfig *tls.Config, err error) {
	tlsConfig = opt.TLSConfig
	if tlsConfig == nil {
		tlsConfig = &tls.Config{}
	}
	tlsConfig.Time = ntp.Now

	if opt.ZeroTrust {
		tlsConfig.RootCAs = zeroTrustCertPool()
	} else if tlsConfig.RootCAs == nil {
		tlsConfig.RootCAs = GetCertPool()
	}

	if len(opt.Fingerprint) > 0 {
		verifier, err := NewFingerprintVerifier(opt.Fingerprint, tlsConfig.Time)
		if err != nil {
			return nil, err
		}
		tlsConfig.VerifyConnection = func(state tls.ConnectionState) error {
			// [ConnectionState.ServerName] can return the actual ServerName needed for verification,
			// avoiding inconsistencies caused by [tlsConfig.ServerName] being modified after the [NewFingerprintVerifier] call.
			// https://github.com/golang/go/issues/36736#issuecomment-587925536
			serverName := state.ServerName
			if opt.NameCertVerify != "" {
				serverName = opt.NameCertVerify
			}
			return verifier(state.PeerCertificates, serverName)
		}
		tlsConfig.InsecureSkipVerify = true
	} else if opt.NameCertVerify != "" {
		verifier := NewNameCertVerifier(opt.NameCertVerify, tlsConfig.RootCAs, tlsConfig.Time)
		tlsConfig.VerifyConnection = func(state tls.ConnectionState) error {
			return verifier(state.PeerCertificates)
		}
		tlsConfig.InsecureSkipVerify = true
	}

	if len(opt.Certificate) > 0 || len(opt.PrivateKey) > 0 {
		certLoader, err := NewTLSKeyPairLoader(opt.Certificate, opt.PrivateKey)
		if err != nil {
			return nil, err
		}
		tlsConfig.GetClientCertificate = func(*tls.CertificateRequestInfo) (*tls.Certificate, error) {
			return certLoader()
		}
	}
	return tlsConfig, nil
}

var zeroTrustCertPool = once.OnceValue(func() *x509.CertPool {
	if len(_CaCertificates) != 0 { // always using embed cert first
		zeroTrustCertPool := x509.NewCertPool()
		if zeroTrustCertPool.AppendCertsFromPEM(_CaCertificates) {
			return zeroTrustCertPool
		}
	}
	return nil // fallback to system pool
})
