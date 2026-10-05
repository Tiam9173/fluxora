import 'package:flutter/material.dart';
import 'package:fluxora/models/chain_analytics.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

class ChainIntelligenceDashboard extends StatelessWidget {
  final ChainTelemetrySnapshot telemetrySnapshot;

  const ChainIntelligenceDashboard({
    super.key,
    required this.telemetrySnapshot,
  });

  @override
  Widget build(BuildContext context) {
    if (telemetrySnapshot.isEmpty) {
      return const SizedBox.shrink();
    }

    final analytics = ChainIntelligenceSnapshot.fromTelemetry(
      telemetrySnapshot,
    );

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Intelligence Analytics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScoreAndLatency(context, analytics),
            const SizedBox(height: 12),
            if (analytics.failureAnalytics.topErrorCode != null) ...[
              _buildFailureAnalytics(context, analytics),
              const SizedBox(height: 12),
            ],
            if (analytics.nodeReliability.isNotEmpty)
              _buildNodeReliability(context, analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreAndLatency(
    BuildContext context,
    ChainIntelligenceSnapshot analytics,
  ) {
    Color scoreColor;
    if (analytics.healthScore >= 90) {
      scoreColor = Colors.green;
    } else if (analytics.healthScore >= 70) {
      scoreColor = Colors.lightGreen;
    } else if (analytics.healthScore >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.redAccent;
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Score',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${analytics.healthScore}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      analytics.healthRating,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avg Latency',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      analytics.averageLatencyMs > 0
                          ? '${analytics.averageLatencyMs.round()}'
                          : '--',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ms',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureAnalytics(
    BuildContext context,
    ChainIntelligenceSnapshot analytics,
  ) {
    final topError = analytics.failureAnalytics.topErrorCode!;
    final topErrorCount = analytics.failureAnalytics.errorCodeCounts[topError]!;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Failure Reason',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$topError ($topErrorCount occurrences)',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeReliability(
    BuildContext context,
    ChainIntelligenceSnapshot analytics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Node Reliability:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...analytics.nodeReliability.take(3).map((node) {
          final isUnreliable = node.isHighlyUnreliable;
          final ratePct = (node.failureRate * 100).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: isUnreliable
                      ? const Text(
                          '⚠',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        )
                      : const Text(
                          '✓',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                ),
                Expanded(
                  child: Text(
                    '[${node.role}] ${node.nodeName}',
                    style: const TextStyle(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Fails: ${node.failCount}/${node.totalInvolvements} ($ratePct%)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isUnreliable
                        ? Colors.orangeAccent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
