import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/models/chain_score.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/models/common.dart';

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
  });
}
