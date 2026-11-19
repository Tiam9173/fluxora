import argparse
import ctypes as win
import http.client
import json
import os
from pathlib import Path
import re
import socket
import statistics
import struct
import subprocess
import tempfile
import time

if os.name == 'nt':
    from ctypes import wintypes as wint
else:
    wint = None


class ProcessMemory(win.Structure):
    _fields_ = [
        ("cb", win.c_uint32),
        ("faults", win.c_uint32),
        *((field, win.c_size_t) for field in (
            "peak_rss", "rss", "peak_paged", "paged",
            "peak_nonpaged", "nonpaged", "pagefile", "peak_pagefile",
        )),
    ]


def process_sample(handle):
    memory = ProcessMemory()
    memory.cb = win.sizeof(memory)
    times = [win.c_ulonglong() for _ in range(4)]
    if not win.windll.psapi.GetProcessMemoryInfo(handle, win.byref(memory), memory.cb):
        raise win.WinError()
    if not win.windll.kernel32.GetProcessTimes(handle, *(win.byref(t) for t in times)):
        raise win.WinError()
    return memory.rss, (times[2].value + times[3].value) / 1e7


def read_exact(conn, count):
    data = bytearray()
    while len(data) < count:
        chunk = conn.recv(count - len(data))
        if not chunk:
            raise EOFError("core closed RPC")
        data.extend(chunk)
    return data


def rpc(conn, method, data=None):
    request = json.dumps(dict(id=method, method=method, data=data)).encode()
    conn.sendall(struct.pack("<I", len(request)) + request)
    while True:
        length, = struct.unpack("<I", read_exact(conn, 4))
        reply = json.loads(read_exact(conn, length))
        if reply.get("id") == method:
            assert reply["code"] == 0, reply
            return reply["data"]


def http_get(port, path):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        conn.request("GET", path, headers={"Authorization": "Bearer local-only"})
        response = conn.getresponse()
        assert response.status == 200, response.status
        return response.read()
    finally:
        conn.close()


def idle_sample(process, conn, api, start):
    rss, cpu = process_sample(wint.HANDLE(int(process._handle)))
    heap_text = http_get(api, "/debug/pprof/heap?debug=1")
    heap = int(re.search(rb"# HeapAlloc = (\d+)", heap_text)[1])
    status = json.loads(rpc(conn, "getCoreStatus"))
    return dict(seconds=round(time.monotonic() - start, 3), rss_bytes=rss,
                cpu_seconds=cpu, heap_bytes=heap, goroutines=status["goroutines"])


def reserve_port(*, udp=False):
    for _ in range(32):
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
            if udp:
                try:
                    with socket.socket(type=socket.SOCK_DGRAM) as datagram:
                        datagram.bind(("127.0.0.1", port))
                except OSError:
                    continue
            return port
    raise OSError("no available TCP/UDP loopback port")


def run(binary, duration, interval):
    with socket.socket() as control, tempfile.TemporaryDirectory() as home:
        control.bind(("127.0.0.1", 0))
        control.listen(1)
        control.settimeout(15)
        mixed, api = reserve_port(udp=True), reserve_port()
        assert mixed != api
        config = (f"mixed-port: {mixed}\nallow-lan: false\nlog-level: debug\n"
                  f"external-controller: 127.0.0.1:{api}\nsecret: local-only\n"
                  "dns:\n  enable: false\ntun:\n  enable: false\nmode: rule\n"
                  "proxies:\n"
                  + "".join(f"  - {{name: p{i}, type: http, server: 127.0.0.1, port: 1}}\n"
                            for i in range(1000))
                  + "rules:\n"
                  + "".join(f"  - DOMAIN,d{i}.example.invalid,DIRECT\n" for i in range(3000))
                  + "  - MATCH,DIRECT\n")
        Path(home, "config.yaml").write_text(config, encoding="utf-8")
        log_path = Path(home, "core.log")
        with log_path.open("wb") as log:
            process = subprocess.Popen([str(binary), str(control.getsockname()[1])], cwd=home,
                                       stdout=log, stderr=log)
            try:
                with control.accept()[0] as conn:
                    conn.settimeout(15)
                    assert rpc(conn, "initClash", json.dumps({"home-dir": home, "version": 1}))
                    assert rpc(conn, "setupConfig", "{}") == ""
                    assert rpc(conn, "startListener") is True
                    time.sleep(15)
                    start = time.monotonic()
                    samples = []
                    for second in range(0, duration + 1, interval):
                        time.sleep(max(0, start + second - time.monotonic()))
                        samples.append(idle_sample(process, conn, api, start))
                    status_end = json.loads(http_get(api, "/version"))
                    assert status_end["version"] == "v1.19.34", status_end
                    assert rpc(conn, "getIsInit") is True
                    assert rpc(conn, "shutdown") is True
                assert process.wait(timeout=8) == 0
            except Exception:
                print(log_path.read_text(encoding="utf-8", errors="replace"))
                raise
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=8)
    return samples


def summarize(samples):
    start, end = samples[0], samples[-1]
    elapsed = end["seconds"] - start["seconds"]
    cpu = end["cpu_seconds"] - start["cpu_seconds"]
    stat = {"cpu_percent_one_logical_core": 100 * cpu / elapsed}
    for metric in ("rss_bytes", "heap_bytes", "goroutines"):
        values = [sample[metric] for sample in samples]
        stat[metric] = dict(start=values[0], end=values[-1],
                            median=statistics.median(values), peak=max(values))
    return stat


if __name__ == "__main__":
    args = argparse.ArgumentParser()
    args.add_argument("binary", type=Path)
    args.add_argument("output", type=Path)
    args.add_argument("--duration", type=int, default=600)
    args.add_argument("--interval", type=int, default=15)
    options = args.parse_args()
    if options.interval <= 0 or options.duration < options.interval or options.duration % options.interval:
        args.error("duration must be a positive multiple of interval")
    samples = run(options.binary.resolve(), options.duration, options.interval)
    summary = summarize(samples)
    options.output.write_text(json.dumps(dict(samples=samples, summary=summary), indent=2),
                              encoding="utf-8")
    print(json.dumps(summary))

