import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

/// P1.1-F — production failover wiring.
///
/// These tests go through `ChainProxyManager.triggerAutoFailover` (the real
/// production entry) — NOT through a hand-injected executor on an isolated
/// service. The [ChainProxyManager.failoverExecutorWrapper] seam lets the test
/// observe the executor the manager builds; if the manager ever stops
/// constructing/passing it, every `applyCount`/`commitCount`/`rollbackCount`
/// assertion below stays at 0 and the suite fails. That is the regression guard.
///
/// Only `probeCandidate` is stubbed (the real probe needs a live Mihomo core);
/// `applyCandidate` / `rollbackToOriginal` / `commitSuccess` are delegated to
/// the REAL executor the manager wired, so the real apply/rollback/commit
/// boundaries are exercised.
///
/// NOTE: the manager builds the executor **lazily inside** `triggerAutoFailover`,
/// so the recording wrapper cannot be configured before the call — the probe
/// override and apply gate therefore live at file scope.
ChainProbeReport? Function(ChainProxyConfig cfg)? _probeOverride;
Completer<void>? _applyGate;

class _RecordingExecutor implements IChainFailoverExecutor {
  _RecordingExecutor(this._real);

  final IChainFailoverExecutor _real;

  int applyCount = 0;
  int probeCount = 0;
  int rollbackCount = 0;
  int commitCount = 0;
  ChainProxyConfig? lastCommitted;

  @override
  Future<void> applyCandidate(ChainProxyConfig c, CancelToken? t) async {
    applyCount++;
    final gate = _applyGate;
    if (gate != null) await gate.future;
    await _real.applyCandidate(c, t);
  }

  @override
  Future<ChainProbeReport> probeCandidate(ChainProxyConfig c, CancelToken? t) {
    probeCount++;
    final o = _probeOverride;
    if (o != null) return Future.value(o(c));
    return _real.probeCandidate(c, t);
  }

  @override
  Future<void> rollbackToOriginal(ChainProxyConfig c, CancelToken? t) {
    rollbackCount++;
    return _real.rollbackToOriginal(c, t);
  }

  @override
  Future<void> commitSuccess(ChainProxyConfig c) {
    commitCount++;
    lastCommitted = c;
    return _real.commitSuccess(c);
  }
}

ChainProbeReport _failedReport() => ChainProbeReport(
  mode: ChainHopMode.twoHop,
  isOverallHealthy: false,
  healthStatus: ChainHealthStatus.failed,
  failureHop: 2,
  errorCode: ChainProbeErrorCodes.exitTimeout,
  hops: const [],
  timestamp: DateTime.now(),
);

ChainProbeReport _healthyReport(ChainProxyConfig cfg) => ChainProbeReport(
  mode: cfg.hopMode,
  isOverallHealthy: true,
  healthStatus: ChainHealthStatus.healthy,
  totalChainLatencyMs: 120,
  hops: const [],
  timestamp: DateTime.now(),
);

void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late ChainProxyManager manager;
  _RecordingExecutor? recorder;

  const baseConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'HK-01',
    hop2Node: 'US-01',
    defaultDialerProxy: 'HK-01',
  );

  ChainFallbackPool poolWithExit(String name) => ChainFallbackPool(
    exitCandidates: [
      ChainFallbackCandidate(nodeName: name, role: FallbackCandidateRole.exit),
    ],
  );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_failover_wiring_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;

    recorder = null;
    _probeOverride = null;
    _applyGate = null;
    ChainProxyManager.failoverExecutorWrapper = (real) {
      final r = _RecordingExecutor(real);
      recorder = r;
      return r;
    };

    chainFlapDampenerService.reset();
    manager = ChainProxyManager();
    await manager.updateConfig((_) => baseConfig);
    await manager.updateFallbackPool((_) => const ChainFallbackPool());
  });

  tearDown(() {
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.failoverExecutorWrapper = null;
    _probeOverride = null;
    _applyGate = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('1+2. manager builds AND passes a real executor (apply + rollback run)',
      () async {
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    final configBefore = File(configPath).readAsStringSync();

    // Force the probe to fail → the candidate must be applied then rolled back.
    _probeOverride = (cfg) => _failedReport();

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );

    expect(recorder, isNotNull, reason: 'manager must construct an executor');
    expect(
      recorder!.applyCount,
      greaterThan(0),
      reason: 'apply must be invoked → the executor was really passed',
    );
    expect(
      recorder!.rollbackCount,
      greaterThan(0),
      reason: 'a failed candidate must be rolled back',
    );
    expect(result.isSuccess, isFalse);

    // apply/rollback must NOT persist: the config file is byte-identical.
    expect(
      File(configPath).readAsStringSync(),
      configBefore,
      reason: 'apply/rollback must never write chain_proxies.json',
    );
  });

  test('6. apply success commits (and only commit persists)', () async {
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));

    _probeOverride = _healthyReport;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );

    expect(recorder!.applyCount, greaterThan(0));
    expect(recorder!.commitCount, 1, reason: 'commitSuccess must be invoked once');
    expect(recorder!.rollbackCount, 0, reason: 'a healthy candidate needs no rollback');
    expect(result.isSuccess, isTrue);
    expect(result.switchedNodeName, 'US-FB-01');

    // commit DID persist.
    final persisted = jsonDecode(File(configPath).readAsStringSync())
        as Map<String, dynamic>;
    expect(persisted['enable'], isTrue);
  });

  test('8. no candidate → no apply / no commit', () async {
    // Pool intentionally empty.
    _probeOverride = _healthyReport;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );

    expect(recorder!.applyCount, 0);
    expect(recorder!.commitCount, 0);
    expect(result.isSuccess, isFalse);
  });

  test('10. single-flight: a second trigger is rejected, not started', () async {
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    _probeOverride = _healthyReport;
    final gate = Completer<void>();
    _applyGate = gate;

    final first = manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );
    expect(manager.isFailingOver, isTrue);

    // Second trigger while the first is mid-apply → must be rejected outright.
    final second = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );
    expect(second.isCancelled, isTrue);
    expect(second.rootCause, contains('已有故障转移正在执行'));
    expect(
      recorder!.applyCount,
      1,
      reason: 'the rejected trigger must not start a second session',
    );

    gate.complete();
    final firstResult = await first;
    expect(firstResult.isSuccess, isTrue);
  });

  test('11. P1.1-E: failover never writes chain_fallback_pool.json', () async {
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    final poolBefore = File(poolPath).readAsStringSync();

    _probeOverride = _healthyReport;
    await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: _failedReport(),
    );

    expect(
      File(poolPath).readAsStringSync(),
      poolBefore,
      reason: 'failover runtime pool write-back must not persist',
    );
  });

  test('12. D1/D2: setFallbackPool still does not persist', () async {
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    final before = File(poolPath).readAsStringSync();

    final runtimePool = manager.fallbackPool.copyWith(
      exitCandidates: [
        manager.fallbackPool.exitCandidates.single.copyWith(
          health: ChainHealthStatus.healthy,
          latencyMs: 42,
        ),
      ],
    );
    await manager.setFallbackPool(runtimePool);

    expect(File(poolPath).readAsStringSync(), before);
    expect(manager.fallbackPool.exitCandidates.single.latencyMs, 42);
  });

  // ── availableProxyNames (rule-level) ──────────────────────────────────────
  //
  // NOTE: the manager→groupsProvider read itself needs a live provider scope
  // (AppController.ref is a WidgetRef) and is therefore NOT exercised here; it
  // is verified by code inspection. What IS verified below is the
  // `MISSING_NODE` rule that consumes `availableProxyNames`.
  //
  // `availableProxyNames` must also contain the CURRENT chain's hops, otherwise
  // `ChainTopologyValidator` rejects the hypothetical topology with
  // NODE_NOT_FOUND before ranking.
  group('4. availableProxyNames → MISSING_NODE rule', () {
    const universe = ['HK-01', 'US-01', 'US-ALIVE-01'];

    test('candidate absent from the universe is excluded', () {
      const service = ChainFallbackService();
      final result = service.selectCandidates(
        currentConfig: baseConfig,
        role: FallbackCandidateRole.exit,
        pool: poolWithExit('US-GONE-01'),
        availableProxyNames: universe,
      );
      expect(result.selected, isNull);
      expect(
        result.excluded.map((e) => e.reasonCode),
        contains('MISSING_NODE'),
      );
    });

    test('candidate present in the universe is eligible', () {
      const service = ChainFallbackService();
      final result = service.selectCandidates(
        currentConfig: baseConfig,
        role: FallbackCandidateRole.exit,
        pool: poolWithExit('US-ALIVE-01'),
        availableProxyNames: universe,
      );
      expect(result.selected?.nodeName, 'US-ALIVE-01');
    });
  });
}
