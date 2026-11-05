import 'dart:async';
import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9 — `globalState.coreSHA256` used to be read directly by the helper probe.
///
/// `main.dart` awaits `preload()` **concurrently** with `initApp()` inside one
/// `Future.wait`, and `preload()` constructs `ClashService`, whose constructor
/// fires `reStart()` immediately. The probe therefore reached `_pingHelper`
/// while `initApp` was still hashing the core (~200 ms vs ~60–120 ms), saw a
/// null SHA, and reported "unhealthy" — indistinguishable from a real identity
/// mismatch. `registerService()` returned false and the app silently spawned
/// the core itself, never using the helper at all.
void main() {
  final globalState = GlobalState();

  setUp(() {
    globalState.resetCoreShaForTest();
    Windows.scRunnerForTest = null;
    Windows.skipAuthKeyForTest = false;
  });

  tearDown(() {
    globalState.resetCoreShaForTest();
    Windows.scRunnerForTest = null;
    Windows.skipAuthKeyForTest = false;
  });

  group('ensureCoreSha — shared computation', () {
    test('a caller that arrives mid-computation awaits the same future', () async {
      final gate = Completer<void>();
      GlobalState.coreShaComputerForTest = () async {
        await gate.future;
        return 'a' * 64;
      };

      // Stands in for `initApp()`: starts the one and only computation.
      final initAppCall = globalState.ensureCoreSha();
      // Stands in for the helper probe: arrives while it is still running.
      final probeCall = globalState.ensureCoreSha();

      expect(
        identical(initAppCall, probeCall),
        isTrue,
        reason: 'the probe must join the in-flight computation, not start its own',
      );

      var probeResolved = false;
      unawaited(probeCall.then((_) => probeResolved = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        probeResolved,
        isFalse,
        reason: 'a probe must not answer before the SHA exists — that is the '
            'exact bug: "not computed yet" was read as "not our helper"',
      );

      gate.complete();
      expect(await probeCall, 'a' * 64);
      expect(await initAppCall, 'a' * 64);
      expect(globalState.coreSHA256, 'a' * 64);
    });

    test('the computation runs once for every caller', () async {
      var calls = 0;
      GlobalState.coreShaComputerForTest = () async {
        calls++;
        return 'b' * 64;
      };

      await Future.wait([
        globalState.ensureCoreSha(),
        globalState.ensureCoreSha(),
        globalState.ensureCoreSha(),
      ]);

      expect(calls, 1);
    });

    test('a null result is memoised too — no repeated failing hashes', () async {
      var calls = 0;
      GlobalState.coreShaComputerForTest = () async {
        calls++;
        return null;
      };

      expect(await globalState.ensureCoreSha(), isNull);
      expect(await globalState.ensureCoreSha(), isNull);
      expect(calls, 1);
    });
  });

  group('registerService — the probe waits for the SHA', () {
    // `Windows()` opens shell32.dll through FFI, so this case can only run on
    // Windows. The `ensureCoreSha` group above is platform-independent and still
    // runs everywhere.
    test('does not answer "no helper" while the SHA is still being computed',
        skip: !Platform.isWindows, () async {
      final gate = Completer<void>();
      GlobalState.coreShaComputerForTest = () async {
        await gate.future;
        // Empty on purpose: once the gate opens the probe declines without
        // touching a real pipe, so this test stays offline.
        return '';
      };

      Windows.skipAuthKeyForTest = true;
      Windows.scRunnerForTest = (_) async => ProcessResult(
        0,
        0,
        'SERVICE_NAME: FluxoraHelperService\n'
            '        STATE              : 4  RUNNING\n',
        '',
      );

      var settled = false;
      final registration = Windows().registerService();
      unawaited(registration.whenComplete(() => settled = true));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        settled,
        isFalse,
        reason: 'returning false here is what made the app skip the helper '
            'entirely; it must wait for the SHA instead',
      );

      gate.complete();
      expect(
        await registration,
        isFalse,
        reason: 'an empty SHA is still a real "cannot verify" answer',
      );
      expect(settled, isTrue);
    });
  });
}
