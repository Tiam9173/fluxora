import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9-S04 — a failed core start must be **recorded**, not only logged.
///
/// `preload()` reports transport readiness, so without `lastStartFailure` a core
/// that never came up is invisible to both the UI and the tests. Nothing here
/// spawns a core: the failure is produced by blocking the socket bind.
void main() {
  setUp(() {
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(milliseconds: 30);
    ClashService.resetForTest();
    IOOverrides.global = null;
  });

  tearDown(() {
    IOOverrides.global = null;
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(seconds: 5);
    ClashService.resetForTest();
  });

  test('a failed start is recorded, not just logged', () async {
    IOOverrides.global = _FailingBind();

    final service = ClashService();

    await expectLater(
      service.preload().timeout(const Duration(seconds: 5)),
      throwsA(isA<SocketException>()),
    );

    // The failure is recorded by `reStart`, which runs unawaited from the
    // constructor — give it a moment to land.
    for (var i = 0; i < 100 && service.lastStartFailure == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      service.lastStartFailure,
      isA<SocketException>(),
      reason: 'a start that failed must be readable, not only in the log',
    );
    expect(service.isStarting, isFalse);
  });

  test('a successful start clears a previously recorded failure', () async {
    ClashService.skipTransportForTest = true;
    ClashService.skipCoreSpawnForTest = true;
    ClashService.resetForTest();

    final service = ClashService();
    service.lastStartFailure = StateError('stale failure');

    // Stand in for the bind: the transport seam skipped it, so complete the
    // completer by hand. No core is started (`skipCoreSpawnForTest`).
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close());
    service.serverCompleter.complete(server);

    await service.reStart();

    expect(
      service.lastStartFailure,
      isNull,
      reason: 'a later success must not leave a stale failure behind',
    );
  });
}

/// Fails every `ServerSocket.bind`, which is what a start needs to succeed.
final class _FailingBind extends IOOverrides {
  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    throw const SocketException('bind blocked for test');
  }
}
