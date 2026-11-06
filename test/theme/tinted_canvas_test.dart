import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/fluxora_colors.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';

/// 用户反馈：「自定义配色后所改变的地方太少，只有字体和几个按钮颜色变了」
/// 以及「怎么换都没啥大变化」。
///
/// 原因不是没生效，而是 `fluxoraSchemeFromSeed` 把画布、卡片层级和两条线全部
/// 钉死在 `FluxoraColorSet` 上，种子色只影响 `primary` / `onSurface`。
///
/// 现在的约定：
///  * **品牌配色** → 画设计稿那套（中性色 = token，逐值相等）；
///  * **系统取色 / 自定义** → 用种子自己的完整方案，只有 error 对被钉住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const red = Color(0xFFE53935);

  ColorScheme brand(Brightness brightness) => fluxoraSchemeFromSeed(
    brightness: brightness,
    seed: FluxoraColors.fluxCyan,
    variant: DynamicSchemeVariant.tonalSpot,
  );

  ColorScheme followed(Brightness brightness, {Color seed = red}) =>
      fluxoraSchemeFromSeed(
        brightness: brightness,
        seed: seed,
        variant: DynamicSchemeVariant.tonalSpot,
        followSeed: true,
      );

  group('品牌配色 = 设计稿', () {
    test('画布、卡片层级、线条逐值等于 token', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        final scheme = brand(brightness);
        expect(scheme.surface, tokens.background);
        expect(scheme.surfaceContainerLowest, tokens.surface);
        expect(scheme.surfaceContainer, tokens.surfaceContainer);
        expect(scheme.surfaceContainerHigh, tokens.surfaceContainerHigh);
        expect(scheme.surfaceContainerHighest, tokens.surfaceContainerHighest);
        expect(scheme.outline, tokens.outline);
        expect(scheme.outlineVariant, tokens.outlineVariant);
      }
    });
  });

  group('跟随种子 = 完整方案', () {
    test('画布 / 卡片 / 线条全部不再等于 token', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        final scheme = followed(brightness);
        expect(
          scheme.surface,
          isNot(tokens.background),
          reason: '底色不变就是用户报的那个问题',
        );
        expect(scheme.surfaceContainer, isNot(tokens.surfaceContainer));
        expect(scheme.surfaceContainerHigh, isNot(tokens.surfaceContainerHigh));
        expect(scheme.outline, isNot(tokens.outline));
        expect(scheme.outlineVariant, isNot(tokens.outlineVariant));
      }
    });

    test('取值就是种子自己的方案，而不是 token 的某个变体', () {
      for (final brightness in Brightness.values) {
        final expected = ColorScheme.fromSeed(
          seedColor: red,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        );
        final scheme = followed(brightness);
        expect(scheme.surface, expected.surface);
        expect(scheme.surfaceContainer, expected.surfaceContainer);
        expect(scheme.outline, expected.outline);
        expect(scheme.primary, expected.primary);
      }
    });

    test('换一个种子，整个方案都跟着换', () {
      final blue = followed(Brightness.dark, seed: const Color(0xFF1565C0));
      final green = followed(Brightness.dark, seed: const Color(0xFF2E7D32));
      expect(blue.surface, isNot(green.surface));
      expect(blue.surfaceContainer, isNot(green.surfaceContainer));
      expect(blue.primary, isNot(green.primary));
    });
  });

  group('两种模式都必须钉住 error', () {
    test('红色种子不会把「失败」染成主题色', () {
      for (final brightness in Brightness.values) {
        final tokens = FluxoraColorSet.of(brightness);
        for (final scheme in [brand(brightness), followed(brightness)]) {
          expect(scheme.error, tokens.error);
          expect(scheme.onError, tokens.onError);
        }
      }
    });
  });

  group('完整方案仍然满足对比度下限', () {
    // Material 的色调板保证 on/off 配对，但这条是产品底线，用测试钉住。
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('onSurface / surface 与 primary / surface 都过 4.5:1', () {
      for (final brightness in Brightness.values) {
        final scheme = followed(brightness);
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('genColorSchemeProvider 按颜色来源选择模式', () {
    ColorScheme schemeFor(ThemeProps props, Brightness brightness) {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(props)),
        ],
      );
      addTearDown(container.dispose);
      return container.read(genColorSchemeProvider(brightness));
    }

    test('fluxora 品牌 → 画设计稿的底色', () {
      final scheme = schemeFor(
        const ThemeProps(colorSource: ColorSource.fluxora),
        Brightness.dark,
      );
      expect(scheme.surface, FluxoraColorSet.of(Brightness.dark).background);
    });

    test('custom → 完整跟随选中的颜色', () {
      final scheme = schemeFor(
        const ThemeProps(
          colorSource: ColorSource.custom,
          primaryColor: 0xFFE53935,
        ),
        Brightness.dark,
      );
      final expected = ColorScheme.fromSeed(
        seedColor: const Color(0xFFE53935),
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      expect(scheme.surface, expected.surface);
      expect(scheme.surface, isNot(FluxoraColorSet.of(Brightness.dark).background));
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
