"""Compare same-source Windows builds at fixed TCP/UDP offered load."""

import argparse
import json
from pathlib import Path
import socketserver

from benchmark_core_relay_windows import EchoTCP, EchoUDP, core, serve, trial


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('baseline', 'pgo', 'output'):
        parser.add_argument(field, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    builds = {'A': args.baseline.resolve(), 'B': args.pgo.resolve()}
    rows = []
    with serve(socketserver.ThreadingTCPServer, EchoTCP) as t, serve(socketserver.UDPServer, EchoUDP) as u:
        for repeat, name in enumerate('ABBAABBA'):
            with core(builds[name], output / f'pgo-{repeat}-{name}.log') as instance:
                for case, port in [(('tcp', 4, 32768, 1), t), (('udp', 4, 1200, 8), u)]:
                    sample = trial(instance, port, case, True, 2, interval=.004)
                    assert sample['sent'] == 2000 * case[-1]
                    rows.append(dict(build=name, **sample))
    (output / 'pgo.json').write_text(json.dumps(dict(samples=rows,
        binary_bytes={name: path.stat().st_size for name, path in builds.items()}), indent=2))
