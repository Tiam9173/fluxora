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

  // ── Phase 01 — surface ladder legibility ─────────────────────────────────
  //
  // Text has to stay readable on every rung of the surface ladder, not just on
  // `surface`. Nothing asserted this before: the existing groups pin status
  // roles and their tints, but `onSurface` / `onSurfaceVariant` against
  // `surfaceContainerHigh` / `surfaceContainerHighest` was untested in either
  // brightness — and the light theme is where a neutral that sits too close to
  // its surface shows up first.
  //
  // 4.5:1 is WCAG 2.1 AA for normal text, so these are external thresholds, not
  // numbers invented for this codebase.

  group('surface ladder legibility', () {
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

    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    Map<String, Color> ladder(ColorScheme s) => {
      'surface': s.surface,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
    };

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('primary text clears AA on every rung ($brightness)', () {
        final s = schemeFor(brightness);
        for (final entry in ladder(s).entries) {
          expect(
            contrastRatio(s.onSurface, entry.value),
            greaterThanOrEqualTo(4.5),
            reason: 'onSurface on ${entry.key} ($brightness)',
          );
        }
      });

      test('secondary text clears AA on every rung ($brightness)', () {
        final s = schemeFor(brightness);
        for (final entry in ladder(s).entries) {
          expect(
            contrastRatio(s.onSurfaceVariant, entry.value),
            greaterThanOrEqualTo(4.5),
            reason: 'onSurfaceVariant on ${entry.key} ($brightness)',
          );
        }
      });

      test('the rungs are strictly ordered by luminance ($brightness)', () {
        // A flat or inverted ladder is the failure mode this guards: two rungs
        // within a rounding step of each other read as one sheet, and an
        // inverted one puts "higher" cards below their background.
        final s = schemeFor(brightness);
        final values = ladder(s).values.toList();
        final rising = brightness == Brightness.dark;
        for (var i = 1; i < values.length; i++) {
          final prev = values[i - 1].computeLuminance();
          final next = values[i].computeLuminance();
          expect(
            next,
            isNot(equals(prev)),
            reason: 'rung $i must differ from rung ${i - 1} ($brightness)',
          );
          if (rising) {
            expect(
              next,
              greaterThan(prev),
              reason:
                  'dark ladder rises with elevation: rung $i must sit above '
                  'rung ${i - 1}',
            );
          }
        }
      });
    }
  });

  // ── Phase 01 — SnackBar legibility (M3 inverse roles) ────────────────────
  //
  // `genColorScheme` maps most roles explicitly but leaves `inverseSurface`,
  // `onInverseSurface`, `inversePrimary`, `surfaceTint` and `scrim` to
  // `ColorScheme.fromSeed`. A `SnackBar` reads `inverseSurface` /
  // `onInverseSurface` for its background and text, and **none** of the 4
  // construction paths in the app overrides either one — so those derived
  // values are what every snackbar actually paints.
  //
  // Measured 2026-10-28 (fluxora seed, tonalSpot):
  //   light: bg #2B3230 / text #ECF2F0 → 11.57:1
  //   dark : bg #DDE4E2 / text #2B3230 → 10.16:1
  //
  // Both clear AA by a wide margin, so these tests **pin the current state**
  // rather than fix a defect: a seed or variant change that drops the ratio
  // below 4.5:1 now fails here instead of shipping.

  group('snackbar legibility (M3 inverse roles)', () {
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

    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('snackbar text clears AA on its inverse surface ($brightness)', () {
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.onInverseSurface, s.inverseSurface),
          greaterThanOrEqualTo(4.5),
          reason:
              'SnackBar paints onInverseSurface on inverseSurface '
              '($brightness)',
        );
      });

      test('the snackbar surface separates from the page ($brightness)', () {
        // If the two collapsed, a floating snackbar would read as part of the
        // page instead of an overlay. 3:1 is the WCAG non-text threshold.
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.inverseSurface, s.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'inverseSurface must stand off surface ($brightness)',
        );
      });
    }
  });

  // ── Phase 01 — component state contrast ──────────────────────────────────
  //
  // Every semantic pair a component paints text with, measured on the live
  // scheme. Values as of 2026-10-28:
  //
  // | pair                              | light | dark  |
  // | --------------------------------- | ----- | ----- |
  // | error / surface                   | 6.18  | 10.99 |
  // | primary / surface                 | 6.13  | 10.94 |
  // | onPrimary / primary               | 6.49  |  7.72 |
  // | onPrimaryContainer / container    | 7.25  |  7.25 |
  // | onSecondaryContainer / container  | 7.25  |  7.25 |
  //
  // Deliberately **not** asserted, with the measured value recorded here so a
  // future reader does not mistake the gap for an oversight:
  //
  // * `outline` / `surface` = 1.40 (light) / 1.80 (dark). That is below the
  //   3:1 WCAG 1.4.11 asks of a *meaningful* component boundary. Raising it
  //   means editing the palette every border in the app shares — a global
  //   design decision, not a local fix, so it is reported rather than changed.
  // * `outlineVariant` / `surfaceContainerHighest` = 1.05. `outlineVariant` is
  //   Material's decorative-divider role; low contrast is by design (N/A).
  // * disabled text (`onSurface` @ 38 %) / `surface` = 2.34 (light) / 3.02
  //   (dark). WCAG 1.4.3 explicitly exempts inactive controls (N/A).

  group('component state contrast', () {
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

    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('semantic text pairs clear AA ($brightness)', () {
        final s = schemeFor(brightness);
        final pairs = <String, (Color, Color)>{
          'error on surface': (s.error, s.surface),
          'primary on surface': (s.primary, s.surface),
          'onPrimary on primary': (s.onPrimary, s.primary),
          'onPrimaryContainer on primaryContainer': (
            s.onPrimaryContainer,
            s.primaryContainer,
          ),
          'onSecondaryContainer on secondaryContainer': (
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
        };
        for (final entry in pairs.entries) {
          expect(
            contrastRatio(entry.value.$1, entry.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} ($brightness)',
          );
        }
      });
    }
  });

  // ── Phase 02 — navigation / content surface separation ───────────────────
  //
  // The generic surface-ladder group above walks `surface → surfaceContainer*`.
  // This one checks the two **actual pairs the navigation paints**, read off the
  // production widgets:
  //
  //   · desktop rail background  → `colorScheme.surfaceContainerHigh`
  //     (`app_manager.dart:309`)
  //   · mobile bottom bar        → `colorScheme.surfaceContainer`
  //     (`aurora_bottom_nav_bar.dart`)
  //   · page canvas              → `colorScheme.surface`
  //
  // Measured 2026-10-28 (fluxora seed):
  //
  // | pair                     | light            | dark             |
  // | ------------------------ | ---------------- | ---------------- |
  // | rail / page contrast     | 1.168            | 1.309            |
  // | bar  / page contrast     | **1.055**        | 1.181            |
  // | rail luminance           | 0.8000           | 0.0236           |
  // | bar  luminance           | 0.8911           | 0.0164           |
  // | page luminance           | 0.9431           | 0.0063           |
  //
  // The bar's 1.055 in light mode is **not** asserted against a ratio floor: a
  // floating bar separates itself with its `menu` shadow and an
  // `outlineVariant` border, not with fill alone, and forcing a higher fill
  // contrast would mean editing the shared surface ladder. It is pinned by
  // ordering instead, which is enough to catch the bar collapsing onto the page.
  //
  // None of this is visual acceptance: it proves the numbers, not that the rail
  // reads as a separate plane in a real window.

  group('navigation / content surface separation', () {
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

    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('the rail stands off the page ($brightness)', () {
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.surfaceContainerHigh, s.surface),
          greaterThanOrEqualTo(1.10),
          reason:
              'surfaceContainerHigh vs surface must be a visible plane change '
              '($brightness)',
        );
      });

      test('navigation surfaces are distinct from the page ($brightness)', () {
        final s = schemeFor(brightness);
        expect(s.surfaceContainerHigh, isNot(equals(s.surface)));
        expect(s.surfaceContainer, isNot(equals(s.surface)));
      });

      test('the rail steps further from the page than the bar ($brightness)', () {
        // Elevation order, expressed in luminance: the rail is the "higher"
        // plane in both themes, so its distance from the page must be larger.
        final s = schemeFor(brightness);
        final page = s.surface.computeLuminance();
        final bar = s.surfaceContainer.computeLuminance();
        final rail = s.surfaceContainerHigh.computeLuminance();

        expect(
          (rail - page).abs(),
          greaterThan((bar - page).abs()),
          reason: 'the rail must sit further from the page than the bar',
        );
      });

      test('the ladder direction matches the brightness ($brightness)', () {
        // Light: planes get darker as they rise. Dark: planes get lighter.
        final s = schemeFor(brightness);
        final page = s.surface.computeLuminance();
        final bar = s.surfaceContainer.computeLuminance();
        final rail = s.surfaceContainerHigh.computeLuminance();

        if (brightness == Brightness.light) {
          expect(page, greaterThan(bar));
          expect(bar, greaterThan(rail));
        } else {
          expect(page, lessThan(bar));
          expect(bar, lessThan(rail));
        }
      });
    }
  });


  // ── Phase 02 — Aurora rail state legibility ──────────────────────────────
  //
  // The rail marks the current page with a low-saturation brand wash plus a
  // 3 px accent bar, and leaves the label neutral. That split is deliberate:
  // `primary` on the tinted pill only reaches ≈4.1:1 in the light theme, which
  // would fail the text threshold. These assertions pin the split so a later
  // "make it more branded" tweak has to argue with numbers, not taste.

  group('Aurora rail state legibility', () {
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

    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    /// The pill as it actually renders: the translucent tint over the rail.
    Color pill(ColorScheme s) => Color.alphaBlend(
      FluxoraColorSet.selectionTint(s.primary, s.brightness),
      s.surfaceContainerHigh,
    );

    Color hoverWash(ColorScheme s) => Color.alphaBlend(
      s.onSurface.withValues(
        alpha: s.brightness == Brightness.dark ? 0.06 : 0.05,
      ),
      s.surfaceContainerHigh,
    );

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('the selected label clears 4.5:1 on the pill ($brightness)', () {
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.onSurface, pill(s)),
          greaterThanOrEqualTo(4.5),
          reason: 'the current page label is body-sized text',
        );
      });

      test('the unselected label clears 4.5:1 on the rail ($brightness)', () {
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.onSurfaceVariant, s.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('the selected icon clears the 3:1 graphic threshold ($brightness)', () {
        final s = schemeFor(brightness);
        expect(
          contrastRatio(s.primary, pill(s)),
          greaterThanOrEqualTo(3.0),
          reason: 'the icon is a graphic, not text — 3:1 is its bar',
        );
      });

      test('hover is visible but weaker than selection ($brightness)', () {
        final s = schemeFor(brightness);
        final hover = contrastRatio(hoverWash(s), s.surfaceContainerHigh);
        final selected = contrastRatio(pill(s), s.surfaceContainerHigh);

        expect(hover, greaterThan(1.0), reason: 'hover must be perceivable');
        expect(
          hover,
          lessThan(selected),
          reason: 'hover must not read as strong as the current page',
        );
      });
    }
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
