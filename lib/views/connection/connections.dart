import 'dart:async';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'item.dart';

enum _ConnectionScope { active, closed, all }

class ConnectionsView extends ConsumerStatefulWidget {
  final bool respectCurrentPage;
  final bool startWithHistory;

  const ConnectionsView({
    super.key,
    this.respectCurrentPage = true,
    this.startWithHistory = false,
  });

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with WidgetsBindingObserver, WindowListener {
  late final ScrollController _scrollController;
  Timer? _timer;
  ProviderSubscription? _pageLabelSubscription;
  final _connectionUpdateGate = SerialTaskGate();
  late var _scope = widget.startWithHistory
      ? _ConnectionScope.closed
      : _ConnectionScope.active;
  var _network = 'all';
  var _autoScrollToEnd = false;

  bool get _isForeground {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    globalState.backgroundMode.addListener(_handleBackgroundModeChanged);
    if (system.isDesktop) {
      windowManager.addListener(this);
    }
    _pageLabelSubscription = ref.listenManual(currentPageLabelProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        unawaited(_syncUpdateTimer());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncUpdateTimer());
    });
  }

  @override
  void dispose() {
    _pageLabelSubscription?.close();
    globalState.backgroundMode.removeListener(_handleBackgroundModeChanged);
    if (system.isDesktop) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _shouldRunTimer() async {
    if (!mounted) return false;
    if (globalState.backgroundMode.value) {
      return false;
    }
    if (widget.respectCurrentPage &&
        ref.read(currentPageLabelProvider) != PageLabel.connections) {
      return false;
    }
    if (!_isForeground) {
      return false;
    }
    if (system.isDesktop && await window?.isVisible == false) {
      return false;
    }
    return true;
  }

  Future<void> _syncUpdateTimer() async {
    final shouldRun = await _shouldRunTimer();
    if (!mounted) return;
    if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) {
      return;
    }
    await _updateConnections();
    if (!mounted || !await _shouldRunTimer()) {
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_updateConnections());
    });
  }

  Future<void> _updateConnections() async {
    try {
      await _connectionUpdateGate.run(_refreshConnectionsOnce);
    } catch (e) {
      commonPrint.log('Connections refresh failed: $e');
    }
  }

  Future<void> _refreshConnectionsOnce() async {
    if (!mounted || !await _shouldRunTimer()) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final connections = clashCore.hasLiveProcess
        ? await clashCore.getConnections()
        : const <TrackerInfo>[];
    if (!mounted || !await _shouldRunTimer()) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final oldConnections = ref.read(connectionsProvider);
    final oldMap = {for (final e in oldConnections) e.id: e};
    var hasChanges = oldConnections.length != connections.length;
    final newConnections = connections.map((item) {
      final oldItem = oldMap[item.id];
      if (oldItem != null) {
        final upSpeed = item.upload - oldItem.upload;
        final downSpeed = item.download - oldItem.download;
        final newItem = item.copyWith(
          uploadSpeed: upSpeed > 0 ? upSpeed : 0,
          downloadSpeed: downSpeed > 0 ? downSpeed : 0,
        );
        if (newItem != oldItem) hasChanges = true;
        return newItem;
      }
      hasChanges = true;
      return item.copyWith(uploadSpeed: 0, downloadSpeed: 0);
    }).toList();
    if (hasChanges) {
      ref.read(connectionsProvider.notifier).state = newConnections;
    }
  }

  void _handleBackgroundModeChanged() {
    unawaited(_syncUpdateTimer());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_syncUpdateTimer());
  }

  @override
  void onWindowMinimize() {
    unawaited(_syncUpdateTimer());
  }

  @override
  void onWindowRestore() {
    unawaited(_syncUpdateTimer());
  }

  Future<void> _handleBlockConnection(String id) async {
    clashCore.closeConnection(id);
    await _updateConnections();
  }

  void _handleCloseAll() async {
    clashCore.closeConnections();
    await _updateConnections();
  }

  void _onSearch(String value) {
    ref.read(connectionsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(connectionsKeywordsProvider.notifier).state = keywords;
  }

  void _changeScope(_ConnectionScope scope) {
    setState(() {
      _scope = scope;
      _autoScrollToEnd = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      backgroundColor: FluxoraMaterial.of(context).enabled
          ? context.colorScheme.surface
          : null,
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      actions: [
        if (_scope == _ConnectionScope.closed) ...[
          IconButton(
            onPressed: ref.read(requestsProvider.notifier).clearRequests,
            tooltip: appLocalizations.clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            isSelected: _autoScrollToEnd,
            onPressed: () =>
                setState(() => _autoScrollToEnd = !_autoScrollToEnd),
            tooltip: appLocalizations.autoScroll,
            icon: const Icon(Icons.vertical_align_top_outlined),
          ),
        ] else ...[
          IconButton(
            onPressed: _handleCloseAll,
            tooltip: appLocalizations.closeAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: appLocalizations.connectionsSort,
            onPressed: () async {
              final currentSortType = ref.read(connectionsSortProvider);
              final selectedSortType = await globalState
                  .showCommonDialog<ConnectionsSortType>(
                    child: OptionsDialog<ConnectionsSortType>(
                      title: appLocalizations.connectionsSort,
                      options: ConnectionsSortType.values
                          .where(
                            (sortType) =>
                                sortType != ConnectionsSortType.creationTime,
                          )
                          .toList(),
                      value: currentSortType,
                      textBuilder: (sortType) {
                        return switch (sortType) {
                          ConnectionsSortType.defaultSort =>
                            appLocalizations.defaultSort,
                          ConnectionsSortType.realTimeSpeed =>
                            appLocalizations.realTimeSpeed,
                          ConnectionsSortType.totalTraffic =>
                            appLocalizations.totalTraffic,
                          ConnectionsSortType.creationTime =>
                            appLocalizations.creationTime,
                        };
                      },
                    ),
                  );
              if (selectedSortType != null &&
                  selectedSortType != currentSortType) {
                ref.read(connectionsSortProvider.notifier).state =
                    selectedSortType;
              }
            },
            icon: const Icon(Icons.sort),
          ),
        ],
      ],
      body: Consumer(
        builder: (_, ref, _) {
          final chinese = Localizations.localeOf(context).languageCode == 'zh';
          final live = ref.watch(filteredConnectionsProvider);
          final history = ref.watch(filteredConnectionHistoryProvider);
          // The close event can arrive a frame before the next live snapshot.
          final closedIds = ref
              .watch(requestsProvider.select((state) => state.list))
              .map((item) => item.id)
              .toSet();
          bool matchesNetwork(TrackerInfo item) =>
              _network == 'all' ||
              item.metadata.network.toLowerCase() == _network;
          final seen = <String>{};
          final rows = <(TrackerInfo, bool)>[
            if (_scope != _ConnectionScope.closed)
              for (final item in live)
                if (!closedIds.contains(item.id) &&
                    matchesNetwork(item) &&
                    seen.add(item.id))
                  (item, true),
            if (_scope != _ConnectionScope.active)
              for (final item in history)
                if (matchesNetwork(item) && seen.add(item.id)) (item, false),
          ];

          final list = CommonScrollBar(
            controller: _scrollController,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                bottom: 16 + getFloatingBottomBarReserveHeight(context),
                top: 8,
              ),
              itemBuilder: (context, index) {
                final (trackerInfo, active) = rows[index];
                return TrackerInfoItem(
                  key: ValueKey(trackerInfo.id),
                  index: index,
                  count: rows.length,
                  trackerInfo: trackerInfo,
                  onClickKeyword: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                  trailing: active
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          style: const ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size.zero),
                          ),
                          icon: const Icon(Icons.block),
                          onPressed: () =>
                              _handleBlockConnection(trackerInfo.id),
                        )
                      : _scope == _ConnectionScope.all
                      ? Tooltip(
                          message: chinese ? '已关闭' : 'Closed',
                          child: const Icon(Icons.history, size: 18),
                        )
                      : null,
                  detailTitle: appLocalizations.details,
                );
              },
              itemExtentBuilder: (index, _) {
                return TrackerInfoItem.height + 1;
              },
              itemCount: rows.length,
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryFilterBar(
                key: const ValueKey('connection-category-strip'),
                children: [
                  for (final scope in _ConnectionScope.values)
                    CategoryFilterChip(
                      label: switch (scope) {
                        _ConnectionScope.active => chinese ? '活跃' : 'Active',
                        _ConnectionScope.closed => chinese ? '已关闭' : 'Closed',
                        _ConnectionScope.all => appLocalizations.filterAll,
                      },
                      selected: _scope == scope,
                      onSelected: (_) => _changeScope(scope),
                    ),
                  const SizedBox(height: 20, child: VerticalDivider(width: 8)),
                  for (final network in ['all', 'tcp', 'udp'])
                    CategoryFilterChip(
                      label: network == 'all'
                          ? (chinese ? '不限协议' : 'Any protocol')
                          : network.toUpperCase(),
                      selected: _network == network,
                      onSelected: (selected) =>
                          setState(() => _network = selected ? network : 'all'),
                    ),
                ],
              ),
              Expanded(
                child: rows.isEmpty
                    ? FluxoraEmptyState(
                        title: appLocalizations.nullTip(
                          appLocalizations.connections,
                        ),
                      )
                    : ScrollToEndBox(
                        controller: _scrollController,
                        dataSource: rows,
                        enable:
                            _scope == _ConnectionScope.closed &&
                            _autoScrollToEnd,
                        onCancelToEnd: () {
                          if (_autoScrollToEnd) {
                            setState(() => _autoScrollToEnd = false);
                          }
                        },
                        child: list,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
