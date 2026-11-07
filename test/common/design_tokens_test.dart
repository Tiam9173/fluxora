import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// Phase 01-C-0A — contract guards for the design-token layer.
///
/// These are **change detectors, not design opinions**. Every expected value
/// below is copied from the token sources (`fluxora_spacing.dart`,
/// `fluxora_typography.dart`, `fluxora_radius.dart`), so a failure means
/// "someone changed the token layer" — and with it the spacing / type rhythm of every screen that already
/// uses it.
///
/// Before this file there was **no** such guard: editing `FluxoraSpacing.md`
/// from 12 to 14, or `FluxoraTypography.body` from 14 to 15, would silently
/// re-lay-out the app and `flutter test` would stay green.
///
/// Deliberately **not** asserted:
/// * The six levels' `TextStyle.height` (line-height ratio). The spec expresses
///   line height in absolute pixels ("32 / 40"); the ratio is a derived
///   implementation choice, so a future switch to absolute line heights must
///   not fail this guard. Numeric variants are still compared against their
///   level, and `numericTitle` against its own documented 1.33.
/// * `FluxoraSpacing.settingsRowInsets()` — currently unreferenced by any call
///   site, so its shape is not yet a contract.
void main() {
  group('FluxoraSpacing — 4-based ladder', () {
    test('rung values', () {
      expect(FluxoraSpacing.none, 0.0);
      expect(FluxoraSpacing.xxs, 2.0);
      expect(FluxoraSpacing.xs, 4.0);
      expect(FluxoraSpacing.sm, 8.0);
      expect(FluxoraSpacing.md, 12.0);
      expect(FluxoraSpacing.lg, 16.0);
      expect(FluxoraSpacing.xl, 24.0);
      expect(FluxoraSpacing.xxl, 32.0);
      expect(FluxoraSpacing.xxxl, 48.0);
      expect(FluxoraSpacing.huge, 64.0);
    });

    test('ladder is strictly ascending', () {
      const rungs = [
        FluxoraSpacing.none,
        FluxoraSpacing.xxs,
        FluxoraSpacing.xs,
        FluxoraSpacing.sm,
        FluxoraSpacing.md,
        FluxoraSpacing.lg,
        FluxoraSpacing.xl,
        FluxoraSpacing.xxl,
        FluxoraSpacing.xxxl,
        FluxoraSpacing.huge,
      ];
      for (var i = 1; i < rungs.length; i++) {
        expect(
          rungs[i],
          greaterThan(rungs[i - 1]),
          reason: 'rung $i must sit above rung ${i - 1}',
        );
      }
    });

    test('semantic aliases point at the documented rung', () {
      expect(FluxoraSpacing.pagePadding, FluxoraSpacing.lg);
      expect(FluxoraSpacing.cardPadding, FluxoraSpacing.md);
      expect(FluxoraSpacing.listItemPadding, FluxoraSpacing.md);
      expect(FluxoraSpacing.sectionGap, FluxoraSpacing.xl);
      expect(FluxoraSpacing.inlineGap, FluxoraSpacing.sm);
      expect(FluxoraSpacing.fieldGap, FluxoraSpacing.md);
    });

    test('EdgeInsets constants compose from the aliases', () {
      expect(
        FluxoraSpacing.pageInsets,
        EdgeInsets.all(FluxoraSpacing.pagePadding),
      );
      expect(
        FluxoraSpacing.pageInsetsHorizontal,
        EdgeInsets.symmetric(horizontal: FluxoraSpacing.pagePadding),
      );
      expect(
        FluxoraSpacing.cardInsets,
        EdgeInsets.all(FluxoraSpacing.cardPadding),
      );
      expect(
        FluxoraSpacing.cardInsetsHorizontal,
        EdgeInsets.symmetric(horizontal: FluxoraSpacing.cardPadding),
      );
      expect(
        FluxoraSpacing.listItemInsets,
        EdgeInsets.symmetric(
          horizontal: FluxoraSpacing.pagePadding,
          vertical: FluxoraSpacing.listItemPadding,
        ),
      );
      expect(
        FluxoraSpacing.inlineInsets,
        EdgeInsets.symmetric(horizontal: FluxoraSpacing.inlineGap),
      );
      expect(FluxoraSpacing.zeroInsets, EdgeInsets.zero);
    });
  });

  group('FluxoraTypography — weights', () {
    test('only three weights exist', () {
      expect(FluxoraTypography.regular, FontWeight.w400);
      expect(FluxoraTypography.medium, FontWeight.w500);
      expect(FluxoraTypography.semibold, FontWeight.w600);
    });

    test('mono family mirrors the pubspec-declared family', () {
      expect(FluxoraTypography.monoFontFamily, 'JetBrainsMono');
    });
  });

  group('FluxoraTypography — level identity', () {
    // (level, size, weight, letter-spacing) — the four columns of the spec table
    // that define a level. `height` is intentionally excluded, see file header.
    final levels = <(String, TextStyle, double, FontWeight, double)>[
      ('display', FluxoraTypography.display, 32, FontWeight.w600, -0.5),
      ('headline', FluxoraTypography.headline, 24, FontWeight.w600, -0.25),
      ('title', FluxoraTypography.title, 18, FontWeight.w600, 0),
      ('body', FluxoraTypography.body, 14, FontWeight.w400, 0.15),
      ('label', FluxoraTypography.label, 12, FontWeight.w500, 0.4),
      ('caption', FluxoraTypography.caption, 11, FontWeight.w400, 0.4),
    ];

    for (final (name, style, size, weight, spacing) in levels) {
      test('$name is ${size}px / ${weight.toString()} / $spacing', () {
        expect(style.fontSize, size, reason: '$name font size');
        expect(style.fontWeight, weight, reason: '$name weight');
        expect(style.letterSpacing, spacing, reason: '$name letter spacing');
        expect(
          style.fontFamily,
          isNull,
          reason: '$name must inherit the theme font family',
        );
      });
    }

    test('levels lists all six in descending size order', () {
      final listed = FluxoraTypography.levels;
      expect(listed.length, 6);
      expect(listed.first, FluxoraTypography.display);
      expect(listed.last, FluxoraTypography.caption);
      for (var i = 1; i < listed.length; i++) {
        expect(
          listed[i].fontSize,
          lessThan(listed[i - 1].fontSize!),
          reason: 'levels must be ordered by descending size',
        );
      }
    });
  });

  group('FluxoraTypography — numeric variants', () {
    void expectMonoRecast(TextStyle numeric, TextStyle level, String name) {
      expect(
        numeric.fontFamily,
        FluxoraTypography.monoFontFamily,
        reason: '$name must use the mono family',
      );
      expect(numeric.fontSize, level.fontSize, reason: '$name size');
      expect(numeric.fontWeight, level.fontWeight, reason: '$name weight');
      expect(numeric.height, level.height, reason: '$name line height');
      expect(
        numeric.letterSpacing,
        level.letterSpacing,
        reason: '$name letter spacing',
      );
    }

    test('numericTitle is an 18px w500 mono read-out, not mono(title)', () {
      // `numericTitle` intentionally sits at w500 while `title` is w600 — live
      // read-outs read too heavy at semibold. The doc comment says so; this
      // test pins the shipped contract so neither side drifts silently.
      expect(FluxoraTypography.numericTitle.fontSize, 18);
      expect(FluxoraTypography.numericTitle.fontWeight, FontWeight.w500);
      expect(FluxoraTypography.numericTitle.height, 1.33);
      expect(FluxoraTypography.numericTitle.letterSpacing, 0);
      expect(
        FluxoraTypography.numericTitle.fontFamily,
        FluxoraTypography.monoFontFamily,
      );
    });

    test('numericBody is `body` on the mono family', () {
      expectMonoRecast(
        FluxoraTypography.numericBody,
        FluxoraTypography.body,
        'numericBody',
      );
    });

    test('numericLabel is `label` on the mono family', () {
      expectMonoRecast(
        FluxoraTypography.numericLabel,
        FluxoraTypography.label,
        'numericLabel',
      );
    });

    test('mono() recasts a level without touching the other properties', () {
      final recast = FluxoraTypography.mono(FluxoraTypography.body);
      expect(recast.fontFamily, FluxoraTypography.monoFontFamily);
      expect(recast.fontSize, FluxoraTypography.body.fontSize);
      expect(recast.fontWeight, FluxoraTypography.body.fontWeight);
      expect(recast.height, FluxoraTypography.body.height);
      expect(recast.letterSpacing, FluxoraTypography.body.letterSpacing);
    });
  });

  group('FluxoraTypography — TextTheme mapping', () {
    test('Material slots resolve to the six levels', () {
      final t = FluxoraTypography.textTheme();
      expect(t.displayLarge, FluxoraTypography.display);
      expect(t.displayMedium, FluxoraTypography.display);
      expect(t.displaySmall, FluxoraTypography.headline);
      expect(t.headlineLarge, FluxoraTypography.headline);
      expect(t.headlineSmall, FluxoraTypography.title);
      expect(t.titleLarge, FluxoraTypography.title);
      expect(t.titleMedium, FluxoraTypography.title);
      expect(t.titleSmall, FluxoraTypography.label);
      expect(t.bodyLarge, FluxoraTypography.body);
      expect(t.bodyMedium, FluxoraTypography.body);
      expect(t.bodySmall, FluxoraTypography.caption);
      expect(t.labelLarge, FluxoraTypography.label);
      expect(t.labelMedium, FluxoraTypography.label);
      expect(t.labelSmall, FluxoraTypography.caption);
    });

    test('every mapped style leaves colour unset so the theme supplies it', () {
      final t = FluxoraTypography.textTheme();
      for (final style in FluxoraTypography.levels) {
        expect(style.color, isNull);
      }
      expect(t.bodyMedium?.color, isNull);
      expect(t.titleLarge?.color, isNull);
    });
  });

  group('FluxoraRadius — ladder and semantic aliases', () {
    test('4-based ladder values', () {
      expect(FluxoraRadius.none, 0.0);
      expect(FluxoraRadius.xs, 4.0);
      expect(FluxoraRadius.sm, 8.0);
      expect(FluxoraRadius.md, 12.0);
      expect(FluxoraRadius.lg, 16.0);
      expect(FluxoraRadius.xl, 24.0);
      expect(FluxoraRadius.xxl, 36.0);
      expect(FluxoraRadius.full, 999.0);
    });

    test('semantic aliases point at the documented rung', () {
      expect(FluxoraRadius.card, FluxoraRadius.xl);
      expect(FluxoraRadius.button, FluxoraRadius.full);
      expect(FluxoraRadius.chip, FluxoraRadius.lg);
      expect(FluxoraRadius.dialog, FluxoraRadius.xl);
      expect(FluxoraRadius.inputCompact, FluxoraRadius.sm);
      expect(FluxoraRadius.icon, FluxoraRadius.sm);
      expect(FluxoraRadius.badge, FluxoraRadius.xs);
      expect(FluxoraRadius.avatar, FluxoraRadius.full);
    });

    test('off-ladder design values are deliberate, not drift', () {
      // Each of these is set explicitly by the theme layer in both brightnesses.
      // Rounding them onto the 4-based ladder would visibly change surfaces the
      // whole app shares, so they stay off it on purpose — see the token docs.
      expect(FluxoraRadius.sheet, 28.0, reason: 'bottom sheet surface');
      expect(FluxoraRadius.field, 18.0, reason: 'inputDecorationTheme borders');
      expect(
        FluxoraRadius.fab,
        20.0,
        reason: 'floatingActionButtonTheme shape',
      );
    });

    test('field and inputCompact are different roles, not duplicates', () {
      // 18 on a 36 px dense field would clamp to a pill, which is why the
      // editor's find/replace bar uses the 8 px compact token instead.
      expect(FluxoraRadius.field, isNot(FluxoraRadius.inputCompact));
    });

    test('*All constants mirror their scalar token', () {
      const cases = <(double, BorderRadius)>[
        (FluxoraRadius.xs, FluxoraRadius.xsAll),
        (FluxoraRadius.sm, FluxoraRadius.smAll),
        (FluxoraRadius.md, FluxoraRadius.mdAll),
        (FluxoraRadius.lg, FluxoraRadius.lgAll),
        (FluxoraRadius.xl, FluxoraRadius.xlAll),
        (FluxoraRadius.full, FluxoraRadius.fullAll),
        (FluxoraRadius.card, FluxoraRadius.cardAll),
        (FluxoraRadius.button, FluxoraRadius.buttonAll),
        (FluxoraRadius.dialog, FluxoraRadius.dialogAll),
        (FluxoraRadius.sheet, FluxoraRadius.sheetAll),
        (FluxoraRadius.field, FluxoraRadius.fieldAll),
        (FluxoraRadius.fab, FluxoraRadius.fabAll),
      ];
      for (final (value, radius) in cases) {
        expect(
          radius,
          BorderRadius.all(Radius.circular(value)),
          reason: '*All must equal BorderRadius.all(circular($value))',
        );
      }
    });

    test('sheetTop rounds only the top edge with the sheet radius', () {
      final r = Radius.circular(FluxoraRadius.sheet);
      expect(FluxoraRadius.sheetTop.topLeft, r);
      expect(FluxoraRadius.sheetTop.topRight, r);
      expect(FluxoraRadius.sheetTop.bottomLeft, Radius.zero);
      expect(FluxoraRadius.sheetTop.bottomRight, Radius.zero);
    });
  });

  group('FluxoraFontSize — size-only companion', () {
    test('values match the sizes they replace', () {
      // These three are value-identical to the literals they were migrated from,
      // which is the whole point: naming a size must not re-typeset the text.
      expect(FluxoraFontSize.micro, 10.0);
      expect(FluxoraFontSize.compact, 13.0);
      expect(FluxoraFontSize.section, 15.0);
    });

    test('they carry no weight or tracking of their own', () {
      // A size-only token is a double, not a TextStyle — so it can never
      // silently change weight/spacing the way a composite level would.
      expect(FluxoraFontSize.micro, isA<double>());
      expect(FluxoraFontSize.compact, isA<double>());
      expect(FluxoraFontSize.section, isA<double>());
    });

    test('section sits between body and title, which is why it exists', () {
      expect(
        FluxoraFontSize.section,
        greaterThan(FluxoraTypography.body.fontSize!),
      );
      expect(
        FluxoraFontSize.section,
        lessThan(FluxoraTypography.title.fontSize!),
      );
    });

    test('the sizes stay off the six-level ladder on purpose', () {
      final levelSizes = FluxoraTypography.levels
          .map((s) => s.fontSize!)
          .toSet();
      expect(levelSizes, isNot(contains(FluxoraFontSize.micro)));
      expect(levelSizes, isNot(contains(FluxoraFontSize.compact)));
      expect(levelSizes, isNot(contains(FluxoraFontSize.section)));
    });
  });

  group(
    'FluxoraColorSet.selectionTint — one definition for three navigations',
    () {
      const primary = Color(0xFF006A62);

      test('light keeps 20 % and dark keeps 26 %', () {
        // These two numbers were duplicated across the desktop rail, the mobile
        // bottom bar and the TV bar; if one drifts the navigations stop matching.
        expect(
          FluxoraColorSet.selectionTint(primary, Brightness.light).a,
          closeTo(0.20, 0.005),
        );
        expect(
          FluxoraColorSet.selectionTint(primary, Brightness.dark).a,
          closeTo(0.26, 0.005),
        );
      });

      test('the base colour is passed through untouched', () {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          final tint = FluxoraColorSet.selectionTint(primary, brightness);
          expect(tint.r, primary.r);
          expect(tint.g, primary.g);
          expect(tint.b, primary.b);
        }
      });

      test('the result is translucent, not opaque', () {
        // A regression to a plain `primary` would paint a solid block instead of
        // a wash and would also change the label contrast underneath.
        for (final brightness in [Brightness.light, Brightness.dark]) {
          expect(
            FluxoraColorSet.selectionTint(primary, brightness).a,
            lessThan(1.0),
          );
        }
      });
    },
  );
  group('FluxoraElevation — the rung the navigation bars use', () {
    test('semantic aliases point at the documented level', () {
      expect(FluxoraElevation.menu, FluxoraElevation.level3);
      expect(FluxoraElevation.raised, FluxoraElevation.level2);
      expect(FluxoraElevation.overlay, FluxoraElevation.level4);
      expect(FluxoraElevation.resting, FluxoraElevation.level0);
    });

    test('the menu rung is one soft shadow, not a stack', () {
      // Both navigation bars take this rung (mobile in the previous batch, TV in
      // this one). The old TV bar stacked a hand-rolled blur 20 / 15 % shadow,
      // so pinning the shape keeps the two from diverging again.
      expect(FluxoraElevation.light.menu, hasLength(1));
      expect(FluxoraElevation.dark.menu, hasLength(1));

      expect(FluxoraElevation.light.menu.single.blurRadius, 16);
      expect(FluxoraElevation.dark.menu.single.blurRadius, 16);
    });

    test('dark uses a heavier alpha than light at the same rung', () {
      // §8.2: a black shadow over a navy surface barely reads, so the dark
      // ladder leans harder on alpha where it keeps a shadow at all.
      final lightAlpha = FluxoraElevation.light.menu.single.color.a;
      final darkAlpha = FluxoraElevation.dark.menu.single.color.a;
      expect(darkAlpha, greaterThan(lightAlpha));
    });

    test('light blurs rise with the ladder', () {
      final blurs = [
        FluxoraElevation.light.level1,
        FluxoraElevation.light.level2,
        FluxoraElevation.light.level3,
        FluxoraElevation.light.level4,
        FluxoraElevation.light.level5,
      ].map((shadows) => shadows.single.blurRadius).toList();
      for (var i = 1; i < blurs.length; i++) {
        expect(blurs[i], greaterThan(blurs[i - 1]), reason: 'rung $i');
      }
    });

    test('the low dark rungs carry no shadow at all', () {
      // Hierarchy in dark mode comes from surface brightness, not shadow.
      expect(FluxoraElevation.dark.level0, isEmpty);
      expect(FluxoraElevation.dark.level1, isEmpty);
      expect(FluxoraElevation.dark.level2, isEmpty);
    });
  });
}
