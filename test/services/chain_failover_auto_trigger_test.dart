import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show DebugPrintCallback, debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

/// P1.1-F2 — automatic failover.
///
/// Everything goes through the REAL manager entry points:
///   `runChainHealthCheck()` → `probeCurrentChain()` → `_maybeAutoFailover()`
///   → `triggerAutoFailover()` → `DelegateChainFailoverExecutor`
/// Never through an isolated `ChainFailoverService(executor: fake)`.
///
/// Only two things are stubbed, both via `@visibleForTesting` seams:
///  * `chainProbeOverride` — the network chain probe (needs a live Mihomo core);
///  * `coreRunningOverride` — the "core is running" guard.
/// The rest of `probeCurrentChain` (state flags, `_lastProbeReport`, candidate
/// write-back) and the whole failover executor chain still run for real.
///
/// NOTE: `ChainProxyManager` is a singleton, so `_consecutiveHealthCheckFailures`
/// leaks across tests. `setUp` normalises it via `setAutoFailover(false)`.
/// The chain-probe override is installed ONCE (counting every call) and reads
/// the file-level [_healthReport], so tests never lose the counter by replacing
/// the closure.
ChainProbeReport? Function(ChainProxyConfig cfg)? _candidateProbeOverride;
ChainProbeReport Function(ChainHopMode mode)? _healthReport;
Completer<void>? _applyGate;

class _RecordingExecutor implements IChainFailoverExecutor {
  _RecordingExecutor(this._real);

  final IChainFailoverExecutor _real;
  int applyCount = 0;
  int probeCount = 0;
  int rollbackCount = 0;
  int commitCount = 0;

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
    final o = _candidateProbeOverride;
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
    return _real.commitSuccess(c);
  }
}

ChainProbeReport _healthy(ChainHopMode mode) => ChainProbeReport(
  mode: mode,
  isOverallHealthy: true,
  healthStatus: ChainHealthStatus.healthy,
  totalChainLatencyMs: 100,
  hops: const [],
  timestamp: DateTime.now(),
);

ChainProbeReport _failed(ChainHopMode mode, {int? failureHop = 2}) =>
    ChainProbeReport(
      mode: mode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.failed,
      failureHop: failureHop,
      errorCode: ChainProbeErrorCodes.exitTimeout,
      hops: const [],
      timestamp: DateTime.now(),
    );

ChainProbeReport _degraded(ChainHopMode mode) => ChainProbeReport(
  mode: mode,
  isOverallHealthy: true,
  healthStatus: ChainHealthStatus.degraded,
  totalChainLatencyMs: 140,
  hops: const [],
  timestamp: DateTime.now(),
);

ChainProbeReport _cancelledReport(ChainHopMode mode) => ChainProbeReport(
  mode: mode,
  isOverallHealthy: false,
  healthStatus: ChainHealthStatus.cancelled,
  isCancelled: true,
  hops: const [],
  timestamp: DateTime.now(),
);

void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late ChainProxyManager manager;
  _RecordingExecutor? recorder;
  int healthProbeCalls = 0;

  const chainConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'HK-01',
    hop2Node: 'US-01',
    defaultDialerProxy: 'HK-01',
  );

  ChainFallbackPool poolWithExit(String name, {DateTime? cooldownUntil}) =>
      ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: name,
            role: FallbackCandidateRole.exit,
            cooldownUntil: cooldownUntil,
          ),
        ],
      );

  /// Enables the auto flag WITHOUT starting the timer (logic tests drive
  /// `runChainHealthCheck()` explicitly for determinism).
  Future<void> enableAuto() =>
      manager.updateConfig((c) => c.copyWith(autoFailover: true));

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_auto_failover_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
    recorder = null;
    healthProbeCalls = 0;
    _healthReport = null;
    // ONE counting probe for the whole suite; tests swap `_healthReport`.
    ChainProxyManager.chainProbeOverride = (cfg) {
      healthProbeCalls++;
      return Future.value((_healthReport ?? _healthy)(cfg.hopMode));
    };
    ChainProxyManager.failoverExecutorWrapper = (real) {
      final r = _RecordingExecutor(real);
      recorder = r;
      return r;
    };
    _candidateProbeOverride = null;
    _applyGate = null;

    chainFlapDampenerService.reset();
    manager = ChainProxyManager();
    manager.stopChainHealthCheck();
    await manager.setAutoFailover(false);
    await manager.updateConfig((_) => chainConfig);
    await manager.updateFallbackPool((_) => const ChainFallbackPool());
  });

  tearDown(() async {
    manager.stopChainHealthCheck();
    // Drain any in-flight tick while the stub is still installed, so a late
    // probe can never fall through to the real (core-dependent) probe.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.failoverExecutorWrapper = null;
    _candidateProbeOverride = null;
    _healthReport = null;
    _applyGate = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // ── Timer / startup ───────────────────────────────────────────────────────
  group('A–D. timer lifecycle', () {
    test('A. autoFailover=false → no health-check timer', () async {
      expect(manager.config.autoFailover, isFalse);
      expect(manager.isAutoHealthCheckRunning, isFalse);
    });

    test('B. autoFailover=true starts the timer; false stops it', () async {
      await manager.setAutoFailover(true);
      expect(manager.config.autoFailover, isTrue);
      expect(manager.isAutoHealthCheckRunning, isTrue);

      await manager.setAutoFailover(false);
      expect(manager.config.autoFailover, isFalse);
      expect(manager.isAutoHealthCheckRunning, isFalse);
    });

    test('B2. startChainHealthCheck is idempotent', () async {
      await manager.setAutoFailover(true);
      manager.startChainHealthCheck();
      manager.startChainHealthCheck();
      expect(manager.isAutoHealthCheckRunning, isTrue);
    });

    test('C. enabling does NOT probe immediately (delayed first run)',
        () async {
      ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 5);
      await manager.setAutoFailover(true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        healthProbeCalls,
        0,
        reason: 'startup must not probe before one full interval elapses',
      );
    });

    test('D. the timer fires after the interval', () async {
      ChainProxyManager.autoHealthCheckInterval = const Duration(
        milliseconds: 80,
      );
      await manager.setAutoFailover(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        healthProbeCalls,
        greaterThanOrEqualTo(1),
        reason: 'periodic health check must run',
      );
    });
  });

  // ── Consecutive failure gate ──────────────────────────────────────────────
  group('E–H. consecutive failure gate', () {
    test('E. healthy → no failover, counter stays 0', () async {
      await enableAuto();
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 0);
      expect((recorder?.applyCount ?? 0), 0);
      expect(manager.lastProbeReport, isNotNull); // D1 behaviour intact
    });

    test('F. first failure is transient → no failover', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 1);
      expect(
        (recorder?.applyCount ?? 0),
        0,
        reason: 'single failure must not switch',
      );
    });

    test('G. second consecutive failure allows automatic failover', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;
      _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

      await manager.runChainHealthCheck();
      expect((recorder?.applyCount ?? 0), 0);

      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, greaterThanOrEqualTo(2));
      expect(
        (recorder?.applyCount ?? 0),
        greaterThan(0),
        reason: 'second consecutive failure must trigger failover',
      );
    });

    test('H. failure → healthy clears the counter', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 1);

      _healthReport = null; // healthy
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 0);
    });

    test('I. a redundant start does not reset the failure counter (F-C1)',
        () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));

      // A live loop, started through the same public entry the tests use.
      manager.startChainHealthCheck();
      expect(manager.isAutoHealthCheckRunning, isTrue);

      _healthReport = _failed;
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 1);

      // F-C1: a second start must not cancel-and-restart the live loop. Doing so
      // would reset the consecutive-failure counter and delay detection by a
      // whole failure window.
      manager.startChainHealthCheck();
      expect(
        manager.consecutiveHealthCheckFailures,
        1,
        reason: 'restarting an already-running loop must not reset the counter',
      );
      expect(manager.isAutoHealthCheckRunning, isTrue);
    });
  });

  // ── Condition gate ────────────────────────────────────────────────────────
  group('I–K. report-condition gate', () {
    test('I. degraded → never auto-switches', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _degraded;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 0);
      expect((recorder?.applyCount ?? 0), 0);
    });

    test('J. cancelled report → never auto-switches', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _cancelledReport;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 0);
      expect((recorder?.applyCount ?? 0), 0);
    });

    test('K. failure without failureHop → never auto-switches', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = (mode) => _failed(mode, failureHop: null);

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect((recorder?.applyCount ?? 0), 0);
    });
  });

  // ── Candidate gate ────────────────────────────────────────────────────────
  group('L–N. candidate gate', () {
    test('L. no fallback candidate → no failover', () async {
      await enableAuto();
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect((recorder?.applyCount ?? 0), 0);
    });

    test('M. only a disabled candidate → no failover', () async {
      await enableAuto();
      await manager.updateFallbackPool(
        (_) => ChainFallbackPool(
          exitCandidates: [
            const ChainFallbackCandidate(
              nodeName: 'US-FB-01',
              role: FallbackCandidateRole.exit,
              enabled: false,
            ),
          ],
        ),
      );
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect((recorder?.applyCount ?? 0), 0);
    });

    test('N. candidate in cooldown → no failover', () async {
      await enableAuto();
      await manager.updateFallbackPool(
        (_) => poolWithExit(
          'US-FB-01',
          cooldownUntil: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect((recorder?.applyCount ?? 0), 0);
    });
  });

  // ── Dampener ──────────────────────────────────────────────────────────────
  test('O+P. dampener suppression blocks the automatic trigger '
      '(proves bypassDampening:false)', () async {
    await enableAuto();
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    _healthReport = _failed;

    // Drive the dampener into suppression (penaltyPerFlap 1000 >= threshold 2000).
    chainFlapDampenerService.recordFlap(
      role: FallbackCandidateRole.exit,
      fromNode: 'A',
      toNode: 'B',
    );
    chainFlapDampenerService.recordFlap(
      role: FallbackCandidateRole.exit,
      fromNode: 'B',
      toNode: 'C',
    );
    expect(chainFlapDampenerService.evaluate().isDampened, isTrue);

    await manager.runChainHealthCheck();
    await manager.runChainHealthCheck();
    expect(
      (recorder?.applyCount ?? 0),
      0,
      reason: 'a suppressed dampener must block automatic failover',
    );
  });

  // ── Automatic failover execution ──────────────────────────────────────────
  group('Q–S. automatic failover execution', () {
    test('Q. apply + candidate probe healthy → commit', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;
      _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect((recorder?.applyCount ?? 0), greaterThan(0));
      expect((recorder?.commitCount ?? 0), 1);
      expect((recorder?.rollbackCount ?? 0), 0);

      final persisted = jsonDecode(File(configPath).readAsStringSync())
          as Map<String, dynamic>;
      expect(persisted['autoFailover'], isTrue);
    });

    test('R+S. candidate probe failure → rollback, no config persisted',
        () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;
      _candidateProbeOverride = (cfg) => _failed(cfg.hopMode);
      final configBefore = File(configPath).readAsStringSync();

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect((recorder?.applyCount ?? 0), greaterThan(0));
      expect((recorder?.rollbackCount ?? 0), greaterThan(0));
      expect((recorder?.commitCount ?? 0), 0);
      expect(
        File(configPath).readAsStringSync(),
        configBefore,
        reason: 'a failed candidate must never be persisted',
      );
    });
  });

  // ── Loop prevention / single-flight / guards ──────────────────────────────
  test('T. failover-internal candidate probe never re-enters the health check',
      () async {
    await enableAuto();
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    _healthReport = _failed;
    _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

    await manager.runChainHealthCheck(); // consecutive = 1
    final healthCallsBeforeFailover = healthProbeCalls;
    await manager.runChainHealthCheck(); // triggers the failover

    expect((recorder?.probeCount ?? 0), greaterThan(0)); // candidate probes
    expect(
      healthProbeCalls - healthCallsBeforeFailover,
      1,
      reason: 'exactly one health probe — the failover must not feed back',
    );
  });

  test('U. single-flight: health check is skipped while failing over', () async {
    await enableAuto();
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    _healthReport = _failed;
    _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

    final gate = Completer<void>();
    _applyGate = gate;

    await manager.runChainHealthCheck(); // consecutive = 1, no failover yet
    final pending = manager.runChainHealthCheck(); // triggers; apply blocks
    // runChainHealthCheck is async, so let the probe resolve before asserting.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(manager.isFailingOver, isTrue);

    final callsBefore = healthProbeCalls;
    await manager.runChainHealthCheck(); // must be a no-op
    expect(
      healthProbeCalls,
      callsBefore,
      reason: 'no probe while a failover is in flight',
    );

    gate.complete();
    await pending;
  });

  test('V. manual + automatic race → only one session runs', () async {
    await enableAuto();
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

    final gate = Completer<void>();
    _applyGate = gate;

    final manual = manager.triggerAutoFailover(
      triggerReason: '用户手动触发故障转移',
      bypassDampening: true,
      initialFailureReport: _failed(ChainHopMode.twoHop),
    );
    expect(manager.isFailingOver, isTrue);

    final callsBefore = healthProbeCalls;
    await manager.runChainHealthCheck();
    expect(healthProbeCalls, callsBefore);

    gate.complete();
    await manual;
  });

  test('W. core not running → no probe, no failover', () async {
    await enableAuto();
    await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
    ChainProxyManager.coreRunningOverride = false;
    _healthReport = _failed;

    await manager.runChainHealthCheck();
    await manager.runChainHealthCheck();
    expect(healthProbeCalls, 0);
    expect((recorder?.applyCount ?? 0), 0);
  });

  // ── Persistence ───────────────────────────────────────────────────────────
  group('X–Y. autoFailover persistence', () {
    test('X. autoFailover persists and restores', () async {
      await manager.setAutoFailover(true);
      final raw = jsonDecode(File(configPath).readAsStringSync())
          as Map<String, dynamic>;
      expect(raw['autoFailover'], isTrue);

      final restored = ChainProxyConfig.fromJson(raw);
      expect(restored.autoFailover, isTrue);

      await manager.setAutoFailover(false);
      final raw2 = jsonDecode(File(configPath).readAsStringSync())
          as Map<String, dynamic>;
      expect(raw2['autoFailover'], isFalse);
    });

    test('Y. legacy JSON without autoFailover → false', () {
      final legacy = <String, dynamic>{
        'enable': true,
        'hop1Node': 'HK-01',
        'hop2Node': 'US-01',
      };
      expect(ChainProxyConfig.fromJson(legacy).autoFailover, isFalse);

      // Non-bool / malformed values must not throw and must default to false.
      final weird = <String, dynamic>{'autoFailover': 'yes'};
      expect(ChainProxyConfig.fromJson(weird).autoFailover, isFalse);
    });
  });

  // ── Regression ────────────────────────────────────────────────────────────
  group('Z–AB. regression protection', () {
    test('Z. automatic failover never writes chain_fallback_pool.json',
        () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      final poolBefore = File(poolPath).readAsStringSync();

      _healthReport = _failed;
      _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);
      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect(File(poolPath).readAsStringSync(), poolBefore);
    });

    test('AA. D1: probeCurrentChain still records lastProbeReport, no switch',
        () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      await manager.runChainHealthCheck(); // healthy
      expect(manager.lastProbeReport, isNotNull);
      expect(manager.isProbingChain, isFalse);
      expect((recorder?.applyCount ?? 0), 0);
    });

    test('AB. D1/D2: setFallbackPool stays memory-only', () async {
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
  });

  // ── P1.5-A: low-noise auto-failover skip diagnosis ────────────────────────
  //
  // The *state* is asserted through the read-only `autoFailoverSkipDiagnosis`
  // getter; the *emission count* through a `debugPrint` override —
  // `commonPrint.log` routes through `debugPrint` in tests because
  // `globalState.isInit` is false there. The override is installed for this
  // group only and restored in `tearDown`, so the other tests in this file keep
  // the real `debugPrint`.
  //
  // Trigger priority is decided by nesting depth in `_maybeAutoFailover`, so at
  // most ONE reason is reported per pass:
  //   `failureHop 未提供`  >  `无可用候选`  >  `抖动抑制中`
  group('P1.5-A. auto-failover skip diagnosis (low-noise)', () {
    late DebugPrintCallback originalDebugPrint;
    late List<String> emitted;

    setUp(() {
      emitted = <String>[];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        // Count ONLY the diagnosis lines — the manager logs other things too
        // (e.g. a failover failure), and those must not pollute the count.
        if (message != null && message.contains('auto failover skip')) {
          emitted.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    int skippedLogs() =>
        emitted.where((m) => m.contains('auto failover skipped')).length;
    int clearedLogs() =>
        emitted.where((m) => m.contains('auto failover skip cleared')).length;

    /// A pool whose only exit candidate is disabled — the same shape test `M`
    /// uses, so the pool is non-empty while the *eligible* candidate list is.
    ChainFallbackPool poolWithDisabledExit() => const ChainFallbackPool(
      exitCandidates: [
        ChainFallbackCandidate(
          nodeName: 'US-FB-01',
          role: FallbackCandidateRole.exit,
          enabled: false,
        ),
      ],
    );

    test('T1. exhausted candidate pool → diagnosed once, switching unchanged',
        () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithDisabledExit());
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect(manager.autoFailoverSkipDiagnosis, contains('无可用候选'));
      expect(manager.autoFailoverSkipDiagnosis, contains('exit'));
      expect(recorder?.applyCount ?? 0, 0, reason: 'switching must not change');
      expect(skippedLogs(), 1, reason: 'one diagnosis, not one per tick');
    });

    test('T2. a persistent condition is not re-logged on every tick', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithDisabledExit());
      _healthReport = _failed;

      for (var i = 0; i < 4; i++) {
        await manager.runChainHealthCheck();
      }

      expect(skippedLogs(), 1);
      expect(manager.autoFailoverSkipDiagnosis, contains('无可用候选'));
    });

    test('T3. failureHop == null → its own diagnosis (outranks the pool gate)',
        () async {
      await enableAuto();
      // A VALID candidate is present, so if the failureHop gate did not fire
      // first we would see the candidate diagnosis instead.
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = (mode) => _failed(mode, failureHop: null);

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect(manager.autoFailoverSkipDiagnosis, contains('failureHop 未提供'));
      expect(manager.autoFailoverSkipDiagnosis, isNot(contains('无可用候选')));
      expect(recorder?.applyCount ?? 0, 0);
    });

    test('T4. dampened → its own diagnosis', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));

      // Dampen the singleton through its own public API. A very large
      // `penaltyPerFlap` keeps the verdict stable against the time-based decay
      // (`halfLife`), so this test is deliberately NOT timing-sensitive — unlike
      // the 2-flap-equals-threshold pattern behind the known flaky suite.
      chainFlapDampenerService.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'US-01',
        toNode: 'US-FB-01',
        policy: const ChainFlapDampeningPolicy(penaltyPerFlap: 100000.0),
      );

      _healthReport = _failed;
      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect(manager.autoFailoverSkipDiagnosis, contains('抖动抑制中'));
      expect(recorder?.applyCount ?? 0, 0);
    });

    test('T5. healthy clears the diagnosis once, and it can re-arm', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithDisabledExit());
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect(manager.autoFailoverSkipDiagnosis, isNotNull);

      _healthReport = _healthy;
      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();

      expect(manager.autoFailoverSkipDiagnosis, isNull);
      expect(clearedLogs(), 1, reason: 'cleared is logged once, not per tick');

      // Re-arm: the same condition is reported again after a recovery.
      _healthReport = _failed;
      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect(manager.autoFailoverSkipDiagnosis, contains('无可用候选'));
      expect(skippedLogs(), 2);
    });

    test('T6. degraded / cancelled are NOT treated as recovery', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithDisabledExit());
      _healthReport = _failed;

      await manager.runChainHealthCheck();
      await manager.runChainHealthCheck();
      expect(manager.autoFailoverSkipDiagnosis, contains('无可用候选'));

      _healthReport = _degraded;
      await manager.runChainHealthCheck();
      expect(
        manager.autoFailoverSkipDiagnosis,
        contains('无可用候选'),
        reason: 'a still-impaired chain does not clear the skip reason',
      );

      _healthReport = _cancelledReport;
      await manager.runChainHealthCheck();
      expect(
        manager.autoFailoverSkipDiagnosis,
        contains('无可用候选'),
        reason: 'a cancelled probe proves nothing about recovery',
      );

      expect(clearedLogs(), 0);
    });
  });

  // ── F-B2 / H3: dispose() must not let a resumed tick trigger failover ──────
  //
  // H4 proves a post-dispose tick does not *start a probe*; that alone does not
  // prove it cannot *trigger failover*. This test parks the tick PAST the
  // `_isCoreReady()` re-check — inside the health probe, a real async boundary —
  // then disposes and releases the probe. The tick must bail at the
  // `_probeGeneration != probeGeneration` re-check and never reach
  // `_maybeAutoFailover` → `triggerAutoFailover`.
  //
  // The arrangement (failing report ×2 + a valid, enabled exit candidate) is
  // identical to test G, which proves a tick that *completes* DOES apply
  // failover (`applyCount > 0`). So `applyCount == 0` here is a real result,
  // not an accident of an inert setup.
  //
  // MUST RUN LAST: `dispose()` tears down the process-wide singleton, so no
  // later test could use it.
  group('F-B2 / H3 — dispose() blocks the auto-failover path', () {
    test('a tick resuming after dispose does not trigger failover', () async {
      await enableAuto();
      await manager.updateFallbackPool((_) => poolWithExit('US-FB-01'));
      _healthReport = _failed;
      _candidateProbeOverride = (cfg) => _healthy(cfg.hopMode);

      // First tick completes normally: the counter advances to 1 and nothing
      // switches yet — the exact "armed" state test G triggers from.
      await manager.runChainHealthCheck();
      expect(manager.consecutiveHealthCheckFailures, 1);
      expect(recorder?.applyCount ?? 0, 0);

      // Park the SECOND tick inside the health probe. `probeStarted` fires the
      // instant the override is invoked, i.e. after the tick has already passed
      // its entry re-check — so this isolates the generation-bump guard, not
      // H4's `_disposed` re-check.
      final probeStarted = Completer<void>();
      final probeGate = Completer<ChainProbeReport>();
      ChainProxyManager.chainProbeOverride = (cfg) {
        if (!probeStarted.isCompleted) probeStarted.complete();
        return probeGate.future;
      };

      final tick = manager.runChainHealthCheck();
      await probeStarted.future; // deterministic: the tick is now parked
      manager.dispose();
      if (!probeGate.isCompleted) {
        probeGate.complete(_failed(ChainHopMode.twoHop));
      }
      await tick;

      expect(
        recorder?.applyCount ?? 0,
        0,
        reason: 'a tick that outlives dispose() must not trigger failover',
      );
    });
  });
}
