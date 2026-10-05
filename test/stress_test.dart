import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';
import 'dart:math';

void main() {
  test('stress test', () {
    final random = Random(42);
    final nodes = List.generate(20, (i) => 'Node_$i');
    final contexts = ['wifi_home', 'cellular_5g', 'unknown_default'];

    var candidates = <String, ChainFallbackCandidate>{};
    for (final node in nodes) {
      candidates[node] = ChainFallbackCandidate(
        nodeName: node,
        role: FallbackCandidateRole.entry,
        statsByContext: {
          for (final ctx in contexts)
            ctx: ChainReliabilityStats.initial(networkFingerprint: ctx),
        },
      );
    }

    int totalEvents = 0;
    final start = DateTime.now();
    var currentTime = start;

    for (int i = 0; i < 10000; i++) {
      final node = nodes[random.nextInt(nodes.length)];
      final ctx = contexts[random.nextInt(contexts.length)];
      final isSuccess = random.nextDouble() > 0.2; // 80% success

      // Simulate time passing (1-10 minutes between events)
      currentTime = currentTime.add(Duration(minutes: random.nextInt(10) + 1));

      var c = candidates[node]!;
      final stats = c.statsByContext[ctx]!;
      final newStats = stats.recordEvent(
        isSuccess: isSuccess,
        now: currentTime,
        lambda: 0.0288,
      );

      final map = Map<String, ChainReliabilityStats>.from(c.statsByContext);
      map[ctx] = newStats;
      candidates[node] = c.copyWith(statsByContext: map);

      totalEvents++;
    }

    expect(totalEvents, 10000);

    // Calculate score 1000 times for determinism
    final target = candidates[nodes[0]]!;
    final score1 = ChainAdaptiveScoreService.calculateNodeScore(
      candidate: target,
    );
    for (int i = 0; i < 1000; i++) {
      final score2 = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: target,
      );
      expect(score1.totalScore, score2.totalScore);
      expect(score1.confidence, score2.confidence);
    }
  });
}
