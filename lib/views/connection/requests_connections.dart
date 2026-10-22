import 'package:fluxora/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connections.dart';
import 'requests.dart';

/// 请求页与连接页合并后的入口。
///
/// 两页本来是两个导航项，内容又是同一件事的两面（正在发生 / 刚刚发生），
/// 分开摆等于让人来回切。这里用标题位置的「请求 | 连接」切换器合并成一个入口。
///
/// 注意这不是把两个 Scaffold 套在一起：切换器作为 `titleWidgetOverride`
/// 交给当前那一页，页面自己的搜索、动作和滚动状态都原样保留，只是标题让位。
class RequestsConnectionsView extends ConsumerStatefulWidget {
  /// 外部打开时直接落在连接页（例如首页的"连接数"点进来）。
  final bool startOnConnections;

  const RequestsConnectionsView({super.key, this.startOnConnections = false});

  @override
  ConsumerState<RequestsConnectionsView> createState() =>
      _RequestsConnectionsViewState();
}

class _RequestsConnectionsViewState
    extends ConsumerState<RequestsConnectionsView> {
  late bool _showConnections = widget.startOnConnections;

  Widget _buildTitleItem(String label, bool connections) {
    final isCurrent = _showConnections == connections;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isCurrent
          ? null
          : () {
              setState(() {
                _showConnections = connections;
              });
            },
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? null
            : TextStyle(
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _buildTitleItem(appLocalizations.requests, false)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '|',
            style: TextStyle(
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ),
        Flexible(child: _buildTitleItem(appLocalizations.connections, true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _buildTitle();
    if (_showConnections) {
      return ConnectionsView(titleWidgetOverride: title);
    }
    return RequestsView(titleWidgetOverride: title);
  }
}
