import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/l10n/chain_proxy_l10n.dart';
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

  @override
  Widget build(BuildContext context) {
    final params = (role: widget.role, sortMode: _sortMode);
    final viewModels = ref.watch(adaptiveRankingProvider(params));

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
                  label: Text('鏅鸿兘'),
                  icon: Icon(Icons.auto_awesome),
                ),
                ButtonSegment(
                  value: 'latency',
                  label: Text('寤惰繜'),
                  icon: Icon(Icons.speed),
                ),
                ButtonSegment(
                  value: 'name',
                  label: Text('鍚嶇О'),
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
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: viewModels.length + 2,
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

                final vm = viewModels[index - 2];
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
