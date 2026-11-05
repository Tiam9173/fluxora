import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

/// B2 — who is allowed to stop the helper service.
///
/// Before B2 every Fluxora instance that exited sent `helper.stop_service`,
/// including one that never used the helper and one that merely found a service
/// someone else had started. The gate is now three independent facts, and these
/// cases pin each of them.
///
/// Nothing here reaches the SCM, the named pipe or the auth key.
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

  const trustedPath = r'C:\Fake\FluxoraHelperService.exe';

  late List<List<String>> scCalls;
  late int ipcCalls;

  ProcessResult sc(int code, String out) => ProcessResult(0, code, out, '');

  setUp(() {
    scCalls = <List<String>>[];
    ipcCalls = 0;
    Windows.resetHelperSessionForTest();
    Windows.stopHelperServiceOverrideForTest = null;
    Windows.helperStopIpcOverrideForTest = null;
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    Windows.helperIdentityTrustedOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = trustedPath;
    // P9-A — a service an instance is allowed to stop is DEMAND_START by
    // definition; the AUTO branch has its own suite.
    Windows.helperStartTypeOverrideForTest = HelperServiceStartType.demand;
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      return sc(0, '');
    };
  });

  tearDown(() {
    Windows.resetHelperSessionForTest();
    Windows.stopHelperServiceOverrideForTest = null;
    Windows.helperStopIpcOverrideForTest = null;
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    Windows.helperIdentityTrustedOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = null;
    Windows.helperStartTypeOverrideForTest = null;
    Windows.scRunnerForTest = null;
  });

  List<String> verbs() => scCalls.map((a) => a.first).toList();

  /// Records whether the IPC stop was attempted at all.
  void recordIpc({bool ack = true}) {
    Windows.helperStopIpcOverrideForTest = () async {
      ipcCalls++;
      return ack;
    };
  }

  /// A `sc` runner that reports a running service with a matching ImagePath.
  void runningWithMatchingPath() {
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      switch (args.first) {
        case 'qc':
          return sc(0, 'BINARY_PATH_NAME : "$trustedPath"');
        case 'query':
          return sc(0, 'STATE : 1  STOPPED');
      }
      return sc(0, '');
    };
  }

  // ── T-S1 ───────────────────────────────────────────────────────────────────
  group('T-S1 — release does not stop what it did not start', () {
    test('a reused service is left running, with zero IPC', () async {
      Windows.markHelperSessionForTest(reused: true);
      recordIpc();

      final outcome = await Windows().stopHelperService();

      expect(outcome, HelperStopOutcome.notOwned);
      expect(ipcCalls, 0, reason: 'reused is not ownership');
      expect(scCalls, isEmpty, reason: 'no SCM call of any kind');
    });

    test('an instance that never touched the helper stops nothing', () async {
      recordIpc();

      expect(await Windows().stopHelperService(), HelperStopOutcome.notOwned);
      expect(ipcCalls, 0);
      expect(scCalls, isEmpty);
    });
  });

  // ── T-S2 ───────────────────────────────────────────────────────────────────
  group('T-S2 — a foreign installation is never touched', () {
    test(
      'ImagePath mismatch reports identityConflict and writes nothing',
      () async {
        Windows.markHelperSessionForTest(startedByUs: true);
        recordIpc();
        Windows.scRunnerForTest = (args) async {
          scCalls.add(args);
          if (args.first == 'qc') {
            return sc(
              0,
              r'BINARY_PATH_NAME : C:\Other\Fluxora\FluxoraHelperService.exe',
            );
          }
          return sc(0, '');
        };

        final outcome = await Windows().stopHelperService();

        expect(outcome, HelperStopOutcome.identityConflict);
        expect(ipcCalls, 0, reason: 'never ask a foreign helper to stop');
        expect(
          verbs(),
          isNot(contains('stop')),
          reason: 'no SCM write of any kind',
        );
        expect(verbs(), isNot(contains('delete')));
        expect(verbs(), isNot(contains('create')));
        expect(verbs(), isNot(contains('config')));
      },
    );

    test('a suffixed binary (.exe.backup) is a mismatch too', () async {
      Windows.markHelperSessionForTest(startedByUs: true);
      recordIpc();
      Windows.scRunnerForTest = (args) async {
        scCalls.add(args);
        if (args.first == 'qc') {
          return sc(0, 'BINARY_PATH_NAME : "$trustedPath.backup"');
        }
        return sc(0, '');
      };

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.identityConflict,
      );
      expect(ipcCalls, 0);
    });
  });

  // ── T-S3 ───────────────────────────────────────────────────────────────────
  group('T-S3 — the instance that started it may stop it', () {
    test(
      'started + matching ImagePath + SCM STOPPED reports stopped',
      () async {
        Windows.markHelperSessionForTest(startedByUs: true);
        recordIpc();
        runningWithMatchingPath();

        final outcome = await Windows().stopHelperService();

        expect(outcome, HelperStopOutcome.stopped);
        expect(ipcCalls, 1);
        expect(verbs(), contains('qc'));
        expect(verbs(), contains('query'));
      },
    );

    test(
      'started but the SCM never reaches STOPPED is not a success',
      () async {
        Windows.markHelperSessionForTest(startedByUs: true);
        recordIpc();
        Windows.scRunnerForTest = (args) async {
          scCalls.add(args);
          if (args.first == 'qc') {
            return sc(0, 'BINARY_PATH_NAME : "$trustedPath"');
          }
          if (args.first == 'query') return sc(0, 'STATE : 4  RUNNING');
          return sc(0, '');
        };

        expect(await Windows().stopHelperService(), HelperStopOutcome.ackOnly);
      },
    );
  });

  // ── T-S4 ───────────────────────────────────────────────────────────────────
  group('T-S4 — the host test identity has its own rule', () {
    test('reused + matching path + lock held is allowed', () async {
      Windows.hostTestOverrideForTest = true;
      Windows.markHelperSessionForTest(reused: true, lockHeld: true);
      recordIpc();
      runningWithMatchingPath();

      expect(await Windows().stopHelperService(), HelperStopOutcome.stopped);
      expect(ipcCalls, 1);
    });

    test('reused without the lock is refused', () async {
      Windows.hostTestOverrideForTest = true;
      Windows.markHelperSessionForTest(reused: true, lockHeld: false);
      recordIpc();

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.notOwned,
        reason: 'a second HostTest instance must not stop the shared service',
      );
      expect(ipcCalls, 0);
      expect(scCalls, isEmpty);
    });

    test(
      'the host test rule does not leak into the release identity',
      () async {
        // Same session state, but not a HostTest build: `reused` must still be
        // refused. This is the guard against the two rules drifting together.
        Windows.markHelperSessionForTest(reused: true, lockHeld: true);
        recordIpc();

        expect(await Windows().stopHelperService(), HelperStopOutcome.notOwned);
        expect(ipcCalls, 0);
      },
    );
  });
}
