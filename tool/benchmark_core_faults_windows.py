"""Controlled same-target recovery, DNS failure, cancellation and TLS checks."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack, contextmanager
import json
from pathlib import Path
import socket
import socketserver
import ssl
import struct
import threading
import time

from benchmark_core_relay_windows import LOCAL, address, command, connections, core, greet, http_get, metrics, resources, serve, tcp


class Origin(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(2)
        try:
            with self.server.context.wrap_socket(self.request, server_side=True) as conn:
                if conn.recv(1024):
                    conn.sendall(b'HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK')
        except (OSError, ssl.SSLError):
            return


class DNS(socketserver.BaseRequestHandler):
    def handle(self):
        request, transport = self.request
        end = request.index(0, 12)
        label = request[13:13 + request[12]].decode()
        with self.server.lock:
            self.server.seen[label] += 1
            attempt = self.server.seen[label]
        if label.startswith('dead') or (label.startswith('loss') and attempt == 1):
            return
        qtype = struct.unpack_from('!H', request, end + 1)[0]
        data = socket.inet_aton(LOCAL) if qtype == 1 else socket.inet_pton(socket.AF_INET6, '::1')
        has_answer = not (label.startswith('v6only-') and qtype == 1)
        reply = request[:2] + struct.pack('!5H', 0x8180, 1, int(has_answer), 0, 0) + request[12:end + 5]
        if has_answer:
            reply += b'\xc0\x0c' + struct.pack('!HHIH', qtype, 1, 30, len(data)) + data
        transport.sendto(reply, self.client_address)


class UnresponsiveDNS(socketserver.BaseRequestHandler):
    def handle(self):
        packet, _ = self.request
        self.server.labels.add(packet[13:13 + packet[12]])


def tunnel(sock, port, host=None):
    greet(sock)
    if host:
        encoded = host.encode()
        dest = b'\x03' + bytes([len(encoded)]) + encoded + struct.pack('!H', port)
    else:
        dest = address(port)
    command(sock, 1, dest)


def request(sock, ctx, host='ip.relay.test'):
    with ctx.wrap_socket(sock, server_hostname=host) as conn:
        conn.sendall(b'GET / HTTP/1.0\r\n\r\n')
        with conn.makefile('rb') as stream:
            assert stream.read() == b'HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK'


def probe(mixed, port, context, expected, host=None):
    started = time.perf_counter()
    actual = 'success'
    with tcp(mixed) as sock:
        tunnel(sock, port, host)
        try:
            request(sock, context, host or 'ip.relay.test')
        except (OSError, ssl.SSLError) as error:
            actual = type(error).__name__
    assert actual in expected, (host, actual, expected)
    return dict(result=actual, ms=(time.perf_counter() - started) * 1000)


@contextmanager
def origin(context, activate=True, family=socket.AF_INET):
    class HTTPS(socketserver.ThreadingTCPServer):
        address_family = family
        daemon_threads = True
        request_queue_size = 128

    addr = '::1' if family == socket.AF_INET6 else LOCAL
    with HTTPS((addr, 0), Origin, bind_and_activate=False) as server:
        server.context = context
        server.server_bind()
        if activate:
            server.server_activate()
            thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .025})
            thread.start()
        try:
            yield server
        finally:
            if activate:
                server.shutdown()
                thread.join()


def run(binary, cert, key, output):
    ctx = ssl.create_default_context(cafile=cert)
    ctx_server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx_server.load_cert_chain(cert, key)
    untrusted = ssl.create_default_context()
    seen = Counter()

    class DNSFixture(socketserver.ThreadingUDPServer):
        observations = seen
        lock = threading.Lock()

    class UnresponsiveFixture(socketserver.UDPServer):
        labels = set()

    DNSFixture.seen = seen
    failures = ('SSLEOFError', 'ConnectionResetError', 'TimeoutError')
    samples = {}
    with origin(ctx_server) as target, serve(DNSFixture, DNS) as dns_port:
        dns = ('  enable: true\n  use-hosts: false\n  enhanced-mode: redir-host\n'
               f'  nameserver: [udp://{LOCAL}:{dns_port}]')
        with core(binary, output / 'faults.log', dns) as (proc, ctrl, mixed, api, _):
            port = target.server_address[1]
            with origin(ctx_server, activate=False) as dormant:
                recovery_port = dormant.server_address[1]
                with ThreadPoolExecutor(max_workers=8) as pool:
                    group = [pool.submit(probe, mixed, recovery_port, ctx, ('success',) + failures) for _ in range(8)]
                    time.sleep(.55)
                    dormant.server_activate()
                    thread = threading.Thread(target=dormant.serve_forever, kwargs={'poll_interval': .025})
                    thread.start()
                    try:
                        samples['same_endpoint_recovery'] = [job.result() for job in group]
                        assert any(row['result'] == 'success' for row in samples['same_endpoint_recovery'])
                    finally:
                        dormant.shutdown()
                        thread.join()
            assert f':{recovery_port} error: dial tcp' in (output / 'faults.log').read_text(encoding='utf-8')
            with ThreadPoolExecutor(max_workers=16) as pool, origin(ctx_server, activate=False) as refused:
                refused_port = refused.server_address[1]
                groups = {
                    'refused': [pool.submit(probe, mixed, refused_port, ctx, failures) for _ in range(4)],
                    'dns_timeout': [pool.submit(probe, mixed, port, ctx, failures, f'dead-{i}.relay.test') for i in range(4)],
                    'dns_loss': [pool.submit(probe, mixed, port, ctx, failures, f'loss-{i}.relay.test') for i in range(4)],
                }
                samples.update({name: [job.result() for job in batch] for name, batch in groups.items()})
                assert all(seen[f'loss-{i}'] and seen[f'dead-{i}'] for i in range(4)), seen
                samples['dns_second_request'] = [probe(mixed, port, ctx, ('success',), f'loss-{i}.relay.test') for i in range(4)]
            with tcp(mixed) as sock:
                greet(sock)
                sock.sendall(b'\x05\x02\x00' + address(port))  # Unsupported BIND command.
                assert sock.recv(1) == b''
            samples['certificate_rejected'] = [probe(mixed, port, untrusted, ('SSLCertVerificationError',))]
            before = resources(proc, ctrl, api)
            for i in range(12):
                with tcp(mixed) as sock:
                    tunnel(sock, port, f'dead-cancel-{i}.relay.test')
            settle = time.monotonic()
            time.sleep(6)
            samples_at_six_seconds = resources(proc, ctrl, api)
            (output / 'cancel-goroutines.txt').write_bytes(http_get(api, '/debug/pprof/goroutine?debug=1'))
            after = samples_at_six_seconds
            while after['goroutines'] > before['goroutines'] + 1 and time.monotonic() - settle < 15:
                time.sleep(.5)
                after = resources(proc, ctrl, api)
            assert not connections(api), after
            assert after['goroutines'] <= before['goroutines'] + 1, (before, after)
            samples['after_cancel'] = [probe(mixed, port, ctx, ('success',))]
        with origin(ctx_server, family=socket.AF_INET6) as ipv6_target, core(
            binary, output / 'dualstack-dns.log', dns, ipv6=True,
            route='proxies: [{name: same-destination, type: direct, ip-version: ipv6-prefer}]\n'
                  'rules: ["MATCH,same-destination"]',
        ) as (_, _, mixed, _, _):
            samples['dualstack_v4'] = [
                probe(mixed, target.server_address[1], ctx, ('success',), f'dual-{i}.relay.test')
                for i in range(8)
            ]
            samples['aaaa_only'] = [
                probe(mixed, ipv6_target.server_address[1], ctx, ('success',), f'v6only-{i}.relay.test')
                for i in range(8)
            ]
        with serve(UnresponsiveFixture, UnresponsiveDNS) as dead_port, core(
            binary, output / 'dns-two-upstreams.log',
            dns.replace(f'nameserver: [udp://{LOCAL}:{dns_port}]',
                        f'nameserver: [udp://{LOCAL}:{dead_port}, udp://{LOCAL}:{dns_port}]'),
        ) as (_, _, mixed, _, _):
            with ThreadPoolExecutor(max_workers=8) as pool:
                samples['dns_parallel_upstreams'] = list(pool.map(
                    lambda i: probe(mixed, target.server_address[1], ctx, ('success',),
                                    f'parallel-{i}.relay.test'), range(16)))
            assert UnresponsiveFixture.labels and all(seen[f'parallel-{i}'] for i in range(16)), seen
    summary = {kind: metrics([row['ms'] for row in rows]) for kind, rows in samples.items()}
    (output / 'faults.json').write_text(json.dumps(dict(samples=samples, ms=summary, dns_counts=seen,
        cancelled=sum(seen[f'dead-cancel-{i}'] for i in range(12)), before=before, after=after,
        at_six_seconds=samples_at_six_seconds, settle_seconds=time.monotonic() - settle,
        unresponsive_upstream_labels=len(UnresponsiveFixture.labels)), indent=2))
    print(json.dumps(summary))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('binary', 'cert', 'key', 'output'):
        parser.add_argument(field, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    run(args.binary.resolve(), args.cert, args.key, args.output.resolve())
