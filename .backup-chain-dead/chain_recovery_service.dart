import 'package:fluxora/models/chain_decision.dart';
import 'package:fluxora/models/chain_recovery.dart';

class ChainRecoveryPlanner {
  static ChainRecoveryPlan fromDecision(ChainDecisionSupport decision) {
    if (decision.recommendations.isEmpty) {
      return const ChainRecoveryPlan(
        action: ChainRecoveryAction.none,
        title: 'System Optimal',
        description: 'No recovery action needed.',
        requiresConfirmation: false,
      );
    }

    final hasPause = decision.recommendations.any(
      (r) => r.action == DecisionAction.pauseChainProxy,
    );
    final hasReplace = decision.recommendations.any(
      (r) =>
          r.action == DecisionAction.replaceEntryNode ||
          r.action == DecisionAction.replaceRelayNode ||
          r.action == DecisionAction.replaceExitNode,
    );
    final hasMonitor = decision.recommendations.any(
      (r) => r.action == DecisionAction.monitorClosely,
    );

    if (hasPause) {
      return const ChainRecoveryPlan(
        action: ChainRecoveryAction.pauseChainProxy,
        title: 'Pause Chain Proxy',
        description:
            'Network instability detected. Pause the chain to restore basic connectivity.',
        requiresConfirmation: true,
      );
    }

    if (hasReplace) {
      final replaces = decision.recommendations
          .where(
            (r) =>
                r.action == DecisionAction.replaceEntryNode ||
                r.action == DecisionAction.replaceRelayNode ||
                r.action == DecisionAction.replaceExitNode,
          )
          .toList();

      final affected = replaces
          .map((e) => e.targetNode)
          .whereType<String>()
          .toList();

      return ChainRecoveryPlan(
        action: ChainRecoveryAction.suggestNodeReplacement,
        title: 'Replace Unstable Nodes',
        description:
            'Highly correlated unstable nodes detected. Prepare to failover and replace them.',
        affectedNodes: affected,
        requiresConfirmation: true,
      );
    }

    if (hasMonitor) {
      return const ChainRecoveryPlan(
        action: ChainRecoveryAction.none,
        title: 'Monitor Closely',
        description:
            'Chain is volatile but no clear target for replacement yet.',
        requiresConfirmation: false,
      );
    }

    return const ChainRecoveryPlan(
      action: ChainRecoveryAction.none,
      title: 'System Optimal',
      description: 'No recovery action needed.',
      requiresConfirmation: false,
    );
  }
}
