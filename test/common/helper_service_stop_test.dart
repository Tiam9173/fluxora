import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/system.dart';

/// H1 — the helper-stop contract that `AppController.handleExit` relies on.
///
/// Safety: every case drives [Windows.stopHelperServiceOverrideForTest], which
/// short-circuits **before** the helper named pipe and before `sc`. No test here
/// can reach a real IPC request, a real service, or `Process.run('sc', ...)`.
/// `flutter_test_config.dart` additionally keeps the core transport out of the
/// test process (`ClashService.skipTransportForTest = true`).
///
/// Not covered here (see the H1 report): the wiring inside `handleExit` itself,
/// which needs the full controller/preferences/tray harness. That is asserted
/// by source reading, not by these tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Windows.stopHelperServiceOverrideForTest = null;
  });

  group('H1 — helper stop contract', () {
    test('T4 — a helper that is not running reports false, never throws', () async {
      final w = windows;
      if (w == null) {
        markTestSkipped('Windows-only surface');
        return;
      }

      var calls = 0;
      Windows.stopHelperServiceOverrideForTest = () async {
        calls++;
        return false;
      };

      expect(await w.stopHelperService(), HelperStopOutcome.ipcRefused);
      expect(calls, 1);
    });

    test('T6 — a stop that times out is not reported as success', () async {
      final w = windows;
      if (w == null) {
        markTestSkipped('Windows-only surface');
        return;
      }

      Windows.stopHelperServiceOverrideForTest = () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return false;
      };

      expect(
        await w.stopHelperService(),
        HelperStopOutcome.ipcRefused,
        reason: 'a refused or timed-out stop must never read as stopped',
      );
    });

    test('T3 — repeating the stop is safe and stays one call per invocation', () async {
      final w = windows;
      if (w == null) {
        markTestSkipped('Windows-only surface');
        return;
      }

      var calls = 0;
      Windows.stopHelperServiceOverrideForTest = () async {
        calls++;
        return true;
      };

      expect(await w.stopHelperService(), HelperStopOutcome.stopped);
      expect(await w.stopHelperService(), HelperStopOutcome.stopped);
      expect(calls, 2, reason: 'each call goes through the seam exactly once');
    });

    test('T5 — the seam fully replaces the IPC and sc path', () async {
      final w = windows;
      if (w == null) {
        markTestSkipped('Windows-only surface');
        return;
      }

      var calls = 0;
      Windows.stopHelperServiceOverrideForTest = () async {
        calls++;
        return true;
      };

      await w.stopHelperService();

      expect(
        calls,
        1,
        reason: 'while the seam is set, neither the named pipe nor `sc` is '
            'reachable — otherwise this test would touch the real system',
      );
    });

    test('an override that throws surfaces to the caller, not swallowed', () async {
      final w = windows;
      if (w == null) {
        markTestSkipped('Windows-only surface');
        return;
      }

      Windows.stopHelperServiceOverrideForTest = () async {
        throw StateError('stop failed');
      };

      await expectLater(
        w.stopHelperService(),
        throwsA(isA<StateError>()),
        reason: 'the caller decides how to handle failure; the seam must not '
            'pretend it succeeded',
      );
    });
  });
}
