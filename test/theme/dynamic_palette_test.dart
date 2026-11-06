import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';

/// 莫奈取色以前只在 `init()` 里读一次，换壁纸要重启才生效。
/// `DynamicColorBuilder` 现在把变化推进 `dynamicPaletteProvider`，
/// `genColorScheme` 通过它取种子色。这里钉住这条链。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // `accentColor` is `late` and filled by `globalState.init()` at runtime;
    // `genColorScheme` reads it as the last fallback when no Monet palette
    // exists, which is exactly the test environment.
    globalState.accentColor = const Color(0xFF29D6C7);
  });

  ProviderContainer containerFor(ThemeProps props) {
    final container = ProviderContainer(
      overrides: [
        themeSettingProvider.overrideWith(() => _MockThemeSetting(props)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ColorScheme palette(Color primary) => ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
  );

  group('dynamicPaletteProvider', () {
    test('新调色板会改变「系统」来源的 primary', () {
      final container = containerFor(
        const ThemeProps(colorSource: ColorSource.system),
      );

      final before = container.read(genColorSchemeProvider(Brightness.dark));

      container
          .read(dynamicPaletteProvider.notifier)
          .update(
            palette(const Color(0xFF7B1FA2)),
            palette(const Color(0xFF7B1FA2)),
          );

      final after = container.read(genColorSchemeProvider(Brightness.dark));
      expect(
        after.primary,
        isNot(before.primary),
        reason: '换了调色板主题色却不动，就等于没刷新',
      );
    });

    test('写入相同调色板不会改变状态（避免无谓重建）', () {
      final container = containerFor(
        const ThemeProps(colorSource: ColorSource.system),
      );
      final notifier = container.read(dynamicPaletteProvider.notifier);
      final dark = palette(const Color(0xFF00897B));

      notifier.update(dark, dark);
      final first = container.read(dynamicPaletteProvider);

      notifier.update(dark, dark);
      final second = container.read(dynamicPaletteProvider);

      expect(second, first);
    });

    test('没有调色板时回落系统强调色，而不是崩', () {
      final container = containerFor(
        const ThemeProps(colorSource: ColorSource.system),
      );

      // 测试环境没有 Monet：初始状态两侧都是 null。
      expect(container.read(dynamicPaletteProvider).dark, isNull);

      final scheme = container.read(genColorSchemeProvider(Brightness.dark));
      expect(scheme.primary, isNotNull);
    });

    test('品牌配色不受调色板影响', () {
      final container = containerFor(
        const ThemeProps(colorSource: ColorSource.fluxora),
      );
      final before = container.read(genColorSchemeProvider(Brightness.dark));

      container
          .read(dynamicPaletteProvider.notifier)
          .update(
            palette(const Color(0xFF7B1FA2)),
            palette(const Color(0xFF7B1FA2)),
          );

      final after = container.read(genColorSchemeProvider(Brightness.dark));
      expect(after.primary, before.primary);
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
