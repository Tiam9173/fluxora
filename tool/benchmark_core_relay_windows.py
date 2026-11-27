"""Isolated benchmark for the real core bridge and mixed SOCKS port."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import ctypes as win
from contextlib import contextmanager, ExitStack
from http.client import HTTPConnection
import errno
import json
import os
from pathlib import Path
import re
import select
import socket
import socketserver
import statistics
import struct
import subprocess
import tempfile
import threading
import time

from measure_core_idle_windows import ProcessMemory, http_get, process_sample, read_exact, reserve_port, rpc, wint


LOCAL = '127.0.0.1'
FIN = b'relay-fin'


def drain_bridge_events(conn, bridge_lock, stop):
    # Match the desktop app's continuous consumption of unsolicited events.
    while not stop.is_set():
        with bridge_lock:
            while select.select([conn], [], [], 0)[0]:
                length, = struct.unpack('<I', read_exact(conn, 4))
                event = json.loads(read_exact(conn, length))
                assert event['method'] == 'message' and not event.get('id'), event
        stop.wait(.005)


class PrivateMemory(ProcessMemory):
    _fields_ = [('private', win.c_size_t)]


class EchoTCP(socketserver.BaseRequestHandler):
    def handle(self):
        with self.request as conn:
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            try:
                while True:
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    conn.sendall(chunk)
                conn.sendall(FIN)
            except (BrokenPipeError, ConnectionResetError):
                pass


class EchoUDP(socketserver.BaseRequestHandler):
    def handle(self):
        packet, conn = self.request
        conn.sendto(packet, self.client_address)


@contextmanager
def serve(server_type, handler):
    with server_type((LOCAL, 0), handler) as server:
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .05})
        thread.start()
        try:
            yield server.server_address[1]
        finally:
            server.shutdown()
            thread.join()


def timed(call, *args):
    start = time.perf_counter_ns()
    result = call(*args)
    return result, (time.perf_counter_ns() - start) / 1e6


@contextmanager
def core(binary, output, dns='  enable: false', *, route='rules: ["MATCH,DIRECT"]', ipv6=False, home_ready=None):
    with tempfile.TemporaryDirectory() as home, socket.socket() as listener:
        mixed, api = reserve_port(udp=True), reserve_port()
        assert api != mixed
        listener.bind((LOCAL, 0))
        listener.listen()
        listener.settimeout(15)
        config = Path(home, 'config.yaml')
        config.write_text(
            f'mixed-port: {mixed}\nallow-lan: false\nlog-level: debug\n'
            f'external-controller: {LOCAL}:{api}\nsecret: local-only\n'
            f'ipv6: {str(ipv6).lower()}\ndns:\n{dns}\ntun: {{enable: false}}\n'
            f'mode: rule\n{route}\n', encoding='utf-8')
        if home_ready:
            home_ready(config)
        started = time.perf_counter_ns()
        with output.open('wb') as log, subprocess.Popen(
            [str(binary), str(listener.getsockname()[1])], cwd=home, stdout=log, stderr=log
        ) as proc:
            try:
                conn, _ = listener.accept()
                startup = {'spawn_ns': started, 'spawn_to_bridge_ms': (time.perf_counter_ns() - started) / 1e6}
                with conn:
                    conn.settimeout(15)
                    for name, arg, expected in (
                        ('initClash', json.dumps({'home-dir': home, 'version': 1}), True),
                        ('setupConfig', '{}', ''), ('startListener', None, True),
                    ):
                        result, startup[name + '_ms'] = timed(rpc, conn, name, arg)
                        assert result == expected, (name, result)
                    assert json.loads(http_get(api, '/version'))['version'] == 'v1.19.34'
                    yield proc, conn, mixed, api, startup
                    assert rpc(conn, 'shutdown') is True
                assert proc.wait(timeout=10) == 0
                with socket.socket() as check:
                    refused = 10061 if os.name == 'nt' else errno.ECONNREFUSED
                    assert check.connect_ex((LOCAL, mixed)) == refused
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait(timeout=10)


def tcp(port):
    conn = socket.create_connection((LOCAL, port), timeout=10)
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    return conn


def greet(conn):
    conn.sendall(b'\x05\x01\x00')
    assert read_exact(conn, 2) == b'\x05\x00'


def address(port):
    return b'\x01' + socket.inet_aton(LOCAL) + struct.pack('!H', port)


def command(conn, code, dest):
    conn.sendall(bytes((5, code, 0)) + dest)
    version, status, reserved, family = read_exact(conn, 4)
    assert (version, reserved) == (5, 0)
    if status:
        raise ConnectionError(f'SOCKS status {status}')
    assert family in (1, 4)
    read_exact(conn, 4 if family == 1 else 16)
    return int.from_bytes(read_exact(conn, 2), 'big')


@contextmanager
def channel(mixed, port, proto):
    with ExitStack() as stack:
        if mixed:
            control = stack.enter_context(tcp(mixed))
            greet(control)
            relay_port = command(control, 1 if proto == 'tcp' else 3, address(port if proto == 'tcp' else 0))
        if proto == 'tcp':
            conn = control if mixed else stack.enter_context(tcp(port))
            yield conn, b''
        else:
            conn = stack.enter_context(socket.socket(type=socket.SOCK_DGRAM))
            conn.connect((LOCAL, relay_port if mixed else port))
            conn.settimeout(.3)
            yield conn, b'\0\0\0' + address(port) if mixed else b''


def transfer(conn, header, proto, size, window, timeout=.3):
    if proto == 'tcp':
        payload = b'x' * size
        start = time.perf_counter_ns()
        conn.sendall(payload)
        assert read_exact(conn, size) == payload
        return [(time.perf_counter_ns() - start) / 1000], 0

    payload = b'x' * (size - 8)
    pending = {}
    for sequence in range(window):
        stamp = time.perf_counter_ns()
        pending[stamp] = sequence
        conn.send(header + struct.pack('!Q', stamp) + payload)
    samples, reordered, last = [], 0, -1
    deadline = time.monotonic() + timeout
    while pending and deadline > time.monotonic():
        conn.settimeout(max(.001, deadline - time.monotonic()))
        try:
            packet = conn.recv(2048)
        except TimeoutError:
            break
        assert packet.startswith(header) and packet[len(header) + 8:] == payload
        stamp, = struct.unpack_from('!Q', packet, len(header))
        if stamp in pending:
            sequence = pending.pop(stamp)
            reordered += sequence < last
            last = max(last, sequence)
            samples.append((time.perf_counter_ns() - stamp) / 1000)
    return samples, reordered


def metrics(values):
    ordered = sorted(values)
    assert ordered
    return dict(p50=statistics.median(ordered), p95=ordered[(len(ordered) * 95 - 1) // 100],
                p99=ordered[(len(ordered) * 99 - 1) // 100])


def process_resources(proc):
    if os.name != 'nt':
        path = Path('/proc', str(proc.pid))
        fields = path.joinpath('stat').read_text().rsplit(')', 1)[1].split()
        cpu = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
        memory = dict(re.findall(r'^(Rss|Private_Clean|Private_Dirty):\s+(\d+) kB$',
                                 path.joinpath('smaps_rollup').read_text(), re.M))
        rss = int(memory['Rss']) * 1024
        # Linux private resident pages; distinct from committed Windows Private Bytes.
        private = (int(memory['Private_Clean']) + int(memory['Private_Dirty'])) * 1024
        return rss, private, cpu
    handle = wint.HANDLE(int(proc._handle))
    rss, cpu = process_sample(handle)
    private_info = PrivateMemory()
    private_info.cb = win.sizeof(private_info)
    if not win.windll.psapi.GetProcessMemoryInfo(handle, win.byref(private_info), private_info.cb):
        raise win.WinError()
    return rss, private_info.private, cpu


def resources(proc, conn, api):
    rss, private, cpu = process_resources(proc)
    heap = dict(re.findall(rb'^# (HeapAlloc|TotalAlloc|Mallocs) = (\d+)',
                           http_get(api, '/debug/pprof/heap?debug=1'), re.M))
    status = json.loads(rpc(conn, 'getCoreStatus'))
    trackers = [item['metadata']['network'] for item in connections(api)]
    return dict(rss=rss, private=private, cpu=cpu, heap=int(heap[b'HeapAlloc']),
                total_alloc=int(heap[b'TotalAlloc']), mallocs=int(heap[b'Mallocs']),
                goroutines=status['goroutines'], tcp=trackers.count('tcp'), udp=trackers.count('udp'))


def connections(api):
    return json.loads(http_get(api, '/connections'))['connections'] or []


def trial(instance, port, case, use_proxy, duration, interval=0):
    proc, rpc_conn, mixed, api, _ = instance
    proto, clients, size, window = case
    barrier = threading.Barrier(clients + 1, timeout=15)
    start_work = threading.Event()
    started = None

    def work():
        samples, reordered, sent = [], 0, 0
        with channel(mixed if use_proxy else 0, port, proto) as (conn, header):
            for warmup in range(15):
                assert transfer(conn, header, proto, size, 1, timeout=6 if not warmup else .3)[0]
            barrier.wait()
            assert start_work.wait(15)
            while (sent * interval / window < duration if interval
                   else time.perf_counter() < started + duration):
                if interval:
                    delay = started + sent * interval / window - time.perf_counter()
                    if delay > 0:
                        time.sleep(delay)
                received, order = transfer(conn, header, proto, size, window)
                samples.extend(received)
                reordered += order
                sent += window
        return samples, reordered, sent

    with ThreadPoolExecutor(max_workers=clients) as pool:
        jobs = [pool.submit(work) for _ in range(clients)]
        barrier.wait()
        before = resources(proc, rpc_conn, api) if use_proxy else None
        started = time.perf_counter()
        start_work.set()
        batches = [job.result() for job in jobs]
        elapsed = time.perf_counter() - started
        after = resources(proc, rpc_conn, api) if use_proxy else None
    samples = [item for batch, _, _ in batches for item in batch]
    sent = sum(sent for _, _, sent in batches)
    assert sent and (proto == 'udp' or sent == len(samples))
    result = dict(case=case, path='mihomo' if use_proxy else 'direct', elapsed=elapsed, interval=interval,
                  sent=sent, received=len(samples), reordered=sum(order for _, order, _ in batches),
                  mib_s=2 * len(samples) * size / elapsed / 2**20, us=metrics(samples))
    if use_proxy:
        result.update(before=before, after=after,
                      cpu_us_op=(after['cpu'] - before['cpu']) * 1e6 / len(samples),
                      bytes_op=(after['total_alloc'] - before['total_alloc']) / len(samples),
                      allocs_op=(after['mallocs'] - before['mallocs']) / len(samples))
    return result


def recovery(instance, ports):
    proc, ctrl, mixed, api, _ = instance
    baseline = resources(proc, ctrl, api)
    with channel(mixed, ports['tcp'], 'tcp') as (conn, _):
        conn.sendall(b'half-close')
        conn.shutdown(socket.SHUT_WR)
        assert read_exact(conn, 10 + len(FIN)) == b'half-close' + FIN
        assert conn.recv(1) == b''

    def wait_count(count, timeout):
        deadline = time.monotonic() + timeout
        while True:
            udp = [item for item in connections(api) if item['metadata']['network'] == 'udp']
            if len(udp) == count:
                return udp
            assert time.monotonic() < deadline, (count, len(udp))
            time.sleep(.15)

    with channel(mixed, ports['udp'], 'udp') as (conn, header):
        assert transfer(conn, header, 'udp', 256, 1, timeout=6)[0]
        key = wait_count(1, 2)[0]['id']
        started = time.monotonic()
        wait_count(0, 68)
        udp_expire = time.monotonic() - started
        expired = resources(proc, ctrl, api)
        assert transfer(conn, header, 'udp', 256, 1, timeout=6)[0]
        new_key = wait_count(1, 2)[0]['id']
        assert new_key != key
    after_control_close = resources(proc, ctrl, api)
    http = HTTPConnection(LOCAL, api, timeout=5)
    try:
        http.request('DELETE', f'/connections/{new_key}', headers={'Authorization': 'Bearer local-only'})
        assert http.getresponse().status == 204
    finally:
        http.close()
    wait_count(0, 2)
    return dict(before=baseline, expired=expired, udp_expire_seconds=udp_expire,
                after_control_close=after_control_close, after_delete=resources(proc, ctrl, api),
                tcp_half_close=True)


def profiles(instance, port, proto, output):
    api = instance[3]
    case = (proto, 4, 1200 if proto == 'udp' else 16384, 1)
    with ThreadPoolExecutor(max_workers=2) as pool:
        work = pool.submit(trial, instance, port, case, True, 7)
        time.sleep(1.25)
        (output / f'{proto}-cpu.pb.gz').write_bytes(http_get(api, '/debug/pprof/profile?seconds=3'))
        (output / f'{proto}-heap.pb.gz').write_bytes(http_get(api, '/debug/pprof/heap'))
        work.result()
    (output / f'{proto}-allocs.pb.gz').write_bytes(http_get(api, '/debug/pprof/allocs'))


def relay(binary, output):
    server = socketserver.ThreadingTCPServer
    cases = [('tcp', 1, 16384, 1), ('tcp', 4, 65536, 1),
             ('udp', 1, 256, 1), ('udp', 4, 1200, 16)]
    with serve(server, EchoTCP) as tcp_port, serve(socketserver.UDPServer, EchoUDP) as udp_port:
        ports = {'tcp': tcp_port, 'udp': udp_port}
        with core(binary, output / 'recovery.log') as instance:
            reclaimed = recovery(instance, ports)
        results = []
        for repeat in range(4):
            with core(binary, output / f'relay-{repeat}.log') as instance:
                for case in cases:
                    for proxied in (False, True) if repeat in (0, 3) else (True, False):
                        result = trial(instance, ports[case[0]], case, proxied, 1.5)
                        results.append(dict(repeat=repeat, **result))
                        print(json.dumps(results[-1]), flush=True)
        for proto in ports:
            with core(binary, output / f'{proto}-profiles.log') as instance:
                profiles(instance, ports[proto], proto, output)
    (output / 'relay.json').write_text(json.dumps(dict(trials=results, recovery=reclaimed), indent=2))


def compare(baseline, candidate, output):
    cases = [('udp', 1, 256, 1), ('udp', 4, 1200, 16), ('tcp', 4, 65536, 1)]
    results = []
    with serve(socketserver.ThreadingTCPServer, EchoTCP) as t, serve(socketserver.UDPServer, EchoUDP) as u:
        for repeat, version in enumerate('ABBAABBA'):
            with core(baseline if version == 'A' else candidate, output / f'ab-{repeat}-{version}.log') as instance:
                for case in cases:
                    result = trial(instance, u if case[0] == 'udp' else t, case, True, 2.5)
                    results.append(dict(repeat=repeat, version=version, **result))
                    print(json.dumps(results[-1]), flush=True)
        with core(candidate, output / 'candidate-recovery.log') as instance:
            reclaimed = recovery(instance, {'tcp': t, 'udp': u})
    (output / 'relay-ab.json').write_text(json.dumps(dict(trials=results, recovery=reclaimed), indent=2))


def paced(baseline, candidate, output):
    results = []
    with serve(socketserver.UDPServer, EchoUDP) as port:
        for repeat, version in enumerate('BAABBAAB'):
            with core(baseline if version == 'A' else candidate, output / f'paced-{repeat}-{version}.log') as instance:
                result = trial(instance, port, ('udp', 4, 1200, 16), True, 2, interval=.004)
                assert result['sent'] == 32000
                results.append(dict(repeat=repeat, version=version, **result))
        for version, binary in [('A', baseline), ('B', candidate)]:
            folder = output / f'profile-{version}'
            folder.mkdir(exist_ok=True)
            with core(binary, folder / 'udp.log') as instance:
                profiles(instance, port, 'udp', folder)
    (output / 'relay-paced.json').write_text(json.dumps(results, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--candidate', type=Path)
    parser.add_argument('--paced', action='store_true', help='fixed-rate UDP and comparable profiles for both cores')
    parser.add_argument('--recovery-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.recovery_only:
        output = args.output.resolve()
        with serve(socketserver.ThreadingTCPServer, EchoTCP) as t, \
             serve(socketserver.UDPServer, EchoUDP) as u, \
             core(args.binary.resolve(), output / 'recovery.log') as instance:
            result = recovery(instance, {'tcp': t, 'udp': u})
        (output / 'recovery.json').write_text(json.dumps(result, indent=2))
    elif args.paced:
        if not args.candidate:
            parser.error('--paced requires --candidate')
        paced(args.binary.resolve(), args.candidate.resolve(), args.output.resolve())
    elif args.candidate:
        compare(args.binary.resolve(), args.candidate.resolve(), args.output.resolve())
    else:
        relay(args.binary.resolve(), args.output.resolve())
