import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_insight.dart';

enum DecisionAction {
  replaceEntryNode,
  replaceRelayNode,
  replaceExitNode,
  pauseChainProxy,
  monitorClosely,
  none,
}

@immutable
class ChainRecommendation {
  final DecisionAction action;
  final String title;
  final String description;
  final String? targetNode;

  const ChainRecommendation({
    required this.action,
    required this.title,
    required this.description,
    this.targetNode,
  });
}

@immutable
class ChainDecisionSupport {
  final List<ChainRecommendation> recommendations;

  const ChainDecisionSupport({required this.recommendations});

  factory ChainDecisionSupport.fromInsight(ChainAdaptiveInsight insight) {
    final recs = <ChainRecommendation>[];

    // 1. Critical Stability -> Pause
    if (insight.forecast == StabilityForecast.critical) {
      recs.add(
        const ChainRecommendation(
          action: DecisionAction.pauseChainProxy,
          title: 'Pause Chain Proxy',
          description:
              'The chain is experiencing critical instability. Consider pausing it to restore basic connectivity.',
        ),
      );
    }

    // 2. Node Correlation -> Replace specific node
    if (insight.failureCorrelation.highlyCorrelatedNode != null) {
      final role = insight.failureCorrelation.highlyCorrelatedRole;
      final node = insight.failureCorrelation.highlyCorrelatedNode!;
      DecisionAction action = DecisionAction.none;
      if (role == 'entry') {
        action = DecisionAction.replaceEntryNode;
      } else if (role == 'relay') {
        action = DecisionAction.replaceRelayNode;
      } else if (role == 'exit') {
        action = DecisionAction.replaceExitNode;
      }

      if (action != DecisionAction.none) {
        recs.add(
          ChainRecommendation(
            action: action,
            title: 'Replace $role node',
            description: 'Node $node is causing over 60% of recent failures.',
            targetNode: node,
          ),
        );
      }
    }

    // 3. Volatile but no specific node -> Monitor
    if (insight.forecast == StabilityForecast.volatile &&
        insight.failureCorrelation.highlyCorrelatedNode == null) {
      recs.add(
        const ChainRecommendation(
          action: DecisionAction.monitorClosely,
          title: 'Monitor Closely',
          description:
              'Chain is experiencing latency spikes or scattered failures. No single node identified yet.',
        ),
      );
    }

    // 4. Stable -> None
    if (recs.isEmpty) {
      recs.add(
        const ChainRecommendation(
          action: DecisionAction.none,
          title: 'System Optimal',
          description: 'The chain proxy is operating smoothly.',
        ),
      );
    }

    return ChainDecisionSupport(recommendations: List.unmodifiable(recs));
  }
}
