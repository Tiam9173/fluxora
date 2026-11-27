"""Measure rule position, local rule providers, reload and idle/traffic soak."""

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import socketserver
import threading
import time

from benchmark_core_relay_windows import (
    EchoTCP, LOCAL, command, core, drain_bridge_events, greet, http_get, metrics, read_exact, resources, rpc, serve, tcp,
)


def rules_config(exit_port):
    proxies = '\n'.join(f'  - {{name: p{i}, type: http, server: {LOCAL}, port: {exit_port}}}' for i in range(1000))
    rules = '\n'.join(f'  - DOMAIN,name{i}.corex.test,DIRECT' for i in range(3000))
    return (f'proxies:\n{proxies}\n'
            'rule-providers:\n  testset:\n    type: inline\n    behavior: domain\n'
            '    payload: [provider.corex.test]\n'
            'sub-rules:\n  testsub: ["DOMAIN,sub.corex.test,DIRECT"]\n'
            'hosts:\n  "+.corex.test": 127.0.0.1\n'
            f'rules:\n{rules}\n  - RULE-SET,testset,DIRECT\n'
            '  - SUB-RULE,(DOMAIN,sub.corex.test),testsub\n  - MATCH,DIRECT')


def exchange(mixed, port, name):
    raw = name.encode()
    started = time.perf_counter()
    with tcp(mixed) as conn:
        greet(conn)
        command(conn, 1, b'\x03' + bytes([len(raw)]) + raw + port.to_bytes(2, 'big'))
        conn.sendall(b'checked')
        assert read_exact(conn, 7) == b'checked'
    return (time.perf_counter() - started) * 1000


def heap_classes(api):
    stats = http_get(api, '/debug/pprof/heap?debug=1')
    fields = ('Sys', 'HeapAlloc', 'HeapInuse', 'HeapReleased', 'GCSys', 'NumGC', 'NumForcedGC')
    data = {key: int(re.search(rb'^# ' + key.encode() + rb' = (\d+)$', stats, re.M)[1]) for key in fields}
    data['go_sys_minus_released'] = data['Sys'] - data['HeapReleased']
    return data


def measure(binary, output, soak_seconds, reload=True):
    files = []
    with serve(socketserver.ThreadingTCPServer, EchoTCP) as port, core(
        binary, output / 'rules.log', route=rules_config(port), home_ready=files.append,
    ) as (proc, ctrl, mixed, api, startup):
        conf, = files
        original = conf.read_text(encoding='utf-8')
        try:
            conf.write_text(original.replace('  - MATCH,DIRECT', '  - INVALID,DIRECT'), encoding='utf-8')
            rejection = rpc(ctrl, 'setupConfig', '{}')
            assert rejection, rejection
            assert exchange(mixed, port, 'nomatch.corex.test') > 0
            assert rpc(ctrl, 'stopListener')
            assert rpc(ctrl, 'startListener'), 'rejected config cleared the last good configuration'
            assert exchange(mixed, port, 'nomatch.corex.test') > 0
        finally:
            conf.write_text(original, encoding='utf-8')
        assert rpc(ctrl, 'setupConfig', '{}') == ''
        modes = {'first': 'name0', 'last': 'name2999', 'provider': 'provider',
                 'subrule': 'sub', 'miss': 'nomatch'}
        rows = defaultdict(list)
        for _ in range(40):
            for mode, label in modes.items():
                rows[mode].append(exchange(mixed, port, f'{label}.corex.test'))
        exit_flag = threading.Event()
        completion = []
        request_errors = []

        def continuous():
            while not exit_flag.wait(.04):
                began = time.monotonic()
                try:
                    completion.append(exchange(mixed, port, 'nomatch.corex.test'))
                except (OSError, EOFError) as e:
                    completion.append(type(e).__name__)
                    request_errors.append(dict(
                        start=began - start, end=time.monotonic() - start, error=type(e).__name__,
                    ))

        with ThreadPoolExecutor(max_workers=2) as pool:
            if soak_seconds:
                (output / 'heap-start.txt').write_bytes(http_get(api, '/debug/pprof/heap?debug=1'))
                start = time.monotonic()
                bridge_lock = threading.Lock()
                drainer = pool.submit(drain_bridge_events, ctrl, bridge_lock, exit_flag)
                traffic = pool.submit(continuous)
                try:
                    ticks = []
                    deadline = start + soak_seconds
                    next_reload = start
                    next_heap = start
                    reload_events = []
                    sample_errors = []
                    sample_path = output / 'soak-samples.jsonl'
                    sample_path.write_text('', encoding='utf-8')
                    while time.monotonic() < deadline:
                        if drainer.done():
                            drainer.result()
                            raise RuntimeError('bridge event reader stopped early')
                        now = time.monotonic()
                        if reload and now >= next_reload:
                            begin = time.perf_counter()
                            with bridge_lock:
                                assert rpc(ctrl, 'setupConfig', '{}') == ''
                            rows['reload'].append((time.perf_counter() - begin) * 1000)
                            reload_events.append(dict(start=now - start, end=time.monotonic() - start))
                            next_reload = now + 30
                        try:
                            with bridge_lock:
                                tick = dict(seconds=now - start, **resources(proc, ctrl, api))
                            if now >= next_heap:
                                tick.update(heap_classes(api))
                                next_heap = now + 30
                            ticks.append(tick)
                        except (OSError, EOFError) as error:
                            sample_errors.append(dict(seconds=now - start, error=str(error)))
                            time.sleep(min(1, max(0, deadline - time.monotonic())))
                            continue
                        with sample_path.open('a', encoding='utf-8') as sample_file:
                            sample_file.write(json.dumps(dict(ticks[-1], requests=len(completion),
                                reloads=len(rows['reload']), sample_errors=len(sample_errors))) + '\n')
                        time.sleep(min(5, max(0, deadline - time.monotonic())))
                finally:
                    exit_flag.set()
                    drainer.result()
                    traffic.result()
                elapsed_seconds = time.monotonic() - start
                (output / 'heap-end.txt').write_bytes(http_get(api, '/debug/pprof/heap?debug=1'))
                (output / 'soak.json').write_text(json.dumps(dict(samples=ticks, requests=completion,
                    reloads=rows['reload'], sample_errors=sample_errors,
                    elapsed_seconds=elapsed_seconds, request_errors=request_errors,
                    reload_events=reload_events), indent=2))
            else:
                workload = pool.submit(lambda: [exchange(mixed, port, 'name2999.corex.test') for _ in range(160)])
                profile = http_get(api, '/debug/pprof/profile?seconds=3')
                (output / 'rule-cpu.pb.gz').write_bytes(profile)
                rows['profiled_late'] = workload.result()

        out = {name: metrics(data) for name, data in rows.items() if data}
        (output / 'rules.json').write_text(json.dumps(dict(startup=startup, ms=out,
            rejected_config=rejection), indent=2))
        print(json.dumps(out))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--soak-seconds', type=int, default=0)
    parser.add_argument('--without-reload', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    measure(args.binary.resolve(), args.output.resolve(), args.soak_seconds, reload=not args.without_reload)
