import 'package:flutter/material.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_decision.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

class ChainDecisionPanel extends StatelessWidget {
  final ChainTelemetrySnapshot telemetrySnapshot;

  const ChainDecisionPanel({super.key, required this.telemetrySnapshot});

  @override
  Widget build(BuildContext context) {
    if (telemetrySnapshot.isEmpty ||
        telemetrySnapshot.recentEvents.length < 5) {
      return const SizedBox.shrink();
    }

    final insight = ChainAdaptiveInsight.fromTelemetry(telemetrySnapshot);
    final decisionSupport = ChainDecisionSupport.fromInsight(insight);
    final colorScheme = Theme.of(context).colorScheme;

    final recs = decisionSupport.recommendations;

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
                  Icons.lightbulb_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Decision Support',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recs.map((r) => _buildRecItem(context, r)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecItem(BuildContext context, ChainRecommendation rec) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color color;

    switch (rec.action) {
      case DecisionAction.pauseChainProxy:
        icon = Icons.pause_circle_outline;
        color = Colors.redAccent;
        break;
      case DecisionAction.replaceEntryNode:
      case DecisionAction.replaceRelayNode:
      case DecisionAction.replaceExitNode:
        icon = Icons.swap_horiz;
        color = Colors.orange;
        break;
      case DecisionAction.monitorClosely:
        icon = Icons.visibility_outlined;
        color = colorScheme.primary;
        break;
      case DecisionAction.none:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
