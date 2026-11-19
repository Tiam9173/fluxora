"""Verify HTTP rule refresh, ETag, and preservation of active rules and cache."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socketserver
from threading import Event, Lock
import time

import benchmark_core_relay_windows as relay
from benchmark_core_cidr_reload_windows import reserve_dual_port
from benchmark_core_relay_windows import EchoTCP, core, drain_bridge_events, http_get, metrics, resources, rpc, serve, LOCAL
from benchmark_core_rules_windows import exchange, rules_config


class Remote(BaseHTTPRequestHandler):
    version = 'init'
    payload = b''
    statuses = []

    def log_message(self, *_):
        pass

    def do_GET(self):
        assert self.path == '/routes.yaml'
        tag = '"' + self.version + '"'
        status = 304 if self.headers.get('If-None-Match') == tag else 200
        self.statuses.append(status)
        self.send_response(status)
        self.send_header('ETag', tag)
        self.send_header('Content-Length', str(len(self.payload) if status == 200 else 0))
        self.end_headers()
        if status == 200:
            self.wfile.write(self.payload)


def ruleset(allow, syntax):
    head = ('payload:', 'rules:', '"payload": # comment')[syntax]
    data = '\n'.join(f'  - 198.18.{i//256}.{i%256}/32' for i in range(10000))
    first = ('127.0.0.1' if allow else '127.0.2.1') + '/32'
    if syntax == 1:
        first = f"'{first}' # loopback policy"
    return f'{head}\n  - {first}\n{data}\n'.encode()


def refresh(api):
    with closing(HTTPConnection(LOCAL, api, timeout=5)) as conn:
        conn.request('PUT', '/providers/rules/remote', headers={'Authorization': 'Bearer local-only'})
        r = conn.getresponse()
        return r.status, r.read()


def check(mixed, port, allowed):
    try:
        exchange(mixed, port, 'nomatch.corex.test')
    except (OSError, EOFError):
        assert not allowed, 'matching rule failed'
    else:
        assert allowed, 'non-matching rule reached echo'


def stress(proc, ctrl, mixed, api, port, cached, count, rounds):
    stop = Event()
    bridge = Lock()

    def observe(check):
        samples = []
        while not stop.is_set():
            tick = time.perf_counter()
            check()
            samples.append((time.perf_counter() - tick) * 1000)
            stop.wait(.05)
        return dict(count=len(samples), **metrics(samples))

    def check_status():
        assert count() in (10001, 10002)

    snapshots = [resources(proc, ctrl, api)]
    started = time.monotonic()
    updates = []
    with ThreadPoolExecutor(max_workers=3) as workers:
        status = workers.submit(observe, check_status)
        traffic = workers.submit(observe, lambda: exchange(mixed, port, 'nomatch.corex.test'))
        bridge_reader = workers.submit(drain_bridge_events, ctrl, bridge, stop)
        try:
            for i in range(rounds):
                for task in (status, traffic, bridge_reader):
                    if task.done():
                        task.result()
                        raise AssertionError('load or bridge reader exited early')
                Remote.version = f'stress-{i}'
                Remote.payload = ruleset(True, i % 3) + (b'  - 198.19.0.1/32\n' if i % 2 else b'')
                tick = time.perf_counter()
                result = refresh(api)
                updates.append((time.perf_counter() - tick) * 1000)
                assert result[0] == 204, result
                assert count() == 10001 + i % 2 and cached.read_bytes() == Remote.payload
                if (i + 1) % 100 == 0:
                    with bridge:
                        snapshots.append(resources(proc, ctrl, api))
                time.sleep(.2)
        finally:
            stop.set()
        sampled_status, sampled_traffic = status.result(), traffic.result()
        bridge_reader.result()
    time.sleep(.5)
    snapshots.append(resources(proc, ctrl, api))
    assert snapshots[-1]['tcp'] == snapshots[-1]['udp'] == 0, snapshots[-1]
    return dict(seconds=time.monotonic() - started, updates=dict(count=rounds, **metrics(updates)),
                status=sampled_status, traffic=sampled_traffic, resources=snapshots)


def measure(binary, folder, stress_rounds):
    relay.reserve_port = reserve_dual_port
    Remote.version = 'init'
    Remote.statuses = []
    Remote.payload = ruleset(True, 0)
    rows = {k: [] for k in ('changed', 'unchanged', 'invalid')}
    with serve(ThreadingHTTPServer, Remote) as http, serve(socketserver.ThreadingTCPServer, EchoTCP) as port:
        route = rules_config(port).replace('  - MATCH,DIRECT', '  - RULE-SET,remote,DIRECT\n  - MATCH,REJECT').replace(
            'rule-providers:\n',
            f'rule-providers:\n  remote: {{type: http, behavior: ipcidr, url: "http://127.0.0.1:{http}/routes.yaml", proxy: DIRECT, path: ./remote-rules.yaml}}\n',
        )
        paths = []
        with core(binary, folder/'provider.log', route=route, home_ready=paths.append) as (proc, ctrl, mixed, api, _):
            cached = paths[0].with_name('remote-rules.yaml')
            count = lambda: json.loads(http_get(api, '/providers/rules'))['providers']['remote']['ruleCount']
            check(mixed, port, True)
            for i in range(36):
                allow = i % 2 == 1
                Remote.version = f'{i}'
                Remote.payload = ruleset(allow, i % 3)
                tick = time.perf_counter_ns()
                result = refresh(api)
                rows['changed'].append((time.perf_counter_ns()-tick)/1e6)
                assert result[0] == 204, result
                check(mixed, port, allow)
                assert count() == 10001 and cached.read_bytes() == Remote.payload
                tick = time.perf_counter_ns()
                result = refresh(api)
                rows['unchanged'].append((time.perf_counter_ns()-tick)/1e6)
                assert result[0] == 204 and Remote.statuses[-1] == 304, (result, Remote.statuses[-1])
                check(mixed, port, allow)
                if i % 6 == 1:
                    before = cached.read_bytes()
                    Remote.version = f'bad-{i}'
                    Remote.payload = b'bad-header:\n  - 127.0.0.1/32\n'
                    tick = time.perf_counter_ns()
                    result = refresh(api)
                    rows['invalid'].append((time.perf_counter_ns()-tick)/1e6)
                    assert result[0] == 503, result
                    assert count() == 10001 and cached.read_bytes() == before
                    check(mixed, port, True)
                    assert rpc(ctrl, 'stopListener') is True
                    assert rpc(ctrl, 'startListener') is True
                    check(mixed, port, True)
            for i, payload in enumerate((b'payload: []', b'rules: []\n')):
                Remote.version = f'empty-{i}'
                Remote.payload = payload
                assert refresh(api)[0] == 204
                assert count() == 0 and cached.read_bytes() == payload
                check(mixed, port, False)
                Remote.version = f'restore-{i}'
                Remote.payload = ruleset(True, i)
                assert refresh(api)[0] == 204
                assert count() == 10001
                check(mixed, port, True)
            sustained = stress(proc, ctrl, mixed, api, port, cached, count, stress_rounds) if stress_rounds else None
    res = {k: dict(count=len(v), **metrics(v)) for k, v in rows.items()}
    if sustained:
        res['sustained'] = sustained
    res['statuses'] = {code: Remote.statuses.count(code) for code in (200, 304)}
    (folder/'results.json').write_text(json.dumps(dict(summary=res, elapsed_ms=rows), indent=2))
    print(res, flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('binary', type=Path)
    p.add_argument('folder', type=Path)
    p.add_argument('--stress-rounds', type=int, choices=range(1, 10001), metavar='1..10000')
    args = p.parse_args()
    args.folder.mkdir(exist_ok=False)
    measure(args.binary.resolve(), args.folder, args.stress_rounds)
