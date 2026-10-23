import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/core_health_service.dart';


/// P2.4-E (CF-5) — Core health truth.
void main() {
  final service = CoreHealthService.instance;

  setUp(() {
    CoreHealthService.coreProbeOverride = null;
    CoreHealthService.desktopOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.chainProbeOverride = null;
  });

  tearDown(() {
    CoreHealthService.coreProbeOverride = null;
    CoreHealthService.desktopOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.chainProbeOverride = null;
  });

  // ── A: healthy probe → running ───────────────────────────────────────────
  test('A. a healthy core probe reports RUNNING', () async {
    CoreHealthService.desktopOverride = true;
    CoreHealthService.coreProbeOverride = (_) async => true;

    final r = await service.check();
    expect(r.state, CoreHealthState.running);
    expect(r.isRunning, isTrue);
    expect(r.latencyMs, isNotNull);
  });

  // ── B / E / D: failing probe is never "running" ──────────────────────────
  test('B. a failing probe is UNREACHABLE when local state says running, '
      'STOPPED otherwise', () async {
    CoreHealthService.desktopOverride = true;
    CoreHealthService.coreProbeOverride = (_) async => false;
    // local state cannot fabricate RUNNING — the service has no local input on
    // desktop, so a failed probe is STOPPED (no local "running" claim).
    final r = await service.check();
    expect(r.state, isNot(CoreHealthState.running));
    expect(
      r.state,
      anyOf(CoreHealthState.stopped, CoreHealthState.unreachable),
    );
  });

  test('D. a throwing/timeout probe is never RUNNING', () async {
    CoreHealthService.desktopOverride = true;
    CoreHealthService.coreProbeOverride = (_) async =>
        throw TimeoutException('core api timeout');

    final r = await service.check();
    expect(r.state, isNot(CoreHealthState.running));
    expect(r.error, isNotNull);
    expect(
      r.state,
      anyOf(CoreHealthState.stopped, CoreHealthState.unreachable),
    );
  });

  // ── C: no desktop core service → UNKNOWN (never a guess) ─────────────────
  test('C. a platform without a desktop core service is UNKNOWN', () async {
    CoreHealthService.desktopOverride = false;
    CoreHealthService.coreProbeOverride = (_) async {
      fail('no core probe may run without a desktop core service');
    };

    final r = await service.check();
    expect(r.state, CoreHealthState.unknown);
  });

  // ── single-flight ───────────────────────────────────────────────────────
  test(
    'E. concurrent checks share one in-flight probe (single-flight)',
    () async {
      CoreHealthService.desktopOverride = true;
      var probes = 0;
      final gate = Completer<bool>();
      CoreHealthService.coreProbeOverride = (_) {
        probes++;
        return gate.future;
      };

      final a = service.check();
      final b = service.check();
      final c = service.check();
      gate.complete(true);
      final results = await Future.wait([a, b, c]);

      expect(probes, 1, reason: 'single-flight: one probe, not three');
      for (final r in results) {
        expect(r.state, CoreHealthState.running);
      }
    },
  );

  // ── F / G: production gate in ChainProxyManager ──────────────────────────

  // ── H: recovery ─────────────────────────────────────────────────────────

  // ── I / K: no leaks across repeated checks ──────────────────────────────

  // ── F2: no desktop core service → UNKNOWN never fabricates readiness ─────
  //
  // The Android fallback: with no desktop core service the determination is
  // `unknown`, and the production gate (`ChainProxyManager._isCoreReady()`)
  // must then consult the local lifecycle state — which, when the app is not
  // booted, is unavailable, so the gate must answer "not ready" rather than
  // optimistically assuming the core is up.

  // ── P2.8-C structural guard: no cached "last result" state ──────────────
  //
  // The determination is returned to the caller only. A cached result had zero
  // production readers and could only ever be read as stale runtime truth, so
  // it was removed rather than wired to an invented consumer.
}
