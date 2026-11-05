import 'dart:async';
import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9B-D2 — a core that never connects must fail the start.
///
/// No core binary is launched: the transport is skipped and the "core became
/// ready" signal is a loopback socket pair the test owns.
void main() {
  setUp(() {
    ClashService.skipTransportForTest = true;
    ClashService.skipCoreSpawnForTest = true;
    ClashService.resetForTest();
    // Production budget is 5 s; no test should wait for it.
    ClashService.coreReadyTimeout = const Duration(milliseconds: 30);
  });

  tearDown(() {
    ClashService.coreReadyTimeout = const Duration(seconds: 5);
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.resetForTest();
  });

  test('a core that never connects fails instead of reporting success',
      () async {
    final service = ClashService();
    service.isStarting = true;
    service.socketCompleter = Completer<Socket>(); // never completes

    await expectLater(
      service.ensureCoreReadyOrThrowForTest(),
      throwsA(isA<StateError>()),
    );

    expect(
      service.isStarting,
      isFalse,
      reason: 'a failed start must not leave the service stuck in "starting"',
    );
  });

  test('a core that connects passes', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close());
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    addTearDown(() async => socket.close());

    final service = ClashService();
    service.isStarting = true;
    service.socketCompleter = Completer<Socket>()..complete(socket);

    await service.ensureCoreReadyOrThrowForTest();

    expect(service.isStarting, isTrue, reason: 'the caller resets it');
  });

  test('a timeout does not poison the next attempt', () async {
    final service = ClashService();
    service.isStarting = true;
    service.socketCompleter = Completer<Socket>();

    await expectLater(
      service.ensureCoreReadyOrThrowForTest(),
      throwsA(isA<StateError>()),
    );
    expect(service.isStarting, isFalse);

    // Second attempt: this time the core does connect.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close());
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    addTearDown(() async => socket.close());
    service.socketCompleter = Completer<Socket>()..complete(socket);

    await service.ensureCoreReadyOrThrowForTest();

    // The gate never sets `isStarting` back to true on success — that belongs to
    // the caller. What matters is that the second attempt is not poisoned by the
    // first failure: it returns instead of throwing.
    expect(service.isStarting, isFalse);
  });
}
