import 'package:fluxora/models/chain_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/services/chain_probe_service.dart';

void main() {
  group('Phase 5.9-E.1.1 — Adaptive Ranking Adapter & ViewModel', () {
    test('1. Score projection: Higher score is ranked first', () {
      final a = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        score: const ChainScore(
            totalScore: 90.0,
            confidence: 0.9,
            reliabilityScore: 90.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      final b = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeB', type: 'SS'),
        nodeName: 'NodeB',
        score: const ChainScore(
            totalScore: 70.0,
            confidence: 0.7,
            reliabilityScore: 70.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );

      final list = [b, a]..sort((x, y) => x.compareTo(y));
      expect(list.first.nodeName, 'NodeA');
    });

    test('2. Same score tie-breaker: Alphabetical fallback', () {
      final a = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeZ', type: 'SS'),
        nodeName: 'NodeZ',
        score: const ChainScore(
            totalScore: 80.0,
            confidence: 0.8,
            reliabilityScore: 80.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      final b = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        score: const ChainScore(
            totalScore: 80.0,
            confidence: 0.8,
            reliabilityScore: 80.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );

      final list = [a, b]..sort((x, y) => x.compareTo(y));
      expect(list.first.nodeName, 'NodeA');
    });

    test('3. Capability rejection: Incompatible nodes sink to bottom regardless of score', () {
      final a = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA_Rejected', type: 'SS'),
        nodeName: 'NodeA_Rejected',
        capabilityEvidence: CapabilityEvidenceType.runtimeRejected,
        score: const ChainScore(
            totalScore: 99.0, // High score but rejected
            confidence: 0.99,
            reliabilityScore: 99.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      final b = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeB_Valid', type: 'SS'),
        nodeName: 'NodeB_Valid',
        capabilityEvidence: CapabilityEvidenceType.runtimeVerified,
        score: const ChainScore(
            totalScore: 50.0,
            confidence: 0.5,
            reliabilityScore: 50.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );

      final list = [a, b]..sort((x, y) => x.compareTo(y));
      expect(list.first.nodeName, 'NodeB_Valid'); // Valid wins over high score rejected
    });

    test('4. Node Lock correctly projects state', () {
      final lockedNode = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        isLocked: true,
      );
      expect(lockedNode.isLocked, true);
    });

    test('5. Cold start correctly identifies exploration nodes', () {
      final newProxy = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        latencyMs: null, // No latency yet
        score: const ChainScore(
            totalScore: 100.0,
            confidence: 1.0, // Max confidence due to totalSamples == 0
            reliabilityScore: 100.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      expect(newProxy.isExploration, true);
    });

    // ── P1.3-A1: health-aware ordering ──────────────────────────────────────
    test('6. A1: a healthy node outranks a higher-scoring failed node', () {
      // Health is now the FIRST key, exactly as `ChainFallbackService`
      // orders candidates before scoring them.
      final failedHighScore = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        health: ChainHealthStatus.failed,
        score: const ChainScore(
            totalScore: 95.0,
            confidence: 0.95,
            reliabilityScore: 95.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      final healthyLowerScore = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeB', type: 'SS'),
        nodeName: 'NodeB',
        health: ChainHealthStatus.healthy,
        score: const ChainScore(
            totalScore: 80.0,
            confidence: 0.8,
            reliabilityScore: 80.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );

      final list = [failedHighScore, healthyLowerScore]
        ..sort((x, y) => x.compareTo(y));
      expect(
        list.first.nodeName,
        'NodeB',
        reason: 'health decides before score, matching the failover ordering',
      );
    });

    test('7. A1: equal health keeps the previous score ordering', () {
      // Both healthy ⇒ the health key is a no-op and the pre-existing
      // capability → score → name order (and the score itself) is unchanged.
      ChainProxyNodeViewModel node(String name, double score) =>
          ChainProxyNodeViewModel(
            proxy: Proxy(name: name, type: 'SS'),
            nodeName: name,
            health: ChainHealthStatus.healthy,
            score: ChainScore(
                totalScore: score,
                confidence: score / 100,
                reliabilityScore: score,
                capabilityScore: 0,
                latencyScore: 0,
                flapPenalty: 0,
                hopPenalty: 0),
          );

      final list = [node('Low', 80), node('High', 90)]
        ..sort((x, y) => x.compareTo(y));
      expect(list.first.nodeName, 'High');
      expect(list.last.nodeName, 'Low');
    });

    test('8. A1: unknown is not treated as failed', () {
      // `unknown` (3) must rank ABOVE `failed` (4) — the same tiering failover
      // uses, so a never-probed node is not punished as if it had failed.
      final unknown = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeA', type: 'SS'),
        nodeName: 'NodeA',
        health: ChainHealthStatus.unknown,
        score: const ChainScore(
            totalScore: 50.0,
            confidence: 0.5,
            reliabilityScore: 50.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );
      final failed = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'NodeB', type: 'SS'),
        nodeName: 'NodeB',
        health: ChainHealthStatus.failed,
        score: const ChainScore(
            totalScore: 90.0,
            confidence: 0.9,
            reliabilityScore: 90.0,
            capabilityScore: 0,
            latencyScore: 0,
            flapPenalty: 0,
            hopPenalty: 0),
      );

      final list = [failed, unknown]..sort((x, y) => x.compareTo(y));
      expect(list.first.nodeName, 'NodeA');
      expect(list.last.nodeName, 'NodeB');
    });
  });
}
