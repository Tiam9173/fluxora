package dns

import (
	"context"
	"net"
	"sync"

	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/common/sockopt"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"

	D "github.com/miekg/dns"
)

var (
	serverMu sync.Mutex
	address  string
	server   = &Server{}

	dnsDefaultTTL uint32 = 600
)

type Server struct {
	service   atomic.TypedValue[resolver.Service]
	tcpServer *D.Server
	udpServer *D.Server
}

type serverHandler struct {
	*Server
	isUDP bool
}

// ServeDNS implement D.Handler ServeDNS
func (s serverHandler) ServeDNS(w D.ResponseWriter, r *D.Msg) {
	msg, err := s.service.Load().ServeMsg(context.Background(), r)
	if err != nil {
		m := new(D.Msg)
		m.SetRcode(r, D.RcodeServerFailure)
		// does not matter if this write fails
		w.WriteMsg(m)
		return
	}
	if s.isUDP {
		// RFC 6891: fit the reply into the client's advertised buffer size,
		// setting the TC bit if records must be dropped; 512 when no OPT present
		msg.Truncate(resolver.RequestUDPSize(r))
	}
	msg.Compress = true
	w.WriteMsg(msg)
}

func (s *Server) UDPHandler() D.Handler {
	return serverHandler{Server: s, isUDP: true}
}

func (s *Server) TCPHandler() D.Handler {
	return serverHandler{Server: s, isUDP: false}
}

func (s *Server) SetService(service resolver.Service) {
	s.service.Store(service)
}

func ReCreateServer(addr string, lc C.InboundListenConfig, service resolver.Service) {
	serverMu.Lock()
	defer serverMu.Unlock()

	if addr != address || lc == nil || service == nil {
		if server.tcpServer != nil {
			_ = server.tcpServer.Shutdown()
		}
		if server.udpServer != nil {
			_ = server.udpServer.Shutdown()
		}
		address = ""
		server = &Server{}
	}

	if addr == "" || lc == nil || service == nil {
		return
	}

	_, port, err := net.SplitHostPort(addr)
	if err != nil {
		log.Errorln("Start DNS server error: %s", err)
		return
	}
	if port == "0" || port == "" {
		return
	}

	address = addr
	server.SetService(service)
	if server.udpServer == nil {
		p, err := lc.ListenPacket(context.Background(), "udp", addr)
		if err != nil {
			log.Errorln("Start DNS server(UDP) error: %s", err)
		} else {
			if err := sockopt.UDPReuseaddr(p); err != nil {
				log.Warnln("Failed to Reuse UDP Address: %s", err)
			}
			udp := &D.Server{Addr: addr, PacketConn: p, Handler: server.UDPHandler()}
			if activateDNSListener(udp, "UDP", p.LocalAddr()) {
				server.udpServer = udp
			} else {
				_ = p.Close()
			}
		}
	}

	if server.tcpServer == nil {
		l, err := lc.Listen(context.Background(), "tcp", addr)
		if err != nil {
			log.Errorln("Start DNS server(TCP) error: %s", err)
		} else {
			tcp := &D.Server{Addr: addr, Listener: l, Handler: server.TCPHandler()}
			if activateDNSListener(tcp, "TCP", l.Addr()) {
				server.tcpServer = tcp
			} else {
				_ = l.Close()
			}
		}
	}
}

func activateDNSListener(s *D.Server, protocol string, addr net.Addr) bool {
	ready := make(chan struct{})
	done := make(chan error, 1)
	s.NotifyStartedFunc = func() { close(ready) }
	go func() { done <- s.ActivateAndServe() }()
	select {
	case <-ready:
		log.Infoln("DNS server(%s) listening at: %s", protocol, addr)
		return true
	case err := <-done:
		log.Errorln("Start DNS server(%s) error: %s", protocol, err)
		return false
	}
}
