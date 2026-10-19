import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/common.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Compact "switch" card: the proxy page in miniature.
///
/// Three levels, in the order the user thinks in — subscription, then group,
/// then node. The data comes from exactly the same providers the proxy page
/// reads, and the delay test is the same `delayTest` call, so a number shown
/// here is the number shown there.
void showNotificationSwitchCard(BuildContext context) {
  globalState.showCommonDialog(child: const SwitchCard());
}

/// A row above the group list for values that are not nodes: following the main
/// selector (a policy group) or a direct connection. The card cannot express
/// those, and dropping them would silently remove the most common choice.
class SwitchCardSpecialOption {
  const SwitchCardSpecialOption({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class SwitchCard extends ConsumerStatefulWidget {
  const SwitchCard({
    super.key,
    this.onFinished,
    this.onSelect,
    this.excludeNames = const {},
    this.title,
    this.specialOptions = const [],
  });

  /// Called once a node has been picked, so the host can dismiss itself.
  final VoidCallback? onFinished;

  /// What a node tap does. Defaults to switching the live proxy, which is what
  /// the notification card is for; the chain passes its own handler so the same
  /// browsing UI can pick a hop instead.
  final void Function(String nodeName, String groupName)? onSelect;

  /// Nodes that must not be offered. The chain uses this to keep one node from
  /// appearing twice in the same path, which would create a self-reference.
  final Set<String> excludeNames;

  /// Dialog title. The card defaults to 「切换」, which reads wrong when it is
  /// being used to pick a hop rather than to switch the live proxy.
  final String? title;

  /// Rows shown above the subscription/group list.
  final List<SwitchCardSpecialOption> specialOptions;

  @override
  ConsumerState<SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends ConsumerState<SwitchCard> {
  String? _groupName;
  bool _showProfiles = false;
  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final groups = ref.watch(groupsProvider);
    final delayMap = ref.watch(delayDataSourceProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final defaultTestUrl = ref.watch(getRealTestUrlProvider());

    final profile = profiles.where((e) => e.id == currentProfileId).firstOrNull;
    final visibleGroups = groups.where((g) => g.hidden != true).toList();
    // Fall back to whatever the core says is current, then to the first group:
    // the group list is replaced wholesale when the subscription changes.
    final currentGroup = visibleGroups.where((g) => g.name == _groupName).firstOrNull ??
        visibleGroups.where((g) => g.name == globalState.appController.getCurrentGroupName()).firstOrNull ??
        (visibleGroups.isEmpty ? null : visibleGroups.first);

    return CommonDialog(
      title: widget.title ?? appLocalizations.switchProxy,
      titleTrailing: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: currentGroup == null || _testing
            ? null
            : () async {
                setState(() => _testing = true);
                try {
                  await delayTest(
                    currentGroup.all,
                    testUrl: currentGroup.testUrl ?? defaultTestUrl,
                    groupName: currentGroup.name,
                  );
                } finally {
                  if (mounted) setState(() => _testing = false);
                }
              },
        icon: _testing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 20),
      ),
      actions: [
        TextButton(
          onPressed: () => globalState.navigatorKey.currentState?.pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
      overrideScroll: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in widget.specialOptions)
            InkWell(
              onTap: () {
                final handler = widget.onSelect;
                if (handler != null) {
                  handler(option.value, '');
                }
                setState(() {});
                widget.onFinished?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(option.icon, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Level 1 — subscription. Hidden when the card is used as a hop
          // picker: the group list always belongs to the active profile, so
          // offering other subscriptions here would switch the whole app
          // without showing anything different.
          if (widget.onSelect == null)
          InkWell(
            onTap: () => setState(() => _showProfiles = !_showProfiles),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile?.label ?? appLocalizations.profiles,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _showProfiles
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_showProfiles)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 132),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final item in profiles)
                    InkWell(
                      onTap: () {
                        // Same one-liner the profiles page uses; the controller
                        // listens and applies the profile (core reload).
                        ref.read(currentProfileIdProvider.notifier).value =
                            item.id;
                        setState(() {
                          _showProfiles = false;
                          _groupName = null;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.id == currentProfileId
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 15,
                              color: item.id == currentProfileId
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label ?? item.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Level 2 — groups of the current subscription.
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final group in visibleGroups)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 5,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _groupName = group.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: group.name == currentGroup?.name
                              ? colorScheme.primary.withValues(alpha: 0.14)
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.4,
                                ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: group.name == currentGroup?.name
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: group.name == currentGroup?.name
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Level 3 — nodes.
          Flexible(
            child: currentGroup == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      appLocalizations.noProxy,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final visible = currentGroup.all
                          .where((p) => !widget.excludeNames.contains(p.name))
                          .toList();
                      return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final proxy = visible[index];
                      final selected =
                          selectedMap[currentGroup.name] == proxy.name ||
                          (selectedMap[currentGroup.name] == null &&
                              currentGroup.now == proxy.name);
                      // url-test / fallback / relay pick their node themselves,
                      // so tapping one would be undone by the core a moment
                      // later. Shown, but not selectable.
                      final selectable = !currentGroup.type.isComputedSelected;
                      // Resolve the same way delayTest does: it stores results
                      // under getRealTestUrl(...), so looking them up by the
                      // raw group URL never matched and every row stayed blank.
                      final delayUrl = globalState.appController.getRealTestUrl(
                        currentGroup.testUrl ?? defaultTestUrl,
                      );
                      final delay = delayMap[delayUrl]?[proxy.name];
                      return InkWell(
                        onTap: selectable
                            ? () {
                                final handler = widget.onSelect;
                                if (handler != null) {
                                  handler(proxy.name, currentGroup.name);
                                } else {
                                  globalState.appController
                                      .changeProxyDebounce(
                                    currentGroup.name,
                                    proxy.name,
                                  );
                                }
                                setState(() {});
                                widget.onFinished?.call();
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 15,
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  proxy.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selectable
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _DelayChip(delay: delay),
                            ],
                          ),
                        ),
                      );
                    },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Latency pill: green / amber / red, with a dash when never measured.
class _DelayChip extends StatelessWidget {
  final int? delay;

  const _DelayChip({this.delay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final value = delay;
    final Color color;
    final String text;
    if (value == null) {
      color = colorScheme.onSurfaceVariant;
      text = '—';
    } else if (value < 0) {
      color = colorScheme.error;
      text = appLocalizations.timeoutLabel;
    } else if (value <= 200) {
      color = const Color(0xFF2E9E5B);
      text = '$value ms';
    } else if (value <= 500) {
      color = const Color(0xFFE0A030);
      text = '$value ms';
    } else {
      color = colorScheme.error;
      text = '$value ms';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
