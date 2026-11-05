import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/system.dart';

/// H2-C — identity hardening, SCM-confirmed stop, and the demand-start template.
///
/// Isolation: Group A drives a pure string function. Groups B/C drive the real
/// production code with every system touch replaced (`scRunnerForTest`,
/// `helperStopIpcOverrideForTest`). Nothing here reaches the SCM, the helper
/// pipe, `runas`, or UAC.
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

  const ours = r'C:\Apps\Fluxora\FluxoraHelperService.exe';

  ProcessResult sc(int exitCode, String stdout) =>
      ProcessResult(0, exitCode, stdout, '');

  // ── Group A — identity matching ───────────────────────────────────────────

  group('H2-C-A — sc qc binary identity', () {
    test('A1 — an exact path matches', () {
      expect(
        Windows.scQcBinaryMatches('BINARY_PATH_NAME : "$ours"', ours),
        isTrue,
      );
    });

    test('A2 — a .exe.backup suffix does NOT match', () {
      expect(
        Windows.scQcBinaryMatches('BINARY_PATH_NAME : "$ours.backup"', ours),
        isFalse,
        reason: 'this is the H2B-01 false positive the substring test had',
      );
    });

    test('A3 — the path appearing in another field does NOT match', () {
      // A display name or description that merely mentions the path is not the
      // binary path.
      expect(
        Windows.scQcBinaryMatches(
          'DISPLAY_NAME     : Fluxora helper ($ours)\n'
          'BINARY_PATH_NAME : "C:\\Other\\FluxoraHelperService.exe"',
          ours,
        ),
        isFalse,
      );
    });

    test('A4 — a quoted path with spaces matches', () {
      const spaced = r'C:\Program Files\Fluxora\FluxoraHelperService.exe';
      expect(
        Windows.scQcBinaryMatches('BINARY_PATH_NAME : "$spaced"', spaced),
        isTrue,
      );
    });

    test('A5 — a quoted path followed by arguments still matches', () {
      expect(
        Windows.scQcBinaryMatches('BINARY_PATH_NAME : "$ours" --service', ours),
        isTrue,
      );
    });

    test('A6 — a different install directory does NOT match', () {
      expect(
        Windows.scQcBinaryMatches(
          r'BINARY_PATH_NAME : "D:\Old\FluxoraHelperService.exe"',
          ours,
        ),
        isFalse,
      );
    });

    test('A7 — a different helper binary name does NOT match', () {
      expect(
        Windows.scQcBinaryMatches(
          r'BINARY_PATH_NAME : "C:\Apps\Fluxora\FluxoraDevHelperService.exe"',
          ours,
        ),
        isFalse,
        reason: 'Dev and Release must never be treated as the same service',
      );
    });

    test('A8 — unparseable output fails closed', () {
      expect(Windows.scQcBinaryMatches('', ours), isFalse);
      expect(Windows.scQcBinaryMatches('SCP? no path here', ours), isFalse);
    });

    test('A9 — case and separator differences still match', () {
      expect(
        Windows.scQcBinaryMatches(
          r'BINARY_PATH_NAME : "c:/apps/fluxora/FLUXORAHELPERSERVICE.EXE"',
          ours,
        ),
        isTrue,
      );
    });

    test('A10 — an unquoted path with spaces, or a %VAR%, does NOT match', () {
      expect(
        Windows.scQcBinaryMatches(
          r'BINARY_PATH_NAME : C:\Program Files\Fluxora\FluxoraHelperService.exe',
          ours,
        ),
        isFalse,
        reason: 'an unquoted spaced path cannot be split safely',
      );
      expect(
        Windows.scQcBinaryMatches(
          r'BINARY_PATH_NAME : "%APPDATA%\Fluxora\FluxoraHelperService.exe"',
          ours,
        ),
        isFalse,
        reason: 'an unresolved environment variable is not the same path',
      );
    });
  });

  // ── Group B — stop confirmation ───────────────────────────────────────────

  group('H2-C-B — stop confirmation', () {
    setUp(() {
      Windows.helperStopIpcOverrideForTest = null;
      Windows.stopHelperServiceOverrideForTest = null;
      Windows.scRunnerForTest = null;
      // B2 — these cases cover the stop mechanics, so the gate is opened here.
      // The gate itself is covered by T-S1 / T-S2 / T-S4 in
      // `test/common/helper_stop_ownership_test.dart`.
      Windows.markHelperSessionForTest(startedByUs: true);
      Windows.helperIdentityTrustedOverrideForTest = () async => true;
      // P9-A — these cases model the DEMAND_START service an instance may stop.
      Windows.helperStartTypeOverrideForTest = HelperServiceStartType.demand;
    });

    tearDown(() {
      Windows.helperStopIpcOverrideForTest = null;
      Windows.stopHelperServiceOverrideForTest = null;
      Windows.scRunnerForTest = null;
      Windows.resetHelperSessionForTest();
      Windows.helperIdentityTrustedOverrideForTest = null;
      Windows.helperStartTypeOverrideForTest = null;
    });

    test('B1 — ACK then STOP_PENDING → STOPPED reports stopped', () async {
      var polls = 0;
      Windows.helperStopIpcOverrideForTest = () async => true;
      Windows.scRunnerForTest = (args) async {
        if (args.first != 'query') return sc(0, '');
        polls++;
        return polls == 1
            ? sc(0, 'STATE : 3  STOP_PENDING')
            : sc(0, 'STATE : 1  STOPPED');
      };

      expect(await Windows().stopHelperService(), HelperStopOutcome.stopped);
    });

    test('B2 — ACK but the service stays RUNNING is not a success', () async {
      Windows.helperStopIpcOverrideForTest = () async => true;
      Windows.scRunnerForTest = (args) async =>
          args.first == 'query' ? sc(0, 'STATE : 4  RUNNING') : sc(0, '');

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.ackOnly,
        reason: 'an IPC acknowledgement must never be reported as stopped',
      );
    });

    test('B3 — a failing query is not a success', () async {
      Windows.helperStopIpcOverrideForTest = () async => true;
      Windows.scRunnerForTest = (args) async =>
          args.first == 'query' ? sc(1, 'SCM is unavailable') : sc(0, '');

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.queryFailed,
      );
    });

    test('B4 — a refused IPC is not a success', () async {
      Windows.helperStopIpcOverrideForTest = () async => false;
      Windows.scRunnerForTest = (args) async => sc(0, 'STATE : 4  RUNNING');

      expect(await Windows().stopHelperService(), HelperStopOutcome.ipcRefused);
    });

    test('B6 — a missing service is reported as such', () async {
      Windows.helperStopIpcOverrideForTest = () async => true;
      Windows.scRunnerForTest = (args) async => args.first == 'query'
          ? sc(
              1060,
              'The specified service does not exist as an installed service.',
            )
          : sc(0, '');

      expect(
        await Windows().stopHelperService(),
        HelperStopOutcome.notInstalled,
      );
    });

    test('B9 — localised field labels still parse by code + English name', () {
      // Chinese Windows prints a translated label; the number and the English
      // state name are not translated.
      expect(Windows.parseServiceState('状态  : 1  STOPPED'), 1);
      expect(Windows.parseServiceState('状态  : 4  RUNNING'), 4);
      // A mismatch between code and name fails closed.
      expect(Windows.parseServiceState('STATE : 1  RUNNING'), isNull);
      expect(Windows.parseServiceState('STATE : 9  RUNNING'), isNull);
      expect(Windows.parseServiceState('no state line'), isNull);
    });

    test('B8 — a repeated stop is bounded, not unbounded', () async {
      Windows.helperStopIpcOverrideForTest = () async => true;
      Windows.scRunnerForTest = (args) async =>
          args.first == 'query' ? sc(0, 'STATE : 1  STOPPED') : sc(0, '');

      final w = Windows();
      expect(await w.stopHelperService(), HelperStopOutcome.stopped);
      expect(await w.stopHelperService(), HelperStopOutcome.stopped);
    });
  });

  // ── Group C — demand start template ───────────────────────────────────────

  group('H2-C-C — new installs are demand-start', () {
    test('C1/C2 — the create template uses demand for every identity', () {
      expect(Windows.serviceStartTypeArg, 'start= demand');
      expect(
        Windows.serviceStartTypeArg.contains('auto'),
        isFalse,
        reason: 'Release used to be auto, which started the helper at boot',
      );
    });

    test('C6 — nothing in this batch migrates an existing service', () {
      // Structural guard: the stop path never calls `sc config`.
      final calls = <List<String>>[];
      Windows.scRunnerForTest = (args) async {
        calls.add(args);
        return args.first == 'query'
            ? ProcessResult(0, 0, 'STATE : 1  STOPPED', '')
            : ProcessResult(0, 0, '', '');
      };
      Windows.helperStopIpcOverrideForTest = () async => true;

      addTearDown(() {
        Windows.scRunnerForTest = null;
        Windows.helperStopIpcOverrideForTest = null;
      });

      return Windows().stopHelperService().then((_) {
        expect(
          calls.map((c) => c.first),
          isNot(contains('config')),
          reason: 'an existing Automatic service must not be reconfigured here',
        );
      });
    });
  });
}
