import 'package:fluxora/common/common.dart';
import 'package:flutter/material.dart';

class CommonTheme {
  final BuildContext context;
  final Map<String, Color> _colorMap;
  final double textScaleFactor;

  CommonTheme.of(this.context, this.textScaleFactor) : _colorMap = {};

  Color get darkenSecondaryContainer {
    return _colorMap.updateCacheValue(
      'darkenSecondaryContainer',
      () => context.colorScheme.secondaryContainer.blendDarken(
        context,
        factor: 0.1,
      ),
    );
  }

  Color get darkenSecondaryContainerLighter {
    return _colorMap.updateCacheValue(
      'darkenSecondaryContainerLighter',
      () => context.colorScheme.secondaryContainer
          .blendDarken(context, factor: 0.1)
          .opacity60,
    );
  }

  Color get darken2SecondaryContainer {
    return _colorMap.updateCacheValue(
      'darken2SecondaryContainer',
      () => context.colorScheme.secondaryContainer.blendDarken(
        context,
        factor: 0.2,
      ),
    );
  }

  Color get darken3PrimaryContainer {
    return _colorMap.updateCacheValue(
      'darken3PrimaryContainer',
      () => context.colorScheme.primaryContainer.blendDarken(
        context,
        factor: 0.3,
      ),
    );
  }
}

/// 让一个中性色带上品牌色相。
///
/// 只改**色相和饱和度，亮度原样保留**。这是关键：对比度由亮度决定，所以已经
/// 测量过的 `onSurface / surface`、`primary / surface` 这些比例不会被破坏；而
/// 画布和卡片会随用户选的种子色一起变，不再是"怎么改主题都是同一个深蓝"。
///
/// 种子是纯灰（saturation == 0）时没有色相可用，原样返回——否则会把一个本来
/// 中性的配色强行染成红色（HSL 里灰色的 hue 是 0）。
Color _tintedNeutral(Color base, Color seed, double amount) {
  final b = HSLColor.fromColor(base);
  final s = HSLColor.fromColor(seed);
  if (s.saturation <= 0.001) return base;
  // 保留一点底色自己的饱和度：完全取种子的饱和度会让深色画布过分鲜艳，
  // 卡片层级（surfaceContainer*）也就分不出来了。
  final saturation =
      (b.saturation + (s.saturation - b.saturation) * amount).clamp(0.0, 1.0);
  return HSLColor.fromAHSL(b.alpha, s.hue, saturation, b.lightness).toColor();
}

/// Maps the Aurora semantic set onto a Material `ColorScheme`.
///
/// Pure on purpose: the provider in `providers/state.dart` is a thin wrapper, so
/// tests can assert the **mapped** result — what widgets actually paint with —
/// instead of the raw token values.
///
/// Roles pinned here: the canvas, the container ladder, the two line roles and
/// the error pair. `onSurface`, `onSurfaceVariant` and `primary` deliberately
/// stay seed-derived, which is exactly why their contrast has to be measured
/// against the *overridden* surfaces rather than assumed from the seed.
ColorScheme fluxoraSchemeFromSeed({
  required Brightness brightness,
  required Color seed,
  required DynamicSchemeVariant variant,
  bool tintNeutrals = false,
}) {
  final fluxora = FluxoraColorSet.of(brightness);
  // How far the neutrals lean toward the seed. 0.55 is enough to read as "the
  // background follows my colour" without turning the canvas into a colour
  // block; the ladder keeps its own steps because lightness is untouched.
  const tint = 0.55;
  // Off by default so the shipped brand palette still paints exactly the
  // designed canvas (and the measured contrast tests keep their meaning).
  // `genColorScheme` turns it on for system / user-picked colours — the whole
  // complaint was that picking a colour left the background unchanged.
  Color neutral(Color base) =>
      tintNeutrals ? _tintedNeutral(base, seed, tint) : base;
  final background = neutral(fluxora.background);
  final surface = neutral(fluxora.surface);
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  ).copyWith(
    // Page canvas. The app shell paints `Material(color: colorScheme.surface)`
    // (`lib/pages/home.dart`), and `scaffoldBackgroundColor` also defaults to
    // `surface` — so D4.2's "Background" (#F6F9FB / #0C1222) belongs here, now
    // carrying the seed's hue.
    surface: background,
    // Card / panel surfaces. `CommonCard` reads `surfaceContainerLow` (plain)
    // and `surfaceContainer` (filled), so D4.2's "Surface" (#FFFFFF / #121A2B)
    // lands on the container ladder.
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: neutral(fluxora.surfaceContainer),
    surfaceContainerHigh: neutral(fluxora.surfaceContainerHigh),
    surfaceContainerHighest: neutral(fluxora.surfaceContainerHighest),
    // Lines.
    outline: fluxora.outline,
    outlineVariant: fluxora.outlineVariant,
    // Status. `ColorScheme.fromSeed` derives its own error tone (#BA1A1A in
    // light) which is **not** the semantic red the rest of the app means
    // (#B3261E), so error states driven by `colorScheme.error` and error states
    // driven by `FluxoraColorSet.error` were two different reds. Pin both error
    // roles to the semantic set — the same one the `fluxora/*` components read.
    // `errorContainer` / `onErrorContainer` have no token counterpart yet, so
    // they stay seed-derived (tracked as 01-B2 follow-up).
    error: fluxora.error,
    onError: fluxora.onError,
  );
}

/// Resting border of an outlined field.
///
/// `outline` / `outlineVariant` are frozen **Lines** roles: measured against the
/// canvas they are 1.80:1 (dark) and 1.40:1 (light), and the field border used
/// to be those values at 45–75 % alpha, i.e. 1.13:1 / 1.30:1 composited — an
/// input whose edge you cannot see. WCAG 1.4.11 wants 3:1 for a *necessary*
/// component boundary.
///
/// `onSurfaceVariant` at 60 % composites to 4.62:1 (dark) and 3.12:1 (light)
/// over the canvas, without touching the palette or inventing a new token.
Color fluxoraFieldBorder(ColorScheme scheme) =>
    scheme.onSurfaceVariant.withValues(alpha: 0.6);
