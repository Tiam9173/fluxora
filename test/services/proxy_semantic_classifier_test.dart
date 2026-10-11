import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/services/proxy_semantic_classifier.dart';

/// P1.1-D2 — pure behavioural availability classifier.
///
/// The classifier must never condemn a node without real evidence: untested
/// nodes stay [ProxySemanticType.unknown], and only a run of consecutive real
/// failures with zero successes is treated as non-connectable.
ChainReliabilityStats _stats({
  double weightedSuccess = 0.0,
  double weightedFailure = 0.0,
  int consecutiveFailures = 0,
  int totalSamples = 0,
}) {
  return ChainReliabilityStats(
    weightedSuccess: weightedSuccess,
    weightedFailure: weightedFailure,
    consecutiveFailures: consecutiveFailures,
    lastUpdated: DateTime(2026, 1, 1),
    totalSamples: totalSamples,
    networkFingerprint: 'test-fp',
  );
}

void main() {
  group('ProxySemanticClassifier.classify', () {
    test('null stats → unknown', () {
      expect(
        ProxySemanticClassifier.classify(null),
        ProxySemanticType.unknown,
      );
    });

    test('zero samples (initial prior) → unknown, never nonConnectable', () {
      expect(
        ProxySemanticClassifier.classify(_stats()),
        ProxySemanticType.unknown,
      );
    });

    test('at least one real success → connectable', () {
      expect(
        ProxySemanticClassifier.classify(
          _stats(weightedSuccess: 1.0, totalSamples: 1),
        ),
        ProxySemanticType.connectable,
      );
    });

    test('success after failures still → connectable', () {
      expect(
        ProxySemanticClassifier.classify(
          _stats(
            weightedSuccess: 1.0,
            weightedFailure: 3.0,
            consecutiveFailures: 0,
            totalSamples: 4,
          ),
        ),
        ProxySemanticType.connectable,
      );
    });

    test('one or two consecutive failures (no success) → unknown', () {
      expect(
        ProxySemanticClassifier.classify(
          _stats(weightedFailure: 1.0, consecutiveFailures: 1, totalSamples: 1),
        ),
        ProxySemanticType.unknown,
      );
      expect(
        ProxySemanticClassifier.classify(
          _stats(weightedFailure: 2.0, consecutiveFailures: 2, totalSamples: 2),
        ),
        ProxySemanticType.unknown,
      );
    });

    test('threshold consecutive failures with zero success → nonConnectable',
        () {
      expect(
        ProxySemanticClassifier.classify(
          _stats(
            weightedFailure: 3.0,
            consecutiveFailures:
                ProxySemanticClassifier.nonConnectableFailureThreshold,
            totalSamples: 3,
          ),
        ),
        ProxySemanticType.nonConnectable,
      );
    });

    test('many consecutive failures → nonConnectable', () {
      expect(
        ProxySemanticClassifier.classify(
          _stats(weightedFailure: 6.0, consecutiveFailures: 6, totalSamples: 6),
        ),
        ProxySemanticType.nonConnectable,
      );
    });

    test('failure threshold is 3', () {
      expect(ProxySemanticClassifier.nonConnectableFailureThreshold, 3);
    });
  });

  group('ChainProxyNodeViewModel.isNonConnectable', () {
    test('derives from semanticType', () {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Node', type: 'hysteria2'),
        nodeName: 'Node',
        semanticType: ProxySemanticType.nonConnectable,
      );
      expect(vm.isNonConnectable, isTrue);
    });

    test('defaults to unknown / not non-connectable', () {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Node', type: 'hysteria2'),
        nodeName: 'Node',
      );
      expect(vm.semanticType, ProxySemanticType.unknown);
      expect(vm.isNonConnectable, isFalse);
    });
  });
}
