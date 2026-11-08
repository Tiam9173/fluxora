import 'package:fluxora/common/brand_icons.dart';
// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui' as ui;

import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/selector.dart';
import 'package:fluxora/views/app_icons.dart';
import 'package:fluxora/widgets/fluxora/fluxora_launch_reveal.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

/// One option of the D4.8 colour-source selector.
class ColorSourceItem {
  final ColorSource colorSource;
  final IconData iconData;
  final String label;

  const ColorSourceItem({
    required this.colorSource,
    required this.iconData,
    required this.label,
  });
}

class ThemeView extends ConsumerWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(currentBrightnessProvider);
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    // Resolve "follow system" / unset first: the raw sentinel is neither 'zh'
    // nor 'en', which would wrongly hide the Harmony font item.
    final effectiveLocale =
        utils.getLocaleForString(locale) ?? utils.getSystemLocale();
    final shouldShowHarmonyFont =
        effectiveLocale.languageCode == 'zh' ||
        effectiveLocale.languageCode == 'en';

    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final appearance = _ThemePanel(
      title: chinese ? '显示与材质' : 'Display & material',
      children: [
        _ThemeModeItem(),
        const _SurfaceStyleItem(),
        const _EffectsItem(),
        if (brightness == Brightness.dark) _PrueBlackItem(),
      ],
    );
    final palette = _ThemePanel(
      title: chinese ? '配色工作台' : 'Colour studio',
      children: [_ColorSourceItem(), _PrimaryColorItem()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ThemePreview(),
                  const SizedBox(height: 16),
                  const _VisualStylePicker(),
                  const SizedBox(height: 20),
                  if (constraints.maxWidth >= 760)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: appearance),
                        const SizedBox(width: 16),
                        Expanded(child: palette),
                      ],
                    )
                  else ...[
                    appearance,
                    const SizedBox(height: 16),
                    palette,
                  ],
                  const SizedBox(height: 16),
                  _ThemePanel(
                    title: chinese ? '品牌标识' : 'Brand identity',
                    children: [
                      const AppIconsItem(),
                      if (system.isWindows) _TrayIconInvertItem(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ThemePanel(
                    title: chinese ? '阅读体验' : 'Reading',
                    children: [
                      if (shouldShowHarmonyFont) _HarmonyFontItem(),
                      _TextScaleFactorItem(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VisualStylePicker extends ConsumerWidget {
  const _VisualStylePicker();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(themeSettingProvider);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return Row(
      children: [
        for (final style in FluxoraVisualStyle.values) ...[
          if (style.index > 0) const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              selected: props.visualStyle == style,
              button: true,
              child: InkWell(
                key: ValueKey('visual-${style.name}'),
                borderRadius: FluxoraRadius.cardAll,
                onTap: () {
                  if (props.visualStyle == style) return;
                  ref
                      .read(themeSettingProvider.notifier)
                      .updateState(
                        (s) => s.copyWith(
                          visualStyle: style,
                          themeMode: style == FluxoraVisualStyle.obsidian
                              ? ThemeMode.dark
                              : s.themeMode,
                          colorSource: style == FluxoraVisualStyle.obsidian
                              ? ColorSource.fluxora
                              : s.colorSource,
                          surfaceStyle:
                              s.surfaceStyle == FluxoraSurfaceStyle.reduced
                              ? s.surfaceStyle
                              : FluxoraSurfaceStyle.hybrid,
                        ),
                      );
                },
                child: AnimatedContainer(
                  duration: FluxoraMotion.ofContext(context).fast,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: FluxoraRadius.cardAll,
                    color: context.colorScheme.surfaceContainerLow,
                    border: Border.all(
                      color: props.visualStyle == style
                          ? context.colorScheme.primary
                          : context.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 72,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: FluxoraRadius.mdAll,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: style == FluxoraVisualStyle.obsidian
                                ? const [
                                    Color(0xFF12141F),
                                    Color(0xFF343D78),
                                    Color(0xFF0A0B11),
                                  ]
                                : const [
                                    Color(0xFFE9EDFF),
                                    Color(0xFFCDD6FA),
                                    Color(0xFFF8FAFF),
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: style == FluxoraVisualStyle.obsidian
                                    ? const Color(0xFF7987ED)
                                    : const Color(0xFF5F6BD3),
                              ),
                              child: const Icon(
                                Icons.power_settings_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 5,
                                    width: 45,
                                    color: style == FluxoraVisualStyle.obsidian
                                        ? Colors.white70
                                        : const Color(0xFF4D5578),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    height: 4,
                                    color: style == FluxoraVisualStyle.obsidian
                                        ? Colors.white24
                                        : const Color(0xFF9AA4C6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        style == FluxoraVisualStyle.obsidian
                            ? (chinese ? '曜石玻璃' : 'Obsidian glass')
                            : 'Fluxora',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EffectsItem extends ConsumerStatefulWidget {
  const _EffectsItem();
  @override
  ConsumerState<_EffectsItem> createState() => _EffectsItemState();
}

class _EffectsItemState extends ConsumerState<_EffectsItem> {
  double? _draft;
  double? _motionDraft;
  @override
  Widget build(BuildContext context) {
    final props = ref.watch(themeSettingProvider);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    void motion(FluxoraMotionStyle style) => ref
        .read(themeSettingProvider.notifier)
        .updateState((s) => s.copyWith(motionStyle: style));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (props.surfaceStyle == FluxoraSurfaceStyle.hybrid) ...[
            Text(
              chinese ? '玻璃质感' : 'Glass intensity',
              style: context.textTheme.titleSmall,
            ),
            Slider(
              key: const ValueKey('glass-intensity'),
              value:
                  _draft ??
                  FluxoraMaterial(
                    glassIntensity: props.glassIntensity,
                  ).strength,
              divisions: 10,
              label: '${((_draft ?? props.glassIntensity) * 100).round()}%',
              onChanged: (value) => setState(() => _draft = value),
              onChangeEnd: (value) {
                ref
                    .read(themeSettingProvider.notifier)
                    .updateState((s) => s.copyWith(glassIntensity: value));
                setState(() => _draft = null);
              },
            ),
          ],
          Text(
            chinese ? '界面动效' : 'Motion',
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                (FluxoraMotionStyle.system, chinese ? '跟随系统' : 'System'),
                (FluxoraMotionStyle.fluid, chinese ? '流畅' : 'Fluid'),
                (FluxoraMotionStyle.depth, chinese ? '景深' : 'Depth'),
                (FluxoraMotionStyle.off, chinese ? '关闭' : 'Off'),
              ])
                ChoiceChip(
                  key: ValueKey('motion-${entry.$1.name}'),
                  label: Text(entry.$2),
                  selected: props.motionStyle == entry.$1,
                  onSelected: (_) => motion(entry.$1),
                ),
            ],
          ),
          if (props.motionStyle != FluxoraMotionStyle.off) ...[
            const SizedBox(height: 16),
            Text(
              chinese ? '动效强度' : 'Motion intensity',
              style: context.textTheme.titleSmall,
            ),
            Slider(
              key: const ValueKey('motion-intensity'),
              value:
                  _motionDraft ??
                  FluxoraMaterial(
                    motionIntensity: props.motionIntensity,
                  ).motionAmount,
              divisions: 10,
              label:
                  '${((_motionDraft ?? props.motionIntensity) * 100).round()}%',
              onChanged: (value) => setState(() => _motionDraft = value),
              onChangeEnd: (value) {
                ref
                    .read(themeSettingProvider.notifier)
                    .updateState((s) => s.copyWith(motionIntensity: value));
                setState(() => _motionDraft = null);
              },
            ),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(chinese ? '开屏动画' : 'Launch animation'),
            value: props.launchAnimation,
            onChanged: (value) => ref
                .read(themeSettingProvider.notifier)
                .updateState((s) => s.copyWith(launchAnimation: value)),
          ),
          TextButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(chinese ? '预览开屏' : 'Preview launch'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 360,
                  height: 460,
                  child: FluxoraLaunchReveal(
                    child: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(appLocalizations.confirm),
                      ),
                    ),
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

class _ThemePanel extends StatelessWidget {
  const _ThemePanel({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => CommonCard(
    type: CommonCardType.plain,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

class _ThemePreview extends ConsumerWidget {
  const _ThemePreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(themeSettingProvider);
    final scheme = Theme.of(context).colorScheme;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Image.asset(
              BrandIcons.asset(props.appIconStyle, props.useDarkIcon),
              width: 64,
              height: 64,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fluxora',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  chinese ? '外观预览' : 'Appearance preview',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in [
                  scheme.primary,
                  scheme.secondary,
                  scheme.tertiary,
                  scheme.surfaceContainerHighest,
                ])
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceStyleItem extends ConsumerWidget {
  const _SurfaceStyleItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(themeSettingProvider.select((s) => s.surfaceStyle));
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final names = {
      FluxoraSurfaceStyle.classic: chinese ? '经典' : 'Classic',
      FluxoraSurfaceStyle.hybrid: 'Hybrid Glass',
      FluxoraSurfaceStyle.reduced: chinese ? '轻量 · 无模糊' : 'Reduced effects',
    };
    return ItemCard(
      info: Info(
        label: chinese ? '界面材质' : 'Interface material',
        iconData: Icons.layers_outlined,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FluxoraSpacing.lg),
        child: Wrap(
          spacing: FluxoraSpacing.sm,
          runSpacing: FluxoraSpacing.sm,
          children: [
            for (final entry in names.entries)
              ChoiceChip(
                key: ValueKey('surface-style-${entry.key.name}'),
                label: Text(entry.value),
                selected: style == entry.key,
                onSelected: (_) => ref
                    .read(themeSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(surfaceStyle: entry.key),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Widget child;
  final Info info;
  final List<Widget> actions;

  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoHeader(info: info, actions: actions),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeSettingProvider.select((s) => s.themeMode));
    final scheme = Theme.of(context).colorScheme;
    final options = [
      ThemeModeItem(
        themeMode: ThemeMode.system,
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
      ),
      ThemeModeItem(
        themeMode: ThemeMode.light,
        iconData: Icons.light_mode_outlined,
        label: appLocalizations.light,
      ),
      ThemeModeItem(
        themeMode: ThemeMode.dark,
        iconData: Icons.dark_mode_outlined,
        label: appLocalizations.dark,
      ),
    ];
    return ItemCard(
      info: Info(
        label: appLocalizations.themeMode,
        iconData: Icons.brightness_high,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in options)
            ChoiceChip(
              key: ValueKey('theme-mode-${item.themeMode.name}'),
              avatar: Icon(item.iconData, size: 18),
              showCheckmark: false,
              label: Text(item.label),
              selected: mode == item.themeMode,
              backgroundColor: scheme.surfaceContainerHigh,
              selectedColor: scheme.primaryContainer,
              onSelected: (_) => ref
                  .read(themeSettingProvider.notifier)
                  .updateState((s) => s.copyWith(themeMode: item.themeMode)),
            ),
        ],
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  int _calcColumns(double maxWidth) {
    return max((maxWidth / 96).ceil(), 3);
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.resetTip),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState((state) {
      return state.copyWith(
        primaryColors: defaultPrimaryColors,
        primaryColor: defaultPrimaryColor,
        schemeVariant: DynamicSchemeVariant.tonalSpot,
        colorSource: ColorSource.fluxora,
      );
    });
  }

  Future<void> _handleDel() async {
    if (_removablePrimaryColor == null) {
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.colorSchemes),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState((state) {
      final newPrimaryColors = List<int>.from(state.primaryColors)
        ..remove(_removablePrimaryColor);
      int? newPrimaryColor = state.primaryColor;
      if (state.primaryColor == _removablePrimaryColor) {
        if (newPrimaryColors.contains(defaultPrimaryColor)) {
          newPrimaryColor = defaultPrimaryColor;
        } else {
          newPrimaryColor = null;
        }
      }
      return state.copyWith(
        primaryColors: newPrimaryColors,
        primaryColor: newPrimaryColor,
      );
    });
    setState(() {
      _removablePrimaryColor = null;
    });
  }

  Future<void> _handleAdd() async {
    final res = await globalState.showCommonDialog<int>(
      child: _PaletteDialog(),
    );
    if (res == null) {
      return;
    }
    final isExists = ref.read(
      themeSettingProvider.select((state) => state.primaryColors.contains(res)),
    );
    if (isExists && mounted) {
      context.showNotifier(
        appLocalizations.existsTip(appLocalizations.colorSchemes),
      );
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState((state) {
      return state.copyWith(
        primaryColors: List.from(state.primaryColors)..add(res),
      );
    });
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select((state) => state.schemeVariant),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: appLocalizations.colorSchemes,
        options: DynamicSchemeVariant.values,
        textBuilder: (item) => Intl.message('${item.name}Scheme'),
        value: schemeVariant,
      ),
    );
    if (value == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState((state) {
      return state.copyWith(schemeVariant: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    // D4.8: the palette picker only applies to a user-chosen colour. When the
    // colour comes from Fluxora or from the system, show a preview instead —
    // letting the user tap a swatch there would silently imply `custom`.
    final colorSource = ref.watch(
      themeSettingProvider.select((state) => state.colorSource),
    );
    if (colorSource != ColorSource.custom) {
      return _buildColorSourcePreview(context, colorSource);
    }

    final vm4 = ref.watch(
      themeSettingProvider.select(
        (state) => VM4(
          a: state.primaryColor,
          b: state.primaryColors,
          c: state.schemeVariant,
          d:
              state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(state.primaryColors, defaultPrimaryColors),
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isEquals = vm4.d;

    return CommonPopScope(
      onPop: () {
        if (_removablePrimaryColor != null) {
          setState(() {
            _removablePrimaryColor = null;
          });
          return false;
        }
        return true;
      },
      child: ItemCard(
        info: Info(
          label: appLocalizations.colorSchemes,
          iconData: Icons.palette,
        ),
        actions: genActions([
          if (_removablePrimaryColor == null)
            FilledButton(
              style: ButtonStyle(visualDensity: VisualDensity.compact),
              onPressed: _handleChangeSchemeVariant,
              child: Text(Intl.message('${schemeVariant.name}Scheme')),
            ),
          if (_removablePrimaryColor != null)
            FilledButton(
              style: ButtonStyle(visualDensity: VisualDensity.compact),
              onPressed: () {
                setState(() {
                  _removablePrimaryColor = null;
                });
              },
              child: Text(appLocalizations.cancel),
            ),
          if (_removablePrimaryColor == null && !isEquals)
            IconButton.filledTonal(
              iconSize: 20,
              padding: EdgeInsets.all(FluxoraSpacing.xs),
              visualDensity: VisualDensity.compact,
              onPressed: _handleReset,
              icon: Icon(Icons.replay),
            ),
        ], space: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (_, constraints) {
              final columns = _calcColumns(constraints.maxWidth);
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final color in primaryColors)
                    Container(
                      clipBehavior: Clip.none,
                      width: itemWidth,
                      height: itemWidth,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          EffectGestureDetector(
                            child: ColorSchemeBox(
                              isSelected: color == primaryColor,
                              primaryColor: color != null ? Color(color) : null,
                              onPressed: () {
                                setState(() {
                                  _removablePrimaryColor = null;
                                });
                                ref
                                    .read(themeSettingProvider.notifier)
                                    .updateState(
                                      (state) =>
                                          state.copyWith(primaryColor: color),
                                    );
                              },
                            ),
                            onLongPress: () {
                              setState(() {
                                _removablePrimaryColor = color;
                              });
                            },
                          ),
                          if (_removablePrimaryColor != null &&
                              _removablePrimaryColor == color)
                            Container(
                              color: Colors.white.opacity0,
                              padding: EdgeInsets.all(FluxoraSpacing.sm),
                              child: IconButton.filledTonal(
                                onPressed: _handleDel,
                                padding: EdgeInsets.all(FluxoraSpacing.md),
                                iconSize: 30,
                                icon: Icon(
                                  color: context.colorScheme.primary,
                                  Icons.delete,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_removablePrimaryColor == null)
                    Container(
                      width: itemWidth,
                      height: itemWidth,
                      padding: EdgeInsets.all(FluxoraSpacing.xs),
                      child: IconButton.filledTonal(
                        onPressed: _handleAdd,
                        iconSize: 32,
                        icon: Icon(
                          color: context.colorScheme.primary,
                          Icons.add,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrueBlackItem extends ConsumerWidget {
  const _PrueBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prueBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    return ListItem.switchItem(
      leading: Icon(Icons.contrast),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.pureBlackMode,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      delegate: SwitchDelegate(
        value: prueBlack,
        onChanged: (value) {
          ref
              .read(themeSettingProvider.notifier)
              .updateState((state) => state.copyWith(pureBlack: value));
        },
      ),
    );
  }
}

class _HarmonyFontItem extends ConsumerWidget {
  const _HarmonyFontItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHarmonyFont = ref.watch(
      themeSettingProvider.select((state) => state.useHarmonyFont),
    );
    return ListItem.switchItem(
      leading: Icon(Icons.font_download_outlined),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.harmonyFont,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        appLocalizations.harmonyFontDesc,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      delegate: SwitchDelegate(
        value: useHarmonyFont,
        onChanged: (value) {
          ref
              .read(themeSettingProvider.notifier)
              .updateState((state) => state.copyWith(useHarmonyFont: value));
        },
      ),
    );
  }
}

class _TrayIconInvertItem extends ConsumerWidget {
  const _TrayIconInvertItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invertTrayIcon = ref.watch(
      themeSettingProvider.select((state) => state.invertTrayIcon),
    );
    return ListItem.switchItem(
      leading: Icon(Icons.invert_colors),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.trayIconInvert,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        appLocalizations.trayIconInvertDesc,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      delegate: SwitchDelegate(
        value: invertTrayIcon,
        onChanged: (bool value) async {
          ref
              .read(themeSettingProvider.notifier)
              .updateState((state) => state.copyWith(invertTrayIcon: value));
          await globalState.appController.updateTray(true);
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final String process = '${(textScale.scale * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ListItem.switchItem(
            leading: Icon(Icons.text_fields),
            horizontalTitleGap: 12,
            title: Text(
              appLocalizations.textScale,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            delegate: SwitchDelegate(
              value: textScale.enable,
              onChanged: (value) {
                ref
                    .read(themeSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith.textScale(enable: value),
                    );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref
                              .read(themeSettingProvider.notifier)
                              .updateState(
                                (state) =>
                                    state.copyWith.textScale(scale: value),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(process, style: context.textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog();

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = ValueNotifier<ui.Color>(const Color(defaultPrimaryColor));

  ui.Color? _parseColor(String input) {
    final cleanInput = input.trim().replaceAll(' ', '').toLowerCase();

    // Hex: #RRGGBB or RRGGBB
    if (RegExp(r'^#?[0-9a-f]{6}$').hasMatch(cleanInput)) {
      final hexString = cleanInput.startsWith('#')
          ? cleanInput.substring(1)
          : cleanInput;
      return ui.Color(int.parse('FF$hexString', radix: 16));
    }

    // Hex with alpha: #AARRGGBB or AARRGGBB
    if (RegExp(r'^#?[0-9a-f]{8}$').hasMatch(cleanInput)) {
      final hexString = cleanInput.startsWith('#')
          ? cleanInput.substring(1)
          : cleanInput;
      return ui.Color(int.parse(hexString, radix: 16));
    }

    // RGB/RGBA: rgb(255,255,255) or rgba(255,255,255,1.0)
    final rgbMatch = RegExp(
      r'^rgba?\((\d+),(\d+),(\d+)(?:,([\d.]+))?\)$',
    ).firstMatch(cleanInput);
    if (rgbMatch != null) {
      final r = int.parse(rgbMatch.group(1)!);
      final g = int.parse(rgbMatch.group(2)!);
      final b = int.parse(rgbMatch.group(3)!);
      final aStr = rgbMatch.group(4);
      final a = aStr != null ? double.parse(aStr) : 1.0;

      final alphaVal = (a * 255).round().clamp(0, 255);
      final rVal = r.clamp(0, 255);
      final gVal = g.clamp(0, 255);
      final bVal = b.clamp(0, 255);
      return ui.Color.fromARGB(alphaVal, rVal, gVal, bVal);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.palette,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.value.toARGB32());
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        children: [
          SizedBox(height: 8),
          SizedBox(
            width: 250,
            height: 250,
            child: Palette(controller: _controller),
          ),
          SizedBox(height: 24),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, color, _) {
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: color.readableForeground,
                ),
                onPressed: () async {
                  final customColorStr = await globalState
                      .showCommonDialog<String>(
                        child: InputDialog(
                          title: appLocalizations.color,
                          value: _controller.value.hex,
                          hintText: '#000000 / rgb(0,0,0)',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return appLocalizations.emptyTip(
                                appLocalizations.color,
                              );
                            }
                            if (_parseColor(value) == null) {
                              return appLocalizations.formatError;
                            }
                            return null;
                          },
                        ),
                      );
                  if (customColorStr != null) {
                    final newColor = _parseColor(customColorStr);
                    if (newColor != null) {
                      _controller.value = newColor;
                    }
                  }
                },
                child: Text(color.hex),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(
    context,
  ).textTheme.labelLarge!.copyWith(color: _colors.onInverseSurface);

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  @override
  double? get trackGap => 6.0;
}

/// Colour-source selector (D4.8).
///
/// Mirrors `_ThemeModeItem`'s layout so the two "pick one of three" controls on
/// this page look and behave the same. Labels reuse existing localisation keys
/// (`system` / `custom`); "Fluxora" is a brand name and needs no translation.
class _ColorSourceItem extends ConsumerWidget {
  const _ColorSourceItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(themeSettingProvider.select((s) => s.colorSource));
    final palette = ref.watch(dynamicPaletteProvider);
    final unavailable =
        system.isAndroid && palette.light == null && palette.dark == null;
    final scheme = Theme.of(context).colorScheme;
    final options = [
      ColorSourceItem(
        colorSource: ColorSource.fluxora,
        iconData: Icons.auto_awesome_outlined,
        label: AppIdentity.displayName,
      ),
      ColorSourceItem(
        colorSource: ColorSource.system,
        iconData: Icons.smartphone_outlined,
        label: appLocalizations.system,
      ),
      ColorSourceItem(
        colorSource: ColorSource.custom,
        iconData: Icons.colorize_outlined,
        label: appLocalizations.custom,
      ),
    ];
    return ItemCard(
      info: Info(
        label: appLocalizations.themeColor,
        iconData: Icons.palette_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in options)
                ChoiceChip(
                  avatar: Icon(item.iconData, size: 18),
                  showCheckmark: false,
                  label: Text(item.label),
                  selected: source == item.colorSource,
                  backgroundColor: scheme.surfaceContainerHigh,
                  selectedColor: scheme.primaryContainer,
                  onSelected:
                      item.colorSource == ColorSource.system && unavailable
                      ? null
                      : (_) => ref
                            .read(themeSettingProvider.notifier)
                            .updateState(
                              (s) => s.copyWith(
                                colorSource: item.colorSource,
                                primaryColor:
                                    item.colorSource == ColorSource.fluxora
                                    ? defaultPrimaryColor
                                    : s.primaryColor,
                              ),
                            ),
                ),
            ],
          ),
          if (unavailable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                appLocalizations.colorSourceSystemUnavailable,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildColorSourcePreview(BuildContext context, ColorSource source) {
  final isFluxora = source == ColorSource.fluxora;
  return ItemCard(
    info: Info(label: appLocalizations.colorSchemes, iconData: Icons.palette),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      child: Row(
        children: [
          if (isFluxora)
            for (final color in const [
              FluxoraColors.fluxCyan,
              FluxoraColors.auroraBlue,
              FluxoraColors.flowViolet,
            ])
              Padding(
                padding: const EdgeInsets.only(right: FluxoraSpacing.sm),
                child: _buildColorSwatch(context, color),
              ),
          if (!isFluxora)
            _buildColorSwatch(context, context.colorScheme.primary),
          const SizedBox(width: FluxoraSpacing.md),
          Expanded(
            child: Text(
              isFluxora ? AppIdentity.displayName : appLocalizations.system,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluxoraTypography.body.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildColorSwatch(BuildContext context, Color color) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color,
      borderRadius: FluxoraRadius.smAll,
      border: Border.all(color: context.colorScheme.outlineVariant),
    ),
  );
}
