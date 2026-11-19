#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} != --isolated ]]; then
  exec unshare -Urn -- bash "$0" --isolated "$@"
fi
shift
binary=$(realpath "$1")
python_bin=$2
stack=$3
case "$stack" in system|gvisor|mixed|mips) ;; *) exit 2 ;; esac
[[ $(readlink /proc/self/ns/net) != "$(readlink /proc/1/ns/net)" ]]

fixture=$(mktemp -d)
core_pid=
peer_pid=
cleanup() {
  if [[ -n $core_pid ]]; then kill "$core_pid" 2>/dev/null || true; wait "$core_pid" || true; fi
  if [[ -n $peer_pid ]]; then kill "$peer_pid" 2>/dev/null || true; wait "$peer_pid" 2>/dev/null || true; fi
  rm -f -- "$fixture/config.yaml" "$fixture/probe.py" "$fixture/peer.py" "$fixture/before" "$fixture/after"
  printf 'Fixture logs %s\n' "$fixture"
}
trap cleanup EXIT
ip link set lo up

cat > "$fixture/peer.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import select
import socket
import threading

class Server(BaseHTTPRequestHandler):
    def do_GET(self):
        data = b'x' * 65536
        self.send_response(200)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

class IPv6HTTPServer(HTTPServer):
    address_family = socket.AF_INET6

def datagrams():
    listeners = {}
    for family, echo, dns in [(socket.AF_INET, '203.0.113.2', '198.51.100.53'),
                             (socket.AF_INET6, 'fd54:2::2', 'fd54:3::53')]:
        for addr, port in [(echo, 18082), (dns, 53)]:
            listener = socket.socket(family, socket.SOCK_DGRAM)
            listener.bind((addr, port))
            listeners[listener] = port
    while True:
        for listener in select.select(listeners, [], [])[0]:
            data, source = listener.recvfrom(65535)
            if listeners[listener] == 53:
                print('DNS reached upstream fixture', flush=True)
            else:
                listener.sendto(data, source)

threading.Thread(target=datagrams, daemon=True).start()
http6 = IPv6HTTPServer(('fd54:2::2', 18081), Server)
threading.Thread(target=http6.serve_forever, daemon=True).start()
HTTPServer(('203.0.113.2', 18081), Server).serve_forever()
PY

ip link add uplink0 type veth peer name target0
unshare -n -- bash -ec 'kill -STOP "$$"; ip link set lo up; ip addr add 203.0.113.2/32 dev lo; ip addr add 198.51.100.53/32 dev lo; ip -6 addr add fd54:2::2/128 dev lo nodad; ip -6 addr add fd54:3::53/128 dev lo nodad; ip addr add 192.0.2.2/24 dev target0; ip link set target0 up; ip -6 addr add fd54:1::2/64 dev target0 nodad; exec "$@"' _ "$python_bin" "$fixture/peer.py" > "$fixture/peer.log" 2>&1 &
peer_pid=$!
for _ in {1..100}; do
  if grep -q '^State:[[:space:]]*T' "/proc/$peer_pid/status"; then break; fi
  sleep .01
done
ip link set target0 netns "$peer_pid"
ip addr add 192.0.2.1/24 dev uplink0
ip link set uplink0 up
ip -6 addr add fd54:1::1/64 dev uplink0 nodad
ip route add default via 192.0.2.2 dev uplink0
ip -6 route add default via fd54:1::2 dev uplink0
kill -CONT "$peer_pid"
for _ in {1..100}; do
  if curl -fsS --noproxy '*' --connect-timeout .2 http://203.0.113.2:18081/ >/dev/null 2>&1; then break; fi
  sleep .03
done
{ ip -4 -o route show table all; ip -6 -o route show table all; ip -4 rule show; ip -6 rule show; } > "$fixture/before"

cat > "$fixture/config.yaml" <<EOF
log-level: debug
ipv6: true
external-controller: 127.0.0.1:19092
secret: fixture-only
dns:
  enable: true
  ipv6: true
  enhanced-mode: redir-host
  nameserver: [udp://127.0.0.1:19153]
tun:
  enable: true
  device: corextun
  stack: $stack
  dns-mode: disabled
  auto-route: true
  auto-detect-interface: false
  inet6-address: ["fd54:4::1/126"]
  route-address: [203.0.113.2/32, 198.51.100.53/32, "fd54:2::2/128", "fd54:3::53/128"]
  dns-hijack: [any:53]
hosts:
  probe4.corex.test: 203.0.113.2
  probe6.corex.test: "fd54:2::2"
proxies:
  - {name: fixture-uplink, type: direct, interface-name: uplink0}
rules: ["MATCH,fixture-uplink"]
EOF
"$python_bin" "$(dirname "$0")/core_bridge_fixture_linux.py" "$binary" "$fixture" > "$fixture/core.log" 2>&1 &
core_pid=$!
for _ in {1..100}; do
  if curl -fsS --noproxy '*' -H 'Authorization: Bearer fixture-only' http://127.0.0.1:19092/version >/dev/null 2>&1; then break; fi
  sleep .03
done
for _ in {1..100}; do
  if ip link show corextun >/dev/null 2>&1; then break; fi
  kill -0 "$core_pid"
  sleep .03
done
ip link show corextun
ip route get 203.0.113.2
ip route get 203.0.113.2 | grep -q 'dev corextun'
ip -6 route get fd54:2::2 | grep -q 'dev corextun'
cat > "$fixture/probe.py" <<'PY'
import socket
import struct
import time

for family, dns, target, label, rtype in [
    (socket.AF_INET, '198.51.100.53', '203.0.113.2', b'probe4', 1),
    (socket.AF_INET6, 'fd54:3::53', 'fd54:2::2', b'probe6', 28),
]:
    query = struct.pack('!6H', 0x1234, 0x0100, 1, 0, 0, 0)
    query += bytes([len(label)]) + label + b'\x05corex\x04test\0' + struct.pack('!2H', rtype, 1)
    expected = socket.inet_pton(family, target)
    with socket.socket(family, socket.SOCK_DGRAM) as s:
        s.settimeout(3)
        s.sendto(query, (dns, 53))
        result, sender = s.recvfrom(2048)
    assert sender[:2] == (dns, 53), sender
    assert result[:2] == query[:2] and result.endswith(expected), result.hex()
    print('DNS hijack PASS type={}'.format(rtype))

    start = time.monotonic()
    lost = 0
    with socket.socket(family, socket.SOCK_DGRAM) as s:
        s.settimeout(.25)
        s.connect((target, 18082))
        for sequence in range(128):
            data = struct.pack('!I', sequence) + b'x' * 1196
            s.send(data)
            try:
                assert s.recv(2048) == data
            except socket.timeout:
                lost += 1
    elapsed = time.monotonic() - start
    assert lost == 0, (target, lost)
    print('UDP echo PASS {} 128/128 1200B in {:.3f}s'.format(target, elapsed))
PY
"$python_bin" "$fixture/probe.py"
! grep -q 'DNS reached upstream fixture' "$fixture/peer.log"
for host in 203.0.113.2 '[fd54:2::2]'; do
  for _ in {1..15}; do
    curl -gfsS --noproxy '*' --max-time 3 -o /dev/null -w "$host,%{time_starttransfer},%{size_download},%{speed_download}\n" "http://$host:18081/"
  done
done
grep -F 'using fixture-uplink' "$fixture/core.log" | tail -n 1
ip link set uplink0 down
for host in 203.0.113.2 '[fd54:2::2]'; do
  if curl -gfsS --noproxy '*' --max-time .5 "http://$host:18081/" >/dev/null 2>&1; then
    echo "unexpected success for $host with fixture uplink down" >&2
    exit 1
  fi
done
restored=$(date +%s%N)
ip link set uplink0 up
ip -6 addr replace fd54:1::1/64 dev uplink0 nodad
ip route replace default via 192.0.2.2 dev uplink0
ip -6 route replace default via fd54:1::2 dev uplink0
for _ in {1..30}; do
  if curl -fsS --noproxy '*' --max-time .5 http://203.0.113.2:18081/ >/dev/null 2>&1; then
    echo "original route recovery $(( ($(date +%s%N) - restored) / 1000000 )) ms"
    break
  fi
done
curl -fsS --noproxy '*' --max-time 3 http://203.0.113.2:18081/ >/dev/null
curl -gfsS --noproxy '*' --max-time 3 'http://[fd54:2::2]:18081/' >/dev/null
grep -F 'using fixture-uplink' "$fixture/core.log" | tail -n 1
kill -TERM "$core_pid"
wait "$core_pid"
core_pid=
! ip link show corextun 2>/dev/null
{ ip -4 -o route show table all; ip -6 -o route show table all; ip -4 rule show; ip -6 rule show; } > "$fixture/after"
diff "$fixture/before" "$fixture/after"
echo 'TUN and route cleanup PASS'
