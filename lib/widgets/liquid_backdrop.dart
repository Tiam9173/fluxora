import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../common/tokens/tokens.dart';

/// One bounded live backdrop; never captures the widget tree to a bitmap.
class LiquidBackdrop extends StatefulWidget {
  const LiquidBackdrop({
    super.key,
    required this.radius,
    required this.strength,
    this.clarity = .5,
    required this.child,
  });
  final double radius;
  final double strength;
  final double clarity;
  final Widget child;
  static bool get supportsRefraction => ui.ImageFilter.isShaderFilterSupported;
  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;
  Offset? _light;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (LiquidBackdrop.supportsRefraction) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      ));
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (error) {
      debugPrint('Liquid glass uses compatible lens: $error');
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = FluxoraMotion.ofContext(context);
    final dark = scheme.brightness == Brightness.dark;
    return Listener(
      onPointerDown: (event) => setState(() {
        _pressed = true;
        _light = event.localPosition;
      }),
      onPointerMove: (event) {
        if (_pressed) setState(() => _light = event.localPosition);
      },
      onPointerHover: (event) => setState(() => _light = event.localPosition),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 1 : 0),
        duration: motion.fast,
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // A compatibility lens needs more tint than the adaptive shader.
            color: (dark ? scheme.surfaceContainer : Colors.white).withValues(
              alpha: _shader != null
                  ? (dark ? .30 : .38) - .22 * widget.clarity
                  : (dark
                        ? .76 - .12 * widget.clarity
                        : .79 - .20 * widget.clarity),
            ),
          ),
          child: widget.child,
        ),
        builder: (context, pressure, child) => Transform.scale(
          scale: motion.reduceMotion
              ? 1
              : 1 - pressure * .008 * motion.intensity,
          child: CustomPaint(
            foregroundPainter: _GlassRim(
              widget.radius,
              widget.strength,
              _light,
              pressure,
              dark,
            ),
            child: _LensFilter(
              radius: widget.radius,
              strength:
                  (widget.strength +
                          (motion.reduceMotion
                              ? 0
                              : pressure * .22 * motion.intensity))
                      .clamp(0, 1),
              clarity: widget.clarity,
              shader: _shader,
              scheme: scheme,
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}

class _LensFilter extends SingleChildRenderObjectWidget {
  const _LensFilter({
    required this.radius,
    required this.strength,
    required this.clarity,
    required this.shader,
    required this.scheme,
    required super.child,
  });
  final double radius, strength, clarity;
  final ui.FragmentShader? shader;
  final ColorScheme scheme;
  @override
  _RenderLensFilter createRenderObject(BuildContext context) =>
      _RenderLensFilter(radius, strength, clarity, shader, scheme);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLensFilter renderObject,
  ) => renderObject.configure(radius, strength, clarity, shader, scheme);
}

class _RenderLensFilter extends RenderBackdropFilter {
  _RenderLensFilter(
    this.radius,
    this.strength,
    this.clarity,
    this.shader,
    this.scheme,
  ) : super(filter: ui.ImageFilter.blur());
  double radius, strength, clarity;
  ui.FragmentShader? shader;
  ColorScheme scheme;
  Size? _previousSize;
  void configure(
    double nextRadius,
    double nextStrength,
    double nextClarity,
    ui.FragmentShader? nextShader,
    ColorScheme nextScheme,
  ) {
    if ((radius, strength, clarity, shader, scheme) ==
        (nextRadius, nextStrength, nextClarity, nextShader, nextScheme)) {
      return;
    }
    radius = nextRadius;
    strength = nextStrength;
    clarity = nextClarity;
    shader = nextShader;
    scheme = nextScheme;
    if (hasSize) _updateFilter();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_previousSize != size) {
      _previousSize = size;
      _updateFilter();
    }
  }

  void _updateFilter() {
    final effect = shader;
    if (effect == null || size.isEmpty) {
      final sigma = 2 + 8 * (1 - clarity) + 2 * strength;
      filter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      return;
    }
    effect
      ..setFloat(2, size.width)
      ..setFloat(3, size.height)
      ..setFloat(4, radius)
      ..setFloat(5, strength)
      ..setFloat(6, scheme.brightness == Brightness.dark ? 1 : 0)
      ..setFloat(7, scheme.surface.r)
      ..setFloat(8, scheme.surface.g)
      ..setFloat(9, scheme.surface.b)
      ..setFloat(10, clarity);
    // A preceding blur can change the shader input bounds on Impeller.
    filter = ui.ImageFilter.shader(effect);
  }
}

class _GlassRim extends CustomPainter {
  _GlassRim(this.radius, this.strength, this.light, this.pressure, this.dark);
  final double radius, strength, pressure;
  final Offset? light;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds.deflate(.8),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dark ? 1.0 : 1.25
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: .34 + .16 * strength),
                  const Color(0xFF8EA8FA).withValues(alpha: .12),
                  Colors.white.withValues(alpha: .08),
                ]
              : [
                  Colors.white,
                  const Color(0xFF9DB7EB).withValues(alpha: .42),
                  Colors.white.withValues(alpha: .16),
                  const Color(0xFF9DB7EB).withValues(alpha: .20),
                  Colors.white.withValues(alpha: .95),
                ],
          stops: dark ? const [0, .55, 1] : const [0, .22, .5, .78, 1],
        ).createShader(bounds),
    );
    final focus = light ?? Offset(size.width * .2, 0);
    canvas.drawRRect(
      shape.deflate(1.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65 + pressure
        ..shader = ui.Gradient.radial(
          focus,
          size.shortestSide * (1.3 + pressure),
          [
            Colors.white.withValues(alpha: (dark ? .16 : .40) + pressure * .3),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassRim old) =>
      (radius, strength, light, pressure, dark) !=
      (old.radius, old.strength, old.light, old.pressure, old.dark);
}
