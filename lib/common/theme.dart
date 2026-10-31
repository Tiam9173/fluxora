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
}) {
  final fluxora = FluxoraColorSet.of(brightness);
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  ).copyWith(
    // Page canvas. The app shell paints `Material(color: colorScheme.surface)`
    // (`lib/pages/home.dart`), and `scaffoldBackgroundColor` also defaults to
    // `surface` — so D4.2's "Background" (#F6F9FB / #0C1222) belongs here.
    surface: fluxora.background,
    // Card / panel surfaces. `CommonCard` reads `surfaceContainerLow` (plain)
    // and `surfaceContainer` (filled), so D4.2's "Surface" (#FFFFFF / #121A2B)
    // lands on the container ladder.
    surfaceContainerLowest: fluxora.surface,
    surfaceContainerLow: fluxora.surface,
    surfaceContainer: fluxora.surfaceContainer,
    surfaceContainerHigh: fluxora.surfaceContainerHigh,
    surfaceContainerHighest: fluxora.surfaceContainerHighest,
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
