import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

class ChainRecoveryPanel extends ConsumerWidget {
  const ChainRecoveryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(chainRecoveryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (plan == null) {
      return const SizedBox.shrink();
    }

    return CommonCard(
      type: CommonCardType.filled,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.redAccent.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recovery Suggested',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.redAccent,
                  ),
                ),
                const Spacer(),
                if (plan.requiresConfirmation)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Requires Confirmation',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reason: ${plan.description}',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Action: ${plan.title}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (plan.affectedNodes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Affected: ${plan.affectedNodes.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    chainProxyManager.rejectRecoveryPlan();
                  },
                  child: const Text(
                    'Ignore',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    chainProxyManager.approveRecoveryPlan();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
