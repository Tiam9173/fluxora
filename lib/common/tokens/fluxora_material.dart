import 'package:flutter/material.dart';

/// Persisted visual material only; never controls application behaviour.
enum FluxoraSurfaceStyle { classic, hybrid, reduced }

/// Material policy added to the existing Fluxora token layer.
@immutable
class FluxoraMaterial extends ThemeExtension<FluxoraMaterial> {
  const FluxoraMaterial({this.style = FluxoraSurfaceStyle.classic});

  final FluxoraSurfaceStyle style;
  static const blurSigma = 10.0;
  bool get enabled => style != FluxoraSurfaceStyle.classic;
  bool get blurEnabled => style == FluxoraSurfaceStyle.hybrid;

  static FluxoraMaterial of(BuildContext context) {
    final material =
        Theme.of(context).extension<FluxoraMaterial>() ??
        const FluxoraMaterial();
    final media = MediaQuery.maybeOf(context);
    if (material.enabled &&
        (media?.highContrast == true ||
            media?.accessibleNavigation == true ||
            media?.disableAnimations == true)) {
      return const FluxoraMaterial(style: FluxoraSurfaceStyle.reduced);
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
                ? .96
                : scheme.brightness == Brightness.dark
                ? .84
                : .92,
          );

  Color border(ColorScheme scheme) => scheme.onSurface.withValues(
    alpha: scheme.brightness == Brightness.dark ? .16 : .12,
  );

  LinearGradient sheen(ColorScheme scheme) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(
        alpha: scheme.brightness == Brightness.dark ? .08 : .42,
      ),
      scheme.primary.withValues(alpha: .025),
      Colors.transparent,
    ],
    stops: const [0, .42, 1],
  );

  @override
  FluxoraMaterial copyWith({FluxoraSurfaceStyle? style}) =>
      FluxoraMaterial(style: style ?? this.style);

  @override
  FluxoraMaterial lerp(covariant FluxoraMaterial? other, double t) =>
      t < .5 || other == null ? this : other;
}
