"""Exercise actual Mihomo dialer-proxy links with local SOCKS exits."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
import json
from pathlib import Path
import socket
import socketserver
import threading
import time

from benchmark_core_relay_windows import (
    EchoTCP, LOCAL, address, channel, connections, core, metrics, read_exact, reserve_port,
    resources, serve, transfer,
)


class SocksExit(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(5)
        try:
            version, count = read_exact(self.request, 2)
            assert version == 5 and 0 in read_exact(self.request, count)
            self.request.sendall(b'\x05\x00')
            assert read_exact(self.request, 4) == b'\x05\x01\x00\x01'
            target = (socket.inet_ntoa(read_exact(self.request, 4)),
                      int.from_bytes(read_exact(self.request, 2), 'big'))
            assert target[0] == LOCAL
            with self.server.lock:
                self.server.dials[target[1]] += 1
            with socket.create_connection(target, timeout=2) as remote:
                remote.settimeout(5)
                self.request.sendall(b'\x05\x00\x00' + address(0))

                def upload():
                    try:
                        while part := self.request.recv(65536):
                            remote.sendall(part)
                        remote.shutdown(socket.SHUT_WR)
                    except OSError:
                        pass

                thread = threading.Thread(target=upload)
                thread.start()
                try:
                    while part := remote.recv(65536):
                        self.request.sendall(part)
                finally:
                    self.request.shutdown(socket.SHUT_RD)
                    thread.join()
        except (EOFError, OSError):
            return


def run(binary, output):
    class Hop(socketserver.ThreadingTCPServer):
        daemon_threads = True
        request_queue_size = 128
        lock = threading.Lock()
        dials = Counter()

    with ExitStack() as stack:
        endpoint = stack.enter_context(serve(socketserver.ThreadingTCPServer, EchoTCP))
        hops = [stack.enter_context(serve(Hop, SocksExit)) for _ in range(3)]
        route = 'proxies:\n'
        for i, port in enumerate(hops):
            route += f'  - name: hop{i + 1}\n    type: socks5\n    server: {LOCAL}\n    port: {port}\n'
            if i:
                route += f'    dialer-proxy: hop{i}\n'
        rows = {}
        for hop in (0, 1, 2, 3):
            selected = 'DIRECT' if hop == 0 else f'hop{hop}'
            cfg = route + f'rules: ["MATCH,{selected}"]'
            with core(binary, output / f'chain-{hop}.log', route=cfg) as instance:
                proc, ctrl, mixed, api, _ = instance
                before = resources(proc, ctrl, api)

                def exchange(_):
                    started = time.perf_counter()
                    with channel(mixed, endpoint, 'tcp') as (conn, header):
                        transfer(conn, header, 'tcp', 65536, 1)
                    return (time.perf_counter() - started) * 1000

                with ThreadPoolExecutor(max_workers=4) as pool:
                    elapsed = list(pool.map(exchange, range(40)))
                for _ in range(20):
                    if not connections(api):
                        break
                    time.sleep(.05)
                assert not connections(api)
                after = resources(proc, ctrl, api)
                rows[hop] = dict(first_echo_ms=metrics(elapsed), before=before, after=after,
                                 bytes=65536 * 40 * 2, applications=len(elapsed))
        for port, expected in [(endpoint, 120), (hops[1], 80), (hops[2], 40)]:
            assert Hop.dials[port] == expected, (port, Hop.dials)
        dead = reserve_port()
        cfg = route.replace(f'port: {hops[1]}\n', f'port: {dead}\n') + 'rules: ["MATCH,hop3"]'
        with core(binary, output / 'chain-broken-hop.log', route=cfg) as instance:
            _, _, mixed, api, _ = instance
            with channel(mixed, endpoint, 'tcp') as (conn, _):
                conn.sendall(b'unreachable')
                try:
                    assert conn.recv(1) == b''
                except ConnectionResetError:
                    pass
            assert not connections(api)
    log = (output / 'chain-broken-hop.log').read_text(encoding='utf-8')
    assert 'hop3' in log and str(dead) in log, log
    (output / 'chain.json').write_text(json.dumps(dict(hops=rows, connections=Hop.dials,
                                                     broken_middle_hop=True), indent=2))
    print({hop: row['first_echo_ms'] for hop, row in rows.items()})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    run(args.binary.resolve(), args.output.resolve())
