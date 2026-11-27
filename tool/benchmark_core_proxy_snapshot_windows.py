"""Compare the real node-list RPC after profile reload and actual latency tests."""

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import statistics
import time

from benchmark_core_relay_windows import core, resources, rpc, serve


class Probe(BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass


def summarize(samples):
    ordered = sorted(samples)
    return dict(
        samples=len(samples), median_ms=statistics.median(samples),
        p95_ms=ordered[int((len(ordered) - 1) * .95)],
    )


def measure(binary, folder, probe_port, node_count, history_count, samples):
    route = (
        "profile: {store-selected: false}\n"
        "proxies:\n"
        + "".join(f"  - {{name: node-{i:04d}, type: direct}}\n" for i in range(node_count))
        + "proxy-groups:\n  - {name: Select, type: select, proxies: [node-0000]}\n"
        "rules: ['MATCH,Select']"
    )
    inputs = []
    with core(binary, folder / "core.log", route=route, home_ready=inputs.append) as instance:
        proc, conn, mixed, api, startup = instance
        config, = inputs
        original = config.read_text(encoding="utf-8")
        reloads = []
        for i in range(10):
            replacement = f"node-{i % 2:04d}"
            config.write_text(
                original.replace("proxies: [node-0000]", f"proxies: [{replacement}]"),
                encoding="utf-8",
            )
            started = time.perf_counter()
            assert rpc(conn, "setupConfig", "{}") == ""
            snapshot = rpc(conn, "getProxies")
            assert snapshot["Select"]["all"] == [replacement]
            assert sum(name.startswith("node-") for name in snapshot) == node_count
            reloads.append((time.perf_counter() - started) * 1000)
        url = f"http://127.0.0.1:{probe_port}/generate_204"
        for _ in range(history_count):
            for i in range(node_count):
                name = f"node-{i:04d}"
                result = json.loads(rpc(conn, "asyncTestDelay", json.dumps({
                    "proxy-name": name, "test-url": url, "timeout": 2000,
                })))
                assert result["name"] == name and result["value"] > 0, result
        snapshot = rpc(conn, "getProxies")
        first = snapshot["node-0000"]
        assert len(first["history"]) == history_count
        if history_count:
            assert len(first["extra"][url]["history"]) == history_count
            assert first["extra"][url]["alive"]
        else:
            assert url not in first["extra"]
        for _ in range(5):
            rpc(conn, "getProxies")
        before = resources(proc, conn, api)
        elapsed = []
        for _ in range(samples):
            started = time.perf_counter()
            snapshot = rpc(conn, "getProxies")
            elapsed.append((time.perf_counter() - started) * 1000)
            assert len(snapshot["node-0000"]["history"]) == history_count
        after = resources(proc, conn, api)
        return dict(
            startup=startup, reload_to_nodes=summarize(reloads),
            snapshot=summarize(elapsed),
            alloc_bytes_per_snapshot=(after["total_alloc"] - before["total_alloc"]) / samples,
            allocs_per_snapshot=(after["mallocs"] - before["mallocs"]) / samples,
            cpu_ms_per_snapshot=(after["cpu"] - before["cpu"]) * 1000 / samples,
            before=before, after=after,
            successful_probes=node_count * history_count,
            node_count=node_count, history_count=history_count,
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--nodes", type=int, default=1000)
    parser.add_argument("--histories", type=int, default=10)
    parser.add_argument("--samples", type=int, default=60)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    with serve(HTTPServer, Probe) as port:
        for i, (name, binary) in enumerate((
            ("before", args.baseline), ("after", args.candidate),
            ("after", args.candidate), ("before", args.baseline),
        )):
            folder = args.output / f"{i}-{name}"
            folder.mkdir()
            result = measure(binary.resolve(), folder, port, args.nodes, args.histories, args.samples)
            results.append(dict(variant=name, **result))
            (args.output / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
            print(name, json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
