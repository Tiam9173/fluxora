import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/views/proxies/common.dart';
import 'card.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Compact "switch" card: the proxy page in miniature.
///
/// Three levels, in the order the user thinks in — subscription, then group,
/// then node. The data comes from exactly the same providers the proxy page
/// reads, and the delay test is the same `delayTest` call, so a number shown
/// here is the number shown there.
void showNotificationSwitchCard(BuildContext context, {VoidCallback? onStart}) {
  globalState.showCommonDialog(
    child: SwitchCard(
      onStart: onStart,
      onOpenProfiles: () {
        globalState.navigatorKey.currentState?.pop();
        globalState.appController.toPage(PageLabel.profiles);
      },
    ),
  );
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
    this.onOpenProfiles,
    this.onStart,
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
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onStart;

  @override
  ConsumerState<SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends ConsumerState<SwitchCard> {
  final _nodesController = ScrollController();
  final _searchController = TextEditingController();
  String? _groupName;
  bool _showProfiles = false;
  bool _testing = false;
  String? _pendingNode;
  String? _selectionError;

  bool get _selecting => _pendingNode != null;

  void _jumpToListStart() {
    if (_nodesController.hasClients) _nodesController.jumpTo(0);
  }

  @override
  void dispose() {
    _nodesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final defaultTestUrl = ref.watch(getRealTestUrlProvider());
    final fromHome = widget.onStart != null;
    final busy =
        fromHome &&
        (ref.watch(isRestartingCoreProvider) ||
            ref.watch(connectionTargetProvider) != null);
    final running =
        fromHome &&
        ref.watch(runTimeProvider.select((runtime) => runtime != null));
    final canStart = fromHome && !running && !busy && currentProfileId != null;

    final profile = profiles.where((e) => e.id == currentProfileId).firstOrNull;
    final visibleGroups = groups.where((g) => g.hidden != true).toList();
    final mode = fromHome
        ? ref.watch(patchClashConfigProvider.select((state) => state.mode))
        : null;
    final initialGroup = mode == Mode.global
        ? GroupName.GLOBAL.name
        : profile?.currentGroupName;
    // Fall back to whatever the core says is current, then to the first group:
    // the group list is replaced wholesale when the subscription changes.
    final currentGroup =
        visibleGroups.where((g) => g.name == _groupName).firstOrNull ??
        visibleGroups.where((g) => g.name == initialGroup).firstOrNull ??
        (visibleGroups.isEmpty ? null : visibleGroups.first);
    final nodes =
        currentGroup?.all
            .where((p) => !widget.excludeNames.contains(p.name))
            .where(
              (p) =>
                  widget.onSelect == null ||
                  ChainProxyConfig.isSelectableProxy(
                    name: p.name,
                    type: p.type,
                  ),
            )
            .toList() ??
        [];
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? nodes
        : nodes
              .where((node) => node.name.toLowerCase().contains(query))
              .toList();
    final selectedName = currentGroup?.getCurrentSelectedName(
      selectedMap[currentGroup.name] ?? '',
    );
    final delayUrl = ref.watch(
      getRealTestUrlProvider(currentGroup?.testUrl ?? defaultTestUrl),
    );
    final showsSelectedNode =
        query.isEmpty || visible.any((node) => node.name == selectedName);
    final rowHeight =
        12 + MediaQuery.textScalerOf(context).scale(16).clamp(36.0, 96.0);

    return CommonDialog(
      maxWidth: 440,
      title:
          widget.title ??
          (fromHome
              ? appLocalizations.cardNodeSelect
              : appLocalizations.switchProxy),
      titleTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('switch-card-locate'),
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? '定位当前节点'
                : 'Locate current node',
            icon: const Icon(Icons.my_location_rounded, size: 20),
            onPressed:
                currentGroup == null || busy || _selecting || query.isNotEmpty
                ? null
                : () {
                    final index = visible.indexWhere(
                      (node) => node.name == selectedName,
                    );
                    if (index < 0 || !_nodesController.hasClients) return;
                    final position = _nodesController.position;
                    final target =
                        (index * rowHeight - position.viewportDimension / 3)
                            .clamp(
                              position.minScrollExtent,
                              position.maxScrollExtent,
                            );
                    final motion = FluxoraMotion.ofContext(context);
                    if (motion.reduceMotion) {
                      _nodesController.jumpTo(target);
                      return;
                    }
                    _nodesController.animateTo(
                      target,
                      duration: motion.base,
                      curve: Curves.easeOutCubic,
                    );
                  },
          ),
          if (widget.onOpenProfiles != null && widget.onSelect == null)
            IconButton(
              key: const ValueKey('switch-card-profiles'),
              tooltip: appLocalizations.profiles,
              onPressed: _selecting || busy ? null : widget.onOpenProfiles,
              icon: const Icon(Icons.folder_open_outlined),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: appLocalizations.startTest,
            onPressed: currentGroup == null || _testing || _selecting || busy
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
        ],
      ),
      actions: [
        TextButton(
          // 卡片模式下这张卡片就是根节点，没有 dialog 可 pop：只 pop 会让
          // 「确定」变成死按钮，卡片永远关不掉，Activity 也就一直留着。
          onPressed: () {
            final finished = widget.onFinished;
            if (finished != null) {
              finished();
            } else {
              globalState.navigatorKey.currentState?.pop();
            }
          },
          child: Text(
            fromHome ? appLocalizations.close : appLocalizations.confirm,
          ),
        ),
        if (canStart)
          FilledButton(
            key: const ValueKey('switch-card-start'),
            onPressed:
                _selecting || _selectionError != null || !showsSelectedNode
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onStart?.call();
                  },
            child: Text(appLocalizations.start),
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
              onTap: _selecting || busy
                  ? null
                  : () => setState(() => _showProfiles = !_showProfiles),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                          fontSize: FluxoraFontSize.compact,
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
                      onTap: _selecting || busy
                          ? null
                          : () {
                              // Same one-liner the profiles page uses; the controller
                              // listens and applies the profile (core reload).
                              ref
                                      .read(currentProfileIdProvider.notifier)
                                      .value =
                                  item.id;
                              setState(() {
                                _showProfiles = false;
                                _groupName = null;
                                _selectionError = null;
                                _searchController.clear();
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
          if (!busy &&
              currentGroup != null &&
              currentGroup.type.isComputedSelected &&
              widget.onSelect == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IgnorePointer(
                    ignoring: _selecting,
                    child: GroupSelectionControl(group: currentGroup),
                  ),
                  Expanded(
                    child: Text(
                      selectedMap[currentGroup.name]?.isNotEmpty == true
                          ? (Localizations.localeOf(context).languageCode ==
                                    'zh'
                                ? '手动锁定 · 点击恢复自动'
                                : 'Manual lock · resume automatic')
                          : (currentGroup.type == GroupType.Fallback
                                ? 'Fallback'
                                : 'URL test'),
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Level 2 — groups of the current subscription.
          if (!fromHome || visibleGroups.length > 1)
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
                        onTap: _selecting || busy
                            ? null
                            : () {
                                _jumpToListStart();
                                setState(() {
                                  _groupName = group.name;
                                  _selectionError = null;
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: group.name == currentGroup?.name
                                ? colorScheme.primary.withValues(alpha: 0.14)
                                : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
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
          if (!fromHome || visibleGroups.length > 1)
            Divider(height: 1, color: colorScheme.outlineVariant),
          if (fromHome &&
              (nodes.length > 8 || _searchController.text.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                key: const ValueKey('switch-card-search'),
                controller: _searchController,
                enabled: !_selecting && !busy,
                onChanged: (_) {
                  _jumpToListStart();
                  setState(() {});
                },
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: appLocalizations.search,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: _selecting || busy
                              ? null
                              : () {
                                  _jumpToListStart();
                                  setState(_searchController.clear);
                                },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
            ),
          if (_selectionError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _selectionError!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          // Level 3 — nodes.
          Flexible(
            child: busy || currentGroup == null || visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(FluxoraSpacing.xl),
                    child: Text(
                      busy
                          ? appLocalizations.init
                          : query.isNotEmpty && nodes.isNotEmpty
                          ? appLocalizations.nodeNoMatches
                          : appLocalizations.noProxy,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      return ListView.builder(
                        controller: _nodesController,
                        itemExtent: rowHeight,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final proxy = visible[index];
                          final selected = selectedName == proxy.name;
                          // Computed groups accept explicit locks; Relay/LoadBalance do not.
                          final selectable =
                              currentGroup.type == GroupType.Selector ||
                              currentGroup.type.isComputedSelected ||
                              widget.onSelect != null;
                          return Semantics(
                            selected: selected,
                            child: InkWell(
                              onTap: selectable && !_selecting
                                  ? () async {
                                      setState(() {
                                        _pendingNode = proxy.name;
                                        _selectionError = null;
                                      });
                                      try {
                                        final handler = widget.onSelect;
                                        if (handler != null) {
                                          handler(
                                            proxy.name,
                                            currentGroup.name,
                                          );
                                        } else {
                                          await globalState.appController
                                              .changeProxy(
                                                groupName: currentGroup.name,
                                                proxyName: proxy.name,
                                              );
                                        }
                                        if (mounted) {
                                          if (running &&
                                              ModalRoute.of(
                                                    this.context,
                                                  )?.isCurrent ==
                                                  true) {
                                            Navigator.of(this.context).pop();
                                          } else {
                                            widget.onFinished?.call();
                                          }
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          setState(
                                            () => _selectionError =
                                                error.formatError,
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _pendingNode = null);
                                        }
                                      }
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 36,
                                  ),
                                  child: Row(
                                    children: [
                                      if (_pendingNode == proxy.name)
                                        const SizedBox.square(
                                          dimension: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
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
                                      _DelayChip(
                                        name: proxy.name,
                                        url: delayUrl,
                                      ),
                                    ],
                                  ),
                                ),
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
class _DelayChip extends ConsumerWidget {
  final String name;
  final String url;

  const _DelayChip({required this.name, required this.url});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(
      delayDataSourceProvider.select((map) => map[url]?[name]),
    );
    return FluxoraLatencyBadge(
      delay: delay,
      timeoutLabel: appLocalizations.timeoutLabel,
      dense: true,
    );
  }
}
