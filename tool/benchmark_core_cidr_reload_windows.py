"""Windows ABBA benchmark for a cached HTTP CIDR provider under real SOCKS load."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import nullcontext
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import socket
import socketserver
import struct
import threading
import time

import benchmark_core_relay_windows as relay
from benchmark_core_relay_windows import (
    EchoTCP, EchoUDP, channel, core, http_get, reserve_port, resources, rpc, serve,
)
from benchmark_core_rules_windows import exchange, rules_config


def reserve_dual_port(*, udp=False):
    if not udp:
        return reserve_port()
    for _ in range(64):
        with socket.socket(type=socket.SOCK_DGRAM) as datagram, socket.socket() as stream:
            datagram.bind(('127.0.0.1', 0))
            port = datagram.getsockname()[1]
            try:
                stream.bind(('127.0.0.1', port))
            except OSError:
                continue
            return port
    raise OSError('no available UDP/TCP fixture port')


class Rules(BaseHTTPRequestHandler):
    fetches = 0
    payload = ('payload:\n  - 127.0.0.1/32\n' + ''.join(
        f'  - 198.18.{i // 256}.{i % 256}/32\n' for i in range(10000)
    )).encode()

    def do_GET(self):
        assert self.path == '/routes.yaml'
        type(self).fetches += 1
        self.send_response(200)
        self.send_header('Content-Length', str(len(self.payload)))
        self.end_headers()
        self.wfile.write(self.payload)


def compare(baseline, candidate, folder):
    relay.reserve_port = reserve_dual_port
    results = []
    with serve(socketserver.ThreadingTCPServer, EchoTCP) as tcp_port, serve(socketserver.UDPServer, EchoUDP) as udp_port, serve(ThreadingHTTPServer, Rules) as rules_port:
        config = rules_config(tcp_port).replace('  - MATCH,DIRECT', '  - RULE-SET,remote,choice\n  - MATCH,REJECT').replace(
            'rule-providers:\n',
            f'rule-providers:\n  remote: {{type: http, behavior: ipcidr, url: "http://127.0.0.1:{rules_port}/routes.yaml", proxy: DIRECT, path: ./remote-rules.yaml}}\n',
        ) + '\nproxy-groups: [{name: choice, type: select, proxies: [REJECT, DIRECT]}]\nprofile: {store-selected: false}\n'
        for trial, mode in enumerate(('baseline', 'candidate', 'candidate', 'baseline'), 1):
            binary = baseline if mode == 'baseline' else candidate
            downloads = Rules.fetches
            stop = threading.Event()
            traffic = {kind: [] for kind in ('udp-existing', 'udp-new', 'tcp-new')}
            with core(binary, folder / f'{trial}-{mode}.log', route=config) as (proc, ctrl, mixed, api, _):
                params = '{"selected-map":{"choice":"DIRECT"}}'
                assert rpc(ctrl, 'setupConfig', params) == ''
                provider = json.loads(http_get(api, '/providers/rules'))['providers']['remote']
                assert provider['ruleCount'] == 10001, provider
                assert Rules.fetches > downloads, 'expected a real local provider download'
                before = resources(proc, ctrl, api)

                def load(kind):
                    shared = channel(mixed, udp_port, 'udp') if kind == 'udp-existing' else nullcontext()
                    with shared as active:
                        sequence = 0
                        while not stop.is_set():
                            sequence += 1
                            start = time.perf_counter_ns()
                            result = 'ok'
                            source_port = None
                            try:
                                if kind == 'tcp-new':
                                    exchange(mixed, tcp_port, 'nomatch.corex.test')
                                else:
                                    with nullcontext(active) if active else channel(mixed, udp_port, 'udp') as (sock, header):
                                        data = struct.pack('!I', sequence) + b'x' * 1196
                                        sock.send(header + data)
                                        source_port = sock.getsockname()[1]
                                        while (reply := sock.recv(4096))[len(header):] != data:
                                            assert reply[:len(header)] == header
                            except (OSError, EOFError, AssertionError) as error:
                                result = type(error).__name__
                            traffic[kind].append((start, time.perf_counter_ns(), result, source_port))
                            stop.wait(.01)

                reloads = []
                with ThreadPoolExecutor(max_workers=len(traffic)) as pool:
                    workers = [pool.submit(load, kind) for kind in traffic]
                    try:
                        time.sleep(.2)
                        for _ in range(48):
                            started = time.perf_counter_ns()
                            assert rpc(ctrl, 'setupConfig', params) == ''
                            reloads.append((started, time.perf_counter_ns()))
                            time.sleep(.08)
                    finally:
                        stop.set()
                    for worker in workers:
                        worker.result()
                assert all(len(events) > 30 for events in traffic.values())
                assert json.loads(http_get(api, '/providers/rules'))['providers']['remote']['ruleCount'] == 10001
                after = resources(proc, ctrl, api)
                row = dict(mode=mode, downloads=Rules.fetches - downloads, reloads=reloads, traffic=traffic, before=before, after=after)
                results.append(row)
                (folder / 'results.json').write_text(json.dumps(results))
                counts = {kind: dict(Counter(row[2] for row in events)) for kind, events in traffic.items()}
                print(trial, mode, counts, flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    compare(args.baseline.resolve(), args.candidate.resolve(), args.output)
