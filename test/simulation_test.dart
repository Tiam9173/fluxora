import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';

void main() {
  test('simulation', () {
    networkFingerprintProvider.setMockFingerprint('test_env');

    void printScore(String name, ChainFallbackCandidate c) {
      final score = ChainAdaptiveScoreService.calculateNodeScore(candidate: c);
      final stats = c.statsByContext['test_env']!;
      print(
        '$name => Confidence: ${score.confidence}, Score: ${score.totalScore}, Rel: ${score.reliabilityScore}, S: ${stats.weightedSuccess.toStringAsFixed(2)}, F: ${stats.weightedFailure.toStringAsFixed(2)}, ConsFail: ${stats.consecutiveFailures}',
      );
    }

    ChainFallbackCandidate makeCandidate(String name) {
      return ChainFallbackCandidate(
        nodeName: name,
        role: FallbackCandidateRole.entry,
        statsByContext: {
          'test_env': ChainReliabilityStats.initial(
            networkFingerprint: 'test_env',
          ),
        },
      );
    }

    ChainFallbackCandidate record(
      ChainFallbackCandidate c,
      bool success, {
      double lambda = 0.0,
    }) {
      final stats = c.statsByContext['test_env']!;
      final newStats = stats.recordEvent(
        isSuccess: success,
        now: DateTime.now(),
        lambda: lambda,
      );
      final map = Map<String, ChainReliabilityStats>.from(c.statsByContext);
      map['test_env'] = newStats;
      return c.copyWith(statsByContext: map);
    }

    // Scenario A: S S S S S
    var cA = makeCandidate('A');
    for (int i = 0; i < 5; i++) cA = record(cA, true);
    printScore('Scenario A', cA);

    // Scenario B: F F F F F
    var cB = makeCandidate('B');
    for (int i = 0; i < 5; i++) cB = record(cB, false);
    printScore('Scenario B', cB);

    // Scenario C: S F S F S F S F
    var cC = makeCandidate('C');
    for (int i = 0; i < 4; i++) {
      cC = record(cC, true);
      cC = record(cC, false);
    }
    printScore('Scenario C', cC);

    // Scenario D: 100 S then 20 F
    var cD = makeCandidate('D');
    for (int i = 0; i < 100; i++) cD = record(cD, true);
    for (int i = 0; i < 20; i++) cD = record(cD, false);
    printScore('Scenario D', cD);

    // Scenario E: 20 F then 100 S
    var cE = makeCandidate('E');
    for (int i = 0; i < 20; i++) cE = record(cE, false);
    for (int i = 0; i < 100; i++) cE = record(cE, true);
    printScore('Scenario E', cE);

    // Flapping S F S F (100 times) then S S S
    var cF = makeCandidate('F');
    for (int i = 0; i < 100; i++) {
      cF = record(cF, true);
      cF = record(cF, false);
    }
    cF = record(cF, true);
    cF = record(cF, true);
    cF = record(cF, true);
    printScore('Flapping', cF);
  });
}
