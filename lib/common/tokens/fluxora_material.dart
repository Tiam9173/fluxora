import 'package:flutter/material.dart';

/// Persisted visual material only; never controls application behaviour.
enum FluxoraSurfaceStyle { classic, hybrid, liquid, reduced }

enum FluxoraMotionStyle { system, fluid, depth, off }

enum FluxoraVisualStyle { fluxora, obsidian }

/// Material policy added to the existing Fluxora token layer.
@immutable
class FluxoraMaterial extends ThemeExtension<FluxoraMaterial> {
  const FluxoraMaterial({
    this.style = FluxoraSurfaceStyle.classic,
    this.motionStyle = FluxoraMotionStyle.system,
    this.glassIntensity = .55,
    this.glassClarity = .5,
    this.motionIntensity = .5,
    this.visualStyle = FluxoraVisualStyle.fluxora,
  });

  final FluxoraSurfaceStyle style;
  final FluxoraMotionStyle motionStyle;
  final double glassIntensity;
  final double glassClarity;
  double get clarity => glassClarity.isFinite ? glassClarity.clamp(0, 1) : .5;
  final double motionIntensity;
  final FluxoraVisualStyle visualStyle;
  bool get isObsidian => visualStyle == FluxoraVisualStyle.obsidian;
  double get motionAmount =>
      motionIntensity.isFinite ? motionIntensity.clamp(0, 1) : .5;
  double get strength =>
      glassIntensity.isFinite ? glassIntensity.clamp(0, 1) : .55;
  double get sigma => 4 + 12 * strength;
  static const blurSigma = 10.0;
  bool get enabled => style != FluxoraSurfaceStyle.classic;
  bool get liquid => style == FluxoraSurfaceStyle.liquid;
  bool get blurEnabled => style == FluxoraSurfaceStyle.hybrid || liquid;

  static FluxoraMaterial of(BuildContext context) {
    final material =
        Theme.of(context).extension<FluxoraMaterial>() ??
        const FluxoraMaterial();
    final media = MediaQuery.maybeOf(context);
    if (material.enabled &&
        (media?.highContrast == true || media?.accessibleNavigation == true)) {
      return material.copyWith(style: FluxoraSurfaceStyle.reduced);
    }
    return material;
  }

  Color fill(ColorScheme scheme, {bool floating = false}) =>
      (scheme.brightness == Brightness.light && !floating
              ? scheme.surfaceContainerLow
              : scheme.surfaceContainer)
          .withValues(
            alpha: !blurEnabled
                ? 1
                : floating
                ? .98 - .04 * strength
                : scheme.brightness == Brightness.dark
                ? .92 - .14 * strength
                : .97 - .08 * strength,
          );

  Color border(ColorScheme scheme) => scheme.onSurface.withValues(
    alpha: scheme.brightness == Brightness.dark
        ? .10 + .12 * strength
        : .08 + .08 * strength,
  );

  /// Colour and depth for content panels; optical filters belong to overlays.
  LinearGradient panelGradient(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          Colors.white.withValues(alpha: dark ? .055 : .92),
          scheme.surfaceContainer,
        ),
        scheme.surfaceContainerLow,
        Color.alphaBlend(
          scheme.primary.withValues(alpha: dark ? .075 : .035),
          scheme.surfaceContainerLow,
        ),
      ],
      stops: const [0, .48, 1],
    );
  }

  LinearGradient sheen(ColorScheme scheme) => liquid
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .12),
            Colors.transparent,
            scheme.primary.withValues(alpha: .02),
          ],
          stops: const [0, .18, 1],
        )
      : isObsidian
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(
              alpha: scheme.brightness == Brightness.dark ? .10 : .65,
            ),
            scheme.primary.withValues(alpha: .08 * strength),
            Colors.transparent,
            scheme.shadow.withValues(alpha: .06),
          ],
          stops: const [0, .32, .68, 1],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(
              alpha: scheme.brightness == Brightness.dark
                  ? .04 + .10 * strength
                  : .24 + .28 * strength,
            ),
            scheme.primary.withValues(alpha: .025),
            Colors.transparent,
          ],
          stops: const [0, .42, 1],
        );

  @override
  FluxoraMaterial copyWith({
    FluxoraSurfaceStyle? style,
    FluxoraMotionStyle? motionStyle,
    double? glassIntensity,
    double? glassClarity,
    double? motionIntensity,
    FluxoraVisualStyle? visualStyle,
  }) => FluxoraMaterial(
    style: style ?? this.style,
    motionStyle: motionStyle ?? this.motionStyle,
    glassIntensity: glassIntensity ?? this.glassIntensity,
    glassClarity: glassClarity ?? this.glassClarity,
    motionIntensity: motionIntensity ?? this.motionIntensity,
    visualStyle: visualStyle ?? this.visualStyle,
  );

  @override
  FluxoraMaterial lerp(covariant FluxoraMaterial? other, double t) =>
      t < .5 || other == null ? this : other;
}
