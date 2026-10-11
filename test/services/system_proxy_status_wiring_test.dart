import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/services/system_proxy_readback.dart';

/// P2.5-B (CF-3) — system-proxy readback → UI status wiring.
///
/// The settings page and the dashboard both render the *same* pure decision
/// ([resolveSystemProxyStatus]) over the *same* owner
/// ([SystemProxyReadbackService]). This mirrors the P2.3-A precedent
/// (`chainNodeUniverse` / `isFallbackCandidateStale`), which pins UI decisions
/// as pure functions instead of pumping widgets.
///
/// Every platform is driven through the readback's own `processRunOverride`
/// seam: no real OS state is read, no MethodChannel is needed.
ProcessResult _res(int code, [String out = '']) =>
    ProcessResult(0, code, out, '');

String _winOut(String name, String value) =>
    '\r\nHKEY_CURRENT_USER\\...\\Internet Settings\r\n'
    '    $name    REG_DWORD    $value\r\n\r\n';

void main() {
  final service = SystemProxyReadbackService.instance;

  setUp(() {
    SystemProxyReadbackService.processRunOverride = null;
    SystemProxyReadbackService.platformOverride = null;
    service.lastReadback.value = null;
    service.isChecking.value = false;
  });

  tearDown(() {
    SystemProxyReadbackService.processRunOverride = null;
    SystemProxyReadbackService.platformOverride = null;
    service.lastReadback.value = null;
    service.isChecking.value = false;
  });

  SystemProxyReadback rb(
    SystemProxyActualState state, {
    bool unsupported = false,
  }) => SystemProxyReadback(
    actualState: state,
    platform: 'test',
    checkedAt: DateTime.now(),
    unsupported: unsupported,
  );

  SystemProxyStatusKind resolve({
    required bool desired,
    bool checking = false,
    SystemProxyReadback? readback,
  }) => resolveSystemProxyStatus(
    desiredEnabled: desired,
    checking: checking,
    readback: readback,
  );

  // ── State: A / B / C / D / E ─────────────────────────────────────────────
  group('A–E: desired vs actual status', () {
    test('A. desired ON + actual ON → on', () {
      expect(resolve(desired: true, readback: rb(SystemProxyActualState.enabled)),
          SystemProxyStatusKind.on);
    });

    test('B. desired ON + actual OFF → mismatchOn', () {
      expect(
        resolve(desired: true, readback: rb(SystemProxyActualState.disabled)),
        SystemProxyStatusKind.mismatchOn,
      );
    });

    test('C. desired OFF + actual ON → mismatchOff', () {
      expect(
        resolve(desired: false, readback: rb(SystemProxyActualState.enabled)),
        SystemProxyStatusKind.mismatchOff,
      );
    });

    test('D. actual UNKNOWN is never mapped to off', () {
      final s = resolve(
        desired: false,
        readback: rb(SystemProxyActualState.unknown),
      );
      expect(s, SystemProxyStatusKind.unknown);
      expect(s, isNot(SystemProxyStatusKind.off));
      expect(s, isNot(SystemProxyStatusKind.mismatchOff));
    });

    test('E. unsupported platform → unsupported (N/A semantics)', () {
      expect(
        resolve(
          desired: false,
          readback: rb(SystemProxyActualState.unknown, unsupported: true),
        ),
        SystemProxyStatusKind.unsupported,
      );
    });

    test('G. a desired state alone never yields ON (no false success)', () {
      expect(resolve(desired: true, readback: null),
          isNot(SystemProxyStatusKind.on));
      expect(
        resolve(desired: true, readback: rb(SystemProxyActualState.unknown)),
        isNot(SystemProxyStatusKind.on),
      );
    });

    test('checking takes precedence while an observation is in flight', () {
      expect(
        resolve(
          desired: true,
          checking: true,
          readback: rb(SystemProxyActualState.disabled),
        ),
        SystemProxyStatusKind.checking,
      );
    });

    test('notChecked before any observation has run', () {
      expect(resolve(desired: true, readback: null),
          SystemProxyStatusKind.notChecked);
    });
  });

  // ── SET → READBACK / robustness: F / H / I ───────────────────────────────
  group('F/H/I: observation behaviour', () {
    test('F. a successful observation publishes and clears isChecking',
        () async {
      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride = (exe, args) async {
        if (args.contains('ProxyEnable')) {
          return _res(0, _winOut('ProxyEnable', '0x1'));
        }
        return _res(0, _winOut('ProxyServer', '127.0.0.1:7890'));
      };

      final seen = <bool>[];
      void listener() => seen.add(service.isChecking.value);
      service.isChecking.addListener(listener);
      final result = await service.read();
      service.isChecking.removeListener(listener);

      expect(result.actualState, SystemProxyActualState.enabled);
      expect(service.lastReadback.value?.actualState,
          SystemProxyActualState.enabled);
      expect(service.isChecking.value, isFalse);
      expect(seen.first, isTrue, reason: 'must report "checking" while in flight');
      expect(seen.last, isFalse, reason: 'must clear "checking" when done');
    });

    test('H. a never-completing observation is bounded → unknown, no throw',
        () async {
      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride =
          (exe, args) => Completer<ProcessResult>().future;

      final result = await service.read();
      expect(result.actualState, SystemProxyActualState.unknown);
      expect(service.lastReadback.value, isNotNull);
      expect(service.isChecking.value, isFalse);
    });

    test('I. a throwing observation → unknown, never throws', () async {
      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride =
          (exe, args) async => throw StateError('boom');

      final result = await service.read();
      expect(result.actualState, SystemProxyActualState.unknown);
      expect(result.error, isNotNull);
      expect(service.isChecking.value, isFalse);
    });
  });

  // ── Race: J ──────────────────────────────────────────────────────────────
  test('J. a slow older observation never overwrites a newer one', () async {
    SystemProxyReadbackService.platformOverride = 'windows';
    final gate = Completer<void>();
    var enableCalls = 0;
    SystemProxyReadbackService.processRunOverride = (exe, args) async {
      if (args.contains('ProxyEnable')) {
        enableCalls++;
        if (enableCalls == 1) {
          await gate.future; // the FIRST (older) observation stalls
          return _res(0, _winOut('ProxyEnable', '0x1')); // → enabled
        }
        return _res(0, _winOut('ProxyEnable', '0x0')); // → disabled
      }
      return _res(0, '');
    };

    final older = service.read(); // stalls on the gate
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final newer = await service.read(); // completes first
    expect(newer.actualState, SystemProxyActualState.disabled);

    gate.complete();
    await older;

    // The stale (enabled) result must NOT have replaced the newer one.
    expect(service.lastReadback.value?.actualState,
        SystemProxyActualState.disabled);
    expect(service.isChecking.value, isFalse);
  });

  // ── O: the readback contract the UI depends on ───────────────────────────
  test('O. matchesDesired treats unknown as never "in sync"', () {
    expect(
      rb(SystemProxyActualState.unknown).matchesDesired(desiredEnabled: false),
      isFalse,
    );
    expect(
      rb(SystemProxyActualState.disabled).matchesDesired(desiredEnabled: false),
      isTrue,
    );
    expect(
      rb(SystemProxyActualState.enabled).matchesDesired(desiredEnabled: true),
      isTrue,
    );
    expect(
      rb(SystemProxyActualState.enabled).matchesDesired(desiredEnabled: false),
      isFalse,
    );
  });
}
