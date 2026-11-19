"""Check the live controller access boundary and core delay batch limit."""

import argparse
from contextlib import closing
import json
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import struct
import threading
import time

from benchmark_core_relay_windows import LOCAL, core, metrics, read_exact, resources, serve


class DelayTarget(BaseHTTPRequestHandler):
    def do_HEAD(self):
        server = type(self.server)
        with server.lock:
            server.active += 1
            server.peak = max(server.peak, server.active)
        try:
            time.sleep(.15)
            self.send_response_only(204)
            self.end_headers()
        finally:
            with server.lock:
                server.active -= 1

    do_GET = do_HEAD

    def log_message(self, *_):
        pass


def status(api, path, token):
    with closing(HTTPConnection(LOCAL, api, timeout=2)) as conn:
        conn.request('GET', path, headers={'Authorization': 'Bearer ' + token} if token else {})
        response = conn.getresponse()
        return response.status, response.read()


def run(binary, output):
    class Http(ThreadingHTTPServer):
        request_queue_size = 128
        lock = threading.Lock()
        active = 0
        peak = 0

    with serve(Http, DelayTarget) as port, core(binary, output / 'controller.log') as (proc, rpc, mixed, api, _):
        for endpoint in ('/version', '/connections', '/configs', '/debug/pprof/'):
            assert status(api, endpoint, '')[0] == 401, endpoint
            assert status(api, endpoint, 'incorrect')[0] == 401, endpoint
            code, body = status(api, endpoint, 'local-only')
            assert code == 200 and b'local-only' not in body, (endpoint, code)
        assert status(api, '/version?token=local-only', '')[0] == 401
        initial = resources(proc, rpc, api)
        peak = []
        latencies = []
        for batch in range(3):
            ids = {f'delay-{batch}-{i}' for i in range(65)}
            started = time.perf_counter()
            messages = bytearray()
            for ident in sorted(ids):
                options = {'proxy-name': 'DIRECT', 'timeout': 2500, 'test-url': f'http://{LOCAL}:{port}/{ident}'}
                msg = json.dumps(dict(id=ident, method='asyncTestDelay', data=json.dumps(options))).encode()
                messages.extend(struct.pack('<I', len(msg)) + msg)
            rpc.sendall(messages)
            while ids:
                size, = struct.unpack('<I', read_exact(rpc, 4))
                message = json.loads(read_exact(rpc, size))
                if message.get('id') not in ids:
                    continue
                outcome = json.loads(message['data'])
                assert message['code'] == 0 and outcome['value'] > 0, outcome
                ids.remove(message['id'])
                latencies.append((time.perf_counter() - started) * 1000)
            with Http.lock:
                peak.append(Http.peak)
                assert 1 <= Http.peak <= 50 and Http.active == 0, (Http.peak, Http.active)
                Http.peak = 0
        time.sleep(.25)
        final = resources(proc, rpc, api)
        assert final['tcp'] == 0 and final['udp'] == 0
    results = dict(auth_paths=4, batches=3, completed=len(latencies), peak=peak,
                   dispatch_to_result_ms=metrics(latencies), initial=initial, final=final)
    (output / 'controller.json').write_text(json.dumps(results, indent=2))
    print(json.dumps(results))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    opts = parser.parse_args()
    opts.output.mkdir(parents=True, exist_ok=True)
    run(opts.binary.resolve(), opts.output.resolve())
