import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class RequestsView extends ConsumerStatefulWidget {
  /// 合并页面用：把标题位置让给「请求 / 连接」切换器。
  ///
  /// 只换标题，页面自己的搜索、动作和滚动状态全部保留——两页共用一套
  /// 头部结构，而不是把两个 Scaffold 嵌套起来。
  final Widget? titleWidgetOverride;

  const RequestsView({super.key, this.titleWidgetOverride});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView> {
  late final ScrollController _scrollController;
  var _autoScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ReverseScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(requestsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(requestsKeywordsProvider.notifier).state = keywords;
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

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(filteredRequestsProvider);
    final hasRequests = requests.isNotEmpty;

    return CommonScaffold(
      title: widget.titleWidgetOverride == null
          ? appLocalizations.requests
          : null,
      titleWidget: widget.titleWidgetOverride,
      actions: [
        IconButton(
          onPressed: () {
            ref.read(requestsProvider.notifier).clearRequests();
          },
          tooltip: appLocalizations.clear,
          icon: const Icon(Icons.delete_sweep_outlined),
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
      ],
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      body: !hasRequests
          ? NullStatus(
              label: appLocalizations.nullTip(appLocalizations.requests),
            )
          : CommonScrollBar(
              trackVisibility: false,
              controller: _scrollController,
              child: ScrollToEndBox(
                controller: _scrollController,
                dataSource: requests,
                enable: _autoScrollToEnd,
                reverse: true,
                onCancelToEnd: _cancelAutoScroll,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ListView.builder(
                    reverse: true,
                    shrinkWrap: requests.length < 20,
                    physics: const NextClampingScrollPhysics(),
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    itemBuilder: (context, index) {
                      final trackerInfo = requests[index];
                      return TrackerInfoItem(
                        key: ValueKey(trackerInfo.id),
                        index: index,
                        count: requests.length,
                        reversed: true,
                        trackerInfo: trackerInfo,
                        onClickKeyword: (value) {
                          context.commonScaffoldState?.addKeyword(value);
                        },
                        detailTitle: appLocalizations.details,
                      );
                    },
                    itemExtentBuilder: (index, _) {
                      return TrackerInfoItem.height + 1;
                    },
                    itemCount: requests.length,
                  ),
                ),
              ),
            ),
    );
  }
}
