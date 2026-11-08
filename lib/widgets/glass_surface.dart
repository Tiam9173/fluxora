import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../common/tokens/tokens.dart';

/// A static sheen by default. Only bounded floating surfaces request blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = FluxoraRadius.card,
    this.floating = false,
    this.blur = false,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final bool floating;
  final bool blur;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final material = FluxoraMaterial.of(context);
    if (!material.enabled) return child;
    final scheme = Theme.of(context).colorScheme;
    final rounded = BorderRadius.circular(radius);
    final hasBlur = _GlassBlurScope.maybeOf(context);
    final useBlur = blur && material.blurEnabled && !hasBlur;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: material.fill(scheme, floating: floating),
        borderRadius: rounded,
        boxShadow: floating && material.blurEnabled
            ? FluxoraElevation.of(scheme.brightness).menu
            : null,
      ),
      // BoxDecoration's gradient replaces its color; paint the fill separately.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: material.blurEnabled ? material.sheen(scheme) : null,
          borderRadius: rounded,
          border: border ? Border.all(color: material.border(scheme)) : null,
        ),
        child: _GlassBlurScope(hasBlur: hasBlur || useBlur, child: child),
      ),
    );
    if (useBlur) {
      surface = ClipRRect(
        borderRadius: rounded,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: material.sigma,
            sigmaY: material.sigma,
          ),
          child: surface,
        ),
      );
    }
    return surface;
  }
}

class _GlassBlurScope extends InheritedWidget {
  const _GlassBlurScope({required this.hasBlur, required super.child});
  final bool hasBlur;
  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassBlurScope>()?.hasBlur ??
      false;
  @override
  bool updateShouldNotify(_GlassBlurScope oldWidget) =>
      hasBlur != oldWidget.hasBlur;
}

/// The canvas has no blur, animation or image decode.
class GlassCanvas extends StatelessWidget {
  const GlassCanvas({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final material = FluxoraMaterial.of(context);
    if (!material.enabled) return child;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: material.blurEnabled && scheme.surface != Colors.black
            ? material.isObsidian
                  ? RadialGradient(
                      center: const Alignment(.7, -.9),
                      radius: 1.4,
                      colors: [
                        Color.alphaBlend(
                          scheme.primary.withValues(alpha: .10),
                          scheme.surface,
                        ),
                        scheme.surface,
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.alphaBlend(
                          scheme.tertiary.withValues(alpha: .055),
                          scheme.surface,
                        ),
                        scheme.surface,
                        Color.alphaBlend(
                          scheme.primary.withValues(alpha: .035),
                          scheme.surface,
                        ),
                      ],
                    )
            : null,
        color: scheme.surface,
      ),
      child: child,
    );
  }
}
