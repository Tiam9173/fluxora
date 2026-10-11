import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/core_health_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

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
  test(
    'F. an unhealthy core blocks runChainHealthCheck (no chain probe)',
    () async {
      final tmp = Directory.systemTemp.createTempSync('fluxora_p24e_');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
      ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
        tmp.path,
        'chain_reliability_stats.json',
      );
      try {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, autoFailover: true),
          reloadCore: false,
        );

        var chainProbes = 0;
        ChainProxyManager.chainProbeOverride = (cfg) async {
          chainProbes++;
          return ChainProbeReport(
            mode: cfg.hopMode,
            isOverallHealthy: true,
            healthStatus: ChainHealthStatus.healthy,
            hops: const [],
            timestamp: DateTime.now(),
          );
        };

        // Core API unreachable → the gate must stop the health check.
        CoreHealthService.desktopOverride = true;
        CoreHealthService.coreProbeOverride = (_) async => false;
        await manager.runChainHealthCheck();
        expect(
          chainProbes,
          0,
          reason: 'an unreachable core must not be treated as running',
        );

        // Core healthy → the health check proceeds.
        CoreHealthService.coreProbeOverride = (_) async => true;
        await manager.runChainHealthCheck();
        expect(chainProbes, 1);
      } finally {
        await ChainProxyManager().flushReliabilityStats();
        ChainProxyManager.configFilePathOverride = null;
        ChainProxyManager.fallbackPoolFilePathOverride = null;
        ChainProxyManager.reliabilityStatsFilePathOverride = null;
        await deleteTempDirWithRetry(tmp);
      }
    },
  );

  // ── H: recovery ─────────────────────────────────────────────────────────
  test('H. a recovered core returns to RUNNING', () async {
    CoreHealthService.desktopOverride = true;
    CoreHealthService.coreProbeOverride = (_) async => false;
    expect((await service.check()).state, isNot(CoreHealthState.running));

    CoreHealthService.coreProbeOverride = (_) async => true;
    expect((await service.check()).state, CoreHealthState.running);
  });

  // ── I / K: no leaks across repeated checks ──────────────────────────────
  test('I. repeated checks leave no in-flight probe behind', () async {
    CoreHealthService.desktopOverride = true;
    var probes = 0;
    CoreHealthService.coreProbeOverride = (_) async {
      probes++;
      return true;
    };

    for (var i = 0; i < 5; i++) {
      await service.check();
    }
    expect(probes, 5);
    // A later call starts a fresh probe (no stuck in-flight future).
    await service.check();
    expect(probes, 6);
  });

  // ── F2: no desktop core service → UNKNOWN never fabricates readiness ─────
  //
  // The Android fallback: with no desktop core service the determination is
  // `unknown`, and the production gate (`ChainProxyManager._isCoreReady()`)
  // must then consult the local lifecycle state — which, when the app is not
  // booted, is unavailable, so the gate must answer "not ready" rather than
  // optimistically assuming the core is up.
  test(
    'F2. an UNKNOWN core health never fabricates readiness (Android path)',
    () async {
      final tmp = Directory.systemTemp.createTempSync('fluxora_p28c_');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
      ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
        tmp.path,
        'chain_reliability_stats.json',
      );
      try {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, autoFailover: true),
          reloadCore: false,
        );

        var chainProbes = 0;
        ChainProxyManager.chainProbeOverride = (cfg) async {
          chainProbes++;
          return ChainProbeReport(
            mode: cfg.hopMode,
            isOverallHealthy: true,
            healthStatus: ChainHealthStatus.healthy,
            hops: const [],
            timestamp: DateTime.now(),
          );
        };

        CoreHealthService.desktopOverride = false;
        CoreHealthService.coreProbeOverride = (_) async {
          fail('no core probe may run without a desktop core service');
        };
        expect((await service.check()).state, CoreHealthState.unknown);

        await manager.runChainHealthCheck();
        expect(
          chainProbes,
          0,
          reason: 'UNKNOWN must fall back to the local state, never to "ready"',
        );
      } finally {
        await ChainProxyManager().flushReliabilityStats();
        ChainProxyManager.configFilePathOverride = null;
        ChainProxyManager.fallbackPoolFilePathOverride = null;
        ChainProxyManager.reliabilityStatsFilePathOverride = null;
        await deleteTempDirWithRetry(tmp);
      }
    },
  );

  // ── P2.8-C structural guard: no cached "last result" state ──────────────
  //
  // The determination is returned to the caller only. A cached result had zero
  // production readers and could only ever be read as stale runtime truth, so
  // it was removed rather than wired to an invented consumer.
  test('P2.8-C. CoreHealthService keeps no cached last-result state', () {
    final src = File(
      'lib/services/core_health_service.dart',
    ).readAsStringSync();
    // Strip `//` line comments so the guard tests code, not prose.
    final code = src
        .split('\n')
        .map((l) {
          final i = l.indexOf('//');
          return i < 0 ? l : l.substring(0, i);
        })
        .join('\n');

    expect(
      code.contains('lastResult'),
      isFalse,
      reason: 'the dead write-only state must be gone',
    );
    expect(
      code.contains('ValueNotifier'),
      isFalse,
      reason: 'the notifier existed only for that state',
    );
    // The single-flight, bounded, never-throwing determination is unchanged.
    expect(code.contains('Future<CoreHealthResult> check()'), isTrue);
    expect(code.contains('Duration(seconds: 2)'), isTrue);
  });
}
