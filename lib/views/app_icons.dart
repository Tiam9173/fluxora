import 'package:fluxora/common/brand_icons.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

bool _chinese(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh';

String appIconsTitle(BuildContext context) =>
    _chinese(context) ? '应用图标' : 'App icons';

class AppIconsItem extends ConsumerWidget {
  const AppIconsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(themeSettingProvider);
    return ListTile(
      leading: Image.asset(
        BrandIcons.asset(props.appIconStyle, props.useDarkIcon),
        width: 40,
        height: 40,
      ),
      title: Text(appIconsTitle(context)),
      subtitle: Text(
        BrandIcons.label(props.appIconStyle, chinese: _chinese(context)),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showExtend(
        context,
        builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          title: appIconsTitle(context),
          body: const AppIconsView(),
        ),
      ),
    );
  }
}

class AppIconsView extends ConsumerStatefulWidget {
  const AppIconsView({super.key});

  @override
  ConsumerState<AppIconsView> createState() => _AppIconsViewState();
}

class _AppIconsViewState extends ConsumerState<AppIconsView> {
  late String _style;
  late bool _dark;
  bool _busy = false;
  bool _systemKnown = !system.isAndroid;
  String? _error;

  @override
  void initState() {
    super.initState();
    final props = ref.read(themeSettingProvider);
    _style = BrandIcons.normalize(props.appIconStyle);
    _dark = props.useDarkIcon;
    if (system.isAndroid) {
      _busy = true;
      _readSystemIcon();
    }
  }

  Future<void> _readSystemIcon() async {
    _systemKnown = false;
    try {
      final actual = await app.getLauncherIcon();
      final style = actual['style'];
      final dark = actual['useDarkIcon'];
      if (style is! String ||
          !BrandIcons.styles.containsKey(style) ||
          dark is! bool) {
        throw const FormatException('Invalid launcher icon response');
      }
      if (!mounted) return;
      // Android's enabled component survives process death and is authoritative.
      ref
          .read(themeSettingProvider.notifier)
          .updateState(
            (props) => props.copyWith(appIconStyle: style, useDarkIcon: dark),
          );
      setState(() {
        _style = style;
        _dark = dark;
        _systemKnown = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final previous = ref.read(themeSettingProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    var changedSystemIcon = false;
    try {
      if (system.isAndroid) {
        if (!await app.setLauncherIcon(_dark, style: _style)) {
          throw PlatformException(code: 'ICON_CHANGE_FAILED');
        }
        changedSystemIcon = true;
      }
      final nextProps = globalState.config.themeProps.copyWith(
        appIconStyle: _style,
        useDarkIcon: _dark,
      );
      final nextConfig = globalState.config.copyWith(themeProps: nextProps);
      if (!await preferences.saveConfig(nextConfig)) {
        throw StateError('Unable to save icon selection');
      }
      // Keep the provider's onUpdate in charge of the existing config flow.
      if (mounted) {
        ref
            .read(themeSettingProvider.notifier)
            .updateState(
              (props) =>
                  props.copyWith(appIconStyle: _style, useDarkIcon: _dark),
            );
      } else {
        globalState.config = nextConfig;
      }
    } catch (error) {
      var message = error.toString();
      if (changedSystemIcon) {
        try {
          if (!await app.setLauncherIcon(
            previous.useDarkIcon,
            style: BrandIcons.normalize(previous.appIconStyle),
          )) {
            throw StateError('Icon rollback failed');
          }
        } catch (rollbackError) {
          message = '$message\n$rollbackError';
        }
      }
      // A native failure can include an unsuccessful platform-side rollback.
      if (system.isAndroid && mounted) await _readSystemIcon();
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chinese = _chinese(context);
    String tr(String zh, String en) => chinese ? zh : en;
    final props = ref.watch(themeSettingProvider);
    final scheme = Theme.of(context).colorScheme;
    final currentStyle = BrandIcons.normalize(props.appIconStyle);
    final changed = currentStyle != _style || props.useDarkIcon != _dark;
    final mode = props.useDarkIcon ? tr('深色', 'Dark') : tr('浅色', 'Light');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_systemKnown ? tr('当前', 'Current') : tr('上次保存', 'Last saved')}: ${BrandIcons.label(currentStyle, chinese: chinese)} · $mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final dark in [false, true])
                Semantics(
                  selected: _dark == dark,
                  child: ChoiceChip(
                    key: ValueKey('icon-mode-$dark'),
                    selected: _dark == dark,
                    avatar: Image.asset(BrandIcons.asset(_style, dark)),
                    label: Text(
                      dark ? tr('深色图标', 'Dark icon') : tr('浅色图标', 'Light icon'),
                    ),
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _dark = dark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 112).floor().clamp(2, 4);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final style in BrandIcons.styles.keys)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        selected: _style == style,
                        button: true,
                        label: BrandIcons.label(style, chinese: chinese),
                        child: CommonCard(
                          key: ValueKey('icon-style-$style'),
                          isSelected: _style == style,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _style = style),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  BrandIcons.asset(style, _dark),
                                  width: 76,
                                  height: 76,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  BrandIcons.label(style, chinese: chinese),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  _style == style
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: _style == style
                                      ? scheme.primary
                                      : scheme.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            system.isAndroid
                ? tr(
                    '应用后更换桌面图标，启动器可能稍后刷新。',
                    'Apply changes the launcher icon. Your launcher may refresh later.',
                  )
                : tr(
                    '此平台可保存应用内图标；系统安装图标暂不支持动态更换。',
                    'Saves the in-app icon. Dynamic installed app icons are unavailable on this platform.',
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('apply-icon'),
            onPressed: _busy || !_systemKnown || !changed ? null : _apply,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              system.isAndroid
                  ? tr('应用图标', 'Apply icon')
                  : tr('保存应用内图标', 'Save in-app icon'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                '${tr('图标设置失败', 'Icon setting failed')}: $_error',
                style: TextStyle(color: scheme.error),
              ),
            ),
            if (!_systemKnown)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _busy = true);
                        _readSystemIcon();
                      },
                child: Text(tr('重新读取系统图标', 'Retry reading system icon')),
              ),
          ],
          const SizedBox(height: 24),
          if (system.isAndroid) const NotificationIconsItem(),
          Text(
            system.isAndroid
                ? tr('快捷磁贴', 'Quick Settings')
                : tr('托盘图标', 'Tray icon'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/icon_white.png',
                  width: 24,
                  height: 24,
                  color: scheme.onInverseSurface,
                  semanticLabel: 'Fluxora F',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  system.isAndroid
                      ? tr('单色 F，由系统着色。', 'Monochrome F, tinted by the system.')
                      : tr(
                          '专用单色 F，外观由托盘设置控制。',
                          'Dedicated monochrome F, controlled by tray settings.',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationIconsItem extends ConsumerStatefulWidget {
  const NotificationIconsItem({super.key});
  @override
  ConsumerState<NotificationIconsItem> createState() =>
      _NotificationIconsItemState();
}

class _NotificationIconsItemState extends ConsumerState<NotificationIconsItem> {
  bool _busy = false;
  String? _pendingStyle;
  String? _error;

  Future<void> _select(String style) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final previous = BrandIcons.normalizeNotification(
      ref.read(themeSettingProvider).notificationIconStyle,
    );
    setState(() {
      _busy = true;
      _pendingStyle = style;
      _error = null;
    });
    try {
      if (!await app.setNotificationIconStyle(style)) {
        throw StateError('Notification icon update failed');
      }
      final config = globalState.config;
      if (!await preferences.saveConfig(
        config.copyWith(
          themeProps: config.themeProps.copyWith(notificationIconStyle: style),
        ),
      )) {
        throw StateError('Unable to save notification icon');
      }
      container
          .read(themeSettingProvider.notifier)
          .updateState((s) => s.copyWith(notificationIconStyle: style));
    } catch (error) {
      try {
        await app.setNotificationIconStyle(previous);
      } catch (_) {}
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chinese = _chinese(context);
    final scheme = Theme.of(context).colorScheme;
    final style = BrandIcons.normalizeNotification(
      ref.watch(themeSettingProvider).notificationIconStyle,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chinese ? '通知栏图标' : 'Notification icon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in BrandIcons.notificationStyles.entries)
                ChoiceChip(
                  key: ValueKey('notification-icon-${item.key}'),
                  selected: style == item.key,
                  showCheckmark: false,
                  backgroundColor: scheme.surfaceContainerHigh,
                  selectedColor: scheme.primaryContainer,
                  avatar: _busy && _pendingStyle == item.key
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : SvgPicture.asset(
                          'assets/images/notification_${item.key}.svg',
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            scheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                  label: Text(chinese ? item.value.$1 : item.value.$2),
                  onSelected: _busy ? null : (_) => _select(item.key),
                ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: scheme.error)),
        ],
      ),
    );
  }
}
