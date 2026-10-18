import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Traffic detail for the dashboard card.
///
/// The numbers come from the core's own counters (`getTotalTraffic`), which
/// reset when the core restarts — hence "since this session". Nothing here is
/// derived or estimated: if the core reports nothing, the panel says so rather
/// than showing a plausible-looking zero.
void showTrafficDetailDialog() {
  globalState.showCommonDialog(child: const _TrafficDetailDialog());
}

class _TrafficDetailDialog extends ConsumerStatefulWidget {
  const _TrafficDetailDialog();

  @override
  ConsumerState<_TrafficDetailDialog> createState() =>
      _TrafficDetailDialogState();
}

class _TrafficDetailDialogState extends ConsumerState<_TrafficDetailDialog> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final traffic = ref.watch(totalTrafficProvider);
    final up = traffic.up.value;
    final down = traffic.down.value;
    final total = up + down;

    return CommonDialog(
      title: appLocalizations.trafficUsage,
      actions: [
        TextButton(
          onPressed: _resetting
              ? null
              : () async {
                  setState(() => _resetting = true);
                  try {
                    clashCore.resetTraffic();
                    // The provider only refreshes on the next traffic tick;
                    // read it back immediately so the panel does not keep
                    // showing the pre-reset numbers.
                    final fresh = await clashCore.getTotalTraffic();
                    if (mounted) {
                      ref.read(totalTrafficProvider.notifier).value = fresh;
                    }
                  } catch (e) {
                    commonPrint.log('resetTraffic failed: $e');
                  } finally {
                    if (mounted) setState(() => _resetting = false);
                  }
                },
          child: Text(appLocalizations.reset),
        ),
        FilledButton(
          onPressed: () => globalState.navigatorKey.currentState?.pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appLocalizations.trafficSinceStart,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TrafficMetric(
                  icon: Icons.arrow_upward_rounded,
                  label: appLocalizations.upload,
                  value: traffic.up.show,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TrafficMetric(
                  icon: Icons.arrow_downward_rounded,
                  label: appLocalizations.download,
                  value: traffic.down.show,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrafficMetric(
            icon: Icons.swap_vert_rounded,
            label: appLocalizations.totalTraffic,
            value: TrafficValue(value: total).show,
            color: colorScheme.onSurface,
            wide: true,
          ),
          if (total == 0) ...[
            const SizedBox(height: 12),
            Text(
              // Honest empty state: a zero counter means either no traffic has
              // gone through yet or the core is not reporting one — the panel
              // must not pretend to know which.
              appLocalizations.noData,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrafficMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _TrafficMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
