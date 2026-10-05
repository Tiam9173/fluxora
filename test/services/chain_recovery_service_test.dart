import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_decision.dart';
import 'package:fluxora/models/chain_recovery.dart';
import 'package:fluxora/services/chain_recovery_service.dart';

void main() {
  group('Chain Proxy 2.0 Phase 4.3-B — Chain Assisted Recovery Layer', () {
    test('1. 基础场景: System Optimal (Empty/Stable) 转换为 None', () {
      const decision = ChainDecisionSupport(
        recommendations: [
          ChainRecommendation(
            action: DecisionAction.none,
            title: 'System Optimal',
            description: '',
          ),
        ],
      );

      final plan = ChainRecoveryPlanner.fromDecision(decision);

      expect(plan.action, equals(ChainRecoveryAction.none));
      expect(plan.requiresConfirmation, isFalse);
    });

    test('2. 异常场景: Critical Forecast 转化为 Pause Chain Proxy (需确认)', () {
      const decision = ChainDecisionSupport(
        recommendations: [
          ChainRecommendation(
            action: DecisionAction.pauseChainProxy,
            title: 'Pause Chain Proxy',
            description: '',
          ),
        ],
      );

      final plan = ChainRecoveryPlanner.fromDecision(decision);

      expect(plan.action, equals(ChainRecoveryAction.pauseChainProxy));
      expect(plan.requiresConfirmation, isTrue);
    });

    test(
      '3. 异常场景: Correlated Node Failure 转化为 Suggest Node Replacement (需确认)',
      () {
        const decision = ChainDecisionSupport(
          recommendations: [
            ChainRecommendation(
              action: DecisionAction.replaceExitNode,
              title: 'Replace Exit Node',
              description: '',
              targetNode: 'NodeA',
            ),
            ChainRecommendation(
              action: DecisionAction.replaceRelayNode,
              title: 'Replace Relay Node',
              description: '',
              targetNode: 'NodeB',
            ),
          ],
        );

        final plan = ChainRecoveryPlanner.fromDecision(decision);

        expect(plan.action, equals(ChainRecoveryAction.suggestNodeReplacement));
        expect(plan.affectedNodes, containsAll(['NodeA', 'NodeB']));
        expect(plan.requiresConfirmation, isTrue);
      },
    );

    test(
      '4. 安全验证: Volatile 状态 (Monitor Closely) 不触发自动干预 (requiresConfirmation: false)',
      () {
        const decision = ChainDecisionSupport(
          recommendations: [
            ChainRecommendation(
              action: DecisionAction.monitorClosely,
              title: 'Monitor Closely',
              description: '',
            ),
          ],
        );

        final plan = ChainRecoveryPlanner.fromDecision(decision);

        expect(plan.action, equals(ChainRecoveryAction.none));
        expect(plan.title, equals('Monitor Closely'));
        expect(plan.requiresConfirmation, isFalse);
      },
    );

    test('5. 用户确认流程验证: 优先级冲突时 Pause 优先于 Replace', () {
      const decision = ChainDecisionSupport(
        recommendations: [
          ChainRecommendation(
            action: DecisionAction.pauseChainProxy,
            title: '',
            description: '',
          ),
          ChainRecommendation(
            action: DecisionAction.replaceEntryNode,
            title: '',
            description: '',
          ),
        ],
      );

      final plan = ChainRecoveryPlanner.fromDecision(decision);

      // Pause is the most critical action to prevent catastrophic networking issues
      expect(plan.action, equals(ChainRecoveryAction.pauseChainProxy));
    });
  });
}
