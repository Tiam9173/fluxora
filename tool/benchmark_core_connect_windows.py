"""Time real SOCKS-to-TLS connections with a controlled loopback DNS upstream."""

import argparse
from collections import defaultdict
from contextlib import ExitStack
import json
from pathlib import Path
import queue
import socket
import socketserver
import ssl
import struct
import subprocess
import time

from benchmark_core_relay_windows import (
    address, command, core, greet, metrics, reserve_port, resources, serve, tcp, timed,
)


class LocalDNS(socketserver.BaseRequestHandler):
    def handle(self):
        query, conn = self.request
        end = query.index(b'\0', 12)
        label = query[13:13 + query[12]].decode()
        qtype, _ = struct.unpack_from('!HH', query, end + 1)
        attempts = self.server.observations[label]
        start = time.perf_counter_ns()
        attempts.append([start, None])
        if label.startswith('timeout-') or (label.startswith('loss-') and len(attempts) == 1):
            return
        if label.startswith('slow-'):
            time.sleep(.040)
        ipv4 = bytes((127, 0, 0, 1))
        answer = b'\xc0\x0c' + struct.pack('!HHIH', 1, 1, 60, 4) + ipv4 if qtype == 1 else b''
        attempts[-1][1] = time.perf_counter_ns()
        conn.sendto(query[:2] + struct.pack('!5H', 0x8180, 1, int(bool(answer)), 0, 0)
                    + query[12:end + 5] + answer, self.client_address)


class LocalHTTPS(socketserver.BaseRequestHandler):
    def handle(self):
        self.server.accepted.put(time.perf_counter_ns())
        self.request.settimeout(10)
        with self.server.context.wrap_socket(self.request, server_side=True) as conn:
            body = b''
            while b'\r\n\r\n' not in body:
                part = conn.recv(1024)
                if not part:
                    return  # The warm-up confirms TLS without an HTTP request.
                body += part
                assert len(body) <= 8192
            if b'Host: slow-' in body:
                time.sleep(.025)
            conn.sendall(b'HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK')


def connection(mixed, target, ctx, host, accepted, observations, expected=True, spawn_ns=None):
    started = time.perf_counter_ns()
    with ExitStack() as stack:
        sock, local_tcp = timed(tcp, mixed)
        stack.enter_context(sock)
        _, greeting = timed(greet, sock)
        packed = (host or '').encode()
        dest = (b'\x03' + bytes((len(packed),)) + packed + struct.pack('!H', target)
                if host else address(target))
        _, socks_ack = timed(command, sock, 1, dest)
        ack_ns = time.perf_counter_ns()
        sock = stack.enter_context(ctx.wrap_socket(sock, server_hostname=host or 'ip.relay.test',
                                                   do_handshake_on_connect=False))
        metrics_ms = dict(local_tcp_ms=local_tcp, socks_greeting_ms=greeting, socks_ack_ms=socks_ack)
        try:
            _, metrics_ms['tls_from_ack_ms'] = timed(sock.do_handshake)
        except (ssl.SSLEOFError, ConnectionResetError, TimeoutError) as error:
            assert expected is not True, (host, error)
            return dict(metrics_ms, failure=type(error).__name__,
                        elapsed_ms=(time.perf_counter_ns() - started) / 1e6)
        assert expected is not False
        accepted_ns = accepted.get_nowait()
        metrics_ms['target_accept_from_ack_ms'] = (accepted_ns - ack_ns) / 1e6
        post_dns_ns = ack_ns
        if host:
            completed = [attempt for attempt in observations[host.split('.')[0]] if attempt[1] is not None]
            dns_start, post_dns_ns = completed[-1]
            metrics_ms['dns_upstream_ms'] = (post_dns_ns - dns_start) / 1e6
        metrics_ms['target_accept_after_dns_ms'] = (accepted_ns - post_dns_ns) / 1e6
        metrics_ms['tls_after_accept_ms'] = (time.perf_counter_ns() - accepted_ns) / 1e6
        sent = time.perf_counter_ns()
        sock.sendall(f'GET / HTTP/1.0\r\nHost: {host or "ip.relay.test"}\r\n\r\n'.encode())
        first = sock.recv(1)
        first_ns = time.perf_counter_ns()
        assert first == b'H'
        with sock.makefile('rb') as stream:
            assert stream.read() == b'TTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK'
        if spawn_ns is not None:
            metrics_ms['spawn_to_first_ms'] = (first_ns - spawn_ns) / 1e6
        return dict(metrics_ms, ttfb_ms=(first_ns - sent) / 1e6,
                    first_traffic_ms=(first_ns - started) / 1e6)


def run(binary, openssl, output):
    cert, key = output / 'local-cert.pem', output / 'local-key.pem'
    subprocess.run([str(openssl), 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                    '-subj', '/CN=*.relay.test', '-addext', 'subjectAltName=DNS:*.relay.test',
                    '-keyout', str(key), '-out', str(cert)], check=True, capture_output=True)
    ctx = ssl.create_default_context(cafile=cert)
    server_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server_ctx.load_cert_chain(cert, key)
    key.unlink()
    observations = defaultdict(list)
    accepted = queue.SimpleQueue()

    class DNS(socketserver.UDPServer):
        pass

    DNS.observations = observations

    class HTTPS(socketserver.ThreadingTCPServer):
        context = server_ctx

    HTTPS.accepted = accepted
    raw, restarts, resource_samples = defaultdict(list), [], []
    with serve(DNS, LocalDNS) as dns_port, serve(HTTPS, LocalHTTPS) as https_port:
        dns = ('  enable: true\n  use-hosts: false\n  enhanced-mode: redir-host\n'
               f'  nameserver: [udp://127.0.0.1:{dns_port}]')
        total = 0
        for repeat in range(4):
            with core(binary, output / f'connect-{repeat}.log', dns) as (proc, rpc, mixed, api, startup):
                spawn_ns = startup.pop('spawn_ns')
                cold = connection(mixed, https_port, ctx, f'cold-{repeat}.relay.test', accepted, observations,
                                  spawn_ns=spawn_ns)
                restarts.append(dict(startup, **cold))
                before = resources(proc, rpc, api)
                for index in range(40):
                    i = repeat * 40 + index
                    cases = [('ip', None), ('dns', f'normal-{i}.relay.test'),
                             ('slow', f'slow-{i}.relay.test')]
                    for name, host in cases if i % 2 else reversed(cases):
                        raw[name].append(connection(mixed, https_port, ctx, host, accepted, observations))
                        total += 1
                after = resources(proc, rpc, api)
                resource_samples.append(dict(before=before, after=after))
                if repeat == 3:
                    for attempt in range(3):
                        for mode, port, host in (
                            ('refused', reserve_port(), None),
                            ('timeout', https_port, f'timeout-{attempt}.relay.test'),
                            ('loss', https_port, f'loss-{attempt}.relay.test'),
                        ):
                            raw[mode].append(connection(mixed, port, ctx, host, accepted, observations,
                                                        expected=None if mode == 'loss' else False))
    assert len(restarts) == 4 and total == 480
    assert all(observations[f'loss-{i}'] for i in range(3))
    summary = {name: {field: metrics([row[field] for row in rows if field in row])
                      for field in sorted({key for row in rows for key in row if key.endswith('_ms')})}
               for name, rows in (list(raw.items()) + [('fresh_process', restarts)])}
    (output / 'connect.json').write_text(json.dumps(dict(samples=raw, restarts=restarts, resources=resource_samples,
        dns=observations, summary=summary), indent=2))
    print(json.dumps(summary))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('binary', 'openssl', 'output'):
        parser.add_argument(option, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    run(args.binary.resolve(), args.openssl.resolve(), args.output.resolve())
