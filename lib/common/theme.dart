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

/// Extends the current theme; Classic returns the original theme unchanged.
ThemeData fluxoraMaterialTheme(
  ThemeData base,
  FluxoraSurfaceStyle style, {
  FluxoraMotionStyle motionStyle = FluxoraMotionStyle.system,
  double glassIntensity = .55,
  double glassClarity = .5,
  double motionIntensity = .5,
  FluxoraVisualStyle visualStyle = FluxoraVisualStyle.fluxora,
}) {
  if (style == FluxoraSurfaceStyle.classic &&
      motionStyle == FluxoraMotionStyle.system &&
      motionIntensity == .5 &&
      visualStyle == FluxoraVisualStyle.fluxora) {
    return base;
  }
  final material = FluxoraMaterial(
    style: style,
    motionStyle: motionStyle,
    glassIntensity: glassIntensity,
    glassClarity: glassClarity,
    motionIntensity: motionIntensity,
    visualStyle: visualStyle,
  );
  if (style == FluxoraSurfaceStyle.classic) {
    return base.copyWith(
      extensions: [
        ...base.extensions.values.where((e) => e is! FluxoraMaterial),
        material,
      ],
    );
  }
  final original = base.colorScheme;
  final scheme = original.surface == Colors.black || material.isObsidian
      ? original
      : original.copyWith(
          surfaceContainerLow: Color.alphaBlend(
            original.tertiary.withValues(alpha: .035),
            original.surfaceContainerLow,
          ),
          surfaceContainer: Color.alphaBlend(
            original.tertiary.withValues(alpha: .04),
            original.surfaceContainer,
          ),
          surfaceContainerHigh: Color.alphaBlend(
            original.primary.withValues(alpha: .025),
            original.surfaceContainerHigh,
          ),
        );
  final side = BorderSide(color: material.border(scheme));
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Color.alphaBlend(
      scheme.tertiary.withValues(
        alpha: scheme.surface == Colors.black ? 0 : .035,
      ),
      scheme.surface,
    ),
    extensions: [
      ...base.extensions.values.where((e) => e is! FluxoraMaterial),
      material,
    ],
    cardTheme: base.cardTheme.copyWith(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: FluxoraElevation.resting,
      shape: RoundedRectangleBorder(
        borderRadius: FluxoraRadius.cardAll,
        side: side,
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: FluxoraRadius.dialogAll,
        side: side,
      ),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: FluxoraRadius.mdAll,
        side: side,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundBuilder: material.isObsidian && material.blurEnabled
            ? (context, states, child) {
                if (states.contains(WidgetState.disabled)) {
                  return child ?? const SizedBox.shrink();
                }
                return Builder(
                  builder: (context) {
                    final shape = context
                        .findAncestorWidgetOfExactType<Material>()
                        ?.shape;
                    return DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: shape is OutlinedBorder
                            ? shape.copyWith(side: BorderSide.none)
                            : shape ?? const StadiumBorder(),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x2EFFFFFF),
                            Colors.transparent,
                            Color(0x14000000),
                          ],
                          stops: [0, .45, 1],
                        ),
                      ),
                      child: child,
                    );
                  },
                );
              }
            : null,
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : BorderSide(color: scheme.onPrimary.withValues(alpha: .18)),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: FluxoraRadius.mdAll,
        side: BorderSide(color: scheme.onInverseSurface.withValues(alpha: .14)),
      ),
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: FluxoraRadius.smAll,
        border: Border.all(
          color: scheme.onInverseSurface.withValues(alpha: .14),
        ),
      ),
    ),
  );
}

/// Maps the Aurora semantic set onto a Material `ColorScheme`.
///
/// Pure on purpose: the provider in `providers/state.dart` is a thin wrapper, so
/// tests can assert the **mapped** result — what widgets actually paint with —
/// instead of the raw token values.
///
/// Two modes, and the split is the whole point:
///
///  * **Brand** ([followSeed] false) — the canvas, the container ladder and the
///    two line roles are pinned to `FluxoraColorSet`, i.e. exactly the measured
///    Deep Space / Mist palette. `onSurface`, `onSurfaceVariant` and `primary`
///    stay seed-derived, which is why their contrast is measured against the
///    *overridden* surfaces rather than assumed from the seed.
///  * **Follow the seed** ([followSeed] true) — the seed's own scheme is used
///    wholesale, with only the error pair pinned. This is what "complete
///    Material You" means: every neutral carries the seed's hue and every tonal
///    step is the one Material derived, so picking a colour actually re-themes
///    the app instead of recolouring a few buttons.
///
/// The app is ready for the second mode: outside this file there are **zero**
/// reads of `FluxoraColors.dark` / `.light`, and 563 `colorScheme.` reads — the
/// UI is theme-driven, and `FluxoraColorSet` is only used for semantic status
/// colours (success / warning / error / info), which must not follow the theme.
ColorScheme fluxoraSchemeFromSeed({
  required Brightness brightness,
  required Color seed,
  required DynamicSchemeVariant variant,
  bool followSeed = false,
  FluxoraVisualStyle visualStyle = FluxoraVisualStyle.fluxora,
}) {
  final fluxora = FluxoraColorSet.of(brightness);
  final seeded = ColorScheme.fromSeed(
    seedColor: visualStyle == FluxoraVisualStyle.obsidian && !followSeed
        ? const Color(0xFF526AE6)
        : seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  );

  // Status. `ColorScheme.fromSeed` derives its own error tone (#BA1A1A in
  // light) which is **not** the semantic red the rest of the app means
  // (#B3261E), so error states driven by `colorScheme.error` and error states
  // driven by `FluxoraColorSet.error` were two different reds. Pin both error
  // roles in *both* modes — a red seed must not turn "failed" into something
  // that reads as the accent colour.
  if (followSeed) {
    final scheme = seeded.copyWith(
      error: fluxora.error,
      onError: fluxora.onError,
    );
    return visualStyle == FluxoraVisualStyle.obsidian
        ? _obsidianScheme(scheme)
        : scheme;
  }

  final scheme = seeded.copyWith(
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
    // `errorContainer` / `onErrorContainer` have no token counterpart yet, so
    // they stay seed-derived (tracked as 01-B2 follow-up).
    error: fluxora.error,
    onError: fluxora.onError,
  );
  return visualStyle == FluxoraVisualStyle.obsidian
      ? _obsidianScheme(scheme)
      : scheme;
}

ColorScheme _obsidianScheme(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return scheme.copyWith(
    surface: Color(dark ? 0xFF08090F : 0xFFF4F6FC),
    surfaceDim: Color(dark ? 0xFF06070C : 0xFFE4E8F2),
    surfaceBright: Color(dark ? 0xFF2A2D3D : 0xFFF9FAFE),
    surfaceContainerLowest: Color(dark ? 0xFF101118 : 0xFFFFFFFF),
    surfaceContainerLow: Color(dark ? 0xFF14151E : 0xFFFCFDFF),
    surfaceContainer: Color(dark ? 0xFF1A1C29 : 0xFFF5F7FD),
    surfaceContainerHigh: Color(dark ? 0xFF232638 : 0xFFEEF2FC),
    surfaceContainerHighest: Color(dark ? 0xFF30344A : 0xFFE6ECF8),
    onSurface: Color(dark ? 0xFFF2F3FA : 0xFF181B29),
    onSurfaceVariant: Color(dark ? 0xFFBFC3D4 : 0xFF535B72),
    outline: Color(dark ? 0xFF777C92 : 0xFF717A92),
    outlineVariant: Color(dark ? 0xFF3B3E50 : 0xFFC8CDDE),
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
