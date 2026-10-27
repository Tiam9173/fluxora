import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// Phase 01-C-0A — contract guards for the design-token layer.
///
/// These are **change detectors, not design opinions**. Every expected value
/// below is copied from the token sources (`fluxora_spacing.dart`,
/// `fluxora_typography.dart`), so a failure means "someone changed the token
/// layer" — and with it the spacing / type rhythm of every screen that already
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
}
