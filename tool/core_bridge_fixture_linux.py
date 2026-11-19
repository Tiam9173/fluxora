"""Run the normal desktop bridge in an already isolated test namespace."""
import json
import signal
import socket
import struct
import subprocess
import sys


def stop(*args):
    raise SystemExit()


signal.signal(signal.SIGTERM, stop)
with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    listener.listen()
    listener.settimeout(10)
    proc = subprocess.Popen([sys.argv[1], str(listener.getsockname()[1])], cwd=sys.argv[2])
    try:
        conn, _ = listener.accept()
        conn.settimeout(10)
        with conn, conn.makefile('rb') as stream:
            def call(method, data=None):
                raw = json.dumps(dict(id=method, method=method, data=data)).encode()
                conn.sendall(struct.pack('<I', len(raw)) + raw)
                while True:
                    size, = struct.unpack('<I', stream.read(4))
                    reply = json.loads(stream.read(size))
                    if reply.get('id') == method:
                        assert reply['code'] == 0, reply
                        return reply['data']
            assert call('initClash', json.dumps({'home-dir': sys.argv[2], 'version': 1}))
            assert call('setupConfig', '{}') == ''
            assert call('startListener')
            try:
                signal.pause()
            finally:
                assert call('stopListener')
                assert call('shutdown')
        assert proc.wait(timeout=8) == 0
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=8)
