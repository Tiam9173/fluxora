import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/external_control.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// `appPath` asks `path_provider` for the temp directory, and a VM test has no
/// plugin implementation — same shape as the fake in
/// `clash_service_helper_fallback_test.dart`.
class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getExternalStoragePath() async => dir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [dir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [dir.path];

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}

/// N5 + AF_UNIX containment — the control channel's failure classification,
/// its acknowledgement protocol, and its loopback-TCP authentication.
///
/// **No Unix-domain socket is created here.** `afunix.sys` 10.0.26100.9818
/// bugchecks when a Unix-domain socket handle is torn down at process exit
/// (`0xD1` in `AfUnixTlConnectEndpointDisconnect`), so a test that bound one
/// could crash the developer's machine. Everything below runs on loopback TCP
/// against an in-process fake server — which is also the transport Windows uses.
void main() {
  // `appPath` reaches `path_provider`, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late String socketPath;
  late String portPath;
  ServerSocket? server;

  // Any non-empty secret works; the real one is 32 random bytes in hex.
  const token = 'test-session-token';

  Future<void> cleanFiles() async {
    for (final path in [socketPath, portPath]) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Starts a fake control server on loopback and publishes `<port>\n<token>`.
  ///
  /// [reply] is what the server answers to an authenticated command; `null`
  /// closes the connection without answering. [publishedToken] is the token the
  /// client will read from the port file — a mismatch simulates a caller that
  /// guessed the port but not the secret.
  Future<void> serve({
    String? reply,
    String publishedToken = token,
    bool enforceToken = true,
  }) async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    File(portPath).writeAsStringSync('${server!.port}\n$publishedToken\n');

    server!.listen((socket) {
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (enforceToken && !line.startsWith('$token ')) {
              socket.write('error unauthorized\n');
              socket.flush();
              return;
            }
            if (reply == null) {
              socket.destroy();
              return;
            }
            socket.write('$reply\n');
            socket.flush();
          });
    });
  }

  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      Directory.systemTemp.createTempSync('fluxora_ack_'),
    );
    socketPath = await appPath.controlSocketPath;
    portPath = await appPath.controlPortFilePath;
  });

  setUp(() async {
    await cleanFiles();
  });

  tearDown(() async {
    try {
      await server?.close();
    } catch (_) {}
    server = null;
    await cleanFiles();
  });

  group('sendCommand acknowledgement', () {
    test('a peer that executed the command answers ok', () async {
      await serve(reply: ExternalControl.ackOk);

      await expectLater(
        ExternalControl.sendCommand('show', requireAck: true),
        completes,
      );
    });

    test('a peer that refused the command is reported as rejected', () async {
      await serve(reply: 'error window-unavailable');

      await expectLater(
        ExternalControl.sendCommand('show', requireAck: true),
        throwsA(
          isA<ExternalControlException>().having(
            (e) => e.failure,
            'failure',
            ExternalControlFailure.rejected,
          ),
        ),
      );
    });

    test(
      'a peer that never answers is rejected, not silently accepted',
      () async {
        await serve(reply: null);

        await expectLater(
          ExternalControl.sendCommand('show', requireAck: true),
          throwsA(
            isA<ExternalControlException>().having(
              (e) => e.failure,
              'failure',
              ExternalControlFailure.rejected,
            ),
          ),
        );
      },
    );

    test(
      'commands that do not ask for an ack keep the write-only protocol',
      () async {
        await serve(reply: null);

        // `exit` and `restart` must stay fire-and-forget: the peer is about to
        // disappear, and waiting for a reply would turn every exit into a timeout.
        await expectLater(ExternalControl.sendCommand('exit'), completes);
      },
    );
  });

  group('loopback TCP authentication', () {
    test('a command without the session token is refused', () async {
      await serve(
        reply: ExternalControl.ackOk,
        publishedToken: 'wrong-session-token',
      );

      await expectLater(
        ExternalControl.sendCommand('show', requireAck: true),
        throwsA(
          isA<ExternalControlException>()
              .having(
                (e) => e.failure,
                'failure',
                ExternalControlFailure.rejected,
              )
              .having((e) => e.detail, 'detail', contains('unauthorized')),
        ),
      );
    });

    test('the token is sent as the first field, ahead of the verb', () async {
      final received = <String>[];
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      File(portPath).writeAsStringSync('${server!.port}\n$token\n');
      server!.listen((socket) {
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              received.add(line);
              socket.write('${ExternalControl.ackOk}\n');
              socket.flush();
            });
      });

      await ExternalControl.sendCommand('show', requireAck: true);

      expect(received, hasLength(1));
      expect(received.single, '$token show');
    });
  });

  group('sendCommand failure classification', () {
    test(
      'no channel file at all is "not running", not "unreachable"',
      () async {
        await expectLater(
          ExternalControl.sendCommand('show', requireAck: true),
          throwsA(
            isA<ExternalControlException>().having(
              (e) => e.failure,
              'failure',
              ExternalControlFailure.notRunning,
            ),
          ),
        );
      },
    );

    test('a stale port file nobody listens on is transient', () async {
      // A leftover file from a crashed instance: the client tries the port and
      // nothing accepts. That is exactly the case a bounded retry is for.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close();
      File(portPath).writeAsStringSync('$deadPort\n$token\n');

      await expectLater(
        ExternalControl.sendCommand('show', requireAck: true),
        throwsA(
          isA<ExternalControlException>().having(
            (e) => e.failure,
            'failure',
            ExternalControlFailure.unreachable,
          ),
        ),
      );
    });
  });
}
