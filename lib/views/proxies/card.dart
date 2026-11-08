import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/common.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:collection/collection.dart';
import 'package:emoji_regex/emoji_regex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/views/proxies/node_details_dialog.dart';

final proxyIconProvider = Provider.family<String, String>((ref, proxyName) {
  if (proxyName.isEmpty) return '';
  final style = ref.watch(
    proxiesStyleSettingProvider.select((s) => s.iconStyle),
  );
  if (style == ProxiesIconStyle.none) return '';

  final iconMap = ref.watch(
    proxiesStyleSettingProvider.select((s) => s.iconMap),
  );
  for (final entry in iconMap.entries) {
    try {
      if (RegExp(entry.key).hasMatch(proxyName)) {
        return entry.value;
      }
    } catch (_) {}
  }

  final groups = ref.watch(groupsProvider);
  return groups.getGroup(proxyName)?.icon ?? '';
});

class ProxyCard extends StatelessWidget {
  static final _emojiRegex = emojiRegex();
  static final Map<String, bool> _emojiMatchCache = {};

  static bool _hasEmoji(String name) {
    return _emojiMatchCache.putIfAbsent(name, () => _emojiRegex.hasMatch(name));
  }

  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  // B4: delegates to the single shared rule so the card's bolt button cannot
  // offer a delay test for `DIRECT`, a proxy group or a shadow node.
  bool get _isNonTestableProxy =>
      !ChainProxyConfig.isSelectableProxy(name: proxy.name, type: proxy.type);

  void _handleTestCurrentDelay() {
    if (_isNonTestableProxy) return;
    proxyDelayTest(proxy, testUrl);
  }

  /// The latency slot handed to [FluxoraProxyTile].
  ///
  /// Preserves the original affordances: a testing spinner (`delay == 0`), a
  /// tap-to-test bolt button (`delay == null`), and the Fluxora latency badge
  /// otherwise. Non-testable nodes (REJECT / PASS / REMATCH) render nothing.
  Widget _buildLatencySlot(BuildContext context) {
    return SizedBox(
      height: measure.labelSmallHeight + 8,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        widthFactor: 1,
        child: Consumer(
          builder: (_, ref, _) {
            final delay = ref.watch(
              getDelayProvider(proxyName: proxy.name, testUrl: testUrl),
            );
            final delayAnimation = ref.watch(
              proxiesStyleSettingProvider.select((s) => s.delayAnimation),
            );

            if (_isNonTestableProxy) {
              return const SizedBox(height: 0, width: 0);
            }

            if (delay == 0) {
              return SizedBox(
                height: measure.labelSmallHeight,
                width: measure.labelSmallHeight,
                child: delayAnimation == DelayAnimationType.none
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : _buildDelayAnimation(
                        delayAnimation,
                        measure.labelSmallHeight,
                        context.colorScheme.primary,
                      ),
              );
            }

            if (delay == null) {
              return SizedBox(
                height: measure.labelSmallHeight + 8,
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.network_ping_rounded),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  tooltip: appLocalizations.startTest,
                  onPressed: _handleTestCurrentDelay,
                ),
              );
            }

            return FluxoraLatencyBadge(
              delay: delay,
              dense: true,
              tintBackground: false,
              timeoutLabel: appLocalizations.timeoutLabel,
              onTap: _handleTestCurrentDelay,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDelayAnimation(
    DelayAnimationType animationType,
    double size,
    Color color,
  ) {
    // Delegates to the shared widget so the proxy card and the synced loading
    // indicators cannot drift apart.
    return DelayAnimation(type: animationType, size: size, color: color);
  }

  /// Icon of the sub-group this node belongs to, or '' when the node name
  /// already carries an emoji (the emoji then acts as the icon).
  String _subGroupIcon(WidgetRef ref) {
    if (_hasEmoji(proxy.name)) return '';
    return ref.watch(proxyIconProvider(proxy.name));
  }

  bool _isSelectedProxy(WidgetRef ref) {
    return ref.watch(
      getSelectedProxyNameProvider(
        groupName,
      ).select((name) => name == proxy.name),
    );
  }

  bool _isPinnedProxy(WidgetRef ref) {
    return ref.watch(
      getProxyNameProvider(groupName).select((name) => name == proxy.name),
    );
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final appController = globalState.appController;

      bool isUnlock = false;
      if (isComputedSelected) {
        final currentProfile = ref.read(currentProfileProvider);
        if (currentProfile?.selectedMap[groupName] == proxy.name) {
          isUnlock = true;
        }
      }

      if (isUnlock) {
        appController.changeProxyDebounce(groupName, '');
        return;
      }

      final nextProxyName = proxy.name;
      final chainConfig = chainProxyManager.config;
      final dedicatedGroupName = chainConfig.dedicatedGroupName.isNotEmpty
          ? chainConfig.dedicatedGroupName
          : '🔗 链式代理';
      const hopGroupName = '✈️ 链式跳板';

      final bool isLandingProxy = chainProxyManager.isLandingProxy(proxy.name);
      final bool isDedicatedGroup = proxy.name == dedicatedGroupName;
      final bool isHopGroup = groupName == hopGroupName;
      final bool isAirportProxy =
          !isLandingProxy && !isDedicatedGroup && !isHopGroup;

      final groups = ref.read(groupsProvider);

      if (chainConfig.enable &&
          (isLandingProxy || groupName == dedicatedGroupName)) {
        final landingProxyName = isLandingProxy ? proxy.name : nextProxyName;
        if (landingProxyName.isNotEmpty) {
          final batchMap = <String, String>{};
          if (groups.any((g) => g.name == dedicatedGroupName)) {
            batchMap[dedicatedGroupName] = landingProxyName;
          }

          for (final g in groups) {
            if (g.name == dedicatedGroupName || g.name == hopGroupName) {
              continue;
            }
            if (g.type != GroupType.Selector) continue;

            final hasDedicated = g.all.any((p) => p.name == dedicatedGroupName);
            final hasLanding = g.all.any((p) => p.name == landingProxyName);
            final targetToSelect = hasDedicated
                ? dedicatedGroupName
                : (hasLanding ? landingProxyName : null);

            if (targetToSelect != null) {
              final isMainOrGlobal =
                  g.name == 'GLOBAL' ||
                  g.name.contains(appLocalizations.cardNodeSelect) ||
                  g.name.contains('Proxy') ||
                  g.name.contains('PROXY') ||
                  g.name.contains(appLocalizations.cardSelect) ||
                  g.name ==
                      groups
                          .firstWhereOrNull((grp) => grp.name != 'GLOBAL')
                          ?.name;
              if (isMainOrGlobal || g.name == groupName) {
                batchMap[g.name] = targetToSelect;
              }
            }
          }

          batchMap[groupName] = isLandingProxy
              ? (groups
                            .firstWhereOrNull((g) => g.name == groupName)
                            ?.all
                            .any((p) => p.name == dedicatedGroupName) ==
                        true
                    ? dedicatedGroupName
                    : landingProxyName)
              : landingProxyName;

          await appController.changeProxiesBatch(batchMap);
          return;
        }
      } else if (chainConfig.enable && isDedicatedGroup) {
        final currentProfile = ref.read(currentProfileProvider);
        final selectedLanding =
            currentProfile?.selectedMap[dedicatedGroupName] ??
            chainProxyManager.getPrimaryLandingProxyName();

        final batchMap = <String, String>{};
        if (selectedLanding != null && selectedLanding.isNotEmpty) {
          batchMap[dedicatedGroupName] = selectedLanding;
        }
        batchMap[groupName] = dedicatedGroupName;

        for (final g in groups) {
          if (g.name == groupName ||
              g.name == dedicatedGroupName ||
              g.name == hopGroupName) {
            continue;
          }
          if (g.type != GroupType.Selector) continue;
          if (g.all.any((p) => p.name == dedicatedGroupName)) {
            final isMainOrGlobal =
                g.name == 'GLOBAL' ||
                g.name.contains(appLocalizations.cardNodeSelect) ||
                g.name.contains('Proxy') ||
                g.name.contains('PROXY') ||
                g.name.contains(appLocalizations.cardSelect);
            if (isMainOrGlobal) {
              batchMap[g.name] = dedicatedGroupName;
            }
          }
        }

        await appController.changeProxiesBatch(batchMap);
        return;
      } else if (chainConfig.enable &&
          isAirportProxy &&
          nextProxyName.isNotEmpty) {
        final batchMap = <String, String>{groupName: nextProxyName};
        if (chainConfig.defaultDialerProxy.isEmpty &&
            groups.any((g) => g.name == hopGroupName)) {
          batchMap[hopGroupName] = nextProxyName;
        }
        await appController.changeProxiesBatch(batchMap);
        return;
      }

      // `changeProxyDebounce` owns the optimistic selection write so it can
      // undo it when the core refuses. Writing it here as well would put the
      // value out of the controller's reach.
      appController.changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(appLocalizations.notSelectedTip);
  }

  @override
  Widget build(BuildContext context) {
    final latencySlot = _buildLatencySlot(context);
    final isExpand = type == ProxyCardType.expand;
    return Consumer(
      builder: (_, ref, child) {
        final isSelected = _isSelectedProxy(ref);
        final isLocked = groupType.isComputedSelected && _isPinnedProxy(ref);
        final latencyTier = ref.watch(
          getDelayProvider(
            proxyName: proxy.name,
            testUrl: testUrl,
          ).select(FluxoraLatencyBadge.tierOf),
        );
        final subGroupIcon = _subGroupIcon(ref);

        // Keep the existing list extent and callbacks; only the presentation changes.
        return FluxoraProxyTile(
          name: proxy.name,
          protocol: proxy.type,
          status: switch (latencyTier) {
            FluxoraLatencyTier.good => FluxoraStatusKind.connected,
            FluxoraLatencyTier.testing => FluxoraStatusKind.connecting,
            FluxoraLatencyTier.fair => FluxoraStatusKind.warning,
            FluxoraLatencyTier.poor ||
            FluxoraLatencyTier.timeout => FluxoraStatusKind.error,
            FluxoraLatencyTier.untested => FluxoraStatusKind.unknown,
          },
          selected: isSelected,
          compact: true,
          // `min` cards only ever showed one line; the wider types showed two.
          nameMaxLines: type == ProxyCardType.min ? 1 : 2,
          onTap: () => _changeProxy(ref),
          // 长按看配置：节点名、服务器、加密方式这些平时看不到的信息。
          onLongPress: () => showNodeDetailsDialog(
            context,
            proxyName: proxy.name,
            profileId: globalState.config.currentProfileId,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: FluxoraSpacing.sm,
            vertical: 6,
          ),
          leading: subGroupIcon.isEmpty
              ? null
              : CommonTargetIcon(
                  src: subGroupIcon,
                  size: measure.bodyMediumHeight,
                ),
          nameTrailing: isLocked
              ? Tooltip(
                  message: Localizations.localeOf(context).languageCode == 'zh'
                      ? '已锁定 · 再次点击恢复自动'
                      : 'Locked · tap again to resume automatic selection',
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: context.colorScheme.primary,
                  ),
                )
              : groupType.isComputedSelected && isSelected
              ? Tooltip(
                  message: Localizations.localeOf(context).languageCode == 'zh'
                      ? '自动选中'
                      : 'Automatically selected',
                  child: Icon(
                    Icons.autorenew_rounded,
                    size: 14,
                    color: context.colorScheme.primary,
                  ),
                )
              : null,
          description: isExpand
              ? SizedBox(
                  height: measure.labelSmallHeight,
                  child: _ProxyDesc(proxy: proxy),
                )
              : null,
          latencySlot: latencySlot,
        );
      },
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;

  const _ProxyDesc({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainConfig = ref.watch(chainProxyConfigProvider).config;
    if (chainConfig.enable) {
      final landing = chainConfig.landingProxies
          .where((p) => p.name == proxy.name)
          .firstOrNull;
      if (landing != null) {
        final hop =
            (landing.dialerProxy != null && landing.dialerProxy!.isNotEmpty)
            ? landing.dialerProxy!
            : (chainConfig.defaultDialerProxy.isNotEmpty
                  ? chainConfig.defaultDialerProxy
                  : appLocalizations.cardFollowMain);
        return _ProxyMetaTag(appLocalizations.cardHopValue(hop));
      }
    }

    final group = ref.watch(
      groupsProvider.select((groups) => groups.getGroup(proxy.name)),
    );
    if (group == null) return const SizedBox.shrink();
    final selectedName = ref
        .watch(getProxyCardStateProvider(proxy.name))
        .proxyName;
    if (selectedName.isEmpty) return const SizedBox.shrink();
    return _ProxyMetaTag(selectedName);
  }
}

class _ProxyMetaTag extends StatelessWidget {
  final String text;

  const _ProxyMetaTag(this.text);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return EmojiText(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: FluxoraTypography.label.copyWith(
        height: 1,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class GroupSelectionControl extends ConsumerWidget {
  const GroupSelectionControl({super.key, required this.group});
  final Group group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!group.type.isComputedSelected) return const SizedBox.shrink();
    final locked =
        ref.watch(selectedMapProvider)[group.name]?.isNotEmpty == true;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return IconButton(
      key: ValueKey('group-auto-${group.name}'),
      tooltip: locked
          ? (chinese ? '已锁定 · 恢复自动选择' : 'Locked · resume automatic selection')
          : (chinese ? '自动选择 · 锁定当前节点' : 'Automatic · lock current node'),
      color: locked
          ? context.colorScheme.primary
          : context.colorScheme.onSurfaceVariant,
      icon: Icon(locked ? Icons.lock_rounded : Icons.autorenew_rounded),
      onPressed: group.realNow.isEmpty
          ? null
          : () => globalState.appController.changeProxyDebounce(
              group.name,
              locked ? '' : group.realNow,
            ),
    );
  }
}
