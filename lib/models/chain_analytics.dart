import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_telemetry.dart';

/// 节点可靠性统计
@immutable
class NodeReliabilityStats {
  final String nodeName;
  final String role;
  final int totalInvolvements;
  final int failCount;

  const NodeReliabilityStats({
    required this.nodeName,
    required this.role,
    required this.totalInvolvements,
    required this.failCount,
  });

  double get failureRate =>
      totalInvolvements == 0 ? 0.0 : failCount / totalInvolvements;
  bool get isHighlyUnreliable => totalInvolvements >= 3 && failureRate > 0.6;
}

/// 故障分析统计
@immutable
class FailureAnalyticsData {
  final Map<String, int> errorCodeCounts;
  final String? topErrorCode;

  const FailureAnalyticsData({
    required this.errorCodeCounts,
    this.topErrorCode,
  });
}

/// 链式智能分析快照
@immutable
class ChainIntelligenceSnapshot {
  /// 健康度得分 (0-100)
  final int healthScore;

  /// 健康度评级文本
  final String healthRating;

  /// 平均延迟 (毫秒)
  final double averageLatencyMs;

  /// 节点可靠性列表
  final List<NodeReliabilityStats> nodeReliability;

  /// 故障归因分析
  final FailureAnalyticsData failureAnalytics;

  const ChainIntelligenceSnapshot({
    required this.healthScore,
    required this.healthRating,
    required this.averageLatencyMs,
    required this.nodeReliability,
    required this.failureAnalytics,
  });

  factory ChainIntelligenceSnapshot.empty() {
    return const ChainIntelligenceSnapshot(
      healthScore: 100,
      healthRating: 'Excellent',
      averageLatencyMs: 0.0,
      nodeReliability: [],
      failureAnalytics: FailureAnalyticsData(errorCodeCounts: {}),
    );
  }

  /// 纯函数式分析，从 Telemetry 快照直接计算，不驻留额外业务状态
  factory ChainIntelligenceSnapshot.fromTelemetry(
    ChainTelemetrySnapshot telemetry,
  ) {
    if (telemetry.isEmpty) {
      return ChainIntelligenceSnapshot.empty();
    }

    // 1. Latency Analyzer
    double totalLatency = 0;
    int latencyCount = 0;

    // 2. Failure Analytics
    final errorCounts = <String, int>{};

    // 3. Node Reliability
    final nodeInvolvements = <String, Map<String, dynamic>>{};
    // key: "$role:$nodeName" -> { "role": role, "name": nodeName, "total": int, "fails": int }

    // 4. Health Score Penalties
    int failoverCount = 0;
    int flapCount = 0;
    int consecutiveFails = 0; // 最近连续失败次数

    for (final event in telemetry.recentEvents) {
      // Latency extraction
      if (event.type == ChainTelemetryEventType.probeCompleted &&
          event.metadata != null) {
        final lat = event.metadata!['latencyMs'];
        if (lat is num && lat > 0) {
          totalLatency += lat.toDouble();
          latencyCount++;
        }
      }

      // Error tracking
      if (event.type.isFailure &&
          event.errorCode != null &&
          event.errorCode!.isNotEmpty) {
        errorCounts[event.errorCode!] =
            (errorCounts[event.errorCode!] ?? 0) + 1;
      }

      // Node involvement tracking
      if (event.nodeName != null &&
          event.nodeName!.isNotEmpty &&
          event.role != null &&
          event.role!.isNotEmpty) {
        final key = '${event.role}:${event.nodeName}';
        nodeInvolvements.putIfAbsent(
          key,
          () => {
            'role': event.role!,
            'name': event.nodeName!,
            'total': 0,
            'fails': 0,
          },
        );
        nodeInvolvements[key]!['total'] =
            (nodeInvolvements[key]!['total'] as int) + 1;
        if (event.type.isFailure) {
          nodeInvolvements[key]!['fails'] =
              (nodeInvolvements[key]!['fails'] as int) + 1;
        }
      }

      // Score penalties
      if (event.type == ChainTelemetryEventType.failoverSuccess)
        failoverCount++;
      if (event.type == ChainTelemetryEventType.flapSuppressed) flapCount++;
    }

    // 统计最近连续失败情况
    for (final event in telemetry.recentEvents.reversed) {
      if (event.type.isFailure) {
        consecutiveFails++;
      } else if (event.type.isSuccess) {
        break; // 遇到成功则中断连续失败的计算
      }
    }

    final avgLatency = latencyCount > 0 ? totalLatency / latencyCount : 0.0;

    // Build Node Reliability List
    final reliabilityList = nodeInvolvements.values
        .map(
          (v) => NodeReliabilityStats(
            nodeName: v['name'] as String,
            role: v['role'] as String,
            totalInvolvements: v['total'] as int,
            failCount: v['fails'] as int,
          ),
        )
        .toList();
    // 按照失败率降序，再按总参与次数降序
    reliabilityList.sort((a, b) {
      final rateCmp = b.failureRate.compareTo(a.failureRate);
      if (rateCmp != 0) return rateCmp;
      return b.totalInvolvements.compareTo(a.totalInvolvements);
    });

    // Build Failure Analytics
    String? topError;
    int maxError = 0;
    errorCounts.forEach((code, count) {
      if (count > maxError) {
        maxError = count;
        topError = code;
      }
    });

    // Calculate Health Score (Max 100)
    // - 基础分 100
    // - 最近每次连续失败扣 10 分
    // - 每次抖动抑制记录扣 5 分
    // - 每次 Failover 成功记录扣 2 分（反映链路不稳定需要切换，但由于成功切换所以惩罚较小）
    // - 总体错误率高扣除最多 30 分
    double score = 100.0;
    score -= consecutiveFails * 10;
    score -= flapCount * 5;
    score -= failoverCount * 2;

    final totalEvents = telemetry.totalEvents;
    final failedEvents = telemetry.failedEvents;
    if (totalEvents > 0) {
      final globalFailRate = failedEvents / totalEvents;
      score -=
          globalFailRate * 30; // Max 30 points penalty for general failure rate
    }

    if (score < 0) score = 0;
    if (score > 100) score = 100;
    final int finalScore = score.round();

    String rating = 'Poor';
    if (finalScore >= 90) {
      rating = 'Excellent';
    } else if (finalScore >= 70) {
      rating = 'Good';
    } else if (finalScore >= 50) {
      rating = 'Fair';
    }

    return ChainIntelligenceSnapshot(
      healthScore: finalScore,
      healthRating: rating,
      averageLatencyMs: avgLatency,
      nodeReliability: List.unmodifiable(reliabilityList),
      failureAnalytics: FailureAnalyticsData(
        errorCodeCounts: Map.unmodifiable(errorCounts),
        topErrorCode: topError,
      ),
    );
  }
}
