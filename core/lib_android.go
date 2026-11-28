//go:build android && cgo

package main

import "C"
import (
	bridge "core/dart-bridge"
	"core/platform"
	"core/state"
	t "core/tun"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"net"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"
)

type TunHandler struct {
	listener *sing_tun.Listener
	callback unsafe.Pointer

	callbacks *tunCallbackGate
	ready     atomic.Bool
}

func (t *TunHandler) close() {
	t.ready.Store(false)
	removeTunHook()
	t.callbacks.close(func() {
		if t.listener != nil {
			_ = t.listener.Close()
		}
	}, func() {
		if t.callback != nil {
			releaseObject(t.callback)
		}
		t.callback = nil
		t.listener = nil
	})
}

func (t *TunHandler) handleProtect(fd int) bool {
	if !t.callbacks.enter() {
		return false
	}
	defer t.callbacks.leave()

	cb := t.callback
	if cb == nil {
		return false
	}

	Protect(cb, fd)
	return true
}

func (t *TunHandler) handleResolveProcess(source, target net.Addr) string {
	if !t.callbacks.enter() {
		return ""
	}
	defer t.callbacks.leave()

	if !t.ready.Load() {
		return ""
	}
	var protocol int
	uid := -1
	switch source.Network() {
	case "udp", "udp4", "udp6":
		protocol = syscall.IPPROTO_UDP
	case "tcp", "tcp4", "tcp6":
		protocol = syscall.IPPROTO_TCP
	}
	if version < 29 {
		uid = platform.QuerySocketUidFromProcFs(source, target)
	}
	return ResolveProcess(t.callback, protocol, source.String(), target.String(), uid)
}

var (
	tunLock    sync.Mutex
	runTime    *time.Time
	errBlocked = errors.New("blocked")
	tunHandler atomic.Pointer[TunHandler]
)

func init() {
	dialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
		if platform.ShouldBlockConnection() {
			return errBlocked
		}
		handler := tunHandler.Load()
		if handler != nil {
			protected := false
			err := conn.Control(func(fd uintptr) {
				protected = handler.handleProtect(int(fd))
			})
			if err != nil {
				return err
			}
			if !protected {
				return net.ErrClosed
			}
		}
		return nil
	}
}

func handleStopTun() {
	tunLock.Lock()
	defer tunLock.Unlock()
	stopTunLocked()
}

func stopTunLocked() {
	runTime = nil
	handler := tunHandler.Swap(nil)
	if handler != nil {
		handler.close()
	}
}

func handleStartTun(fd int, callback unsafe.Pointer) bool {
	tunLock.Lock()
	defer tunLock.Unlock()
	stopTunLocked()
	if fd != 0 {
		if currentConfig == nil {
			log.Warnln("[APP] handleStartTun called before setupConfig")
			_ = syscall.Close(fd)
			releaseObject(callback)
			return false
		}
		handler := &TunHandler{
			callback:  callback,
			callbacks: newTunCallbackGate(),
		}
		tunHandler.Store(handler)
		initTunHook()
		tunListener, _ := t.Start(fd, currentConfig.General.Tun, currentConfig.General.IPv6, currentConfig.DNS.Enable)
		if tunListener != nil {
			log.Infoln("TUN address: %v", tunListener.Address())
			handler.listener = tunListener
			handler.ready.Store(true)
		} else {
			tunHandler.Store(nil)
			handler.close()
			return false
		}
	} else {
		releaseObject(callback)
	}
	now := time.Now()
	runTime = &now
	return true
}

func handleGetRunTime() string {
	tunLock.Lock()
	defer tunLock.Unlock()
	if runTime == nil {
		return ""
	}
	return strconv.FormatInt(runTime.UnixMilli(), 10)
}

func initTunHook() {
	process.DefaultPackageNameResolver = func(metadata *constant.Metadata) (string, error) {
		src, dst := metadata.RawSrcAddr, metadata.RawDstAddr
		if src == nil || dst == nil {
			return "", process.ErrInvalidNetwork
		}
		handler := tunHandler.Load()
		if handler == nil {
			return "", errors.New("tun is closed")
		}
		return handler.handleResolveProcess(src, dst), nil
	}
}

func removeTunHook() {
	process.DefaultPackageNameResolver = nil
}

func handleGetAndroidVpnOptions() string {
	tunLock.Lock()
	defer tunLock.Unlock()
	if currentConfig == nil {
		log.Warnln("[APP] handleGetAndroidVpnOptions called before setupConfig")
		return ""
	}
	ipv6Address := ""
	if currentConfig.General.IPv6 {
		ipv6Address = state.DefaultIpv6Address
	}
	options := state.AndroidVpnOptions{
		Enable:                state.CurrentState.VpnProps.Enable,
		Port:                  currentConfig.General.MixedPort,
		Ipv4Address:           state.DefaultIpv4Address,
		Ipv6Address:           ipv6Address,
		AccessControl:         state.CurrentState.VpnProps.AccessControl,
		SystemProxy:           state.CurrentState.VpnProps.SystemProxy,
		AllowBypass:           state.CurrentState.VpnProps.AllowBypass,
		RouteAddress:          currentConfig.General.Tun.RouteAddress,
		RouteMode:             state.CurrentState.VpnProps.RouteMode,
		BypassDomain:          state.CurrentState.BypassDomain,
		DnsServerAddress:      state.GetDnsServerAddress(),
		DozeSuspend:           state.CurrentState.VpnProps.DozeSuspend,
		DisableIcmpForwarding: currentConfig.General.Tun.DisableICMPForwarding,
		Mtu:                   uint32(currentConfig.General.Tun.MTU),
	}
	data, err := json.Marshal(options)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleUpdateDns(value string) {
	dns.UpdateSystemDNS(state.AndroidSystemDNSServers(value))
	dns.FlushCacheWithDefaultResolver()
}

func handleGetCurrentProfileName() string {
	if state.CurrentState == nil {
		return ""
	}
	return state.CurrentState.CurrentProfileName
}

func nextHandle(action *Action, result ActionResult) bool {
	switch action.Method {
	case getAndroidVpnOptionsMethod:
		result.success(handleGetAndroidVpnOptions())
		return true
	case updateDnsMethod:
		data := action.Data.(string)
		handleUpdateDns(data)
		result.success(true)
		return true
	case getRunTimeMethod:
		result.success(handleGetRunTime())
		return true
	case getCurrentProfileNameMethod:
		result.success(handleGetCurrentProfileName())
		return true
	}
	return false
}

//export quickStart
func quickStart(initParamsChar *C.char, paramsChar *C.char, stateParamsChar *C.char, port C.longlong) {
	i := int64(port)
	paramsString := C.GoString(initParamsChar)
	bytes := []byte(C.GoString(paramsChar))
	stateParams := C.GoString(stateParamsChar)
	go func() {
		res := handleInitClash(paramsString)
		if res == false {
			bridge.SendToPort(i, "init error")
		}
		handleSetState(stateParams)
		bridge.SendToPort(i, handleSetupConfig(bytes))
	}()
}

//export startTUN
func startTUN(fd C.int, callback unsafe.Pointer) bool {
	return handleStartTun(int(fd), callback)
}

//export getRunTime
func getRunTime() *C.char {
	return C.CString(handleGetRunTime())
}

//export stopTun
func stopTun() {
	handleStopTun()
}

//export getCurrentProfileName
func getCurrentProfileName() *C.char {
	return C.CString(handleGetCurrentProfileName())
}

//export getAndroidVpnOptions
func getAndroidVpnOptions() *C.char {
	return C.CString(handleGetAndroidVpnOptions())
}

//export setState
func setState(s *C.char) {
	paramsString := C.GoString(s)
	handleSetState(paramsString)
}

//export updateDns
func updateDns(s *C.char) {
	dnsList := C.GoString(s)
	handleUpdateDns(dnsList)
}
