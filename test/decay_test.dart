import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';

void main() {
  test('time decay', () {
    var stats = ChainReliabilityStats.initial(networkFingerprint: 'test_env');
    // Give it 1000 successes
    stats = stats.copyWith(
      weightedSuccess: 1000.0,
      weightedFailure: 0.0,
      consecutiveFailures: 0,
      totalSamples: 1000,
      lastUpdated: DateTime.now(),
    );

    // Apply lambda = 0.0288 (approx half-life of 24h = ln(2)/24)
    // Wait, 0.0288 * 24 = 0.6912 ≈ ln(2). Yes!

    void printDecay(int daysLater) {
      final now = stats.lastUpdated.add(Duration(days: daysLater));
      // Trigger a success event
      final decayed = stats.recordEvent(
        isSuccess: true,
        now: now,
        lambda: 0.0288,
      );
      // We subtract 1 to see what the decayed weighted success was *before* adding the new +1
      final preEventSuccess = decayed.weightedSuccess - 1.0;
      print(
        't$daysLater days -> decayed weight: ${preEventSuccess.toStringAsFixed(2)} / 1000',
      );
    }

    printDecay(0);
    printDecay(1);
    printDecay(7);
    printDecay(30);
    printDecay(90);
  });
}
