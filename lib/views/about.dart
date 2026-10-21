import 'dart:async';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const String githubRepoUrl = 'https://github.com/Tiam9173/fluxora';
  static const String telegramChannelUrl = 'https://t.me/Fluxora_Channel';
  static const String telegramGroupUrl = 'https://t.me/Fluxora_Group1';

  Future<void> _checkUpdate(
    BuildContext context, {
    bool includePrerelease = false,
  }) async {
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final data = await globalState.appController.safeRun<Map<String, dynamic>?>(
      () => request.checkForUpdate(includePrerelease: includePrerelease),
      title: appLocalizations.checkUpdate,
      needLoading: true,
    );
    globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) {
    final colorScheme = context.colorScheme;
    return [
      ...generateSection(
        title: appLocalizations.checkUpdate,
        items: [
          _LinkGridRow(
            tiles: [
              _LinkGridTile(
                title: appLocalizations.checkUpdateStable,
                icon: Icons.verified_outlined,
                iconColor: colorScheme.primary,
                onTap: () => _checkUpdate(context),
              ),
              _LinkGridTile(
                title: appLocalizations.checkUpdatePrerelease,
                icon: Icons.science_outlined,
                iconColor: colorScheme.tertiary,
                onTap: () => _checkUpdate(context, includePrerelease: true),
              ),
            ],
          ),
        ],
      ),
      ...generateSection(
        title: appLocalizations.officialCommunity,
        items: [
          _LinkGridRow(
            tiles: [
              _LinkGridTile(
                title: appLocalizations.telegramChannel,
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFF2CA5E0),
                onTap: () => globalState.openUrl(telegramChannelUrl),
              ),
              _LinkGridTile(
                title: appLocalizations.telegramGroup,
                icon: Icons.forum_outlined,
                iconColor: const Color(0xFF2CA5E0),
                onTap: () => globalState.openUrl(telegramGroupUrl),
              ),
            ],
          ),
          // 「GitHub」是品牌名，不做翻译。单独一行：一行只放两个磁贴。
          _LinkGridRow(
            tiles: [
              _LinkGridTile(
                title: 'GitHub',
                icon: Icons.code,
                iconColor: colorScheme.onSurface,
                onTap: () => globalState.openUrl(githubRepoUrl),
              ),
            ],
          ),
        ],
      ),
      ...generateSection(
        title: appLocalizations.more,
        items: [
          // Three equal columns: one row per upstream project, all the same
          // width, so no credit reads as more important than another.
          _LinkGridRow(
            tiles: [
              _LinkGridTile(
                title: 'FlClash',
                icon: Icons.launch,
                onTap: () => globalState.openUrl(
                  'https://github.com/chen08209/FlClash',
                ),
              ),
              _LinkGridTile(
                title: 'Bettbox',
                icon: Icons.launch,
                onTap: () => globalState.openUrl(
                  'https://github.com/appshubcc/Bettbox',
                ),
              ),
              _LinkGridTile(
                title: 'Mihomo',
                icon: Icons.launch,
                onTap: () => globalState.openUrl(
                  'https://github.com/MetaCubeX/mihomo',
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 48,
                          height: 48,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            globalState.packageInfo.buildNumber.isNotEmpty
                                ? '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}'
                                : globalState.packageInfo.version,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(developerMode: true),
                        );
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildMoreSection(context),
    ];
    return generateListView(items);
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}

class _LinkGridRow extends StatelessWidget {
  /// One or more equal-width cells, separated by hairlines. A single tile keeps
  /// the full row width; anything else is split evenly, so a row of three
  /// credits gives every project exactly the same space.
  final List<_LinkGridTile> tiles;

  const _LinkGridRow({required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.length == 1) return tiles.first;
    final dividerColor = context.colorScheme.outlineVariant.withValues(
      alpha: context.colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: dividerColor,
              ),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _LinkGridTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _LinkGridTile({
    required this.title,
    this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color:
                    iconColor ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
