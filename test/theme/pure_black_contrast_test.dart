import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/color.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/fluxora_colors.dart';

/// Phase 06.2 — the `pureBlack` variant, which `theme_contrast_test` never
/// covered.
///
/// `ColorScheme.toPureBlack(true)` only swaps two roles:
/// `surface: Colors.black` and `surfaceContainer: surfaceContainer.darken(5)`.
/// Everything the user *reads* — `onSurface`, `onSurfaceVariant`, `primary`,
/// `error` — keeps its standard dark value, so the question is whether those
/// still clear 4.5:1 against a black canvas and against the darkened container.
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
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final rows = <String>[];
  final base = fluxoraSchemeFromSeed(
    brightness: Brightness.dark,
    seed: FluxoraColors.fluxCyan,
    variant: DynamicSchemeVariant.tonalSpot,
  );
  final pure = base.toPureBlack(true);

  test('pureBlack only repaints the canvas and the container', () {
    expect(pure.surface, Colors.black);
    expect(pure.surfaceContainer, base.surfaceContainer.darken(5));
    // The roles the user reads are deliberately untouched.
    expect(pure.onSurface, base.onSurface);
    expect(pure.onSurfaceVariant, base.onSurfaceVariant);
    expect(pure.primary, base.primary);
    expect(pure.error, base.error);
  });

  final pairs = <(String, Color, Color, double)>[
    ('onSurface / surface', pure.onSurface, pure.surface, 4.5),
    ('onSurfaceVariant / surface', pure.onSurfaceVariant, pure.surface, 4.5),
    (
      'onSurface / surfaceContainer',
      pure.onSurface,
      pure.surfaceContainer,
      4.5,
    ),
    (
      'onSurfaceVariant / surfaceContainer',
      pure.onSurfaceVariant,
      pure.surfaceContainer,
      4.5,
    ),
    ('primary / surface', pure.primary, pure.surface, 4.5),
    ('error / surface', pure.error, pure.surface, 4.5),
  ];

  for (final (label, fg, bg, min) in pairs) {
    final ratio = contrast(fg, bg);
    rows.add(
      'pureBlack ${label.padRight(34)} ${hex(fg)} on ${hex(bg)}  '
      '${ratio.toStringAsFixed(2)}:1 (min ${min.toStringAsFixed(1)})',
    );
    test('pureBlack — $label', () {
      expect(
        ratio,
        greaterThanOrEqualTo(min),
        reason: '$label = ${ratio.toStringAsFixed(2)}:1 (${hex(fg)} on ${hex(bg)})',
      );
    });
  }

  test('the container is still a step above the black canvas', () {
    final ratio = contrast(pure.surfaceContainer, pure.surface);
    rows.add(
      'pureBlack ${'surfaceContainer / surface (layer)'.padRight(34)} '
      '${hex(pure.surfaceContainer)} on ${hex(pure.surface)}  '
      '${ratio.toStringAsFixed(2)}:1 (layering, no AA threshold)',
    );
    // Not a WCAG requirement — a card has to be *visible* as a separate layer.
    // The contract is only that the container stays lighter than the canvas (and
    // therefore a card is not swallowed by it); comparing the ratio against the
    // standard dark theme would compare two different canvases and is arbitrary.
    expect(ratio, greaterThan(1.0));
    expect(
      luminance(pure.surfaceContainer),
      greaterThan(luminance(pure.surface)),
      reason: 'a card surface must be lighter than the pure-black canvas',
    );
    expect(
      pure.surfaceContainer,
      isNot(base.surfaceContainer),
      reason: 'pureBlack darkens the container, it does not reuse the standard one',
    );
  });

  // ignore: avoid_print
  print('\n${rows.join('\n')}\n');
}
