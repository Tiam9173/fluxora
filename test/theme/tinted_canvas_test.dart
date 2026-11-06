import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/fluxora_colors.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';

/// 用户反馈：「这个底色再怎么自定义都不会改变」。
///
/// 原因是 `fluxoraSchemeFromSeed` 把画布和卡片层级全部钉在
/// `FluxoraColorSet` 的固定 token 上，种子色只影响 `primary`。这里把新的约定
/// 钉住：**品牌配色保持设计稿的底色；用户自己选的颜色（或系统取色）连底色一起
/// 跟着变**，而且亮度不变——对比度靠亮度，所以已经测量过的比例不受影响。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const red = Color(0xFFE53935);

  ColorScheme brand(Brightness brightness) => fluxoraSchemeFromSeed(
    brightness: brightness,
    seed: FluxoraColors.fluxCyan,
    variant: DynamicSchemeVariant.tonalSpot,
  );

  ColorScheme custom(Brightness brightness) => fluxoraSchemeFromSeed(
    brightness: brightness,
    seed: red,
    variant: DynamicSchemeVariant.tonalSpot,
    tintNeutrals: true,
  );

  group('画布跟随种子色', () {
    test('品牌配色仍然画设计稿的底色（不染）', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        expect(brand(brightness).surface, tokens.background);
        expect(brand(brightness).surfaceContainerLowest, tokens.surface);
      }
    });

    test('自定义颜色会把画布和卡片层级一起染色', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        final scheme = custom(brightness);
        expect(
          scheme.surface,
          isNot(tokens.background),
          reason: '选了颜色底色却不变，就是用户报的那个问题',
        );
        // 浅色主题的卡片是纯白（亮度 1.0），HSL 下再高的饱和度也还是白 ——
        // 这不是缺陷，"白卡片浮在带色画布上"本来就该是浅色主题的样子。
        // 深色主题的卡片不是纯白，所以它必须跟着染色。
        if (brightness == Brightness.dark) {
          expect(scheme.surfaceContainerLowest, isNot(tokens.surface));
        }
        expect(scheme.surfaceContainer, isNot(tokens.surfaceContainer));
      }
    });

    test('染色后亮度不变——对比度是靠亮度算的', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        final before = HSLColor.fromColor(tokens.background);
        final after = HSLColor.fromColor(custom(brightness).surface);
        expect(after.lightness, closeTo(before.lightness, 0.0001));
      }
    });

    test('色相跟着种子走', () {
      final scheme = custom(Brightness.dark);
      final hue = HSLColor.fromColor(scheme.surface).hue;
      expect(hue, closeTo(HSLColor.fromColor(red).hue, 1));
    });

    test('纯灰种子不会被强行染成红色', () {
      // HSL 里灰色的 hue 是 0，直接套用会把中性配色染红。
      final scheme = fluxoraSchemeFromSeed(
        brightness: Brightness.dark,
        seed: const Color(0xFF808080),
        variant: DynamicSchemeVariant.neutral,
        tintNeutrals: true,
      );
      expect(scheme.surface, FluxoraColorSet.of(Brightness.dark).background);
    });
  });

  group('genColorSchemeProvider 按颜色来源决定是否染色', () {
    ColorScheme schemeFor(ThemeProps props, Brightness brightness) {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(props)),
        ],
      );
      addTearDown(container.dispose);
      return container.read(genColorSchemeProvider(brightness));
    }

    test('fluxora 品牌 → 底色不动', () {
      final scheme = schemeFor(
        const ThemeProps(colorSource: ColorSource.fluxora),
        Brightness.dark,
      );
      expect(scheme.surface, FluxoraColorSet.of(Brightness.dark).background);
    });

    test('custom → 底色跟着选的颜色变', () {
      final scheme = schemeFor(
        const ThemeProps(colorSource: ColorSource.custom, primaryColor: 0xFFE53935),
        Brightness.dark,
      );
      expect(
        scheme.surface,
        isNot(FluxoraColorSet.of(Brightness.dark).background),
      );
    });
  });
}

class _MockThemeSetting extends ThemeSetting {
  ThemeProps _current;
  _MockThemeSetting(this._current);

  @override
  ThemeProps build() => _current;

  @override
  void updateState(ThemeProps Function(ThemeProps state) builder) {
    _current = builder(_current);
    state = _current;
  }

  @override
  void onUpdate(ThemeProps value) {
    _current = value;
  }
}
