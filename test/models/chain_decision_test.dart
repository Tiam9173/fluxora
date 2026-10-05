import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_decision.dart';

void main() {
  group('Chain Proxy 2.0 Phase 4.3-A — Chain Decision Support Layer', () {
    test('1. Stable State -> None (System Optimal)', () {
      final insight = ChainAdaptiveInsight.empty();
      final decision = ChainDecisionSupport.fromInsight(insight);

      expect(decision.recommendations.length, equals(1));
      expect(
        decision.recommendations.first.action,
        equals(DecisionAction.none),
      );
      expect(decision.recommendations.first.title, equals('System Optimal'));
    });

    test('2. Critical Forecast -> Pause Chain Proxy', () {
      const insight = ChainAdaptiveInsight(
        latencyTrend: TrendDirection.degrading,
        reliabilityTrend: TrendDirection.degrading,
        anomalyDetection: AnomalyDetection(
          hasLatencySpike: true,
          hasFailureBurst: true,
        ),
        failureCorrelation: FailureCorrelation(description: ''),
        forecast: StabilityForecast.critical,
      );

      final decision = ChainDecisionSupport.fromInsight(insight);

      expect(decision.recommendations.length, equals(1));
      expect(
        decision.recommendations.first.action,
        equals(DecisionAction.pauseChainProxy),
      );
    });

    test('3. Node Correlation -> Replace specific node', () {
      const insight = ChainAdaptiveInsight(
        latencyTrend: TrendDirection.stable,
        reliabilityTrend: TrendDirection.stable,
        anomalyDetection: AnomalyDetection(
          hasLatencySpike: false,
          hasFailureBurst: false,
        ),
        failureCorrelation: FailureCorrelation(
          highlyCorrelatedRole: 'exit',
          highlyCorrelatedNode: 'NodeXYZ',
          description: '',
        ),
        forecast: StabilityForecast.stable,
      );

      final decision = ChainDecisionSupport.fromInsight(insight);

      expect(decision.recommendations.length, equals(1));
      expect(
        decision.recommendations.first.action,
        equals(DecisionAction.replaceExitNode),
      );
      expect(decision.recommendations.first.targetNode, equals('NodeXYZ'));
    });

    test('4. Volatile without specific node -> Monitor Closely', () {
      const insight = ChainAdaptiveInsight(
        latencyTrend: TrendDirection.degrading,
        reliabilityTrend: TrendDirection.degrading,
        anomalyDetection: AnomalyDetection(
          hasLatencySpike: false,
          hasFailureBurst: true,
        ),
        failureCorrelation: FailureCorrelation(
          description: '',
        ), // highlyCorrelatedNode is null
        forecast: StabilityForecast.volatile,
      );

      final decision = ChainDecisionSupport.fromInsight(insight);

      expect(decision.recommendations.length, equals(1));
      expect(
        decision.recommendations.first.action,
        equals(DecisionAction.monitorClosely),
      );
    });

    test('5. Critical + Node Correlation -> Pause AND Replace Node', () {
      const insight = ChainAdaptiveInsight(
        latencyTrend: TrendDirection.degrading,
        reliabilityTrend: TrendDirection.degrading,
        anomalyDetection: AnomalyDetection(
          hasLatencySpike: true,
          hasFailureBurst: true,
        ),
        failureCorrelation: FailureCorrelation(
          highlyCorrelatedRole: 'entry',
          highlyCorrelatedNode: 'NodeA',
          description: '',
        ),
        forecast: StabilityForecast.critical,
      );

      final decision = ChainDecisionSupport.fromInsight(insight);

      // Should recommend both Pause and Replace
      expect(decision.recommendations.length, equals(2));
      expect(
        decision.recommendations[0].action,
        equals(DecisionAction.pauseChainProxy),
      );
      expect(
        decision.recommendations[1].action,
        equals(DecisionAction.replaceEntryNode),
      );
      expect(decision.recommendations[1].targetNode, equals('NodeA'));
    });
  });
}
