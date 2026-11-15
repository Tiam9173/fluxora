import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'traffic_detail.dart';

class TrafficUsage extends ConsumerWidget {
  const TrafficUsage({super.key});

  Widget _total(
    BuildContext context,
    String label,
    IconData icon,
    TrafficValue value,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colorScheme.primary),
          const SizedBox(width: FluxoraSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: FluxoraSpacing.xs),
                Text(
                  '${value.showValue} ${value.showUnit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluxoraTypography.numericBody.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffic = ref.watch(totalTrafficProvider);
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        info: Info(
          label: appLocalizations.trafficUsage,
          iconData: Icons.data_usage_rounded,
        ),
        onPressed: showTrafficDetailDialog,
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: ValueListenableBuilder<int>(
            valueListenable: TickerMode.valuesOf(context).enabled
                ? dashboardRefreshManager.tick1s
                : dashboardRefreshManager.paused,
            builder: (_, _, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _total(
                  context,
                  appLocalizations.download,
                  Icons.arrow_downward_rounded,
                  traffic.down,
                ),
                Divider(height: 1, color: context.colorScheme.outlineVariant),
                _total(
                  context,
                  appLocalizations.upload,
                  Icons.arrow_upward_rounded,
                  traffic.up,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
