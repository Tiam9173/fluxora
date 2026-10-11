import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';

/// P1.3-C4-Step5 — `nodeLatency` **write-condition matrix** (read-only w.r.t.
/// production code).
///
/// This file **locks down the CURRENT write policy**; it does not attempt to
/// change it. `test/services/chain_failover_node_latency_write_test.dart` (A2)
/// already fixed "a failed probe never writes, even when the hop latency was
/// measured" — this matrix continues that exact semantics across every
/// role × outcome cell and records *why* each cell skips.
///
/// ── Two different things, never to be conflated ───────────────────────────
///   · **code-path coverage**  — is each branch driven?      → THIS FILE proves it.
///   · **real-world write rate** — how many candidates in a real run end up with
///     a valid `nodeLatency`? → **NOT provable here** (needs live telemetry).
///     This matrix is a *specification of the policy*, not a coverage percentage.
///
/// ── Skip classification (used in every test name) ─────────────────────────
///   ① no valid measurement   — cancelled / config-invalid / the hop itself timed out
///   ② measured but discarded — the chain-level gate (`candidateHealthy`) dropped
///                              a per-node observation that WAS measured
///   ③ no matching hop        — the report carries no hop for this candidate
void main() {
  group('P1.3-C4-Step5 — nodeLatency write-condition matrix', () {
    setUp(() {
      // The service defaults to the process-wide dampener singleton
      // (`chain_failover_service.dart:168`); without this reset flap penalty
      // leaks between cases and silently suppresses candidate selection.
      chainFlapDampenerService.reset();
    });

    const candidate = 'Cand-01';
    const candidateLatencyMs = 42;
    const otherHopLatencyMs = 80;
    const totalChainLatencyMs = 120;

    const twoHop = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi-01',
    );
    const threeHop = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'JP-Relay-01',
      hop3Node: 'US-Exit-01',
    );

    /// `relay` only exists in 3-hop mode (`chain_failover_service.dart:535`
    /// skips a relay candidate in 2-hop mode).
    ChainProxyConfig configFor(FallbackCandidateRole role) =>
        role == FallbackCandidateRole.relay ? threeHop : twoHop;

    ChainFallbackPool poolFor(FallbackCandidateRole role) {
      const c = ChainFallbackCandidate(
        nodeName: candidate,
        role: FallbackCandidateRole.exit,
        health: ChainHealthStatus.healthy,
      );
      return switch (role) {
        FallbackCandidateRole.entry => const ChainFallbackPool(
          entryCandidates: [c],
        ),
        FallbackCandidateRole.relay => const ChainFallbackPool(
          relayCandidates: [c],
        ),
        FallbackCandidateRole.exit => const ChainFallbackPool(
          exitCandidates: [c],
        ),
      };
    }

    /// Builds the hops of the probed chain.
    ///
    /// For a **failure** outcome the break is placed so that it reproduces the
    /// real geometry:
    ///   · candidate is the LAST hop  → its own hop breaks ⇒ no measurement (①)
    ///   · candidate is an earlier hop → a LATER hop breaks ⇒ the candidate's own
    ///     latency WAS measured and is present in the report (②)
    List<HopProbeState> hopsFor({
      required ChainProxyConfig cfg,
      required _Outcome outcome,
      required bool candidateBreaks,
    }) {
      final three = cfg.hopMode == ChainHopMode.threeHop;
      final names = three
          ? [cfg.hop1Node, cfg.hop2Node, cfg.hop3Node]
          : [cfg.hop1Node, cfg.hop2Node];
      final roles = three
          ? [HopRole.hop1Entry, HopRole.hop2Relay, HopRole.hop3Exit]
          : [HopRole.hop1Entry, HopRole.hop2Exit];

      final broken = outcome == _Outcome.failed || outcome == _Outcome.timeout;
      final result = <HopProbeState>[];
      for (var i = 0; i < names.length; i++) {
        final isCandidate = names[i] == candidate;
        final thisBroken =
            broken && (candidateBreaks ? isCandidate : i == names.length - 1);
        result.add(
          HopProbeState(
            hopIndex: i + 1,
            role: roles[i],
            nodeName: names[i],
            nodeAddress: names[i],
            status: thisBroken
                ? (outcome == _Outcome.timeout
                      ? HopProbeStatus.timeout
                      : HopProbeStatus.failed)
                : HopProbeStatus.healthy,
            latencyMs: thisBroken
                ? null
                : (isCandidate ? candidateLatencyMs : otherHopLatencyMs),
            testedAt: DateTime.now(),
          ),
        );
      }
      return result;
    }

    ChainProbeReport reportFor({
      required ChainProxyConfig cfg,
      required _Outcome outcome,
      required bool candidateBreaks,
    }) {
      if (outcome == _Outcome.cancelled) {
        // `hops: const []` — nothing was measured.
        return ChainProbeReport.cancelled(
          mode: cfg.hopMode,
          timestamp: DateTime.now(),
        );
      }
      return ChainProbeReport(
        mode: cfg.hopMode,
        isOverallHealthy: outcome == _Outcome.healthy,
        healthStatus: switch (outcome) {
          _Outcome.healthy => ChainHealthStatus.healthy,
          _Outcome.degraded => ChainHealthStatus.degraded,
          _ => ChainHealthStatus.failed,
        },
        totalChainLatencyMs: totalChainLatencyMs,
        hops: hopsFor(
          cfg: cfg,
          outcome: outcome,
          candidateBreaks: candidateBreaks,
        ),
        errorCode: outcome == _Outcome.degraded
            ? ChainProbeErrorCodes.ipApiUnavailable
            : null,
        timestamp: DateTime.now(),
      );
    }

    /// Runs one cell through the real public entry point and returns the pool
    /// snapshots observed via `onPoolUpdated` (empty ⇒ the write site was never
    /// reached).
    Future<List<ChainFallbackPool>> runCase({
      required FallbackCandidateRole role,
      required _Outcome outcome,
      required bool candidateBreaks,
      Future<void> Function(ChainProxyConfig, CancelToken?)? onApply,
      List<String>? availableProxyNames,
      CancelToken? cancelToken,
    }) async {
      final cfg = configFor(role);
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: onApply ?? (c, t) async {},
        onProbe: (c, t) async => reportFor(
          cfg: c,
          outcome: outcome,
          candidateBreaks: candidateBreaks,
        ),
        onRollback: (c, t) async {},
        onCommit: (c) async {},
      );

      await ChainFailoverService(
        retryService: _MockRetryService(
          (config, _) async => _failingInitialReport(config.hopMode),
        ),
      ).executeFailover(
        currentConfig: cfg,
        fallbackPool: poolFor(role),
        targetRole: role,
        availableProxyNames: availableProxyNames,
        cancelToken: cancelToken,
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );
      return captured;
    }

    /// The candidate as observed in the latest pool snapshot, looked up by the
    /// list its role actually lives in (`entryCandidates` / `relayCandidates` /
    /// `exitCandidates` — `chain_fallback_pool.dart:241/244/247`).
    ChainFallbackCandidate? observedCandidate(
      List<ChainFallbackPool> captured,
    ) {
      if (captured.isEmpty) return null;
      final pool = captured.last;
      if (pool.entryCandidates.isNotEmpty) return pool.entryCandidates.first;
      if (pool.relayCandidates.isNotEmpty) return pool.relayCandidates.first;
      return pool.exitCandidates.first;
    }

    /// `null` when the write site was never reached (cancellation / early exit).
    LatencyState? observedNodeLatency(List<ChainFallbackPool> captured) =>
        observedCandidate(captured)?.nodeLatency;

    // ══════════════════════════════════════════════════════════════════════
    // Matrix: 3 roles × 5 outcomes
    // ══════════════════════════════════════════════════════════════════════
    for (final cell in _matrix) {
      test(
        '${cell.role.name} × ${cell.outcome.name} → '
        '${cell.writes ? "WRITE" : "SKIP"} (${cell.why})',
        () async {
          final captured = await runCase(
            role: cell.role,
            outcome: cell.outcome,
            candidateBreaks: cell.candidateBreaks,
          );

          if (cell.writes) {
            final nodeLatency = observedNodeLatency(captured);
            expect(nodeLatency, isNotNull, reason: cell.why);
            expect(nodeLatency!.latencyMs, candidateLatencyMs);
            expect(nodeLatency.scope, LatencyScope.node);
            expect(nodeLatency.source, LatencySource.failover);
            expect(
              nodeLatency.fingerprint,
              networkFingerprintProvider.getCurrentFingerprint(),
            );
            // Chain scope keeps working, and the shim is untouched by Step5.
            final observed = observedCandidate(captured);
            expect(observed, isNotNull);
            expect(observed!.chainLatency?.latencyMs, totalChainLatencyMs);
            expect(observed.latencyMs, totalChainLatencyMs);
          } else {
            expect(observedNodeLatency(captured), isNull, reason: cell.why);
          }
        },
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // Supplementary: the failure stages the matrix cannot express
    // ══════════════════════════════════════════════════════════════════════
    test(
      'S1. topology conflict → SKIP (① rejected before any probe)',
      () async {
        // ── Observed behaviour (differs from the plan's assumption) ──────────
        // Passing an `availableProxyNames` list that does NOT cover the config's
        // hops makes `selectCandidates` reject the candidate with
        // `TOPOLOGY_CONFLICT` **at selection time**, before the in-loop topology
        // gate at `chain_failover_service.dart:567`/`:586` is ever reached.
        //
        // Observed log:
        //   "no eligible [exit] candidate (... availableProxyNames=[Cand-01]):
        //    (未配置任何备用节点或全不符合要求) 排除原因摘要: Cand-01(TOPOLOGY_CONFLICT)"
        //
        // ⇒ the pool is never updated, so nothing can be written. This test pins
        //   that outcome; reaching `:586` itself is **not achievable through the
        //   public seam** (see the round's report).
        final captured = await runCase(
          role: FallbackCandidateRole.exit,
          outcome: _Outcome.healthy,
          candidateBreaks: false,
          availableProxyNames: const [candidate],
        );
        expect(observedNodeLatency(captured), isNull);
      },
    );

    test('S2. apply/reload failure → SKIP (① no probe result was accepted)',
        () async {
      final captured = await runCase(
        role: FallbackCandidateRole.exit,
        outcome: _Outcome.healthy,
        candidateBreaks: false,
        onApply: (c, t) async => throw Exception('apply failed'),
      );
      expect(observedNodeLatency(captured), isNull);
    });

    test('S3. probe threw (catch at :787, hops empty) → SKIP (①)', () async {
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (c, t) async {},
        onProbe: (c, t) async => throw Exception('probe blew up'),
        onRollback: (c, t) async {},
        onCommit: (c) async {},
      );
      await ChainFailoverService(
        retryService: _MockRetryService(
          (config, _) async => _failingInitialReport(config.hopMode),
        ),
      ).executeFailover(
        currentConfig: twoHop,
        fallbackPool: poolFor(FallbackCandidateRole.exit),
        targetRole: FallbackCandidateRole.exit,
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );
      expect(observedNodeLatency(captured), isNull);
    });

    test('S4. pre-cancelled token → SKIP (① nothing ran)', () async {
      final token = CancelToken()..cancel();
      final captured = await runCase(
        role: FallbackCandidateRole.exit,
        outcome: _Outcome.healthy,
        candidateBreaks: false,
        cancelToken: token,
      );
      expect(observedNodeLatency(captured), isNull);
    });

    test('S5. probe returned a cancelled report → SKIP (①, :804 early return)',
        () async {
      final captured = await runCase(
        role: FallbackCandidateRole.exit,
        outcome: _Outcome.cancelled,
        candidateBreaks: false,
      );
      expect(observedNodeLatency(captured), isNull);
    });

    test('S6. no matching hop in the report → SKIP (③ no per-node evidence)',
        () async {
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (c, t) async {},
        onProbe: (c, t) async => ChainProbeReport(
          mode: c.hopMode,
          isOverallHealthy: true,
          healthStatus: ChainHealthStatus.healthy,
          totalChainLatencyMs: totalChainLatencyMs,
          hops: [
            // A hop for a DIFFERENT node — the candidate itself is absent.
            HopProbeState(
              hopIndex: 2,
              role: HopRole.hop2Exit,
              nodeName: 'Not-The-Candidate',
              nodeAddress: 'Not-The-Candidate',
              status: HopProbeStatus.healthy,
              latencyMs: candidateLatencyMs,
              testedAt: DateTime.now(),
            ),
          ],
          timestamp: DateTime.now(),
        ),
        onRollback: (c, t) async {},
        onCommit: (c) async {},
      );
      await ChainFailoverService(
        retryService: _MockRetryService(
          (config, _) async => _failingInitialReport(config.hopMode),
        ),
      ).executeFailover(
        currentConfig: twoHop,
        fallbackPool: poolFor(FallbackCandidateRole.exit),
        targetRole: FallbackCandidateRole.exit,
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );
      expect(observedNodeLatency(captured), isNull);
    });
  });
}

enum _Outcome { healthy, degraded, failed, timeout, cancelled }

class _Cell {
  final FallbackCandidateRole role;
  final _Outcome outcome;
  final bool writes;
  final String why;
  final bool candidateBreaks;

  const _Cell({
    required this.role,
    required this.outcome,
    required this.writes,
    required this.why,
    this.candidateBreaks = false,
  });
}

/// 3 roles × 5 outcomes. `candidateBreaks` distinguishes the two failure shapes:
/// the candidate's own hop broke (no measurement) vs a later hop broke (the
/// candidate WAS measured but the chain-level gate discards it).
const _matrix = <_Cell>[
  // ── healthy: all hops measured, chain healthy ────────────────────────────
  _Cell(
    role: FallbackCandidateRole.entry,
    outcome: _Outcome.healthy,
    writes: true,
    why: 'success path (:945)',
  ),
  _Cell(
    role: FallbackCandidateRole.relay,
    outcome: _Outcome.healthy,
    writes: true,
    why: 'success path (:945)',
  ),
  _Cell(
    role: FallbackCandidateRole.exit,
    outcome: _Outcome.healthy,
    writes: true,
    why: 'success path (:945)',
  ),
  // ── degraded: transport fine, exit IP unobservable ───────────────────────
  _Cell(
    role: FallbackCandidateRole.entry,
    outcome: _Outcome.degraded,
    writes: true,
    why: 'candidateHealthy includes degraded (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.relay,
    outcome: _Outcome.degraded,
    writes: true,
    why: 'candidateHealthy includes degraded (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.exit,
    outcome: _Outcome.degraded,
    writes: true,
    why: 'candidateHealthy includes degraded (:849)',
  ),
  // ── failed: ② for earlier hops, ① for the exit itself ────────────────────
  _Cell(
    role: FallbackCandidateRole.entry,
    outcome: _Outcome.failed,
    writes: false,
    why: '② measured but discarded — chain-level gate (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.relay,
    outcome: _Outcome.failed,
    writes: false,
    why: '② measured but discarded — chain-level gate (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.exit,
    outcome: _Outcome.failed,
    writes: false,
    why: '① no valid measurement — its own hop broke',
    candidateBreaks: true,
  ),
  // ── timeout: same shape, later hop timed out ─────────────────────────────
  _Cell(
    role: FallbackCandidateRole.entry,
    outcome: _Outcome.timeout,
    writes: false,
    why: '② measured but discarded — chain-level gate (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.relay,
    outcome: _Outcome.timeout,
    writes: false,
    why: '② measured but discarded — chain-level gate (:849)',
  ),
  _Cell(
    role: FallbackCandidateRole.exit,
    outcome: _Outcome.timeout,
    writes: false,
    why: '① no valid measurement — its own hop timed out',
    candidateBreaks: true,
  ),
  // ── cancelled: hops are empty ⇒ nothing was measured ─────────────────────
  _Cell(
    role: FallbackCandidateRole.entry,
    outcome: _Outcome.cancelled,
    writes: false,
    why: '① no valid measurement — hops: const [] (:804)',
  ),
  _Cell(
    role: FallbackCandidateRole.relay,
    outcome: _Outcome.cancelled,
    writes: false,
    why: '① no valid measurement — hops: const [] (:804)',
  ),
  _Cell(
    role: FallbackCandidateRole.exit,
    outcome: _Outcome.cancelled,
    writes: false,
    why: '① no valid measurement — hops: const [] (:804)',
  ),
];

ChainProbeReport _failingInitialReport(ChainHopMode mode) {
  return ChainProbeReport(
    mode: mode,
    isOverallHealthy: false,
    healthStatus: ChainHealthStatus.failed,
    failureHop: 2,
    errorCode: ChainProbeErrorCodes.exitTimeout,
    rootCauseAnalysis: '出口节点握手超时',
    hops: const [],
    timestamp: DateTime.now(),
  );
}

class _MockRetryService implements IChainRetryService {
  final Future<ChainProbeReport> Function(
    ChainProxyConfig config,
    CancelToken? cancelToken,
  )
  onProbe;

  _MockRetryService(this.onProbe);

  @override
  Future<ChainProbeReport> probeWithRetry({
    required ChainProxyConfig config,
    ChainRetryPolicy policy = const ChainRetryPolicy(),
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
    void Function(ChainRetryProgress retryProgress)? onRetryProgress,
  }) {
    return onProbe(config, cancelToken);
  }
}
