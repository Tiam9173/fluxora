import 'package:flutter/material.dart';

/// Persisted visual material only; never controls application behaviour.
enum FluxoraSurfaceStyle { classic, hybrid, reduced }

enum FluxoraMotionStyle { system, fluid, depth, off }

enum FluxoraVisualStyle { fluxora, obsidian }

/// Material policy added to the existing Fluxora token layer.
@immutable
class FluxoraMaterial extends ThemeExtension<FluxoraMaterial> {
  const FluxoraMaterial({
    this.style = FluxoraSurfaceStyle.classic,
    this.motionStyle = FluxoraMotionStyle.system,
    this.glassIntensity = .55,
    this.motionIntensity = .5,
    this.visualStyle = FluxoraVisualStyle.fluxora,
  });

  final FluxoraSurfaceStyle style;
  final FluxoraMotionStyle motionStyle;
  final double glassIntensity;
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
  bool get blurEnabled => style == FluxoraSurfaceStyle.hybrid;

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

  LinearGradient sheen(ColorScheme scheme) => isObsidian
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
    double? motionIntensity,
    FluxoraVisualStyle? visualStyle,
  }) => FluxoraMaterial(
    style: style ?? this.style,
    motionStyle: motionStyle ?? this.motionStyle,
    glassIntensity: glassIntensity ?? this.glassIntensity,
    motionIntensity: motionIntensity ?? this.motionIntensity,
    visualStyle: visualStyle ?? this.visualStyle,
  );

  @override
  FluxoraMaterial lerp(covariant FluxoraMaterial? other, double t) =>
      t < .5 || other == null ? this : other;
}
