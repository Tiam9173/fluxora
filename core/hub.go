package main

import (
	"bytes"
	"context"
	"core/state"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"regexp"
	"runtime"
	"runtime/debug"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	mihomoNtp "github.com/metacubex/mihomo/ntp/ntp"
	rulesProvider "github.com/metacubex/mihomo/rules/provider"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"sync"
)

var (
	isInit            = false
	externalProviders = map[string]cp.Provider{}
	logSubscriber     observable.Subscription[log.Event]
	ageMutex          sync.Mutex
)

func handleInitClash(paramsString string) bool {
	var params = InitParams{}
	err := json.Unmarshal([]byte(paramsString), &params)
	if err != nil {
		return false
	}
	version = params.Version
	if !isInit {
		constant.SetHomeDir(params.HomeDir)
		isInit = true
	}
	return isInit
}

func handleStartListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = true
	updateListeners()
	resolver.ResetConnection()
	return true
}

func handleStopListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = false
	listener.StopListener()
	return true
}

func handleGetIsInit() bool {
	return isInit
}

func handleForceGc(forceFreeOSMemory bool) {
	go func() {
		log.Infoln("[APP] Request force GC, forceFreeOSMemory=%t", forceFreeOSMemory)
		runtime.GC()
		if forceFreeOSMemory {
			debug.FreeOSMemory()
		}
	}()
}

func handleShutdown() bool {
	stopListeners()
	executor.Shutdown()
	runtime.GC()
	debug.FreeOSMemory()
	isInit = false
	return true
}

var shortIDRegexp = regexp.MustCompile(`(?m)(short-id\s*:\s*)([0-9a-fA-F]+)(\s*(?:$|[,\s#\}]))`)

func patchYamlShortID(data []byte) []byte {
	return shortIDRegexp.ReplaceAll(data, []byte(`${1}"${2}"${3}`))
}

func handleValidateConfig(params *ValidateConfigParams) string {
	ageMutex.Lock()
	defer ageMutex.Unlock()

	if params.AgeSecretKey != "" {
		age.SetGlobalSecretKeys(params.AgeSecretKey)
		defer age.SetGlobalSecretKeys()
	}

	data := patchYamlShortID([]byte(params.Data))
	_, err := config.Parse(data)
	if err != nil {
		return err.Error()
	}
	return ""
}

func handleDecryptAgeConfig(params *DecryptAgeConfigParams) string {
	ageMutex.Lock()
	defer ageMutex.Unlock()

	decrypted, err := age.DecryptBytes([]byte(params.Data), params.AgeSecretKey)
	if err != nil {
		return ""
	}
	return string(decrypted)
}

func handleGetProxies() map[string]constant.Proxy {
	runLock.Lock()
	defer runLock.Unlock()
	if !isInit {
		return make(map[string]constant.Proxy)
	}
	return tunnel.Proxies()
}

func handleChangeProxy(data string, fn func(string string)) {
	if !isInit {
		fn("core not initialized")
		return
	}
	runLock.Lock()
	go func() {
		defer runLock.Unlock()
		var params = &ChangeProxyParams{}
		err := json.Unmarshal([]byte(data), params)
		if err != nil {
			fn(err.Error())
			return
		}
		groupName := *params.GroupName
		proxyName := *params.ProxyName
		group, ok := tunnel.Proxies()[groupName]
		if !ok {
			fn("Not found group")
			return
		}
		adapterProxy := group.(*adapter.Proxy)
		selector, ok := adapterProxy.ProxyAdapter.(outboundgroup.SelectAble)
		if !ok {
			fn("Group is not selectable")
			return
		}
		if proxyName == "" {
			selector.ForceSet(proxyName)
		} else {
			err = selector.Set(proxyName)
		}
		if err != nil {
			fn(err.Error())
			return
		}

		fn("")
		return
	}()
}

func handleGetTraffic() string {
	up, down := statistic.DefaultManager.NowTraffic(state.CurrentState.OnlyStatisticsProxy)
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleGetTotalTraffic() string {
	up, down := statistic.DefaultManager.TotalTraffic(state.CurrentState.OnlyStatisticsProxy)
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func handleAsyncTestDelay(paramsString string, fn func(string)) {
	mBatch.Go(paramsString, func() (bool, error) {
		var params = &TestDelayParams{}
		err := json.Unmarshal([]byte(paramsString), params)
		if err != nil {
			fn("")
			return false, nil
		}

		expectedStatus, err := utils.NewUnsignedRanges[uint16]("")
		if err != nil {
			fn("")
			return false, nil
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond*time.Duration(params.Timeout))
		defer cancel()

		var proxy constant.Proxy
		var exist bool
		if proxy, exist = tunnel.Proxies()[params.ProxyName]; !exist {
			for _, provider := range tunnel.Providers() {
				for _, p := range provider.Proxies() {
					if p.Name() == params.ProxyName {
						proxy = p
						exist = true
						break
					}
				}
				if exist {
					break
				}
			}
		}

		delayData := &Delay{
			Name: params.ProxyName,
		}

		if proxy == nil {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		testUrl := constant.DefaultTestURL

		if params.TestUrl != "" {
			testUrl = params.TestUrl
		}
		delayData.Url = testUrl

		delay, err := proxy.URLTest(ctx, testUrl, expectedStatus)
		if err != nil || delay == 0 {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		delayData.Value = int32(delay)
		data, _ := json.Marshal(delayData)
		fn(string(data))
		return false, nil
	})
}

func handleGetConnections() string {
	runLock.Lock()
	defer runLock.Unlock()
	snapshot := statistic.DefaultManager.Snapshot()
	data, err := json.Marshal(snapshot)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleCloseConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	closeConnections()
	return true
}

func closeConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		err := c.Close()
		if err != nil {
			return false
		}
		return true
	})
}

func handleResetConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	resolver.ResetConnection()
	return true
}

func handleCloseConnection(connectionId string) bool {
	runLock.Lock()
	defer runLock.Unlock()
	c := statistic.DefaultManager.Get(connectionId)
	if c == nil {
		return false
	}
	_ = c.Close()
	return true
}

func handleGetExternalProviders() string {
	runLock.Lock()
	defer runLock.Unlock()
	if !isInit {
		return "[]"
	}
	externalProviders = getExternalProvidersRaw()
	eps := make([]ExternalProvider, 0)
	for _, p := range externalProviders {
		externalProvider, err := toExternalProvider(p)
		if err != nil {
			continue
		}
		eps = append(eps, *externalProvider)
	}
	sort.Sort(ExternalProviders(eps))
	data, err := json.Marshal(eps)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleGetExternalProvider(externalProviderName string) string {
	runLock.Lock()
	defer runLock.Unlock()
	externalProvider, exist := externalProviders[externalProviderName]
	if !exist {
		return ""
	}
	e, err := toExternalProvider(externalProvider)
	if err != nil {
		return ""
	}
	data, err := json.Marshal(e)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleUpdateGeoData(geoType string, geoName string, fn func(value string)) {
	go func() {
		path := constant.Path.Resolve(geoName)
		switch geoType {
		case "MMDB":
			err := updater.UpdateMMDBWithPath(path)
			if err != nil {
				fn(err.Error())
				return
			}
		case "ASN":
			err := updater.UpdateASNWithPath(path)
			if err != nil {
				fn(err.Error())
				return
			}
		case "GeoSite":
			err := updater.UpdateGeoSiteWithPath(path)
			if err != nil {
				fn(err.Error())
				return
			}
		}
		fn("")
	}()
}

func handleUpdateExternalProvider(providerName string, fn func(value string)) {
	go func() {
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := externalProvider.Update()
		if err != nil {
			fn(err.Error())
			return
		}
		fn("")
	}()
}

func handleSideLoadExternalProvider(providerName string, data []byte, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := sideUpdateExternalProvider(externalProvider, data)
		if err != nil {
			fn(err.Error())
			return
		}
		fn("")
	}()
}

func handleParseExternalProviderContent(providerName string, fn func(value string)) {
	go func() {
		runLock.Lock()
		p, exist := getExternalProvidersRaw()[providerName]
		rawConfig := currentRawConfig
		runLock.Unlock()

		if !exist {
			fn("external provider does not exist")
			return
		}

		if p.VehicleType() == cp.Inline {
			buf, err := marshalInlineProviderContent(rawConfig, providerName)
			if err != nil {
				fn(err.Error())
				return
			}
			fn(string(buf))
			return
		}

		ep, err := toExternalProvider(p)
		if err != nil || ep.Path == "" {
			fn("provider path is empty")
			return
		}

		buf, err := os.ReadFile(ep.Path)
		if err != nil {
			fn(fmt.Sprintf("read file error: %v", err))
			return
		}

		if rp, ok := p.(cp.RuleProvider); ok {
			var out bytes.Buffer
			if err := rulesProvider.ConvertToMrs(buf, rp.Behavior(), cp.MrsRule, &out); err == nil {
				fn(out.String())
				return
			}
		}

		fn(string(buf))
	}()
}

func marshalInlineProviderContent(rawConfig *config.RawConfig, providerName string) ([]byte, error) {
	if rawConfig == nil {
		return nil, fmt.Errorf("provider content is empty")
	}

	rawProvider, exist := rawConfig.ProxyProvider[providerName]
	if !exist {
		return nil, fmt.Errorf("provider content is empty")
	}
	payload, exist := rawProvider["payload"]
	if !exist {
		return nil, fmt.Errorf("provider content is empty")
	}

	return yaml.Marshal(map[string]any{"proxies": payload})
}

func handleStartLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
	logSubscriber = log.Subscribe()
	go func() {
		for logData := range logSubscriber {
			if logData.LogLevel < log.Level() {
				continue
			}
			message := &Message{
				Type: LogMessage,
				Data: logData,
			}
			sendMessage(*message)
		}
	}()
}

func handleStopLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
}

func handleGetCountryCode(ip string, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		codes := mmdb.IPInstance().LookupCode(net.ParseIP(ip))
		if len(codes) == 0 {
			fn("")
			return
		}
		fn(codes[0])
	}()
}

func handleGetMemory(fn func(value string)) {
	go func() {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		var retainedIdle uint64
		if m.HeapIdle > m.HeapReleased {
			retainedIdle = m.HeapIdle - m.HeapReleased
		}
		mem := m.HeapInuse + retainedIdle + m.StackInuse
		fn(strconv.FormatUint(mem, 10))
	}()
}

func handleGetCoreStatus(fn func(value string)) {
	go func() {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		var retainedIdle uint64
		if m.HeapIdle > m.HeapReleased {
			retainedIdle = m.HeapIdle - m.HeapReleased
		}
		inUse := m.HeapInuse + m.StackInuse
		physical := inUse + retainedIdle

		var proxyGroupsCount int
		proxyNames := make(map[string]struct{})
		for _, p := range tunnel.Proxies() {
			if p == nil {
				continue
			}
			if _, ok := p.Adapter().(outboundgroup.ProxyGroup); ok {
				proxyGroupsCount++
				continue
			}
			switch p.Type() {
			case constant.Direct, constant.Reject, constant.RejectDrop, constant.Compatible, constant.Pass, constant.PassRule, constant.Rematch, constant.Dns:
				continue
			default:
				proxyNames[p.Name()] = struct{}{}
			}
		}

		for name, pr := range tunnel.Providers() {
			if pr == nil || name == "default" || pr.VehicleType() == cp.Compatible {
				continue
			}
			for _, p := range pr.Proxies() {
				if p != nil {
					proxyNames[p.Name()] = struct{}{}
				}
			}
		}

		var ruleProvidersCount int
		var proxyProvidersCount int
		if currentRawConfig != nil {
			ruleProvidersCount = len(currentRawConfig.RuleProvider)
			proxyProvidersCount = len(currentRawConfig.ProxyProvider)
		} else {
			for name, pr := range tunnel.Providers() {
				if pr == nil || name == "default" || pr.VehicleType() == cp.Compatible {
					continue
				}
				proxyProvidersCount++
			}
			ruleProvidersCount = len(tunnel.RuleProviders())
		}

		hasMMDB := geodata.GeoIpEnable()
		hasSite := geodata.GeoSiteEnable()
		hasASN := geodata.ASNEnable()

		if !hasMMDB || !hasSite || !hasASN {
			for _, r := range tunnel.Rules() {
				if r == nil {
					continue
				}
				switch r.RuleType() {
				case constant.GEOIP, constant.SrcGEOIP:
					hasMMDB = true
				case constant.GEOSITE:
					hasSite = true
				case constant.IPASN, constant.SrcIPASN:
					hasASN = true
				}
			}
		}

		var geodatas []string
		if hasMMDB {
			geodatas = append(geodatas, "MMDB")
		}
		if hasSite {
			geodatas = append(geodatas, "Site")
		}
		if hasASN {
			geodatas = append(geodatas, "ASN")
		}

		geodataUse := "None"
		if len(geodatas) > 0 {
			geodataUse = strings.Join(geodatas, ", ")
		}

		status := map[string]any{
			"physical":        physical,
			"in-use":          inUse,
			"reclaimable":     retainedIdle,
			"goroutines":      runtime.NumGoroutine(),
			"heap-objects":    m.HeapObjects,
			"last-gc":         m.LastGC / 1000000,
			"rules":           len(tunnel.Rules()),
			"proxies":         len(proxyNames),
			"proxy-groups":    proxyGroupsCount,
			"rule-providers":  ruleProvidersCount,
			"proxy-providers": proxyProvidersCount,
			"geodata-use":     geodataUse,
		}
		bytes, _ := json.Marshal(status)
		fn(string(bytes))
	}()
}

func handleGetMode() string {
	if !isInit {
		return ""
	}
	return tunnel.Mode().String()
}

func handleSetState(params string) {
	_ = json.Unmarshal([]byte(params), state.CurrentState)
}

func handleGetConfig(params *GetConfigParams) (*config.RawConfig, error) {
	ageMutex.Lock()
	defer ageMutex.Unlock()

	if params.AgeSecretKey != "" {
		age.SetGlobalSecretKeys(params.AgeSecretKey)
		defer age.SetGlobalSecretKeys()
	}

	bytes, err := readFile(params.Path)
	if err != nil {
		return nil, err
	}
	bytes = patchYamlShortID(bytes)
	prof, err := config.UnmarshalRawConfig(bytes)
	if err != nil {
		return nil, err
	}
	return prof, nil
}

func handleFlushFakeIP() bool {
	if !isInit {
		return false
	}
	err := resolver.FlushFakeIP()
	if err != nil {
		log.Errorln("[APP] Flush FakeIP error: %v", err)
		return false
	}
	log.Infoln("[APP] FakeIP pool flushed")
	return true
}

func handleFlushDnsCache() {
	resolver.ClearCache()
	log.Infoln("[APP] DNS cache flushed")
}

func handleCrash() {
	panic("handle invoke crash")
}

func handleUpdateConfig(bytes []byte) string {
	var params = &UpdateParams{}
	err := json.Unmarshal(bytes, params)
	if err != nil {
		return err.Error()
	}
	updateConfig(params)
	return ""
}

func handleSetupConfig(bytes []byte) string {
	var params = defaultSetupParams()
	err := UnmarshalJson(bytes, params)
	if err != nil {
		log.Errorln("unmarshalRawConfig error %v", err)
		_ = setupConfig(defaultSetupParams())
		return err.Error()
	}
	clearSuspendedHealthChecks()
	clearSuspendedWireGuard()
	suspendModeLock.Lock()
	currentSuspendMode = 0
	suspendModeLock.Unlock()
	err = setupConfig(params)
	if err != nil {
		return err.Error()
	}
	return ""
}

var (
	currentSuspendMode = 0
	suspendModeLock    sync.Mutex
)

func handleSuspend(mode int) bool {
	if !isInit {
		return false
	}
	suspendModeLock.Lock()
	defer suspendModeLock.Unlock()

	switch mode {
	case 1:
		if currentSuspendMode == 1 {
			return true
		}
		log.Infoln("[APP] Suspend mode enabled")
		tunnel.OnSuspend()
		pauseHealthChecks()
		pauseWireGuard()

		mihomoNtp.ReCreateNTPService("", 0, "", nil, false)

		statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
			_ = c.Close()
			return true
		})

		runtime.GC()
		currentSuspendMode = 1

	case 2:
		if currentSuspendMode == 1 || currentSuspendMode == 2 {
			return true
		}
		log.Infoln("[APP] Doze suspend mode enabled")
		pauseHealthChecks()
		runtime.GC()
		currentSuspendMode = 2

	case 0:
		if currentSuspendMode == 0 {
			return true
		}
		log.Infoln("[APP] Resume from suspend")
		prevMode := currentSuspendMode
		currentSuspendMode = 0

		if prevMode == 1 {
			tunnel.OnRunning()
			resumeHealthChecks()
			resumeWireGuard()

			runLock.Lock()
			cfg := currentConfig
			runLock.Unlock()
			if cfg != nil && cfg.NTP != nil && cfg.NTP.Enable {
				c := cfg.NTP
				mihomoNtp.ReCreateNTPService(
					net.JoinHostPort(c.Server, strconv.Itoa(c.Port)),
					time.Duration(c.Interval),
					c.DialerProxy,
					tunnel.Tunnel,
					c.WriteToSystem,
				)
			}
		} else if prevMode == 2 {
			resumeHealthChecks()
		}

	default:
		return false
	}
	return true
}

func init() {
	adapter.UrlTestHook = func(url string, name string, delay uint16) {
		delayData := &Delay{
			Url:  url,
			Name: name,
		}
		if delay == 0 {
			delayData.Value = -1
		} else {
			delayData.Value = int32(delay)
		}
		sendMessage(Message{
			Type: DelayMessage,
			Data: delayData,
		})
	}
	statistic.DefaultRequestNotify = func(c statistic.Tracker) {
		sendMessage(Message{
			Type: RequestMessage,
			Data: c.Info(),
		})
	}
	executor.DefaultProviderLoadedHook = func(providerName string) {
		sendMessage(Message{
			Type: LoadedMessage,
			Data: providerName,
		})
	}
}
