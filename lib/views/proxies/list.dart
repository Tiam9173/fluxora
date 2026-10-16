import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

/// The inputs that must invalidate a cached group sliver.
///
/// Extracted so the invalidation contract is unit-testable — the cache's whole
/// value is that a stale entry can never be served, and the easy mistake is
/// forgetting one of these.
///
/// `delayMap` is deliberately included even though it is not a widget field: the
/// delay sort reads it through `getDelayProvider` while the `Group` instance
/// stays the same across a delay update, so omitting it would freeze the sort
/// order the moment a probe returned a new value.
Object groupSliverCacheKey({
  required bool isExpand,
  required ProxiesSortType sortType,
  required int columns,
  required double itemHeight,
  required Object? delayMap,
}) => (isExpand, sortType, columns, itemHeight, delayMap);

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);

    if (state.groups.isEmpty) {
      return FluxoraEmptyState(
        icon: Icons.dns_outlined,
        title: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }

    return _ProxyGroupsList(
      groups: state.groups,
      columns: state.columns,
      cardType: state.proxyCardType,
      sortType: state.proxiesSortType,
      sortNum: state.sortNum,
      currentUnfoldSet: state.currentUnfoldSet,
    );
  }
}

class _ProxyGroupsList extends ConsumerStatefulWidget {
  final List<Group> groups;
  final int columns;
  final ProxyCardType cardType;
  final ProxiesSortType sortType;
  final num sortNum;
  final Set<String> currentUnfoldSet;

  const _ProxyGroupsList({
    required this.groups,
    required this.columns,
    required this.cardType,
    required this.sortType,
    required this.sortNum,
    required this.currentUnfoldSet,
  });

  @override
  ConsumerState<_ProxyGroupsList> createState() => _ProxyGroupsListState();
}

abstract class _FlatItem {
  double getHeight(double headerHeight, double itemHeight);
}

class _HeaderItem extends _FlatItem {
  final Group group;
  _HeaderItem(this.group);

  @override
  double getHeight(double headerHeight, double itemHeight) => headerHeight;
}

class _SpacingItem extends _FlatItem {
  final double height;
  _SpacingItem(this.height);

  @override
  double getHeight(double headerHeight, double itemHeight) => height;
}

class _RowItem extends _FlatItem {
  final Group group;
  final List<Proxy> proxies;
  _RowItem(this.group, this.proxies);

  @override
  double getHeight(double headerHeight, double itemHeight) => itemHeight + 8.0;
}

class _ProxyGroupsListState extends ConsumerState<_ProxyGroupsList> {
  final ScrollController _scrollController = ScrollController();

  /// item 6 (Bettbox 1.19.4 alignment) — per-group build cache.
  ///
  /// `_buildRowsSliver` re-ran `getSortProxies` for **every expanded group** on
  /// every build, so an unrelated rebuild (the 1 s tick, a delay update, a
  /// selection change) repeated an O(n log n) sort per group. The entry stores
  /// the group instance and every input that shapes the sliver, so a stale entry
  /// can never be served.
  final Map<String, (Group, Object, Widget)> _sliverCache = {};

  /// Everything the cached sliver depends on besides the group itself.
  ///
  /// `delayMap` is in the key because the delay sort reads it through
  /// `getDelayProvider` while the `Group` instance stays the same across a delay
  /// update — without it the sort order would go stale the moment a probe
  /// returned. See [groupSliverCacheKey].
  (Object,) _cacheKeyFor(Group group, double itemHeight) => (
    groupSliverCacheKey(
      isExpand: widget.currentUnfoldSet.contains(group.name),
      sortType: widget.sortType,
      columns: widget.columns,
      itemHeight: itemHeight,
      delayMap: globalState.appState.delayMap,
    ),
  );

  void _invalidateCache() => _sliverCache.clear();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Measure / text-scale changes reshape every row.
    _invalidateCache();
  }

  @override
  void didUpdateWidget(_ProxyGroupsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns != widget.columns ||
        oldWidget.cardType != widget.cardType) {
      _invalidateCache();
    } else if (!identical(oldWidget.groups, widget.groups)) {
      final names = {for (final group in widget.groups) group.name};
      _sliverCache.removeWhere((name, _) => !names.contains(name));
    }
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
    } else {
      tempUnfoldSet.add(groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
  }

  double _getHeaderHeight() {
    final measure = globalState.measure;
    final contentRowHeight = [
      40.0,
      measure.titleMediumHeight + 4 + measure.labelMediumHeight,
    ].reduce((a, b) => a > b ? a : b);
    return 28.0 + contentRowHeight;
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    final headerHeight = _getHeaderHeight();
    final itemHeight = getItemHeight(widget.cardType);

    final tempFlatItems = _buildFlatItems();
    var targetIndex = -1;
    for (var i = 0; i < tempFlatItems.length; i++) {
      final item = tempFlatItems[i];
      if (item is _HeaderItem && item.group.name == groupName) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) return;

    var targetOffset = 0.0;
    for (var i = 0; i < targetIndex; i++) {
      targetOffset += tempFlatItems[i].getHeight(headerHeight, itemHeight);
    }

    final group = widget.groups.firstWhere((g) => g.name == groupName);
    final sortedProxies = globalState.appController.getSortProxies(
      proxies: group.all,
      sortType: widget.sortType,
      testUrl: group.testUrl,
    );
    final proxyIndex = sortedProxies.indexWhere((p) => p.name == selectedName);
    if (proxyIndex >= 0) {
      final rowIndex = proxyIndex ~/ widget.columns;
      targetOffset += headerHeight + 8.0;
      targetOffset += rowIndex * (itemHeight + 8.0);
    }

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  List<_FlatItem> _buildFlatItems() {
    final flatItems = <_FlatItem>[];
    for (final group in widget.groups) {
      flatItems.add(_HeaderItem(group));
      flatItems.add(_SpacingItem(8.0));

      final isExpand = widget.currentUnfoldSet.contains(group.name);
      if (isExpand) {
        final sortedProxies = globalState.appController.getSortProxies(
          proxies: group.all,
          sortType: widget.sortType,
          testUrl: group.testUrl,
        );

        for (var i = 0; i < sortedProxies.length; i += widget.columns) {
          final end = (i + widget.columns < sortedProxies.length)
              ? i + widget.columns
              : sortedProxies.length;
          final chunk = sortedProxies.sublist(i, end);
          flatItems.add(_RowItem(group, chunk));
        }
      }
    }
    return flatItems;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// One row of proxy cards for [group] — the same `Row` of `Expanded` cards the
  /// flat-item builder used to produce.
  Widget _buildRow(Group group, List<Proxy> proxies, double itemHeight) {
    final cardWidgets = <Widget>[];
    for (var i = 0; i < widget.columns; i++) {
      if (i < proxies.length) {
        final proxy = proxies[i];
        cardWidgets.add(
          Expanded(
            child: ProxyCard(
              key: ValueKey('${group.name}.${proxy.name}'),
              proxy: proxy,
              groupName: group.name,
              type: widget.cardType,
              groupType: group.type,
              testUrl: group.testUrl,
            ),
          ),
        );
      } else {
        cardWidgets.add(const Expanded(child: SizedBox()));
      }
    }

    final rowChildren = <Widget>[];
    for (var i = 0; i < cardWidgets.length; i++) {
      rowChildren.add(cardWidgets[i]);
      if (i < cardWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(height: itemHeight, child: Row(children: rowChildren)),
    );
  }

  /// The group's proxy rows, or an empty sliver when the group is collapsed.
  Widget _buildRowsSliver(Group group, double itemHeight) {
    final cacheKey = _cacheKeyFor(group, itemHeight);
    final cached = _sliverCache[group.name];
    if (cached != null &&
        identical(cached.$1, group) &&
        cached.$2 == cacheKey) {
      return cached.$3;
    }

    final sliver = _buildRowsSliverUncached(group, itemHeight);
    _sliverCache[group.name] = (group, cacheKey, sliver);
    return sliver;
  }

  Widget _buildRowsSliverUncached(Group group, double itemHeight) {
    if (!widget.currentUnfoldSet.contains(group.name)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final sortedProxies = globalState.appController.getSortProxies(
      proxies: group.all,
      sortType: widget.sortType,
      testUrl: group.testUrl,
    );
    final rowCount = (sortedProxies.length + widget.columns - 1) ~/
        widget.columns;

    return SliverVariedExtentList.builder(
      itemCount: rowCount,
      itemExtentBuilder: (index, _) => itemHeight + 8.0,
      itemBuilder: (context, index) {
        final start = index * widget.columns;
        final end = (start + widget.columns < sortedProxies.length)
            ? start + widget.columns
            : sortedProxies.length;
        return _buildRow(group, sortedProxies.sublist(start, end), itemHeight);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);
    final headerHeight = _getHeaderHeight();
    final itemHeight = getItemHeight(widget.cardType);
    const horizontal = EdgeInsets.symmetric(horizontal: 16);

    // item 6 (Bettbox 1.19.3 alignment) — group headers are pinned. The previous
    // `ListView.builder` + flat-item model kept them scrolling away; the sliver
    // conversion preserves the same per-item extents, so `_scrollToSelected`'s
    // offset arithmetic is unchanged.
    return CommonScrollBar(
      controller: _scrollController,
      child: CustomScrollView(
        key: const PageStorageKey<String>('proxies_list'),
        controller: _scrollController,
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 16)),
          for (final group in widget.groups) ...[
            SliverPadding(
              padding: horizontal,
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _GroupHeaderDelegate(
                  extent: headerHeight,
                  builder: () {
                    final isExpand = widget.currentUnfoldSet.contains(
                      group.name,
                    );
                    return _GroupHeader(
                      key: ValueKey('header_${group.name}'),
                      group: group,
                      isExpand: isExpand,
                      onToggle: () => _handleToggle(group.name),
                      cardType: widget.cardType,
                      columns: widget.columns,
                      onScrollToSelected: () => _scrollToSelected(group.name),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: horizontal,
              sliver: _buildRowsSliver(group, itemHeight),
            ),
          ],
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  (globalState.isAndroidTV ? 48.0 : 16.0) +
                  (isMobileView ? getFloatingBottomBarReserveHeight(context) : 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pins a `_GroupHeader` at the top of the viewport while its group scrolls.
class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  _GroupHeaderDelegate({required this.extent, required this.builder});

  final double extent;
  final Widget Function() builder;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder();
  }

  // The parent only rebuilds this delegate when its own state (unfold set,
  // filters, card type) changes, so an unconditional rebuild is correct here and
  // avoids comparing closures.
  @override
  bool shouldRebuild(covariant _GroupHeaderDelegate oldDelegate) => true;
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    required this.onToggle,
    required this.cardType,
    required this.columns,
    this.onScrollToSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.iconStyle),
    );
    final icon = ref.watch(proxyIconProvider(group.name));
    final selectedProxyName = ref
        .watch(getSelectedProxyNameProvider(group.name))
        .getSafeValue('');

    final selectedProxyIcon = ref.watch(
      proxyIconProvider(selectedProxyName),
    );

    return FluxoraCard(
      // radius == FluxoraRadius.card (16), matching the previous hardcoded 16.
      filled: true,
      onTap: onToggle,
      // Zero padding keeps the explicit 16/12 inset below, so the list's fixed
      // item extent is unchanged.
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIcon(context, iconStyle, icon),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(group.name, style: context.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        group.type.name,
                        style: context.textTheme.labelMedium?.toLight,
                      ),
                      if (selectedProxyName.isNotEmpty) ...[
                        Text(
                          '  •  ',
                          style: context.textTheme.labelMedium?.toLight,
                        ),
                        if (selectedProxyIcon.isNotEmpty) ...[
                          CommonTargetIcon(
                            src: selectedProxyIcon,
                            size: globalState.measure.labelMediumHeight,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: EmojiText(
                            selectedProxyName,
                            style: context.textTheme.labelMedium?.toLight,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isExpand) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.adjust),
                onPressed: onScrollToSelected,
                tooltip: appLocalizations.locate,
              ),
              AnimatedBuilder(
                animation: delayTestCoordinator,
                builder: (_, _) {
                  final isTestingThisGroup = delayTestCoordinator
                      .isTestingGroup(group.name);
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: isTestingThisGroup
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping),
                    onPressed: delayTestCoordinator.isTesting
                        ? null
                        : () => _delayTest(context),
                    tooltip: appLocalizations.startTest,
                  );
                },
              ),
            ],
            IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              icon: CommonExpandIcon(expand: isExpand),
              onPressed: onToggle,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return context.colorScheme.primary.withValues(alpha: 0.2);
                  }
                  return null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, ProxiesIconStyle style, String icon) {
    if (style == ProxiesIconStyle.none) return const SizedBox();
    const iconSize = 40.0;
    if (style == ProxiesIconStyle.standard) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.secondaryContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(src: icon, size: iconSize - 12),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      child: CommonTargetIcon(src: icon, size: iconSize - 8),
    );
  }

  Future<void> _delayTest(BuildContext context) async {
    await delayTest(group.all, testUrl: group.testUrl, groupName: group.name);
  }
}
