import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/system.dart';

/// H2-A — the helper **start recovery** state machine.
///
/// These drive the real `Windows._ensureHelperRunning()` / `registerService()`
/// code. Every system touch is replaced:
///   · `sc`          → [Windows.scRunnerForTest]
///   · helper IPC    → [Windows.helperPingOverrideForTest]
///   · `runas`+`sc`  → [Windows.configureHelperServiceOverrideForTest]
///
/// So no test here can reach the SCM, raise UAC, or spawn a service.
void main() {
  // Windows-only suite: every case drives the helper service through `Windows()`,
  // which opens shell32.dll via FFI. Off Windows that library cannot load at all,
  // so the file is skipped there — no assertion is relaxed, and the full set still
  // runs on Windows.
  if (!Platform.isWindows) {
    test(
      'Windows-only suite',
      () {},
      skip: 'requires Windows FFI (shell32.dll) and the SCM helper service',
    );
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  ProcessResult sc(int exitCode, String stdout) =>
      ProcessResult(0, exitCode, stdout, '');

  late List<List<String>> scCalls;

  /// The helper path every test treats as "ours".
  const trustedHelperPath = r'C:\Fake\FluxoraHelperService.exe';

  setUp(() {
    scCalls = <List<String>>[];
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    // `appPath` needs `path_provider`, which a plain `test()` cannot serve, so
    // the identity check reads this instead. Every test starts with a trusted
    // path unless it deliberately swaps in a foreign one.
    Windows.helperIdentityPathOverrideForTest = trustedHelperPath;
    // `ensureAuthKey()` reads HKLM and writes the key file via `path_provider`,
    // neither of which a plain `test()` can serve.
    Windows.skipAuthKeyForTest = true;
    Windows.scRunnerForTest = null;
  });

  tearDown(() {
    Windows.scRunnerForTest = null;
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = null;
    Windows.skipAuthKeyForTest = false;
  });

  /// Installs a fake `sc` that answers `query` / `qc` / `start` from [handler]
  /// and records every invocation.
  void fakeSc(ProcessResult Function(List<String> args) handler) {
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      return handler(args);
    };
  }

  List<String> verbs() => scCalls.map((a) => a.first).toList();

  group('H2-A — helper start state machine', () {
    test('T1 — running and healthy is reused, never started', () async {
      fakeSc(
        (args) =>
            args.first == 'query' ? sc(0, 'STATE : 4  RUNNING') : sc(0, ''),
      );
      Windows.helperPingOverrideForTest = () async => true;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.reused);
      expect(verbs(), isNot(contains('start')));
      expect(verbs(), isNot(contains('qc')));
    });

    test('T2 — installed, stopped and trusted is started in place', () async {
      const expected = r'C:\Fake\FluxoraHelperService.exe';
      Windows.helperIdentityPathOverrideForTest = expected;
      var started = false;

      fakeSc((args) {
        switch (args.first) {
          case 'query':
            return started
                ? sc(0, 'STATE : 4  RUNNING')
                : sc(0, 'STATE : 1  STOPPED');
          case 'qc':
            return sc(0, 'BINARY_PATH_NAME : "$expected"');
          case 'start':
            started = true;
            return sc(0, 'SERVICE_NAME: x');
        }
        return sc(0, '');
      });
      Windows.helperPingOverrideForTest = () async => true;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.started);
      expect(verbs(), contains('start'));
      expect(
        verbs(),
        isNot(contains('create')),
        reason: 'a stopped service must never be re-created',
      );
      expect(verbs(), isNot(contains('delete')));
    });

    test('T3 — start denied fails safely, no rebuild, no elevation', () async {
      const expected = r'C:\Fake\FluxoraHelperService.exe';
      Windows.helperIdentityPathOverrideForTest = expected;

      fakeSc((args) {
        switch (args.first) {
          case 'query':
            return sc(0, 'STATE : 1  STOPPED');
          case 'qc':
            return sc(0, 'BINARY_PATH_NAME : "$expected"');
          case 'start':
            return sc(5, 'Access is denied.');
        }
        return sc(0, '');
      });
      Windows.helperPingOverrideForTest = () async => false;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.accessDenied);
      expect(verbs(), isNot(contains('create')));
      expect(verbs(), isNot(contains('delete')));
      expect(verbs(), isNot(contains('config')));
    });

    test('T4 — running but unhealthy is reported, not rebuilt', () async {
      fakeSc(
        (args) =>
            args.first == 'query' ? sc(0, 'STATE : 4  RUNNING') : sc(0, ''),
      );
      Windows.helperPingOverrideForTest = () async => false;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.unhealthy);
      expect(verbs(), isNot(contains('start')));
      expect(verbs(), isNot(contains('delete')));
    });

    test('T5 — a foreign ImagePath is never touched', () async {
      fakeSc((args) {
        switch (args.first) {
          case 'query':
            return sc(0, 'STATE : 1  STOPPED');
          case 'qc':
            return sc(
              0,
              r'BINARY_PATH_NAME : "D:\Other\FluxoraHelperService.exe"',
            );
        }
        return sc(0, '');
      });
      Windows.helperPingOverrideForTest = () async => true;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.identityConflict);
      expect(
        verbs(),
        isNot(contains('start')),
        reason: 'a service that is not ours must not be started',
      );
      expect(verbs(), isNot(contains('delete')));
    });

    test(
      'T6 — a missing service is reported, never silently installed',
      () async {
        fakeSc(
          (args) => args.first == 'query'
              ? sc(
                  1060,
                  'The specified service does not exist as an installed service.',
                )
              : sc(0, ''),
        );

        final outcome = await Windows().ensureHelperRunningForTest();

        expect(outcome, HelperStartOutcome.notInstalled);
        expect(verbs(), isNot(contains('create')));
        expect(verbs(), isNot(contains('start')));
      },
    );

    test('T7 — a pending start is waited on, then fails honestly', () async {
      fakeSc(
        (args) => args.first == 'query'
            ? sc(0, 'STATE : 2  START_PENDING')
            : sc(0, ''),
      );
      Windows.helperPingOverrideForTest = () async => false;

      final outcome = await Windows().ensureHelperRunningForTest();

      expect(outcome, HelperStartOutcome.startFailed);
      expect(
        verbs(),
        isNot(contains('start')),
        reason: 'a pending transition is not a stopped service',
      );
      expect(verbs(), isNot(contains('delete')));
    });

    test('T8 — concurrent register runs the sequence once', () async {
      var configureCalls = 0;
      fakeSc(
        (args) => args.first == 'query'
            ? sc(1060, 'The specified service does not exist')
            : sc(0, ''),
      );
      Windows.configureHelperServiceOverrideForTest = () async {
        configureCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return false;
      };

      final w = Windows();
      final results = await Future.wait([
        w.registerService(),
        w.registerService(),
      ]);

      expect(results, [false, false]);
      expect(
        configureCalls,
        1,
        reason: 'the in-flight guard must collapse concurrent registrations',
      );
    });
  });

  group('H2-A — first install stays the explicit path', () {
    test('only notInstalled reaches the configure sequence', () async {
      var configureCalls = 0;
      fakeSc(
        (args) => args.first == 'query'
            ? sc(1060, 'The specified service does not exist')
            : sc(0, ''),
      );
      Windows.helperPingOverrideForTest = () async => false;
      Windows.configureHelperServiceOverrideForTest = () async {
        configureCalls++;
        return false;
      };

      expect(await Windows().registerService(), isFalse);
      expect(configureCalls, 1);
    });

    test('a stopped service never reaches the configure sequence', () async {
      const expected = r'C:\Fake\FluxoraHelperService.exe';
      Windows.helperIdentityPathOverrideForTest = expected;
      var configureCalls = 0;
      var started = false;

      fakeSc((args) {
        switch (args.first) {
          case 'query':
            return started
                ? sc(0, 'STATE : 4  RUNNING')
                : sc(0, 'STATE : 1  STOPPED');
          case 'qc':
            return sc(0, 'BINARY_PATH_NAME : "$expected"');
          case 'start':
            started = true;
            return sc(0, '');
        }
        return sc(0, '');
      });
      Windows.helperPingOverrideForTest = () async => true;
      Windows.configureHelperServiceOverrideForTest = () async {
        configureCalls++;
        return true;
      };

      expect(await Windows().registerService(), isTrue);
      expect(
        configureCalls,
        0,
        reason: 'this is the H2-A fix: stopped ≠ reinstall',
      );
    });
  });
}
