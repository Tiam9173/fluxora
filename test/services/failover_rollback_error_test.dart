import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.5-E (E-2) — failover rollback error truth.
///
/// Drives the REAL production entry (`ChainProxyManager.triggerAutoFailover`)
/// with a stub executor injected through the existing `failoverExecutorWrapper`
/// seam, so the *manager → service → executor* wiring is the production one.
class _StubExecutor implements IChainFailoverExecutor {
  _StubExecutor({
    this.applyError,
    this.rollbackError,
    this.probeCancelled = false,
  });

  final Object? applyError;
  final Object? rollbackError;

  /// P2.6-B: makes the candidate probe report a **cancellation**, which drives
  /// `executeFailover` into the "cancel during probe" cleanup branch.
  final bool probeCancelled;

  int applyCalls = 0;
  int rollbackCalls = 0;
  int commitCalls = 0;

  @override
  Future<void> applyCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) async {
    applyCalls++;
    if (applyError != null) throw applyError!;
  }

  @override
  Future<ChainProbeReport> probeCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) async => ChainProbeReport(
    mode: candidateConfig.hopMode,
    isOverallHealthy: !probeCancelled,
    isCancelled: probeCancelled,
    hops: const [],
    timestamp: DateTime.now(),
  );

  @override
  Future<void> rollbackToOriginal(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  ) async {
    rollbackCalls++;
    if (rollbackError != null) throw rollbackError!;
  }

  @override
  Future<void> commitSuccess(ChainProxyConfig finalConfig) async {
    commitCalls++;
  }
}

/// Delegates to the **real** executor but stubs only the candidate probe.
///
/// Needed by test J: `_buildFailoverExecutor`'s `onProbe` calls
/// `chainProbeService.probeChain` directly (the `chainProbeOverride` seam only
/// affects `probeCurrentChain`), so without this the real probe would fail on a
/// missing Flutter binding and the flow would never reach the commit step.
class _RealExecutorWithHealthyProbe implements IChainFailoverExecutor {
  _RealExecutorWithHealthyProbe(this._real);

  final IChainFailoverExecutor _real;

  @override
  Future<void> applyCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) => _real.applyCandidate(candidateConfig, cancelToken);

  @override
  Future<ChainProbeReport> probeCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) async => ChainProbeReport(
    mode: candidateConfig.hopMode,
    isOverallHealthy: true,
    healthStatus: ChainHealthStatus.healthy,
    hops: const [],
    timestamp: DateTime.now(),
  );

  @override
  Future<void> rollbackToOriginal(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  ) => _real.rollbackToOriginal(originalConfig, cancelToken);

  @override
  Future<void> commitSuccess(ChainProxyConfig finalConfig) =>
      _real.commitSuccess(finalConfig);
}

void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;
  final manager = ChainProxyManager();

  setUp(() {
    chainFlapDampenerService.reset();
    tmp = Directory.systemTemp.createTempSync('fluxora_p25e_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.failoverExecutorWrapper = null;
    ChainProxyManager.chainProbeOverride = null;
  });

  tearDown(() async {
    await manager.flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.failoverExecutorWrapper = null;
    ChainProxyManager.chainProbeOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<void> seedChain({String node = 'E-EXIT'}) async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'E-1', hop2Node: 'E-2'),
      reloadCore: false,
    );
    await manager.updateFallbackPool(
      (_) => ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: node,
            role: FallbackCandidateRole.exit,
          ),
        ],
      ),
    );
  }

  ChainProbeReport failingReport() => ChainProbeReport(
    mode: ChainHopMode.twoHop,
    isOverallHealthy: false,
    healthStatus: ChainHealthStatus.failed,
    failureHop: 2,
    hops: const [],
    timestamp: DateTime.now(),
  );

  // ── G. apply fails, rollback SUCCEEDS → plain failure ────────────────────
  test('G. apply failure + successful rollback → a plain failover failure',
      () async {
    await seedChain(node: 'G-EXIT');
    final stub = _StubExecutor(applyError: StateError('apply failed'));
    ChainProxyManager.failoverExecutorWrapper = (_) => stub;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(stub.applyCalls, greaterThan(0));
    expect(stub.rollbackCalls, greaterThan(0), reason: 'cleanup ran');
    expect(result.isSuccess, isFalse);
    expect(
      result.isRollbackFailed,
      isFalse,
      reason: 'the rollback succeeded — this is NOT a rollback failure',
    );
  });

  // ── H. apply fails, rollback FAILS → rollback failure exposed ────────────
  test('H. apply failure + failed rollback → rollback failure is exposed',
      () async {
    await seedChain(node: 'H-EXIT');
    final stub = _StubExecutor(
      applyError: StateError('apply failed'),
      rollbackError: StateError('rollback exploded'),
    );
    ChainProxyManager.failoverExecutorWrapper = (_) => stub;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.isRollbackFailed,
      isTrue,
      reason: 'a failed cleanup rollback must not be reported as a plain failure',
    );
    expect(result.rollbackError, isNotNull);
    expect(result.rollbackError, contains('rollback exploded'));
  });

  // ── I. the rollback exception is not swallowed ───────────────────────────
  test('I. the rollback exception text reaches the caller', () async {
    await seedChain(node: 'I-EXIT');
    final stub = _StubExecutor(
      applyError: StateError('apply failed'),
      rollbackError: StateError('UNIQUE_ROLLBACK_MARKER'),
    );
    ChainProxyManager.failoverExecutorWrapper = (_) => stub;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(
      '${result.rollbackError} ${result.rootCause}',
      contains('UNIQUE_ROLLBACK_MARKER'),
      reason: 'the rollback error must be observable, never swallowed',
    );
  });

  // ── J. commit persistence failure is a real failure, not an escape ───────
  test('J. a failed commit persistence yields a failed result (no escape)',
      () async {
    await seedChain(node: 'J-EXIT');

    // Use the REAL executor (so `onCommit` → `_commitConfig` → the real save),
    // with only the candidate probe stubbed healthy — that is what lets the
    // flow actually reach the commit step instead of dying at the probe.
    ChainProxyManager.coreConfigReloadOverride = () async {};
    ChainProxyManager.failoverExecutorWrapper = (real) =>
        _RealExecutorWithHealthyProbe(real);

    // Make the *commit* write fail: a DIRECTORY where the config file goes.
    await File(configPath).delete();
    Directory(configPath).createSync(recursive: true);

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(
      result.isSuccess,
      isFalse,
      reason:
          'a switch that was never persisted must not be reported as success',
    );
    expect('${result.rootCause}', contains('Commit'));
  });

  // ── K. cancel during probe + rollback SUCCEEDS → cancellation preserved ──
  test('K. cancel during probe + successful rollback → cancellation kept',
      () async {
    await seedChain(node: 'K-EXIT');
    final stub = _StubExecutor(probeCancelled: true);
    ChainProxyManager.failoverExecutorWrapper = (_) => stub;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(stub.applyCalls, greaterThan(0));
    expect(stub.rollbackCalls, greaterThan(0), reason: 'cleanup ran');
    expect(
      result.isCancelled,
      isTrue,
      reason: 'a cancellation whose rollback succeeded stays a cancellation',
    );
    expect(result.isRollbackFailed, isFalse);
  });

  // ── L. cancel during probe + rollback FAILS → rollback truth exposed ─────
  test('L. cancel during probe + failed rollback → rollback failure exposed',
      () async {
    await seedChain(node: 'L-EXIT');
    final stub = _StubExecutor(
      probeCancelled: true,
      rollbackError: StateError('CANCELLED_ROLLBACK_MARKER'),
    );
    ChainProxyManager.failoverExecutorWrapper = (_) => stub;

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: failingReport(),
    );

    expect(
      result.isRollbackFailed,
      isTrue,
      reason: 'P2.6-B: the third rollback site must not swallow the failure',
    );
    expect(result.rollbackError, isNotNull);
    expect(result.rollbackError, contains('CANCELLED_ROLLBACK_MARKER'));
    expect(result.isCancelled, isFalse);
  });
}
