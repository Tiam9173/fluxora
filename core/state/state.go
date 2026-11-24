package state

import (
	"net"
	"net/netip"
	"strings"
)

var DefaultIpv4Address = "172.19.100.1/30"
var DefaultDnsAddress = "172.19.100.2"
var DefaultIpv6Address = "fdfe:dcba:9876::1/126"

type AndroidVpnOptions struct {
	Enable                bool           `json:"enable"`
	Port                  int            `json:"port"`
	AccessControl         *AccessControl `json:"accessControl"`
	AllowBypass           bool           `json:"allowBypass"`
	SystemProxy           bool           `json:"systemProxy"`
	BypassDomain          []string       `json:"bypassDomain"`
	RouteAddress          []netip.Prefix `json:"routeAddress"`
	RouteMode             string         `json:"routeMode"`
	Ipv4Address           string         `json:"ipv4Address"`
	Ipv6Address           string         `json:"ipv6Address"`
	DnsServerAddress      string         `json:"dnsServerAddress"`
	DozeSuspend           bool           `json:"dozeSuspend"`
	DisableIcmpForwarding bool           `json:"disableIcmpForwarding"`
	Mtu                   uint32         `json:"mtu"`
}

type AccessControl struct {
	Enable     bool     `json:"enable"`
	Mode       string   `json:"mode"`
	AcceptList []string `json:"acceptList"`
	RejectList []string `json:"rejectList"`
}

type AndroidVpnRawOptions struct {
	Enable        bool           `json:"enable"`
	AccessControl *AccessControl `json:"accessControl"`
	AllowBypass   bool           `json:"allowBypass"`
	SystemProxy   bool           `json:"systemProxy"`
	RouteMode     string         `json:"routeMode"`
	DozeSuspend   bool           `json:"dozeSuspend"`
}

type State struct {
	VpnProps            AndroidVpnRawOptions `json:"vpn-props"`
	CurrentProfileName  string               `json:"current-profile-name"`
	OnlyStatisticsProxy bool                 `json:"only-statistics-proxy"`
	BypassDomain        []string             `json:"bypass-domain"`
}

var CurrentState = &State{
	OnlyStatisticsProxy: false,
	CurrentProfileName:  "",
}

func GetDnsServerAddress() string {
	return DefaultDnsAddress
}

func AndroidDNSHijackAddresses(configured []string, dnsEnabled bool) []string {
	addresses := []string{net.JoinHostPort(GetDnsServerAddress(), "53")}
	if dnsEnabled {
		addresses = append(addresses, configured...)
	}
	return addresses
}

func AndroidSystemDNSServers(value string) []string {
	stub, _ := netip.ParseAddr(GetDnsServerAddress())
	var servers []string
	for _, entry := range strings.Split(value, ",") {
		endpoint, err := netip.ParseAddrPort(strings.TrimSpace(entry))
		if err != nil || endpoint.Port() == 0 || endpoint.Addr().Unmap() == stub {
			continue
		}
		servers = append(servers, endpoint.String())
	}
	return servers
}
