#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} != --isolated ]]; then
  exec unshare -Urn -- bash "$0" --isolated "$@"
fi
shift
core=$(realpath "$1")
translator=$(realpath "$2")
python_bin=$3
[[ $(readlink /proc/self/ns/net) != "$(readlink /proc/1/ns/net)" ]]
work=$(mktemp -d)
pids=()
trap 'for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; echo "Fixture logs $work"' EXIT
ip link set lo up
ip addr add 192.0.2.2/32 dev lo
cat > "$work/tayga.conf" <<'EOF'
tun-device nat64test
ipv4-addr 198.18.44.1
ipv6-addr fd12::1
prefix fd64:abcd::/96
map 198.18.44.2 fd11::1
EOF
"$translator" -c "$work/tayga.conf" --mktun
ip link set nat64test up
ip addr add 198.18.44.1/32 dev nat64test
ip -6 addr add fd11::1/128 dev nat64test nodad
ip -6 route add fd64:abcd::/96 dev nat64test src fd11::1
ip -4 route add 198.18.44.2 dev nat64test
"$translator" -c "$work/tayga.conf" --nodetach > "$work/nat64.log" 2>&1 &
pids+=("$!")
cat > "$work/services.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket
import socketserver
import struct
import threading

class Origin(BaseHTTPRequestHandler):
    def do_GET(self):
        assert self.client_address[0] == '198.18.44.2', self.client_address
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'IPv4 origin over NAT64\n')

class DNS(socketserver.BaseRequestHandler):
    def handle(self):
        data, sock = self.request
        end = data.index(0,12)
        qtype = struct.unpack_from('!H', data, end+1)[0]
        count = int(qtype == 28)
        response = data[:2] + struct.pack('!5H', 0x8180, 1, count, 0, 0) + data[12:end+5]
        if count:
            response += b'\xc0\x0c' + struct.pack('!HHIH', 28, 1, 30, 16)
            response += socket.inet_pton(socket.AF_INET6, 'fd64:abcd::c000:202')
        sock.sendto(response, self.client_address)
        print('DNS type={} answers={}'.format(qtype, count), flush=True)

class DNS6(socketserver.UDPServer):
    address_family = socket.AF_INET6

with DNS6(('::1', 18053), DNS) as dns, HTTPServer(('192.0.2.2', 18080), Origin) as server:
    thread = threading.Thread(target=dns.serve_forever)
    thread.daemon = True
    thread.start()
    server.serve_forever()
PY
"$python_bin" "$work/services.py" > "$work/services.log" 2>&1 &
pids+=("$!")
cat > "$work/config.yaml" <<'EOF'
mixed-port: 18082
allow-lan: false
ipv6: true
log-level: debug
dns:
  enable: true
  ipv6: true
  use-hosts: false
  enhanced-mode: redir-host
  nameserver: ["udp://[::1]:18053"]
proxies:
  - {name: direct-v6, type: direct, ip-version: ipv6}
rules: ["MATCH,direct-v6"]
EOF
"$python_bin" "$(dirname "$0")/core_bridge_fixture_linux.py" "$core" "$work" > "$work/core.log" 2>&1 &
pids+=("$!")
for _ in {1..80}; do
  if grep -q 'Mixed(http+socks) proxy listening' "$work/core.log" 2>/dev/null; then break; fi
  sleep .05
done
ip -6 route get fd64:abcd::c000:202 | grep 'dev nat64test'
ip -6 addr show dev nat64test
ip -6 route list table all
kill -0 "${pids[0]}"
curl -gfsS --noproxy '*' --interface 'fd11::1' --max-time 4 'http://[fd64:abcd::c000:202]:18080/' | grep -F 'IPv4 origin over NAT64'
for i in {1..16}; do
  result=$(curl -fsS --noproxy '' --socks5-hostname 127.0.0.1:18082 --max-time 5 \
    -w ',%{time_starttransfer}' "http://probe$i.corex.test:18080/")
  [[ $result == 'IPv4 origin over NAT64'* ]]
  printf '%s\n' "$result"
done
grep 'DNS type=28 answers=1' "$work/services.log" | wc -l
[[ $(grep -c '^DNS type=28 answers=1' "$work/services.log") == 16 ]]
echo 'NAT64 DNS and IPv4 origin PASS'
