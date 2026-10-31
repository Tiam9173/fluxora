import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/fluxora_colors.dart';

/// Phase 05.2 — WCAG 2.2 AA contrast over the **mapped** scheme.
///
/// The token file declares one palette; `fluxoraSchemeFromSeed` decides which
/// role each value lands on, and `ColorScheme.fromSeed` derives the rest.
/// Measuring the tokens alone would measure the wrong thing: `onSurface` and
/// `onSurfaceVariant` are seed-derived and are painted on surfaces that come from
/// a *different* palette (Mist / Deep Space), so the pair only exists after
/// mapping.
///
/// Ratios are printed for the record; the assertions are the contract.
double _channel(double v) {
  final c = v / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double luminance(Color c) =>
    0.2126 * _channel(c.r * 255) +
    0.7152 * _channel(c.g * 255) +
    0.0722 * _channel(c.b * 255);

double contrast(Color fg, Color bg) {
  final a = luminance(fg);
  final b = luminance(bg);
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// `fg` painted over `bg` with `fg`'s own alpha — the colour the user sees.
Color alphaOver(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final rows = <String>[];

  for (final brightness in Brightness.values) {
    final scheme = fluxoraSchemeFromSeed(
      brightness: brightness,
      seed: FluxoraColors.fluxCyan,
      variant: DynamicSchemeVariant.tonalSpot,
    );
    final fluxora = FluxoraColorSet.of(brightness);

    // (label, foreground, background, minimum ratio)
    final pairs = <(String, Color, Color, double)>[
      ('onSurface / surface', scheme.onSurface, scheme.surface, 4.5),
      (
        'onSurfaceVariant / surface',
        scheme.onSurfaceVariant,
        scheme.surface,
        4.5,
      ),
      (
        'onSurface / surfaceContainer',
        scheme.onSurface,
        scheme.surfaceContainer,
        4.5,
      ),
      (
        'onSurfaceVariant / surfaceContainer',
        scheme.onSurfaceVariant,
        scheme.surfaceContainer,
        4.5,
      ),
      ('primary / surface', scheme.primary, scheme.surface, 4.5),
      (
        'primary / surfaceContainer',
        scheme.primary,
        scheme.surfaceContainer,
        4.5,
      ),
      ('onPrimary / primary', scheme.onPrimary, scheme.primary, 4.5),
      ('error / surface', scheme.error, scheme.surface, 4.5),
      ('onError / error', scheme.onError, scheme.error, 4.5),
      ('success / surface', fluxora.success, scheme.surface, 4.5),
      ('warning / surface', fluxora.warning, scheme.surface, 4.5),
      ('info / surface', fluxora.info, scheme.surface, 4.5),
    ];

    for (final (label, fg, bg, min) in pairs) {
      final ratio = contrast(fg, bg);
      rows.add(
        '${brightness.name.padRight(5)} ${label.padRight(34)} '
        '${hex(fg)} on ${hex(bg)}  ${ratio.toStringAsFixed(2)}:1 '
        '(min ${min.toStringAsFixed(1)})',
      );
      test('$brightness — $label', () {
        expect(
          ratio,
          greaterThanOrEqualTo(min),
          reason:
              '$label = ${ratio.toStringAsFixed(2)}:1, needs $min:1 '
              '(${hex(fg)} on ${hex(bg)})',
        );
      });
    }

    // `outline` is the frozen Lines role (Phase 03.7 decision): it is never used
    // for text (see `neutral_text_role_test`) and only for dividers, which WCAG
    // 1.4.11 exempts. Recorded so the number cannot drift unnoticed — it is
    // deliberately not asserted as passing.
    test('$brightness — outline stays a low-contrast Lines role', () {
      final ratio = contrast(scheme.outline, scheme.surface);
      expect(
        ratio,
        lessThan(3.0),
        reason:
            'outline is the Lines role (${hex(scheme.outline)} on '
            '${hex(scheme.surface)} = ${ratio.toStringAsFixed(2)}:1); if it ever '
            'clears 3:1 the palette decision changed and this note is stale',
      );
    });

    // A field edge is a *necessary* boundary: 3:1 after compositing. Computed at
    // registration time so the printed table contains it.
    final borderComposite = alphaOver(fluxoraFieldBorder(scheme), scheme.surface);
    final borderRatio = contrast(borderComposite, scheme.surface);
    rows.add(
      '${brightness.name.padRight(5)} ${'field border (composited)'.padRight(34)} '
      '${hex(borderComposite)} on ${hex(scheme.surface)}  '
      '${borderRatio.toStringAsFixed(2)}:1 (min 3.0)',
    );
    test('$brightness — field border clears 3:1 once composited', () {
      expect(
        borderRatio,
        greaterThanOrEqualTo(3.0),
        reason:
            'field border = ${borderRatio.toStringAsFixed(2)}:1 '
            '(${hex(borderComposite)} on ${hex(scheme.surface)})',
      );
    });
  }

  // ignore: avoid_print
  print('\n${rows.join('\n')}\n');
}
