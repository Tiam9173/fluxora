import 'package:flutter/material.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

class ChainInsightPanel extends StatelessWidget {
  final ChainTelemetrySnapshot telemetrySnapshot;

  const ChainInsightPanel({super.key, required this.telemetrySnapshot});

  @override
  Widget build(BuildContext context) {
    if (telemetrySnapshot.isEmpty ||
        telemetrySnapshot.recentEvents.length < 5) {
      return const SizedBox.shrink();
    }

    final insight = ChainAdaptiveInsight.fromTelemetry(telemetrySnapshot);
    final colorScheme = Theme.of(context).colorScheme;

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
                  Icons.insights_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Adaptive Insights',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildForecastAndTrends(context, insight),
            if (insight.anomalyDetection.anomalyDescription != null) ...[
              const SizedBox(height: 12),
              _buildAnomalyWarning(context, insight),
            ],
            if (insight.failureCorrelation.highlyCorrelatedNode != null) ...[
              const SizedBox(height: 12),
              _buildCorrelationInfo(context, insight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForecastAndTrends(
    BuildContext context,
    ChainAdaptiveInsight insight,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color forecastColor;
    String forecastText;
    IconData forecastIcon;

    switch (insight.forecast) {
      case StabilityForecast.highlyStable:
        forecastColor = Colors.green;
        forecastText = 'Highly Stable';
        forecastIcon = Icons.shield_outlined;
        break;
      case StabilityForecast.stable:
        forecastColor = colorScheme.primary;
        forecastText = 'Stable';
        forecastIcon = Icons.check_circle_outline;
        break;
      case StabilityForecast.volatile:
        forecastColor = Colors.orange;
        forecastText = 'Volatile';
        forecastIcon = Icons.waves;
        break;
      case StabilityForecast.critical:
        forecastColor = Colors.redAccent;
        forecastText = 'Critical';
        forecastIcon = Icons.warning_amber_rounded;
        break;
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: forecastColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: forecastColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stability Forecast',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(forecastIcon, color: forecastColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      forecastText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: forecastColor,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrendIndicator(
                context,
                'Latency Trend',
                insight.latencyTrend,
                inverseGoodBad: true, // degrading latency is bad (up arrow bad)
              ),
              const SizedBox(height: 8),
              _buildTrendIndicator(
                context,
                'Reliability Trend',
                insight.reliabilityTrend,
                inverseGoodBad: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator(
    BuildContext context,
    String label,
    TrendDirection trend, {
    required bool inverseGoodBad,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color color;

    switch (trend) {
      case TrendDirection.improving:
        icon = inverseGoodBad ? Icons.trending_down : Icons.trending_up;
        color = Colors.green;
        break;
      case TrendDirection.degrading:
        icon = inverseGoodBad ? Icons.trending_up : Icons.trending_down;
        color = Colors.orange;
        break;
      case TrendDirection.stable:
        icon = Icons.trending_flat;
        color = colorScheme.primary;
        break;
      case TrendDirection.insufficientData:
        icon = Icons.horizontal_rule;
        color = colorScheme.onSurfaceVariant;
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildAnomalyWarning(
    BuildContext context,
    ChainAdaptiveInsight insight,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.anomalyDetection.anomalyDescription!,
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationInfo(
    BuildContext context,
    ChainAdaptiveInsight insight,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, color: colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.failureCorrelation.description,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
