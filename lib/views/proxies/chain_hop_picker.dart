import 'package:flutter/material.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';

/// Picks a node for one front hop.
///
/// Deliberately the same browsing UI as the notification's switch card: it
/// already walks subscription → group → node with live latency, which is exactly
/// what picking a hop needs. Reusing it also means the two screens cannot drift
/// apart in how they present a node.
///
/// The two entries above the list are the ones a card cannot express: following
/// the main selector (a policy group, not a node) and a direct connection.
Future<void> showChainHopPicker({
  required BuildContext context,
  required String title,
  required bool allowFollowMain,
  required Set<String> excludeNames,
  required void Function(String name) onSelect,
}) {
  void pick(BuildContext ctx, String value) {
    onSelect(value);
    Navigator.of(ctx).pop();
  }

  return showDialog(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              if (allowFollowMain)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.auto_awesome, size: 18),
                  title: const Text('跟随主选择', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    '使用当前节点选择组，随主界面切换而变化',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () => pick(ctx, ''),
                ),
              ListTile(
                dense: true,
                leading: Icon(Icons.bolt, size: 18, color: colors.primary),
                title: const Text('DIRECT', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  '这一跳不经过任何节点',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () => pick(ctx, 'DIRECT'),
              ),
              const Divider(height: 1),
              Flexible(
                child: SwitchCard(
                  excludeNames: excludeNames,
                  onSelect: (name, _) => pick(ctx, name),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
