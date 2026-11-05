import 'dart:async';
import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9-S08 — "kill was sent" is not "the process exited".
///
/// The hooks replace `kill` and `exitCode`, so the real child below is never
/// signalled — it only provides a genuine `Process` handle. Nothing here starts
/// FluxoraCore.
void main() {
  late Process child;

  setUp(() async {
    ClashService.skipTransportForTest = true;
    ClashService.startHooksForTest = null;
    ClashService.resetForTest();
    // A long-running child to reap. Portable on purpose: the logic under test
    // (`_reapDirectCore`) is platform-neutral, so only the command changes.
    child = Platform.isWindows
        ? await Process.start('cmd', ['/c', 'ping', '-n', '30', '127.0.0.1'])
        : await Process.start('sleep', ['30']);
  });

  tearDown(() async {
    ClashService.startHooksForTest = null;
    ClashService.skipTransportForTest = false;
    ClashService.resetForTest();
    try {
      child.kill(ProcessSignal.sigkill);
    } catch (_) {}
  });

  /// Runs the direct-branch cleanup with the supplied behaviour.
  Future<bool> reap({
    required Future<void> Function(Process, bool) kill,
    required Future<int> Function(Process) awaitExit,
  }) async {
    ClashService.startHooksForTest = ClashServiceStartHooks(
      killProcess: kill,
      awaitExit: awaitExit,
    );
    final service = ClashService();
    service.process = child;
    final result = await service.abortFailedStartForTest(viaHelper: false);
    expect(
      service.process,
      result ? isNull : same(child),
      reason: 'the handle is released only when the exit is confirmed',
    );
    return result;
  }

  test('a kill that throws is reported as not reaped', () async {
    final result = await reap(
      kill: (p, force) async => throw ProcessException('kill', const []),
      awaitExit: (p) async => 0,
    );
    expect(result, isFalse);
  });

  test('an exit code completes ⇒ reaped', () async {
    final result = await reap(
      kill: (p, force) async {},
      awaitExit: (p) async => 0,
    );
    expect(result, isTrue);
  });

  test('a timeout escalates to sigkill and then succeeds', () async {
    final forces = <bool>[];
    var calls = 0;
    final result = await reap(
      kill: (p, force) async => forces.add(force),
      awaitExit: (p) async {
        calls++;
        // First wait never completes; after the escalation it does.
        if (calls == 1) throw TimeoutException('still running');
        return 0;
      },
    );

    expect(result, isTrue);
    expect(forces, [
      false,
      true,
    ], reason: 'the escalation must use force, and only after a timeout');
  });

  test('a timeout that survives sigkill is not a success', () async {
    final result = await reap(
      kill: (p, force) async {},
      awaitExit: (p) async => throw TimeoutException('still running'),
    );
    expect(
      result,
      isFalse,
      reason: 'an unconfirmed exit must never be recorded as cleaned up',
    );
  });

  test('a sigkill that throws is not a success', () async {
    var calls = 0;
    final result = await reap(
      kill: (p, force) async {
        if (force) throw ProcessException('sigkill', const []);
      },
      awaitExit: (p) async {
        calls++;
        if (calls == 1) throw TimeoutException('still running');
        return 0;
      },
    );
    expect(result, isFalse);
  });

  test('an exitCode that throws for another reason is not a success', () async {
    final result = await reap(
      kill: (p, force) async {},
      awaitExit: (p) async => throw StateError('no such process'),
    );
    expect(result, isFalse);
  });
}
