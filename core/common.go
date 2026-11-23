package main

import (
	b "bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/batch"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/constant/features"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	rp "github.com/metacubex/mihomo/rules/provider"
	"github.com/metacubex/mihomo/tunnel"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"sync"
	"time"
)

var (
	currentConfig    *config.Config
	currentRawConfig *config.RawConfig
	version          = 0
	isRunning        = false
	runLock          sync.Mutex
	mBatch, _        = batch.New[bool](context.Background(), batch.WithConcurrencyNum[bool](50))
)

type ExternalProviders []ExternalProvider

func (a ExternalProviders) Len() int           { return len(a) }
func (a ExternalProviders) Less(i, j int) bool { return a[i].Name < a[j].Name }
func (a ExternalProviders) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }

func getExternalProvidersRaw() map[string]cp.Provider {
	eps := make(map[string]cp.Provider)
	for n, p := range tunnel.Providers() {
		eps[n] = p
	}
	for n, p := range tunnel.RuleProviders() {
		eps[n] = p
	}
	return eps
}

func toExternalProvider(p cp.Provider) (*ExternalProvider, error) {
	switch p.(type) {
	case *provider.ProxySetProvider:
		psp := p.(*provider.ProxySetProvider)
		return &ExternalProvider{
			Name:             psp.Name(),
			Type:             psp.Type().String(),
			VehicleType:      psp.VehicleType().String(),
			Count:            psp.Count(),
			UpdateAt:         psp.UpdatedAt(),
			Path:             psp.Vehicle().Path(),
			SubscriptionInfo: psp.GetSubscriptionInfo(),
			Proxies:          psp.Proxies(),
		}, nil
	case *provider.InlineProvider:
		ip := p.(*provider.InlineProvider)
		return &ExternalProvider{
			Name:             ip.Name(),
			Type:             ip.Type().String(),
			VehicleType:      ip.VehicleType().String(),
			Count:            ip.Count(),
			UpdateAt:         time.Now(),
			Path:             "",
			SubscriptionInfo: nil,
			Proxies:          ip.Proxies(),
		}, nil
	case *rp.RuleSetProvider:
		rsp := p.(*rp.RuleSetProvider)
		return &ExternalProvider{
			Name:        rsp.Name(),
			Type:        rsp.Type().String(),
			VehicleType: rsp.VehicleType().String(),
			Count:       rsp.Count(),
			UpdateAt:    rsp.UpdatedAt(),
			Path:        rsp.Vehicle().Path(),
		}, nil
	default:
		return nil, errors.New("not external provider")
	}
}

func sideUpdateExternalProvider(p cp.Provider, bytes []byte) error {
	switch p.(type) {
	case *provider.ProxySetProvider:
		psp := p.(*provider.ProxySetProvider)
		_, _, err := psp.SideUpdate(bytes)
		if err == nil {
			return err
		}
		return nil
	case *provider.InlineProvider:
		return nil
	case rp.RuleSetProvider:
		rsp := p.(*rp.RuleSetProvider)
		_, _, err := rsp.SideUpdate(bytes)
		if err == nil {
			return err
		}
		return nil
	default:
		return errors.New("not external provider")
	}
}

// Bind the requested entry point before publishing configuration changes.
func bindMixed(g *config.General) error {
	if !isRunning {
		return nil
	}
	listener.SetAllowLan(g.AllowLan)
	listener.SetBindAddress(g.BindAddress)
	return listener.ReCreateMixed(g.MixedPort, tunnel.Tunnel)
}

func updateListeners() error {
	if !isRunning || currentConfig == nil {
		return nil
	}
	listeners := currentConfig.Listeners
	general := currentConfig.General
	listener.PatchInboundListeners(listeners, tunnel.Tunnel, true)
	listener.SetAllowLan(general.AllowLan)
	inbound.SetSkipAuthPrefixes(general.SkipAuthPrefixes)
	inbound.SetAllowedIPs(general.LanAllowedIPs)
	inbound.SetDisAllowedIPs(general.LanDisAllowedIPs)
	listener.SetBindAddress(general.BindAddress)
	listener.ReCreateHTTP(general.Port, tunnel.Tunnel)
	listener.ReCreateSocks(general.SocksPort, tunnel.Tunnel)
	listener.ReCreateRedir(general.RedirPort, tunnel.Tunnel)
	listener.ReCreateTProxy(general.TProxyPort, tunnel.Tunnel)
	mixedErr := listener.ReCreateMixed(general.MixedPort, tunnel.Tunnel)
	listener.ReCreateShadowSocks(general.ShadowSocksConfig, tunnel.Tunnel)
	listener.ReCreateVmess(general.VmessConfig, tunnel.Tunnel)
	listener.ReCreateTuic(general.TuicServer, tunnel.Tunnel)
	if !features.Android {
		listener.ReCreateTun(general.Tun, tunnel.Tunnel)
	}
	listenerErrors := []error{mixedErr}
	if general.MixedPort > 0 && listener.GetPorts().MixedPort != general.MixedPort {
		listenerErrors = append(listenerErrors, fmt.Errorf("mixed port %d did not start", general.MixedPort))
	}
	if !features.Android && general.Tun.Enable && !listener.GetTunConf().Enable {
		listenerErrors = append(listenerErrors, errors.New("TUN listener did not start"))
	}
	return errors.Join(listenerErrors...)
}

func stopListeners() {
	listener.StopListener()
}

func patchSelectGroup(mapping map[string]string) {
	for name, proxy := range tunnel.Proxies() {
		outbound, ok := proxy.(*adapter.Proxy)
		if !ok {
			continue
		}

		selector, ok := outbound.ProxyAdapter.(outboundgroup.SelectAble)
		if !ok {
			continue
		}

		selected, exist := mapping[name]
		if !exist {
			continue
		}

		selector.ForceSet(selected)
	}
}

func defaultSetupParams() *SetupParams {
	return &SetupParams{
		TestURL:     "https://g.cn/generate_204",
		SelectedMap: map[string]string{},
	}
}

func readFile(path string) ([]byte, error) {
	return os.ReadFile(path)
}

func updateConfig(params *UpdateParams) error {
	runLock.Lock()
	defer runLock.Unlock()
	if currentConfig == nil {
		return errors.New("updateConfig called before setupConfig")
	}
	general := currentConfig.General
	next := *general
	if params.MixedPort != nil {
		next.MixedPort = *params.MixedPort
	}
	if params.AllowLan != nil {
		next.AllowLan = *params.AllowLan
	}
	if params.LogLevel != nil {
		next.LogLevel = *params.LogLevel
	}
	if err := bindMixed(&next); err != nil {
		return errors.Join(err, bindMixed(general))
	}
	if currentConfig.Controller != nil {
		controller := *currentConfig.Controller
		if params.ExternalController != nil {
			controller.ExternalController = *params.ExternalController
		}
		if controller.ExternalController != currentConfig.Controller.ExternalController ||
			(next.LogLevel == log.DEBUG) != (general.LogLevel == log.DEBUG) {
			candidate := *currentConfig
			candidate.General, candidate.Controller = &next, &controller
			if err := hub.ApplyRoute(&candidate); err != nil {
				return errors.Join(err, bindMixed(general))
			}
			currentConfig.Controller = &controller
		}
	}
	general.MixedPort, general.AllowLan = next.MixedPort, next.AllowLan

	if params.Sniffing != nil {
		general.Sniffing = *params.Sniffing
		tunnel.SetSniffing(general.Sniffing)
	}
	if params.FindProcessMode != nil {
		general.FindProcessMode = *params.FindProcessMode
		tunnel.SetFindProcessMode(general.FindProcessMode)
	}
	if params.TCPConcurrent != nil {
		general.TCPConcurrent = *params.TCPConcurrent
		dialer.SetTcpConcurrent(general.TCPConcurrent)
	}
	if params.Interface != nil {
		general.Interface = *params.Interface
		dialer.DefaultInterface.Store(general.Interface)
	}
	if params.UnifiedDelay != nil {
		general.UnifiedDelay = *params.UnifiedDelay
		adapter.UnifiedDelay.Store(general.UnifiedDelay)
	}
	if params.Mode != nil {
		general.Mode = *params.Mode
		tunnel.SetMode(general.Mode)
	}
	if params.LogLevel != nil {
		general.LogLevel = *params.LogLevel
		log.SetLevel(general.LogLevel)
	}
	if params.IPv6 != nil {
		general.IPv6 = *params.IPv6
		resolver.DisableIPv6 = !general.IPv6
	}

	if params.Tun != nil {
		general.Tun.Enable = params.Tun.Enable
		general.Tun.AutoRoute = *params.Tun.AutoRoute
		if params.Tun.AutoRedirect != nil {
			general.Tun.AutoRedirect = *params.Tun.AutoRedirect
		}
		general.Tun.Device = *params.Tun.Device
		general.Tun.RouteAddress = *params.Tun.RouteAddress
		if params.Tun.RouteExcludeAddress != nil {
			general.Tun.RouteExcludeAddress = *params.Tun.RouteExcludeAddress
		}
		if params.Tun.StrictRoute != nil {
			general.Tun.StrictRoute = *params.Tun.StrictRoute
		}
		general.Tun.DNSHijack = *params.Tun.DNSHijack
		general.Tun.Stack = *params.Tun.Stack
		general.Tun.DisableICMPForwarding = *params.Tun.DisableICMPForwarding
	}

	return updateListeners()
}

func setupConfig(params *SetupParams) error {
	runLock.Lock()
	defer runLock.Unlock()

	constant.DefaultTestURL = params.TestURL

	buf, err := readFile(filepath.Join(constant.Path.HomeDir(), constant.Path.Config()))
	if err != nil {
		return err
	}
	rawCfg, err := config.UnmarshalRawConfig(buf)
	if err != nil {
		return err
	}

	if params.OverrideTestUrl && rawCfg.ProxyGroup != nil {
		for _, group := range rawCfg.ProxyGroup {
			group["url"] = params.TestURL
		}
	}

	parsed, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return err
	}
	previous := currentConfig
	if err := bindMixed(parsed.General); err != nil {
		if previous != nil {
			return errors.Join(err, bindMixed(previous.General))
		}
		return err
	}
	if err := hub.ApplyConfig(parsed); err != nil {
		if previous != nil {
			return errors.Join(err, bindMixed(previous.General))
		}
		return err
	}
	currentConfig = parsed
	currentRawConfig = rawCfg
	patchSelectGroup(params.SelectedMap)
	err = updateListeners()
	runtime.GC()
	debug.FreeOSMemory()
	return err
}

func UnmarshalJson(data []byte, v any) error {
	decoder := json.NewDecoder(b.NewReader(data))
	decoder.UseNumber()
	err := decoder.Decode(v)
	return err
}
