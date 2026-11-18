import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';

class LogsView extends ConsumerStatefulWidget {
  /// 历史日志的来源。为空时走内核（生产路径）；测试注入假数据，
  /// 这样布局用例不需要真的内核二进制。
  final Future<List<Log>> Function()? historyLoader;

  const LogsView({super.key, this.historyLoader});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  late final ScrollController _scrollController;
  var _autoScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ReverseScrollController();
    // item 6 — the core only *streams* logs once `openLogs` is on, so a page
    // opened afterwards used to start from an empty list even though the core
    // had been talking the whole time. Pull the buffered history first.
    //
    // Deferred to after the first frame: this is async and touches a provider,
    // and `setLogs` bails out if the page has already gone away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedHistoryFromCore();
    });
  }

  Future<void> _seedHistoryFromCore() async {
    // Only pull when the core is actually up. `invoke` is happy to (re)start the
    // core process to satisfy a request, which in a fresh desktop session means
    // spawning `FluxoraDevCore.exe` just to read a log — and in tests it throws
    // a `ProcessException` after the test has finished.
    final loader = widget.historyLoader;
    final List<Log> history;
    try {
      if (loader != null) {
        history = await loader();
      } else {
        // 用被动标志：`isInit` 会为了回答这个问题去启动内核。
        if (!clashCore.hasLiveProcess) return;
        history = await clashCore.getLogs();
      }
    } catch (_) {
      // Reading history is best-effort: the page still works off the stream.
      return;
    }
    if (!mounted || history.isEmpty) return;
    // The core snapshot is authoritative for core logs. The provider also keeps
    // app messages, which are not part of that snapshot.
    ref.read(logsProvider.notifier).setLogs(history);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(logsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(logsKeywordsProvider.notifier).state = keywords;
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollToEnd = !_autoScrollToEnd;
    });
  }

  void _cancelAutoScroll() {
    if (_autoScrollToEnd) {
      setState(() {
        _autoScrollToEnd = false;
      });
    }
  }

  Future<void> _handleLogLevelSettings() async {
    final currentLogLevel = ref.read(
      patchClashConfigProvider.select((state) => state.logLevel),
    );

    final selectedLogLevel = await globalState.showCommonDialog<LogLevel>(
      child: OptionsDialog<LogLevel>(
        title: appLocalizations.logLevel,
        options: LogLevel.values,
        value: currentLogLevel,
        textBuilder: (logLevel) => logLevel.name,
      ),
    );

    if (selectedLogLevel != null && selectedLogLevel != currentLogLevel) {
      ref
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => state.copyWith(logLevel: selectedLogLevel));
      globalState.appController.updateClashConfigDebounce();
    }
  }

  Future<void> _handleExport() async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        return await globalState.appController.exportLogs();
      },
      needLoading: true,
      title: appLocalizations.exportLogs,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
      cancelable: false,
    );
  }

  void _handleClearLogs() {
    ref.read(logsProvider.notifier).clearLogs();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(filteredLogsProvider);
    final category = ref.watch(logsCategoryFilterProvider);
    final modules = ref.watch(logsModulesProvider);
    final hasLogs = logs.isNotEmpty;
    // The list is `reverse: true`, so index 0 — the **newest** line — renders at
    // the visual bottom, exactly where the floating dock sits. Every other
    // scrollable page reserves the dock through
    // `getFloatingBottomBarReserveHeight`; this one only ever had a flat 16 px,
    // which left the newest line behind the dock on a phone.
    final isMobileView = ref.watch(isMobileViewProvider);
    return CommonScaffold(
      backgroundColor: FluxoraMaterial.of(context).enabled
          ? context.colorScheme.surface
          : null,
      actions: [
        IconButton(
          onPressed: _handleLogLevelSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: appLocalizations.logLevel,
        ),
        IconButton(
          style: _autoScrollToEnd
              ? ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    context.colorScheme.secondaryContainer,
                  ),
                )
              : null,
          onPressed: _toggleAutoScroll,
          tooltip: appLocalizations.autoScroll,
          icon: const Icon(Icons.vertical_align_top_outlined),
        ),
        Tooltip(
          message: appLocalizations.export,
          child: InkWell(
            onTap: _handleExport,
            onLongPress: _handleClearLogs,
            borderRadius: BorderRadius.circular(FluxoraRadius.full),
            child: const Padding(
              padding: EdgeInsets.all(FluxoraSpacing.md),
              child: Icon(Icons.save_as_outlined, size: 24),
            ),
          ),
        ),
      ],
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryFilterBar(
            key: const ValueKey('log-category-strip'),
            children: [
              for (final option in <String?>[
                null,
                'APP',
                'CORE',
                ...modules,
                if (category != null &&
                    category != 'APP' &&
                    category != 'CORE' &&
                    !modules.contains(category))
                  category,
              ])
                CategoryFilterChip(
                  key: ValueKey(option),
                  label: switch (option) {
                    null => appLocalizations.filterAll,
                    'APP' => appLocalizations.app,
                    'CORE' => appLocalizations.core,
                    final String name => name,
                  },
                  selected: category == option,
                  onSelected: (selected) =>
                      ref.read(logsCategoryFilterProvider.notifier).state =
                          selected ? option : null,
                ),
            ],
          ),
          Expanded(
            child: !hasLogs
                ? FluxoraEmptyState(
                    title: appLocalizations.nullTip(appLocalizations.logs),
                  )
                : ScrollToEndBox(
                    onCancelToEnd: _cancelAutoScroll,
                    controller: _scrollController,
                    enable: _autoScrollToEnd,
                    reverse: true,
                    dataSource: logs,
                    child: CommonScrollBar(
                      controller: _scrollController,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ListView.builder(
                          physics: const NextClampingScrollPhysics(),
                          reverse: true,
                          shrinkWrap: logs.length < 20,
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            bottom:
                                16 +
                                (isMobileView
                                    ? getFloatingBottomBarReserveHeight(context)
                                    : 0),
                            top: 8,
                          ),
                          itemExtentBuilder: (index, _) {
                            return LogItem.height + 1;
                          },
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return LogItem(
                              index: index,
                              count: logs.length,
                              reversed: true,
                              log: log,
                              onClick: (value) =>
                                  ref
                                          .read(
                                            logsCategoryFilterProvider.notifier,
                                          )
                                          .state =
                                      value,
                            );
                          },
                          itemCount: logs.length,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;
  final int index;
  final int count;
  final bool reversed;

  static double get height {
    final measure = globalState.measure;
    return measure.bodyLargeHeight * 2 + measure.labelMediumHeight + 64;
  }

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
    required this.index,
    required this.count,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ContinuousListItem(
        index: index,
        count: count,
        reversed: reversed,
        child: ListItem(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () {
            globalState.showCommonDialog(child: LogDetailDialog(log: log));
          },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Row(
                spacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 116),
                    child: CommonChip(
                      avatar: Tooltip(
                        message: log.logLevel.name,
                        child: Icon(
                          switch (log.logLevel) {
                            LogLevel.error => Icons.error_outline_rounded,
                            LogLevel.warning => Icons.warning_amber_rounded,
                            _ => Icons.circle,
                          },
                          size: switch (log.logLevel) {
                            LogLevel.error || LogLevel.warning => 13,
                            _ => 7,
                          },
                          color: log.logLevel.colorOf(context),
                        ),
                      ),
                      onPressed: () => onClick?.call(log.category),
                      label: log.category,
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Tooltip(
                      message: log.dateTime,
                      child: Text(
                        log.dateTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              EmojiText(
                log.message.isEmpty ? log.payload : log.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogDetailDialog extends StatelessWidget {
  final Log log;

  const LogDetailDialog({super.key, required this.log});

  Future<void> _searchWithAi(BuildContext context) async {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final payload = log.payload.toLowerCase();
    final topics = const [
      'dns',
      'resolver',
      'tls',
      'handshake',
      'connection refused',
      'deadline exceeded',
    ].where(payload.contains);
    final query = await showDialog<String>(
      context: context,
      builder: (_) => InputDialog(
        title: chinese ? 'AI 搜索' : 'AI search',
        labelText: chinese ? '将发送给 Google 的问题' : 'Query sent to Google',
        hintText: chinese
            ? '请勿粘贴密钥或订阅链接'
            : 'Omit secrets and subscription URLs',
        value: ['Mihomo', log.logLevel.name, ...topics].join(' '),
        maxLines: 4,
      ),
    );
    if (query == null || query.trim().isEmpty) return;
    await globalState.openSafeWebUrl(
      Uri.https('www.google.com', '/search', {
        'q': query.trim(),
        'udm': '50',
      }).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.details,
      actions: [
        TextButton.icon(
          onPressed: () => _searchWithAi(context),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? 'AI 搜索'
                : 'AI search',
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          SelectableText(
            log.payload,
            style: context.textTheme.bodyLarge?.copyWith(
              color: log.logLevel.colorOf(context),
            ),
          ),
          SelectableText(
            log.dateTime,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
