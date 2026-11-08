import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../common/tokens/tokens.dart';
import 'liquid_backdrop.dart';

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
    final panel = material.isObsidian && material.blurEnabled && !useBlur;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: material.liquid && useBlur
            ? Colors.transparent
            : material.fill(scheme, floating: floating),
        borderRadius: rounded,
        // A shadow inside the lens darkens its transparent centre into grey.
        boxShadow: floating && material.blurEnabled && !useBlur
            ? FluxoraElevation.of(scheme.brightness).menu
            : null,
      ),
      // BoxDecoration's gradient replaces its color; paint the fill separately.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: panel
              ? material.panelGradient(scheme)
              : material.blurEnabled
              ? material.sheen(scheme)
              : null,
          borderRadius: rounded,
          border: border ? Border.all(color: material.border(scheme)) : null,
        ),
        child: _GlassBlurScope(hasBlur: hasBlur || useBlur, child: child),
      ),
    );
    if (panel) {
      surface = CustomPaint(
        foregroundPainter: _PanelRim(radius, scheme.brightness),
        child: surface,
      );
    }
    if (useBlur) {
      surface = ClipRRect(
        borderRadius: rounded,
        child: material.liquid
            ? ClipRect(
                child: LiquidBackdrop(
                  radius: radius,
                  strength: material.strength,
                  clarity: material.clarity,
                  child: surface,
                ),
              )
            : BackdropFilter(
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

class _PanelRim extends CustomPainter {
  const _PanelRim(this.radius, this.brightness);
  final double radius;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final dark = brightness == Brightness.dark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(.6), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? .28 : .95),
            Colors.white.withValues(alpha: dark ? .025 : .2),
            const Color(0xFF8492DA).withValues(alpha: dark ? .17 : .18),
          ],
          stops: const [0, .46, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_PanelRim old) =>
      radius != old.radius || brightness != old.brightness;
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
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(
                          scheme.primary.withValues(alpha: .07),
                          scheme.surface,
                        ),
                        scheme.surface,
                        scheme.surface,
                      ],
                      stops: const [0, .38, 1],
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
