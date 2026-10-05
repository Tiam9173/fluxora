import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_analytics.dart';
import 'package:fluxora/models/chain_telemetry.dart';

void main() {
  group('Chain Proxy 2.0 Phase 4.2-A — Analytics Model Test', () {
    test('1. 空状态: 基础得分应为 100 且状态全空', () {
      final snapshot = ChainIntelligenceSnapshot.fromTelemetry(
        ChainTelemetrySnapshot.empty(),
      );

      expect(snapshot.healthScore, equals(100));
      expect(snapshot.healthRating, equals('Excellent'));
      expect(snapshot.averageLatencyMs, equals(0.0));
      expect(snapshot.nodeReliability, isEmpty);
      expect(snapshot.failureAnalytics.topErrorCode, isNull);
      expect(snapshot.failureAnalytics.errorCodeCounts, isEmpty);
    });

    test('2. 延迟统计: 应正确计算平均延迟', () {
      final now = DateTime.now();
      final events = [
        ChainTelemetryEvent(
          timestamp: now.subtract(const Duration(seconds: 10)),
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 100},
        ),
        ChainTelemetryEvent(
          timestamp: now.subtract(const Duration(seconds: 5)),
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 200},
        ),
        ChainTelemetryEvent(
          timestamp: now,
          type: ChainTelemetryEventType.probeCompleted,
          // Invalid latency shouldn't be counted
          metadata: {'latencyMs': -10},
        ),
      ];

      final tSnapshot = ChainTelemetrySnapshot(
        totalEvents: 3,
        failedEvents: 0,
        successEvents: 3,
        lastEventTime: now,
        recentEvents: events,
      );

      final analytics = ChainIntelligenceSnapshot.fromTelemetry(tSnapshot);
      expect(analytics.averageLatencyMs, equals(150.0));
    });

    test('3. 故障归因分析: 提取数量最多的错误码', () {
      final events = [
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          errorCode: 'TIMEOUT',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.retryFailed,
          errorCode: 'TIMEOUT',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateRejected,
          errorCode: 'DIAL_FAIL',
        ),
      ];

      final tSnapshot = ChainTelemetrySnapshot(
        totalEvents: 3,
        failedEvents: 3,
        successEvents: 0,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final analytics = ChainIntelligenceSnapshot.fromTelemetry(tSnapshot);
      expect(analytics.failureAnalytics.errorCodeCounts['TIMEOUT'], equals(2));
      expect(
        analytics.failureAnalytics.errorCodeCounts['DIAL_FAIL'],
        equals(1),
      );
      expect(analytics.failureAnalytics.topErrorCode, equals('TIMEOUT'));
    });

    test('4. 节点可靠性分析: 失败率降序排列及阈值识别', () {
      final events = [
        // Node A: 2 fails, 2 total (100% fail)
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          nodeName: 'NodeA',
          role: 'exit',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.retryFailed,
          nodeName: 'NodeA',
          role: 'exit',
        ),

        // Node B: 1 fail, 3 total (33% fail)
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          nodeName: 'NodeB',
          role: 'relay',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          nodeName: 'NodeB',
          role: 'relay',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateRejected,
          nodeName: 'NodeB',
          role: 'relay',
        ),

        // Node C: 0 fails, 1 total (0% fail)
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          nodeName: 'NodeC',
          role: 'entry',
        ),
      ];

      final tSnapshot = ChainTelemetrySnapshot(
        totalEvents: 6,
        failedEvents: 3,
        successEvents: 3,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final analytics = ChainIntelligenceSnapshot.fromTelemetry(tSnapshot);

      expect(analytics.nodeReliability.length, equals(3));

      // Node A is first because 100% fail rate
      expect(analytics.nodeReliability[0].nodeName, equals('NodeA'));
      expect(analytics.nodeReliability[0].failureRate, equals(1.0));
      // Highly unreliable needs >= 3 involvements, Node A only has 2
      expect(analytics.nodeReliability[0].isHighlyUnreliable, isFalse);

      // Node B is second
      expect(analytics.nodeReliability[1].nodeName, equals('NodeB'));
      expect(analytics.nodeReliability[1].failCount, equals(1));
      expect(analytics.nodeReliability[1].totalInvolvements, equals(3));

      // Node C is third
      expect(analytics.nodeReliability[2].nodeName, equals('NodeC'));
      expect(analytics.nodeReliability[2].failureRate, equals(0.0));
    });

    test('5. 健康分扣除模型: 综合扣分机制与极限值保护', () {
      final events = [
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed), // fail
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed), // fail
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed), // fail
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.flapSuppressed,
        ), // fail & flap (+1 flap = -5)
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.failoverSuccess,
        ), // success & failover (+1 = -2)
      ];

      final tSnapshot = ChainTelemetrySnapshot(
        totalEvents: 10,
        failedEvents: 4, // 40% fail rate = 40% * 30 = -12
        successEvents: 6,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      // 连续失败计算：倒序查找。最后一项是 failoverSuccess (success)，所以连续失败 = 0。
      final analytics = ChainIntelligenceSnapshot.fromTelemetry(tSnapshot);

      // 100 - (0 * 10) - (1 * 5) - (1 * 2) - (0.4 * 30) = 100 - 0 - 5 - 2 - 12 = 81
      expect(analytics.healthScore, equals(81));
      expect(analytics.healthRating, equals('Good'));
    });

    test('6. 健康分扣除模型: 连续失败计算', () {
      final events = [
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
        ), // success
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed), // fail
        ChainTelemetryEvent(type: ChainTelemetryEventType.retryFailed), // fail
      ];

      final tSnapshot = ChainTelemetrySnapshot(
        totalEvents: 3,
        failedEvents: 2, // 66.6% fail rate
        successEvents: 1,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final analytics = ChainIntelligenceSnapshot.fromTelemetry(tSnapshot);

      // 连续失败 = 2 (-20)
      // globalFail = 2/3 * 30 = 20
      // 100 - 20 - 20 = 60
      expect(analytics.healthScore, equals(60));
      expect(analytics.healthRating, equals('Fair'));
    });
  });
}
