"""Test replacement of a rule provider while its previous download is pending."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from http.client import HTTPConnection, RemoteDisconnected
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import socketserver
from threading import Event

import benchmark_core_relay_windows as relay
from benchmark_core_relay_windows import EchoTCP, LOCAL, core, http_get, rpc, serve
from benchmark_core_rules_windows import rules_config
from verify_core_rule_refresh_windows import Remote, check, refresh, reserve_dual_port, ruleset


def reload_config(api, cfg):
    with closing(HTTPConnection(LOCAL, api, timeout=5)) as conn:
        conn.request('PUT', '/configs', json.dumps({'payload': cfg}), headers={
            'Authorization': 'Bearer local-only', 'Content-Type': 'application/json',
        })
        resp = conn.getresponse()
        body = resp.read()
        assert resp.status == 204, (resp.status, body)


def verify(binary, folder, bridge):
    relay.reserve_port = reserve_dual_port
    started, release = Event(), Event()
    initial, outdated = ruleset(True, 0), ruleset(False, 0)
    latest = ruleset(True, 2) + b'  - 198.19.0.1/32\n'
    hold_old = False

    class Delayed(Remote):
        def do_GET(self):
            if self.path == '/old.yaml':
                if hold_old:
                    started.set()
                    assert release.wait(8), 'test did not release the previous response'
                    payload = outdated
                else:
                    payload = initial
            else:
                assert self.path == '/new.yaml'
                payload = latest
            try:
                self.send_response(200)
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass  # The previous generation may cancel its pending request.

    with serve(ThreadingHTTPServer, Delayed) as http, serve(socketserver.ThreadingTCPServer, EchoTCP) as echo:
        route = rules_config(echo).replace('  - MATCH,DIRECT', '  - RULE-SET,remote,DIRECT\n  - MATCH,REJECT').replace(
            'rule-providers:\n',
            f'rule-providers:\n  remote: {{type: http, behavior: ipcidr, proxy: DIRECT, '
            f'url: "http://{LOCAL}:{http}/old.yaml", path: ./remote-rules.yaml}}\n',
        )
        paths = []
        with core(binary, folder/'provider.log', route=route, home_ready=paths.append) as (_, ctrl, mixed, api, _):
            cfg = paths[0]
            cached = cfg.with_name('remote-rules.yaml')

            def count():
                return json.loads(http_get(api, '/providers/rules'))['providers']['remote']['ruleCount']

            def reload():
                if bridge:
                    assert rpc(ctrl, 'setupConfig', '{}') == ''
                else:
                    reload_config(api, cfg.read_text(encoding='utf-8'))

            assert count() == 10001 and cached.read_bytes() == initial
            check(mixed, echo, True)
            hold_old = True
            with ThreadPoolExecutor(max_workers=1) as pool:
                previous = pool.submit(refresh, api)
                try:
                    assert started.wait(3), 'previous request did not reach its upstream'
                    cfg.write_text(cfg.read_text(encoding='utf-8').replace('/old.yaml', '/new.yaml'), encoding='utf-8')
                    reload()
                    assert refresh(api)[0] == 204
                    assert count() == 10002 and cached.read_bytes() == latest
                    check(mixed, echo, True)
                finally:
                    release.set()
                try:
                    old_status = previous.result()[0]
                except RemoteDisconnected:
                    if not bridge:
                        raise
                    old_status = 'controller restarted'
            result = dict(old_refresh=old_status, cache_current=cached.read_bytes() == latest, active_count=count())
            reload()
            result['reloaded_count'] = count()
            (folder/'results.json').write_text(json.dumps(result, indent=2))
            print(result, flush=True)
            assert result['cache_current'] and result['active_count'] == result['reloaded_count'] == 10002, result
            check(mixed, echo, True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('binary', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--bridge', action='store_true')
    args = p.parse_args()
    args.output.mkdir(parents=True)
    verify(args.binary.resolve(), args.output, args.bridge)
