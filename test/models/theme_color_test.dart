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

  // Phase 01-B1 — the error roles must come from the Fluxora semantic set, not
  // from the seed's tonal palette. `dynamicSchemeVariant` is user-selectable, so
  // a variant such as `monochrome` would otherwise drag the error colour along
  // with the brand palette.
  group('genColorSchemeProvider — semantic error roles', () {
    ColorScheme schemeFor(
      Brightness brightness, {
      DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
    }) {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(
            () => _MockThemeSetting(
              ThemeProps(
                colorSource: ColorSource.fluxora,
                schemeVariant: variant,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(genColorSchemeProvider(brightness));
    }

    test('light error + onError come from FluxoraColorSet', () {
      final scheme = schemeFor(Brightness.light);
      final fluxora = FluxoraColorSet.of(Brightness.light);
      expect(scheme.error, fluxora.error);
      expect(scheme.onError, fluxora.onError);
    });

    test('dark error + onError come from FluxoraColorSet', () {
      final scheme = schemeFor(Brightness.dark);
      final fluxora = FluxoraColorSet.of(Brightness.dark);
      expect(scheme.error, fluxora.error);
      expect(scheme.onError, fluxora.onError);
    });

    test('error survives a variant change (monochrome)', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final scheme = schemeFor(
          brightness,
          variant: DynamicSchemeVariant.monochrome,
        );
        expect(
          scheme.error,
          FluxoraColorSet.of(brightness).error,
          reason: 'error must not follow the brand palette on $brightness',
        );
      }
    });

    test('surface / outline / container ladder stay on FluxoraColorSet', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final scheme = schemeFor(brightness);
        final fluxora = FluxoraColorSet.of(brightness);
        expect(scheme.surface, fluxora.background);
        expect(scheme.surfaceContainerLow, fluxora.surface);
        expect(scheme.surfaceContainer, fluxora.surfaceContainer);
        expect(scheme.outline, fluxora.outline);
        expect(scheme.outlineVariant, fluxora.outlineVariant);
      }
    });

    test('primary still tracks the seed', () {
      final scheme = schemeFor(Brightness.light);
      final seeded = ColorScheme.fromSeed(
        seedColor: FluxoraColors.fluxCyan,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
      expect(scheme.primary, seeded.primary);
    });
  });

  // Phase 01-B2 — status tints. `chain_proxy_view.dart` used to wash failure
  // states with `errorContainer` at 30–40%. In dark mode that container is a
  // *dark* tone, so the wash darkened the surface instead of tinting it and the
  // state lost its background cue. The rule is now: tint with the status colour
  // itself — fill 12%, border 40%, text 100%. These tests pin the numbers the
  // rule depends on, using the real schemes and the real card surfaces.
  group('status tint legibility', () {
    ColorScheme schemeFor(Brightness brightness) {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(
            () => _MockThemeSetting(
              ThemeProps(colorSource: ColorSource.fluxora),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(genColorSchemeProvider(brightness));
    }

    /// WCAG 2.1 relative-luminance contrast ratio for two opaque colours.
    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    /// What actually gets painted. `BoxDecoration.color` keeps its alpha, so a
    /// translucent tint is *not* the rendered background — every assertion here
    /// goes through the composite.
    Color over(Color tint, Color background) =>
        Color.alphaBlend(tint, background);

    /// The two surfaces `CommonCard` paints: plain → `surfaceContainerLow`,
    /// filled → `surfaceContainer`. The three-hop banner and the topology node
    /// both sit on a filled card.
    List<Color> cardSurfaces(ColorScheme scheme) => [
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
    ];

    test('error at 12% is a visible wash on every card surface', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final scheme = schemeFor(brightness);
        final tint = scheme.error.withValues(alpha: 0.12);
        for (final surface in cardSurfaces(scheme)) {
          expect(
            contrastRatio(over(tint, surface), surface),
            greaterThanOrEqualTo(1.15),
            reason: 'error@12% must be perceptible on $surface ($brightness)',
          );
        }
      }
    });

    test('error text keeps 4.5:1 on its own 12% tint', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final scheme = schemeFor(brightness);
        final tint = scheme.error.withValues(alpha: 0.12);
        for (final surface in cardSurfaces(scheme)) {
          expect(
            contrastRatio(scheme.error, over(tint, surface)),
            greaterThanOrEqualTo(4.5),
            reason: '11 px error text on its tint ($brightness)',
          );
        }
      }
    });

    test('errorContainer is a weaker wash than error, so it is not a tint', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final scheme = schemeFor(brightness);
        for (final surface in cardSurfaces(scheme)) {
          final containerWash = contrastRatio(
            over(scheme.errorContainer.withValues(alpha: 0.3), surface),
            surface,
          );
          final statusWash = contrastRatio(
            over(scheme.error.withValues(alpha: 0.12), surface),
            surface,
          );
          expect(
            containerWash,
            lessThan(statusWash),
            reason:
                '$brightness / $surface — `errorContainer` must stay the weaker '
                'wash. If this flips, revisit the status note in '
                'fluxora_colors.dart before using it as a tint.',
          );
        }
      }
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

  // Phase 01-B2-B1 — the health / delay / diagnostic badges in
  // `chain_proxy_view.dart` now read `FluxoraColorSet.of(brightness)` instead of
  // `Colors.green` / `orange` / `red` / `blue`. These pin both halves of the
  // reason: the semantic roles carry 10–15 px text, the Material constants they
  // replaced do not.
  //
  // Deliberately **not** asserted: the 12–15 % self-tint behind those badges.
  // On the light theme's `surfaceContainerHigh` that pattern measures 4.15–4.39:1
  // for all four roles — a property of the tint alpha, not of the role colours,
  // and outside this batch.
  group('status role legibility', () {
    /// WCAG 2.1 relative-luminance contrast ratio for two opaque colours.
    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    // `genColorScheme` maps `surfaceContainerLow` → `fluxora.surface` and
    // `surfaceContainer` → `fluxora.surfaceContainer`, so reading the set is the
    // same surfaces `CommonCard` paints — without a provider round-trip.
    Map<String, Color> rolesOf(FluxoraColorSet set) => {
      'success': set.success,
      'warning': set.warning,
      'error': set.error,
      'info': set.info,
    };

    test('every status role carries text on both card surfaces', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final surfaces = {
          'surfaceContainerLow': fluxora.surface,
          'surfaceContainer': fluxora.surfaceContainer,
        };
        for (final role in rolesOf(fluxora).entries) {
          for (final surface in surfaces.entries) {
            expect(
              contrastRatio(role.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${role.key} on ${surface.key} ($brightness) must carry '
                  '10–15 px badge text',
            );
          }
        }
      }
    });

    test('the Material constants this batch replaced cannot carry text', () {
      final lightCard = FluxoraColorSet.of(Brightness.light).surface;
      const replaced = {
        'green': Colors.green,
        'orange': Colors.orange,
        'red': Colors.red,
        'blue': Colors.blue,
      };
      for (final entry in replaced.entries) {
        expect(
          contrastRatio(entry.value, lightCard),
          lessThan(4.5),
          reason:
              'Colors.${entry.key} must stay below AA on a light card — if it '
              'ever passes, re-derive the status roles instead of reverting to '
              'the Material constant.',
        );
      }
    });

    // Phase 01-B2-B2 — the "ready" chip and the test-result bar. They sit on
    // **different** surfaces (`surfaceContainer` on a filled card vs
    // `surfaceContainerHigh` inside `AlertDialog`), so the same tint alpha does
    // not land on the same contrast.
    test('ready chip — success reads on a filled card, plain and tinted', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final card = fluxora.surfaceContainer;
        final fill = Color.alphaBlend(
          fluxora.success.withValues(alpha: 0.15),
          card,
        );
        expect(
          contrastRatio(fluxora.success, card),
          greaterThanOrEqualTo(4.5),
          reason: '11 px bold ready label on the card ($brightness)',
        );
        expect(
          contrastRatio(fluxora.success, fill),
          greaterThanOrEqualTo(4.5),
          reason: '11 px bold ready label on its own 15 % fill ($brightness)',
        );
      }
    });

    // Phase 01-B3-B1 — the healthy / error filter chips draw a 14 px state icon
    // straight on the page surface (the chip body is transparent; only the
    // selected state paints `secondaryContainer`, and then the avatar is covered
    // by the M3 selection scrim). Non-text UI needs 3:1, not 4.5.
    test('filter chip icons meet the 3:1 non-text threshold on the page', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final page = fluxora.background;
        for (final entry in {
          'success': fluxora.success,
          'error': fluxora.error,
        }.entries) {
          expect(
            contrastRatio(entry.value, page),
            greaterThanOrEqualTo(3.0),
            reason: '14 px ${entry.key} chip icon on the page ($brightness)',
          );
        }
      }
    });

    // Phase 01-B3-B2 — the WebRTC protection row sits on a *nested* fill
    // (`surfaceContainerHighest` @50 % over `surfaceContainer`), which is darker
    // than either card surface, so the card-surface test above does not cover it.
    test('webRTC row — success reads on the nested fingerprint fill', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final nested = Color.alphaBlend(
          fluxora.surfaceContainerHighest.withValues(alpha: 0.5),
          fluxora.surfaceContainer,
        );
        expect(
          contrastRatio(fluxora.success, nested),
          greaterThanOrEqualTo(4.5),
          reason: '12 px bold WebRTC text on the nested fill ($brightness)',
        );
      }
    });

    test('test-result bar — plain roles read on the dialog surface', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final dialog = fluxora.surfaceContainerHigh;
        for (final entry in {
          'success': fluxora.success,
          'warning': fluxora.warning,
          'error': fluxora.error,
        }.entries) {
          expect(
            contrastRatio(entry.value, dialog),
            greaterThanOrEqualTo(4.5),
            reason: '12 px result text / icon on the dialog ($brightness)',
          );
        }
      }
    });

    // Phase 01-B2-B2-A — the result bar's fill went 12 % → 8 %. At 12 % the light
    // dialog surface pulled the 12 px text down to 4.36–4.39:1; 8 % clears AA for
    // all three states in both brightnesses.
    test('test-result bar — roles read on their own 8 % fill', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final fluxora = FluxoraColorSet.of(brightness);
        final dialog = fluxora.surfaceContainerHigh;
        for (final entry in {
          'success': fluxora.success,
          'warning': fluxora.warning,
          'error': fluxora.error,
        }.entries) {
          final fill = Color.alphaBlend(
            entry.value.withValues(alpha: 0.08),
            dialog,
          );
          expect(
            contrastRatio(entry.value, fill),
            greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key}@8 % on the dialog surface must carry 12 px result '
                'text ($brightness)',
          );
        }
      }
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
