import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_telemetry.dart';

void main() {
  group('Chain Proxy 2.0 Phase 4.2-B — Adaptive Insight Layer', () {
    test('1. 空置判定: 数据不足 5 条时应返回 empty 模型', () {
      final snapshot = ChainTelemetrySnapshot(
        totalEvents: 4,
        failedEvents: 0,
        successEvents: 4,
        lastEventTime: DateTime.now(),
        recentEvents: [
          ChainTelemetryEvent(type: ChainTelemetryEventType.probeCompleted),
          ChainTelemetryEvent(type: ChainTelemetryEventType.probeCompleted),
        ],
      );

      final insight = ChainAdaptiveInsight.fromTelemetry(snapshot);
      expect(insight.forecast, equals(StabilityForecast.stable));
      expect(insight.latencyTrend, equals(TrendDirection.insufficientData));
    });

    test('2. 趋势分析: Latency Degrading 检测', () {
      final events = [
        // older half
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 100},
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 100},
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 100},
        ),
        // newer half
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 200},
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 250},
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 250},
        ),
      ];

      final snapshot = ChainTelemetrySnapshot(
        totalEvents: 6,
        failedEvents: 0,
        successEvents: 6,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final insight = ChainAdaptiveInsight.fromTelemetry(snapshot);
      expect(insight.latencyTrend, equals(TrendDirection.degrading));
    });

    test('3. 异常捕捉: 捕捉故障爆发 Burst', () {
      final events = List.generate(10, (i) {
        if (i >= 5) {
          return ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed);
        }
        return ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          metadata: {'latencyMs': 100},
        );
      });

      final snapshot = ChainTelemetrySnapshot(
        totalEvents: 10,
        failedEvents: 3,
        successEvents: 7,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final insight = ChainAdaptiveInsight.fromTelemetry(snapshot);
      expect(insight.anomalyDetection.hasFailureBurst, isTrue);
      expect(insight.forecast, equals(StabilityForecast.volatile));
    });

    test('4. 节点相关性分析: 找到高频率关联错误节点', () {
      final events = [
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          role: 'exit',
          nodeName: 'NodeX',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          role: 'exit',
          nodeName: 'NodeX',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'entry',
          nodeName: 'NodeY',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'exit',
          nodeName: 'NodeX',
        ),
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'exit',
          nodeName: 'NodeZ',
        ),
      ];

      final snapshot = ChainTelemetrySnapshot(
        totalEvents: 5,
        failedEvents: 2,
        successEvents: 3,
        lastEventTime: DateTime.now(),
        recentEvents: events,
      );

      final insight = ChainAdaptiveInsight.fromTelemetry(snapshot);
      expect(insight.failureCorrelation.highlyCorrelatedNode, equals('NodeX'));
      expect(insight.failureCorrelation.highlyCorrelatedRole, equals('exit'));
    });
  });
}
