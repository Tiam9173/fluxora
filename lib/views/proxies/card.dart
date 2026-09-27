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
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
    return _emojiMatchCache.putIfAbsent(
      name,
      () => _emojiRegex.hasMatch(name),
    );
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

  bool get _isNonTestableProxy {
    final name = proxy.name.toUpperCase();
    return name == 'REJECT' ||
        name == 'REJECT-DROP' ||
        name == 'PASS' ||
        proxy.type.toUpperCase() == 'REMATCH';
  }

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
      height: measure.labelSmallHeight,
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
              height: measure.labelSmallHeight,
              width: measure.labelSmallHeight,
              child: IconButton(
                icon: const Icon(Icons.bolt),
                iconSize: measure.labelSmallHeight,
                padding: EdgeInsets.zero,
                tooltip: appLocalizations.startTest,
                onPressed: _handleTestCurrentDelay,
              ),
            );
          }

          // D4.7: the raw `Text` + `utils.getDelayColor` pair is replaced by the
          // Fluxora latency badge, so the 600ms legacy threshold and the
          // hardcoded Colors.red/green/amber are gone. `dense` keeps the badge
          // 12px tall so the list's fixed item extent is unchanged.
          return FluxoraLatencyBadge(
            delay: delay,
            dense: true,
            onTap: _handleTestCurrentDelay,
          );
        },
      ),
    );
  }

  Widget _buildDelayAnimation(
    DelayAnimationType animationType,
    double size,
    Color color,
  ) {
    return switch (animationType) {
      DelayAnimationType.none => Icon(Icons.bolt, size: size),
      DelayAnimationType.rotatingCircle => SpinKitRotatingCircle(
        color: color,
        size: size,
      ),
      DelayAnimationType.pulse => SpinKitPulse(color: color, size: size),
      DelayAnimationType.spinningLines => SpinKitSpinningLines(
        color: color,
        size: size,
      ),
      DelayAnimationType.threeInOut => SpinKitThreeInOut(
        color: color,
        size: size,
      ),
      DelayAnimationType.threeBounce => SpinKitThreeBounce(
        color: color,
        size: size,
      ),
      DelayAnimationType.circle => SpinKitCircle(color: color, size: size),
      DelayAnimationType.fadingCircle => SpinKitFadingCircle(
        color: color,
        size: size,
      ),
      DelayAnimationType.fadingFour => SpinKitFadingFour(
        color: color,
        size: size,
      ),
      DelayAnimationType.wave => SpinKitWave(color: color, size: size),
      DelayAnimationType.doubleBounce => SpinKitDoubleBounce(
        color: color,
        size: size,
      ),
    };
  }

  /// Icon of the sub-group this node belongs to, or '' when the node name
  /// already carries an emoji (the emoji then acts as the icon).
  String _subGroupIcon(WidgetRef ref) {
    if (_hasEmoji(proxy.name)) return '';
    return ref.watch(proxyIconProvider(proxy.name));
  }

  bool _isSelectedProxy(WidgetRef ref) {
    return ref.watch(
      getSelectedProxyNameProvider(groupName).select(
        (name) => name == proxy.name,
      ),
    );
  }

  bool _isComputedMatch(WidgetRef ref) {
    return ref.watch(
      getProxyNameProvider(groupName).select(
        (name) => name == proxy.name,
      ),
    );
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final nextProxyName = proxy.name;
      final appController = globalState.appController;
      final chainConfig = chainProxyManager.config;
      final dedicatedGroupName = chainConfig.dedicatedGroupName.isNotEmpty
          ? chainConfig.dedicatedGroupName
          : '🔗 链式代理';
      const hopGroupName = '✈️ 链式跳板';

      final bool isLandingProxy = chainProxyManager.isLandingProxy(proxy.name);
      final bool isDedicatedGroup = proxy.name == dedicatedGroupName;
      final bool isHopGroup = groupName == hopGroupName;
      final bool isAirportProxy = !isLandingProxy && !isDedicatedGroup && !isHopGroup;

      final groups = ref.read(groupsProvider);

      if (chainConfig.enable && (isLandingProxy || groupName == dedicatedGroupName)) {
        final landingProxyName = isLandingProxy ? proxy.name : nextProxyName;
        if (landingProxyName.isNotEmpty) {
          final batchMap = <String, String>{};
          if (groups.any((g) => g.name == dedicatedGroupName)) {
            batchMap[dedicatedGroupName] = landingProxyName;
          }

          for (final g in groups) {
            if (g.name == dedicatedGroupName || g.name == hopGroupName) continue;
            if (g.type != GroupType.Selector) continue;

            final hasDedicated = g.all.any((p) => p.name == dedicatedGroupName);
            final hasLanding = g.all.any((p) => p.name == landingProxyName);
            final targetToSelect = hasDedicated
                ? dedicatedGroupName
                : (hasLanding ? landingProxyName : null);

            if (targetToSelect != null) {
              final isMainOrGlobal = g.name == 'GLOBAL' ||
                  g.name.contains('节点选择') ||
                  g.name.contains('Proxy') ||
                  g.name.contains('PROXY') ||
                  g.name.contains('选择') ||
                  g.name == groups.firstWhereOrNull((grp) => grp.name != 'GLOBAL')?.name;
              if (isMainOrGlobal || g.name == groupName) {
                batchMap[g.name] = targetToSelect;
              }
            }
          }

          batchMap[groupName] = isLandingProxy
              ? (groups.firstWhereOrNull((g) => g.name == groupName)?.all.any((p) => p.name == dedicatedGroupName) == true
                  ? dedicatedGroupName
                  : landingProxyName)
              : landingProxyName;

          await appController.changeProxiesBatch(batchMap);
          return;
        }
      } else if (chainConfig.enable && isDedicatedGroup) {
        final currentProfile = ref.read(currentProfileProvider);
        final selectedLanding = currentProfile?.selectedMap[dedicatedGroupName] ??
            chainProxyManager.getPrimaryLandingProxyName();

        final batchMap = <String, String>{};
        if (selectedLanding != null && selectedLanding.isNotEmpty) {
          batchMap[dedicatedGroupName] = selectedLanding;
        }
        batchMap[groupName] = dedicatedGroupName;

        for (final g in groups) {
          if (g.name == groupName || g.name == dedicatedGroupName || g.name == hopGroupName) continue;
          if (g.type != GroupType.Selector) continue;
          if (g.all.any((p) => p.name == dedicatedGroupName)) {
            final isMainOrGlobal = g.name == 'GLOBAL' ||
                g.name.contains('节点选择') ||
                g.name.contains('Proxy') ||
                g.name.contains('PROXY') ||
                g.name.contains('选择');
            if (isMainOrGlobal) {
              batchMap[g.name] = dedicatedGroupName;
            }
          }
        }

        await appController.changeProxiesBatch(batchMap);
        return;
      } else if (chainConfig.enable && isAirportProxy && nextProxyName.isNotEmpty) {
        final batchMap = <String, String>{
          groupName: nextProxyName,
        };
        if (chainConfig.defaultDialerProxy.isEmpty &&
            groups.any((g) => g.name == hopGroupName)) {
          batchMap[hopGroupName] = nextProxyName;
        }
        await appController.changeProxiesBatch(batchMap);
        return;
      }

      appController.updateCurrentSelectedMap(groupName, nextProxyName);
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
        final isComputedMatch = groupType.isComputedSelected &&
            _isComputedMatch(ref);
        final subGroupIcon = _subGroupIcon(ref);

        // D4.7: the card body is now a FluxoraProxyTile.
        //
        // * `getItemHeight()` is deliberately untouched, so `itemExtentBuilder`
        //   stays correct by construction — the parent SizedBox bounds the tile.
        // * `padding` reproduces the previous horizontal 12px inset with **no**
        //   vertical inset, keeping the same available content height.
        // * `latencySlot` carries the original test affordances (testing
        //   spinner / tap-to-test bolt / badge), so nothing is lost.
        return FluxoraProxyTile(
          name: proxy.name,
          protocol: proxy.type,
          status: isSelected
              ? FluxoraStatusKind.connected
              : (_isNonTestableProxy
                    ? FluxoraStatusKind.disconnected
                    : FluxoraStatusKind.unknown),
          selected: isSelected,
          compact: true,
          // `min` cards only ever showed one line; the wider types showed two.
          nameMaxLines: type == ProxyCardType.min ? 1 : 2,
          onTap: () => _changeProxy(ref),
          padding: const EdgeInsets.symmetric(horizontal: FluxoraSpacing.md),
          leading: subGroupIcon.isEmpty
              ? null
              : CommonTargetIcon(
                  src: subGroupIcon,
                  size: measure.bodyMediumHeight,
                ),
          trailing: isComputedMatch ? const _ProxyComputedMarkIcon() : null,
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
        final hop = (landing.dialerProxy != null && landing.dialerProxy!.isNotEmpty)
            ? landing.dialerProxy!
            : (chainConfig.defaultDialerProxy.isNotEmpty
                ? chainConfig.defaultDialerProxy
                : '跟随主选择');
        return _ProxyMetaTag('🔗 跳板: $hop');
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

class _ProxyComputedMarkIcon extends StatelessWidget {
  const _ProxyComputedMarkIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: Icon(
          Icons.lock_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
