import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/views/proxies/intelligent_node_card.dart';

class IntelligentNodePickerSheet extends ConsumerStatefulWidget {
  final String title;
  final String currentHop;
  final Set<String> excludedHops;
  final bool allowDirect;
  final bool allowFollowMain;
  final ValueChanged<String> onSelect;
  final FallbackCandidateRole role;
  final SheetType sheetType;

  const IntelligentNodePickerSheet({
    super.key,
    required this.title,
    required this.currentHop,
    required this.excludedHops,
    required this.allowDirect,
    required this.allowFollowMain,
    required this.onSelect,
    required this.role,
    required this.sheetType,
  });

  @override
  ConsumerState<IntelligentNodePickerSheet> createState() =>
      _IntelligentNodePickerSheetState();
}

class _IntelligentNodePickerSheetState
    extends ConsumerState<IntelligentNodePickerSheet> {
  String _sortMode = 'adaptive';

  /// item 2 — groups that must never be offered as an entry hop: the dedicated
  /// chain groups are managed by the chain itself, so picking one would make the
  /// chain reference itself.
  static const Set<String> _excludedHopGroups = {
    '🔗 链式代理',
    '✈️ 链式跳板',
  };

  @override
  void initState() {
    super.initState();
    // item 2 — the picker used to open with no latency at all and no way to
    // obtain any: switching the sort to latency showed the "no data" hint
    // forever, because nothing on this sheet ever probed. Probe once on open
    // when nothing is measured; the hint turns into "probing…" while it runs.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoProbeIfNeeded());
  }

  Future<void> _autoProbeIfNeeded() async {
    if (!mounted) return;
    final viewModels = ref.read(
      adaptiveRankingProvider((role: widget.role, sortMode: _sortMode)),
    );
    if (viewModels.any((vm) => vm.latencyMs != null)) return;
    if (chainProxyManager.isProbingChain) return;
    try {
      await chainProxyManager.probeCurrentChain();
    } catch (e) {
      commonPrint.log('Node picker auto probe failed: $e');
    }
  }

  Future<void> _probeNow() async {
    if (chainProxyManager.isProbingChain) return;
    try {
      await chainProxyManager.probeCurrentChain();
    } catch (e) {
      commonPrint.log('Node picker manual probe failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (role: widget.role, sortMode: _sortMode);
    final viewModels = ref.watch(adaptiveRankingProvider(params));
    // item 2 — the entry hop may target a **policy group**, not only a concrete
    // node. Restored alongside the generation-side support in `chain_proxy`.
    final List<String> groupNames = ref
        .watch(groupsProvider)
        .map((g) => g.name)
        .where((n) => n.isNotEmpty && !_excludedHopGroups.contains(n))
        .toList();
    final int groupSectionCount = groupNames.isEmpty ? 0 : groupNames.length + 1;

    // P2 (option 3): 「延迟」 sorts by each node's **own** latency, which only
    // exists once a real measurement has been recorded. With no measurement the
    // list silently falls back to name order — which reads as "sorted by
    // latency" when nothing was measured. Say so instead of implying the nodes
    // were probed. Deliberately NOT a silent switch to the Smart order: the
    // fallback stays the same stable, predictable name order the comparator
    // defines, and this banner explains why.
    final bool hasAnyLatency = viewModels.any((vm) => vm.latencyMs != null);
    final bool showNoLatencyHint = _sortMode == 'latency' && !hasAnyLatency;

    return AdaptiveSheetScaffold(
      type: widget.sheetType,
      title: widget.title,
      body: Column(
        children: [
          // Sort Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'adaptive',
                  label: Text('智能'),
                  icon: Icon(Icons.auto_awesome),
                ),
                ButtonSegment(
                  value: 'latency',
                  label: Text('延迟'),
                  icon: Icon(Icons.speed),
                ),
                ButtonSegment(
                  value: 'name',
                  label: Text('名称'),
                  icon: Icon(Icons.sort_by_alpha),
                ),
              ],
              selected: {_sortMode},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  setState(() => _sortMode = set.first);
                }
              },
            ),
          ),
          const Divider(height: 1),
          if (showNoLatencyHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      chainProxyManager.isProbingChain
                          ? '正在探测节点延迟…'
                          : '暂无延迟数据：尚未测得任何节点延迟，当前按名称排序',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!chainProxyManager.isProbingChain)
                    TextButton(
                      onPressed: _probeNow,
                      child: Text(appLocalizations.chainProbeNow),
                    ),
                ],
              ),
            ),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: viewModels.length + 2 + groupSectionCount,
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  if (widget.allowFollowMain) {
                    return ListTile(
                      leading: const Icon(Icons.auto_mode, color: Colors.blue),
                      title: Text((() { try { return appLocalizations.followMainSelector; } catch (_) { return 'Follow Main'; } })()),
                      subtitle: Text((() { try { return appLocalizations.defaultDialerProxyDesc; } catch (_) { return 'Default dialer desc'; } })()),
                      trailing: widget.currentHop.isEmpty
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        widget.onSelect('');
                        Navigator.of(ctx).pop();
                      },
                    );
                  }
                  return const SizedBox.shrink();
                }
                if (index == 1) {
                  if (widget.allowDirect) {
                    return ListTile(
                      leading:
                          const Icon(Icons.directions, color: Colors.green),
                      title: Text((() { try { return appLocalizations.directConnection; } catch (_) { return 'DIRECT'; } })()),
                      trailing: widget.currentHop == 'DIRECT'
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        widget.onSelect('DIRECT');
                        Navigator.of(ctx).pop();
                      },
                    );
                  }
                  return const SizedBox.shrink();
                }

                // item 2 — policy-group entries, shown as their own section
                // between DIRECT and the concrete nodes.
                if (index >= 2 && index < 2 + groupSectionCount) {
                  final int groupIndex = index - 2;
                  if (groupIndex == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        (() {
                          try {
                            return appLocalizations.proxyGroup;
                          } catch (_) {
                            return 'Proxy Group';
                          }
                        })(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  final String groupName = groupNames[groupIndex - 1];
                  final bool isGroupExcluded = widget.excludedHops.contains(
                    groupName,
                  );
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(groupName),
                    trailing: widget.currentHop == groupName
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    enabled: !isGroupExcluded,
                    onTap: isGroupExcluded
                        ? null
                        : () {
                            widget.onSelect(groupName);
                            Navigator.of(ctx).pop();
                          },
                  );
                }

                final vm = viewModels[index - 2 - groupSectionCount];
                final isExcluded = widget.excludedHops.contains(vm.nodeName);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: IntelligentNodeCard(
                    viewModel: vm,
                    forceSelected: vm.nodeName == widget.currentHop, groupName: '',
                    isDisabled: isExcluded,
                    onTap: isExcluded
                        ? null
                        : () {
                            widget.onSelect(vm.nodeName);
                            Navigator.of(ctx).pop();
                          },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
