"""Run after the native profile-switch test exports switch-A/B.json fixtures.

Usage: python tool/benchmark_rule_cache.py <desktop-core.exe> <fixture-directory>
Uses only loopback listeners, temporary configs, and a local slow rule server.
"""
import copy, http.server, json, os, socket, struct, subprocess, sys, tempfile, threading, time
from pathlib import Path

folder = Path(sys.argv[2]).resolve()
binary = Path(sys.argv[1]).resolve()
fixtures = [json.loads((folder / ('switch-' + p + '.json')).read_text(encoding='utf-8')) for p in ['A', 'B']]

def exact(s, n):
    data = bytearray()
    while len(data) < n:
        block = s.recv(n - len(data))
        assert block, 'bridge closed'
        data.extend(block)
    return data

def rpc(s, method, data=None):
    request = json.dumps(dict(id=method, method=method, data=data)).encode()
    s.sendall(struct.pack('<I', len(request)) + request)
    while True:
        size, = struct.unpack('<I', exact(s, 4))
        reply = json.loads(exact(s, size))
        if reply.get('id') == method:
            assert reply['code'] == 0, reply
            return reply['data']

class Rules(http.server.BaseHTTPRequestHandler):
    calls = 0
    def do_GET(self):
        type(self).calls += 1
        time.sleep(.8)
        self.send_response(200)
        self.send_header('Content-Length', '25')
        self.end_headers()
        self.wfile.write(b'payload: [probe.example]\n')
    def log_message(self, *args): pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Rules)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
results = []
try:
    for variant in ['before', 'after', 'after', 'before']:
        with tempfile.TemporaryDirectory(prefix='fluxora-script-cache-') as home, socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            listener.settimeout(15)
            config_file = Path(home, 'config.yaml')
            def config(profile, fixture):
                value = copy.deepcopy(fixture)
                value.update({'mixed-port': 0, 'allow-lan': False, 'external-controller': '', 'external-ui': '', 'external-ui-url': '', 'log-level': 'warning', 'geodata-mode': False, 'ipv6': False})
                value['tun'] = {'enable': False}
                value['dns'] = {'enable': False}
                value['profile'] = {'store-selected': False, 'store-fake-ip': False}
                provider = value['rule-providers']['common']
                provider['url'] = f'http://127.0.0.1:{server.server_port}/rules.yaml'
                provider['proxy'] = 'DIRECT'
                # Preserve the actual application-generated cache basename.
                basename = Path(provider['path']).name
                provider['path'] = str(Path(home, 'rules', profile if variant == 'before' else 'shared', basename))
                return value
            config_file.write_text(json.dumps(config('A', fixtures[0])), encoding='utf-8')
            log = (folder / f'provider-{len(results)}-{variant}.log').open('wb')
            proc = subprocess.Popen([str(binary), str(listener.getsockname()[1])], cwd=home, stdout=log, stderr=log)
            conn = None
            try:
                conn, _ = listener.accept()
                conn.settimeout(15)
                assert rpc(conn, 'initClash', json.dumps({'home-dir': home, 'version': 1})) is True
                first = time.perf_counter()
                initial_calls = Rules.calls
                assert rpc(conn, 'setupConfig', '{}') == ''
                cold_ms = (time.perf_counter() - first) * 1000
                assert Rules.calls == initial_calls + 1
                assert Path(config('A', fixtures[0])['rule-providers']['common']['path']).read_bytes() == b'payload: [probe.example]\n'
                rows = []
                for profile in ['B', 'C', 'D', 'E']:
                    config_file.write_text(json.dumps(config(profile, fixtures[1])), encoding='utf-8')
                    calls = Rules.calls
                    started = time.perf_counter()
                    assert rpc(conn, 'setupConfig', '{}') == ''
                    proxies = rpc(conn, 'getProxies')
                    assert proxies['Select']['all'] == ['B-node · script'], proxies['Select']
                    assert Path(config(profile, fixtures[1])['rule-providers']['common']['path']).read_bytes() == b'payload: [probe.example]\n'
                    rows.append({'profile': profile, 'apply_to_nodes_ms': (time.perf_counter()-started)*1000, 'downloads': Rules.calls-calls})
                assert all(r['downloads'] == (1 if variant == 'before' else 0) for r in rows)
                if variant == 'after':
                    cache = Path(config('E', fixtures[1])['rule-providers']['common']['path'])
                    old = time.time()-3*86400
                    os.utime(cache, (old, old))
                    calls = Rules.calls
                    assert rpc(conn, 'setupConfig', '{}') == ''
                    deadline = time.monotonic()+3
                    while Rules.calls == calls and time.monotonic()<deadline: time.sleep(.01)
                    assert Rules.calls > calls, 'expired cache was not refreshed'
                    while cache.stat().st_mtime < old+1 and time.monotonic()<deadline: time.sleep(.01)
                    assert cache.stat().st_mtime > old+1
                    # Upstream schedules another immediate pull for an expired
                    # provider; let it finish before shutting its context down.
                    time.sleep(1)
                assert rpc(conn, 'shutdown') is True
                conn.close()
                conn = None
                assert proc.wait(timeout=10) == 0
                results.append({'variant': variant, 'cold_ms': cold_ms, 'switches': rows})
                (folder/'provider-results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
                print(json.dumps(results[-1]), flush=True)
            finally:
                if conn: conn.close()
                if proc.poll() is None: proc.kill(); proc.wait(timeout=10)
                log.close()
finally:
    server.shutdown()
    thread.join()
    server.server_close()
