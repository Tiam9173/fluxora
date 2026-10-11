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

/// P1.3-C4-Step5 — `nodeLatency` **production write path**.
///
/// Drives the real public entry point
/// `executeFailover(executor:, onPoolUpdated:)` so the assertions land on
/// `_updateCandidateStats`'s actual write
/// (`chain_failover_service.dart:1227-1236`) — **not** on a hand-built
/// `LatencyState`.
///
/// Why this file exists: every pre-existing failover test returns reports with
/// `hops: const []` (`chain_failover_service_test.dart:40` / `:51` / `:70`), so
/// `matchedHop` is always `null` and `nodeLatency` is **never** written. This is
/// the first coverage of that path, and it must pass *before* the UI is switched
/// over to `nodeLatency` (Q5).
///
/// Contract under test:
///   · success  → `nodeLatency` written with scope=node / source=failover /
///                the live fingerprint, carrying the candidate's OWN hop latency
///   · failure  → not written (never fabricated)
///   · timeout  → not written (a `null` hop latency must not be invented)
///   · cancel   → not written
void main() {
  group('P1.3-C4-Step5 — nodeLatency production write path', () {
    setUp(() {
      // The failover service defaults to the process-wide dampener singleton
      // (`chain_failover_service.dart:168`), so flap penalty would otherwise leak
      // from one test into the next and silently suppress candidate selection —
      // the same reset the pre-existing failover suite performs.
      chainFlapDampenerService.reset();
    });

    const twoHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi-01',
    );
    const candidateName = 'US-Resi-02';

    /// The initial chain must FAIL so the failover stage actually runs.
    ChainProbeReport failingInitialReport(ChainHopMode mode) {
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

    /// A report whose `hops` **contain the candidate**, which is what makes
    /// `matchedHop` resolvable and the node-scope write possible.
    ChainProbeReport reportWithCandidateHop({
      required ChainHopMode mode,
      required ChainHealthStatus health,
      required String candidateNode,
      int? nodeLatencyMs,
      DateTime? testedAt,
      int totalChainLatencyMs = 120,
    }) {
      return ChainProbeReport(
        mode: mode,
        isOverallHealthy: health == ChainHealthStatus.healthy,
        healthStatus: health,
        totalChainLatencyMs: totalChainLatencyMs,
        hops: [
          HopProbeState(
            hopIndex: 2,
            role: HopRole.hop2Exit,
            nodeName: candidateNode,
            nodeAddress: candidateNode,
            status: HopProbeStatus.healthy,
            latencyMs: nodeLatencyMs,
            testedAt: testedAt ?? DateTime.now(),
          ),
        ],
        timestamp: DateTime.now(),
      );
    }

    ChainFallbackPool poolWithCandidate() {
      return const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: candidateName,
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
          ),
        ],
      );
    }

    ChainFailoverService serviceWithFailingInitialChain() {
      return ChainFailoverService(
        retryService: _MockRetryService(
          (config, _) async => failingInitialReport(config.hopMode),
        ),
      );
    }

    test(
      'A1. successful probe writes nodeLatency (scope=node, source=failover, live fingerprint)',
      () async {
        final captured = <ChainFallbackPool>[];
        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {},
          onProbe: (cfg, token) async => reportWithCandidateHop(
            mode: cfg.hopMode,
            health: ChainHealthStatus.healthy,
            candidateNode: cfg.hop2Node,
            nodeLatencyMs: 42,
          ),
          onRollback: (cfg, token) async {},
          onCommit: (cfg) async {},
        );

        await serviceWithFailingInitialChain().executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: poolWithCandidate(),
          executor: executor,
          onPoolUpdated: (updated) => captured.add(updated),
        );

        expect(captured, isNotEmpty, reason: 'the pool must have been updated');
        final candidate = captured.last.exitCandidates.first;

        // The node-scope observation, carrying the candidate's OWN hop latency.
        expect(candidate.nodeLatency, isNotNull);
        expect(candidate.nodeLatency!.latencyMs, 42);
        expect(candidate.nodeLatency!.scope, LatencyScope.node);
        expect(candidate.nodeLatency!.source, LatencySource.failover);
        expect(
          candidate.nodeLatency!.fingerprint,
          networkFingerprintProvider.getCurrentFingerprint(),
        );

        // The chain-scope observation is written in the same pass and must be
        // unaffected by Step5 (it is the shim's provenance).
        expect(candidate.chainLatency, isNotNull);
        expect(candidate.chainLatency!.latencyMs, 120);
        expect(candidate.chainLatency!.scope, LatencyScope.chain);

        // The legacy shim is still written (Step5 keeps it).
        expect(candidate.latencyMs, 120);
      },
    );

    test('A2. failed probe does NOT write nodeLatency (never fabricated)',
        () async {
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => reportWithCandidateHop(
          mode: cfg.hopMode,
          health: ChainHealthStatus.failed,
          candidateNode: cfg.hop2Node,
          nodeLatencyMs: 42,
        ),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      await serviceWithFailingInitialChain().executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: poolWithCandidate(),
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );

      expect(captured, isNotEmpty);
      expect(
        captured.last.exitCandidates.first.nodeLatency,
        isNull,
        reason: 'an unhealthy candidate must not get a node-scope observation',
      );
    });

    test('A3. timed-out hop latency does NOT write nodeLatency', () async {
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => reportWithCandidateHop(
          mode: cfg.hopMode,
          health: ChainHealthStatus.healthy,
          candidateNode: cfg.hop2Node,
          nodeLatencyMs: null, // ← the hop's own delay test timed out
        ),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      await serviceWithFailingInitialChain().executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: poolWithCandidate(),
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );

      expect(captured, isNotEmpty);
      expect(
        captured.last.exitCandidates.first.nodeLatency,
        isNull,
        reason: 'a null hop latency must not be invented into a node latency',
      );
      // …while the chain-scope write still happens for this successful probe.
      expect(captured.last.exitCandidates.first.chainLatency, isNotNull);
    });

    test('A4. cancelled probe does NOT write nodeLatency', () async {
      final cancelToken = CancelToken();
      final captured = <ChainFallbackPool>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async {
          cancelToken.cancel();
          return ChainProbeReport.cancelled(
            mode: cfg.hopMode,
            timestamp: DateTime.now(),
          );
        },
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      await serviceWithFailingInitialChain().executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: poolWithCandidate(),
        cancelToken: cancelToken,
        executor: executor,
        onPoolUpdated: (updated) => captured.add(updated),
      );

      // Either the pool was never updated (cancellation short-circuits before the
      // write site) or it was — in both cases no node-scope value may appear.
      final observedNodeLatency = captured.isEmpty
          ? null
          : captured.last.exitCandidates.first.nodeLatency;
      expect(observedNodeLatency, isNull);
    });
  });
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
