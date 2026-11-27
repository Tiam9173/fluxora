"""Check Chrome 157 DNS decisions with a loopback SOCKS5 core and dual-stack origins."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler
import json
from pathlib import Path
import socket
import socketserver
import subprocess
import tempfile
import threading
from urllib.parse import urlsplit

from benchmark_core_relay_windows import core, drain_bridge_events, serve

V4_HOST = 'v4.corex-browser.test'
V6_HOST = 'v6.corex-browser.test'
RESPONSE = 'fluxora-browser-fixture'


class Origin(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f'{RESPONSE}-{self.server.address_family.name}'.encode()
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class LocalV6(socketserver.ThreadingTCPServer):
    address_family = socket.AF_INET6

    def __init__(self, address, handler):
        super().__init__(('::1', address[1]), handler)


def browse(browser, output, host, port, family, options):
    log = output / f'{output.name}.netlog.json'
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix='corex-chromium-', ignore_cleanup_errors=True) as profile:
        result = subprocess.run([
            str(browser), '--headless', '--dump-dom', '--no-first-run',
            '--disable-background-networking', '--disable-sync',
            f'--user-data-dir={profile}', f'--log-net-log={log}', *options,
            f'http://{host}:{port}/fixture',
        ], capture_output=True, text=True, timeout=40, check=True,
            creationflags=subprocess.CREATE_NO_WINDOW)
    assert f'{RESPONSE}-{family.name}' in result.stdout, result.stdout[-500:]
    events = json.loads(log.read_text(encoding='utf-8'))
    assert events['constants']['clientInfo']['version'].split('.')[0] == '157'
    types = events['constants']['logEventTypes']
    request_type = types['HOST_RESOLVER_MANAGER_REQUEST']
    tasks_type = types['HOST_RESOLVER_MANAGER_TASK_SEQUENCE_CREATED']
    phases = events['constants']['logEventPhase']
    requests, pending = [], {}
    for event in events['events']:
        source = event['source']['id']
        params = event.get('params', {})
        if event['type'] == tasks_type and source in pending:
            pending[source]['tasks'] = params['tasks']
        if event['type'] != request_type:
            continue
        if event['phase'] == phases['PHASE_BEGIN']:
            target = params.get('host', '')
            if urlsplit(target).hostname == host:
                request = {'host': target, 'speculative': params.get('is_speculative')}
                pending[source] = request
                requests.append(request)
        elif event['phase'] == phases['PHASE_END'] and source in pending:
            pending.pop(source)['net_error'] = params.get('net_error', 0)
    return requests


def verify(browser, binary, output):
    config = (
        f'hosts: {{{V4_HOST}: "127.0.0.1", {V6_HOST}: "::1"}}'
        f'\nrules: ["DOMAIN,{V4_HOST},DIRECT", "DOMAIN,{V6_HOST},DIRECT", "MATCH,REJECT"]'
    )
    with ExitStack() as stack:
        port4 = stack.enter_context(serve(socketserver.ThreadingTCPServer, Origin))
        port6 = stack.enter_context(serve(LocalV6, Origin))
        control = browse(browser, output / 'direct-control', 'localhost', port4, socket.AF_INET, [
            '--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost',
        ])
        assert control, 'direct control did not produce a browser resolver event'
        _, conn, mixed, _, _ = stack.enter_context(
            core(binary, output / 'core.log', route=config, ipv6=True)
        )
        stop = threading.Event()
        with ThreadPoolExecutor(max_workers=1) as reader:
            drain = reader.submit(drain_bridge_events, conn, threading.Lock(), stop)
            try:
                proxied = {
                    host: browse(browser, output / family.name, host, port, family,
                                 [f'--proxy-server=socks5://127.0.0.1:{mixed}',
                                  f'--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1, EXCLUDE {host}'])
                    for host, port, family in (
                        (V4_HOST, port4, socket.AF_INET), (V6_HOST, port6, socket.AF_INET6),
                    )
                }
            finally:
                stop.set()
                drain.result()
        return {'origins_ok': 2, 'direct_resolver_requests': control,
                'proxied_resolver_requests': proxied}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('browser', type=Path)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True)
    report = verify(args.browser.resolve(), args.binary.resolve(), args.output.resolve())
    (args.output / 'browser.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(report)
    # Chrome 157 TaskType 4 and 9 look up the cache and hosts file in process.
    for requests in report['proxied_resolver_requests'].values():
        for request in requests:
            assert request.get('net_error') == -105 and request.get('tasks'), request
            assert set(request['tasks']) <= {4, 9}, request
