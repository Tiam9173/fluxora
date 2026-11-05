import 'dart:io';

import 'package:fluxora/common/system.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9-A — an `AUTO_START` helper is shared.
///
/// The SCM starts it at boot and every session reuses it. Stopping it on exit
/// left the next launch with a service it cannot start (the interactive user
/// has no `SERVICE_START` right on it), and that launch silently fell back to
/// the unprotected core. Only a `DEMAND_START` service may be stopped, and only
/// by the instance that started it.
///
/// The first two groups are pure: they run on every platform and touch neither
/// the SCM nor the named pipe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P9-A — parseServiceStartType', () {
    test('AUTO_START is recognised from a real `sc qc` payload', () {
      const qc =
          '        START_TYPE         : 2   AUTO_START\r\n'
          '        BINARY_PATH_NAME   : "C:\\Program Files\\Fluxora\\Service\\FluxoraHelperService.exe"';

      expect(Windows.parseServiceStartType(qc), HelperServiceStartType.auto);
    });

    test('DEMAND_START is recognised', () {
      expect(
        Windows.parseServiceStartType(
          '        START_TYPE         : 3   DEMAND_START',
        ),
        HelperServiceStartType.demand,
      );
    });

    test('DISABLED and unreadable output fail closed', () {
      expect(
        Windows.parseServiceStartType('START_TYPE : 4   DISABLED'),
        HelperServiceStartType.unknown,
      );
      expect(
        Windows.parseServiceStartType(''),
        HelperServiceStartType.unknown,
        reason: 'a failed query must never look like a stoppable service',
      );
      expect(
        Windows.parseServiceStartType('SCM is unavailable'),
        HelperServiceStartType.unknown,
      );
    });
  });

  group('P9-A — helperStopBlockedReason', () {
    test('AUTO blocks the stop even when this instance started it', () {
      expect(
        Windows.helperStopBlockedReason(
          identityTrusted: true,
          startType: HelperServiceStartType.auto,
        ),
        HelperStopOutcome.sharedAutoStart,
        reason:
            'an admin GUI that ran `sc start` must not stop the shared '
            'service on exit',
      );
    });

    test('an unknown start type blocks the stop', () {
      expect(
        Windows.helperStopBlockedReason(
          identityTrusted: true,
          startType: HelperServiceStartType.unknown,
        ),
        HelperStopOutcome.sharedAutoStart,
      );
    });

    test('DEMAND with a trusted identity may proceed', () {
      expect(
        Windows.helperStopBlockedReason(
          identityTrusted: true,
          startType: HelperServiceStartType.demand,
        ),
        isNull,
      );
    });

    test('a foreign installation is refused before the start type matters', () {
      expect(
        Windows.helperStopBlockedReason(
          identityTrusted: false,
          startType: HelperServiceStartType.demand,
        ),
        HelperStopOutcome.identityConflict,
      );
    });
  });

  // ── Integration: the real `stopHelperService` pipeline ────────────────────
  //
  // `Windows()` opens shell32.dll through FFI, so this half only runs on
  // Windows. It still never reaches the SCM: every `sc` call is faked and the
  // IPC stop is a counter.
  if (!Platform.isWindows) {
    test(
      'P9-A — stopHelperService integration',
      () {},
      skip: 'requires Windows FFI (shell32.dll)',
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
    Windows.helperIdentityTrustedOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = trustedPath;
    Windows.helperStartTypeOverrideForTest = null;
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      return sc(0, '');
    };
  });

  tearDown(() {
    Windows.resetHelperSessionForTest();
    Windows.stopHelperServiceOverrideForTest = null;
    Windows.helperStopIpcOverrideForTest = null;
    Windows.helperIdentityTrustedOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = null;
    Windows.helperStartTypeOverrideForTest = null;
    Windows.scRunnerForTest = null;
  });

  List<String> verbs() => scCalls.map((a) => a.first).toList();

  void recordIpc({bool ack = true}) {
    Windows.helperStopIpcOverrideForTest = () async {
      ipcCalls++;
      return ack;
    };
  }

  /// A `sc` runner whose `qc` reports [startType] and this build's path.
  void serviceWith(String startType) {
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      switch (args.first) {
        case 'qc':
          return sc(
            0,
            'START_TYPE : 2   $startType\n'
            'BINARY_PATH_NAME : "$trustedPath"',
          );
        case 'query':
          return sc(0, 'STATE : 1  STOPPED');
      }
      return sc(0, '');
    };
  }

  group('P9-A — stopHelperService', () {
    test('AUTO + ordinary user (not owned) never touches anything', () async {
      recordIpc();
      serviceWith('AUTO_START');

      expect(await Windows().stopHelperService(), HelperStopOutcome.notOwned);
      expect(ipcCalls, 0);
      expect(scCalls, isEmpty, reason: 'no SCM call of any kind');
    });

    test('AUTO + an admin session that ran `sc start` still refuses', () async {
      Windows.markHelperSessionForTest(startedByUs: true);
      recordIpc();
      serviceWith('AUTO_START');

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.sharedAutoStart,
      );
      expect(ipcCalls, 0, reason: 'the shared helper is never asked to stop');
      expect(verbs(), isNot(contains('stop')));
      expect(verbs(), isNot(contains('config')));
    });

    test('DEMAND + owned keeps the original stop flow', () async {
      Windows.markHelperSessionForTest(startedByUs: true);
      recordIpc();
      serviceWith('DEMAND_START');

      expect(await Windows().stopHelperService(), HelperStopOutcome.stopped);
      expect(ipcCalls, 1);
      expect(verbs(), contains('qc'));
      expect(verbs(), contains('query'));
    });

    test('DEMAND + not owned is left alone', () async {
      recordIpc();
      serviceWith('DEMAND_START');

      expect(await Windows().stopHelperService(), HelperStopOutcome.notOwned);
      expect(ipcCalls, 0);
      expect(scCalls, isEmpty);
    });

    test('a failing `sc qc` refuses the stop', () async {
      Windows.markHelperSessionForTest(startedByUs: true);
      recordIpc();
      Windows.scRunnerForTest = (args) async {
        scCalls.add(args);
        return sc(1, 'SCM is unavailable');
      };

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.identityConflict,
      );
      expect(ipcCalls, 0);
      expect(verbs(), isNot(contains('stop')));
    });

    test('an unparsable start type refuses the stop', () async {
      Windows.markHelperSessionForTest(startedByUs: true);
      recordIpc();
      Windows.scRunnerForTest = (args) async {
        scCalls.add(args);
        if (args.first == 'qc') {
          return sc(0, 'BINARY_PATH_NAME : "$trustedPath"');
        }
        return sc(0, '');
      };

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.sharedAutoStart,
      );
      expect(
        ipcCalls,
        0,
        reason: 'fail closed: prove it is demand-start first',
      );
    });
  });
}
