import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProps Migration Tests', () {
    test('Empty / null JSON falls back to defaultThemeProps with fluxora', () {
      final theme = ThemeProps.safeFromJson(null);
      expect(theme.colorSource, ColorSource.fluxora);
      expect(theme.primaryColor, defaultPrimaryColor);
    });

    test('Legacy Bettbox config without colorSource migrates to fluxora brand', () {
      final legacyJson = {
        'primaryColor': legacyDefaultPrimaryColor, // 0xFF00897B (4278225275)
        'primaryColors': [
          0xFF1E293B,
          0xFF1976D2,
          legacyDefaultPrimaryColor,
          0xFFE91E63,
        ],
        'themeMode': 'system',
      };

      final migrated = ThemeProps.migrateColorSource(legacyJson);
      expect(migrated['colorSource'], ColorSource.fluxora.name);
      expect(migrated['primaryColor'], defaultPrimaryColor);

      final theme = ThemeProps.safeFromJson(legacyJson);
      expect(theme.colorSource, ColorSource.fluxora);
      expect(theme.primaryColor, defaultPrimaryColor);
      expect(theme.primaryColors.contains(legacyDefaultPrimaryColor), isFalse);
      expect(theme.primaryColors.contains(defaultPrimaryColor), isTrue);
    });

    test('Legacy Android signed 32-bit integer (-16741989) migrates correctly', () {
      // 0xFF00897B as signed 32-bit integer is -16741989
      final signedLegacyTeal = legacyDefaultPrimaryColor.toSigned(32);
      final legacyAndroidJson = {
        'primaryColor': signedLegacyTeal,
        'primaryColors': [signedLegacyTeal],
        'themeMode': 'system',
      };

      final migrated = ThemeProps.migrateColorSource(legacyAndroidJson);
      expect(migrated['colorSource'], ColorSource.fluxora.name);
      expect(migrated['primaryColor'], defaultPrimaryColor);

      final theme = ThemeProps.safeFromJson(legacyAndroidJson);
      expect(theme.colorSource, ColorSource.fluxora);
      expect(theme.primaryColor, defaultPrimaryColor);
      expect(theme.primaryColors.contains(signedLegacyTeal), isFalse);
      expect(theme.primaryColors.contains(defaultPrimaryColor), isTrue);
    });

    test('Config already containing colorSource: fluxora but legacy primaryColor is normalized', () {
      final json = {
        'colorSource': 'fluxora',
        'primaryColor': legacyDefaultPrimaryColor,
        'themeMode': 'system',
      };

      final migrated = ThemeProps.migrateColorSource(json);
      expect(migrated['colorSource'], ColorSource.fluxora.name);
      expect(migrated['primaryColor'], defaultPrimaryColor);

      final theme = ThemeProps.safeFromJson(json);
      expect(theme.colorSource, ColorSource.fluxora);
      expect(theme.primaryColor, defaultPrimaryColor);
    });

    test('Config mistakenly marked colorSource: custom with legacy Bettbox teal is upgraded', () {
      final signedLegacyTeal = legacyDefaultPrimaryColor.toSigned(32);
      final json = {
        'colorSource': 'custom',
        'primaryColor': signedLegacyTeal,
        'themeMode': 'system',
      };

      final migrated = ThemeProps.migrateColorSource(json);
      expect(migrated['colorSource'], ColorSource.fluxora.name);
      expect(migrated['primaryColor'], defaultPrimaryColor);

      final theme = ThemeProps.safeFromJson(json);
      expect(theme.colorSource, ColorSource.fluxora);
      expect(theme.primaryColor, defaultPrimaryColor);
    });

    test('Real user custom color is strictly preserved and not overwritten', () {
      const userPickedPink = 0xFFE91E63;
      final userJson = {
        'primaryColor': userPickedPink,
        'primaryColors': [defaultPrimaryColor, userPickedPink],
        'themeMode': 'dark',
      };

      final migrated = ThemeProps.migrateColorSource(userJson);
      expect(migrated['colorSource'], ColorSource.custom.name);
      expect(migrated['primaryColor'], userPickedPink);

      final theme = ThemeProps.safeFromJson(userJson);
      expect(theme.colorSource, ColorSource.custom);
      expect(theme.primaryColor, userPickedPink);
    });
  });

  group('genColorSchemeProvider Tests', () {
    test('ColorSource.fluxora always seeds FluxoraColors.fluxCyan regardless of primaryColor', () {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(
                ThemeProps(
                  colorSource: ColorSource.fluxora,
                  primaryColor: legacyDefaultPrimaryColor, // Even if legacy teal is set!
                ),
              )),
        ],
      );

      final scheme = container.read(genColorSchemeProvider(Brightness.light));
      // Primary color must match seed ColorScheme.fromSeed with FluxoraColors.fluxCyan
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: FluxoraColors.fluxCyan,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      expect(scheme.primary, expectedScheme.primary);
      expect(scheme.primary, isNot(equals(
        ColorScheme.fromSeed(
          seedColor: const Color(legacyDefaultPrimaryColor),
          brightness: Brightness.light,
        ).primary,
      )));
    });

    test('ColorSource.custom with legacy Bettbox teal falls back to FluxoraColors.fluxCyan', () {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(
                const ThemeProps(
                  colorSource: ColorSource.custom,
                  primaryColor: legacyDefaultPrimaryColor,
                ),
              )),
        ],
      );

      final scheme = container.read(genColorSchemeProvider(Brightness.light));
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: FluxoraColors.fluxCyan,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      expect(scheme.primary, expectedScheme.primary);
    });

    test('ColorSource.custom with genuine custom color produces that custom scheme', () {
      const customColor = Color(0xFFE91E63);
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(
                const ThemeProps(
                  colorSource: ColorSource.custom,
                  primaryColor: 0xFFE91E63,
                ),
              )),
        ],
      );

      final scheme = container.read(genColorSchemeProvider(Brightness.light));
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: customColor,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      expect(scheme.primary, expectedScheme.primary);
    });

    test('Dark mode with pureBlack retains Fluxora brand seeds and surface', () {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => _MockThemeSetting(
                const ThemeProps(
                  colorSource: ColorSource.fluxora,
                  pureBlack: true,
                ),
              )),
        ],
      );

      final scheme = container.read(genColorSchemeProvider(Brightness.dark));
      final fluxoraDark = FluxoraColorSet.of(Brightness.dark);
      expect(scheme.surface, fluxoraDark.background);
      expect(scheme.surfaceContainerLowest, fluxoraDark.surface);
    });
  });

  group('Theme Switching & State Updates Tests', () {
    test('Switching from custom to fluxora resets primaryColor to defaultPrimaryColor', () {
      final notifier = _MockThemeSetting(
        const ThemeProps(
          colorSource: ColorSource.custom,
          primaryColor: 0xFFE91E63,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(() => notifier),
        ],
      );

      expect(container.read(themeSettingProvider).colorSource, ColorSource.custom);
      expect(container.read(themeSettingProvider).primaryColor, 0xFFE91E63);

      // Simulate user selecting Fluxora in _ColorSourceItem
      container.read(themeSettingProvider.notifier).updateState(
            (state) => state.copyWith(
              colorSource: ColorSource.fluxora,
              primaryColor: ColorSource.fluxora == ColorSource.fluxora
                  ? defaultPrimaryColor
                  : state.primaryColor,
            ),
          );

      expect(container.read(themeSettingProvider).colorSource, ColorSource.fluxora);
      expect(container.read(themeSettingProvider).primaryColor, defaultPrimaryColor);
    });

    test('Full JSON round-trip maintains ThemeProps fidelity', () {
      final original = const ThemeProps(
        colorSource: ColorSource.fluxora,
        primaryColor: defaultPrimaryColor,
        themeMode: ThemeMode.dark,
        schemeVariant: DynamicSchemeVariant.tonalSpot,
        pureBlack: true,
      );

      final jsonString = json.encode(original.toJson());
      final jsonMap = json.decode(jsonString) as Map<String, Object?>;
      final restored = ThemeProps.safeFromJson(jsonMap);

      expect(restored.colorSource, ColorSource.fluxora);
      expect(restored.primaryColor, defaultPrimaryColor);
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.schemeVariant, DynamicSchemeVariant.tonalSpot);
      expect(restored.pureBlack, isTrue);
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
