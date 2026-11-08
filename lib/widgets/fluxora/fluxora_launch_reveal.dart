import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluxora/common/common.dart';

/// A one-shot brand reveal. Tapping skips it without activating hidden controls.
class FluxoraLaunchReveal extends StatefulWidget {
  const FluxoraLaunchReveal({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  State<FluxoraLaunchReveal> createState() => _FluxoraLaunchRevealState();
}

class _FluxoraLaunchRevealState extends State<FluxoraLaunchReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = FluxoraMotion.ofContext(context);
    if (!widget.enabled || motion.reduceMotion) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.duration = Duration(
        milliseconds: (800 + 400 * motion.intensity).round(),
      );
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FluxoraLaunchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: !_controller.isCompleted,
          child: ExcludeSemantics(
            excluding: !_controller.isCompleted,
            child: child!,
          ),
        ),
        if (!_controller.isCompleted)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _controller.value = 1,
            child: ExcludeSemantics(
              child: FluxoraLaunchScene(progress: _controller.value),
            ),
          ),
      ],
    ),
  );
}

class FluxoraLaunchScene extends StatelessWidget {
  const FluxoraLaunchScene({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final amount = FluxoraMaterial.of(context).motionAmount;
    final reveal = Curves.easeOutCubic.transform((progress / .65).clamp(0, 1));
    final exit = Curves.easeInCubic.transform(
      ((progress - .68) / .32).clamp(0, 1),
    );
    return Opacity(
      opacity: 1 - exit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.25, -.2),
            radius: 1.1,
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: dark ? .2 : .09),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(0, (1 - reveal) * 28 * amount - exit * 20),
            child: Transform.scale(
              scale: .9 + .1 * Curves.easeOutBack.transform(reveal),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 224,
                      height: 164,
                      child: CustomPaint(
                        painter: _OrbitPainter(
                          reveal,
                          amount,
                          scheme.primary,
                          scheme.tertiary,
                        ),
                        child: Center(
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              heightFactor: reveal,
                              child: SvgPicture.asset(
                                'assets/images/fluxora_mark${dark ? '' : '_light'}.svg',
                                width: 144,
                                height: 144,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: reveal,
                      child: Text(
                        'Fluxora',
                        style: Theme.of(context).textTheme.headlineLarge!
                            .copyWith(
                              fontSize: 35,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.8,
                              color: scheme.onSurface,
                              decoration: TextDecoration.none,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.progress, this.amount, this.start, this.end);
  final double progress;
  final double amount;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.38);
    final rect = Rect.fromCenter(center: Offset.zero, width: 196, height: 66);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [start.withValues(alpha: 0), start, end],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi, math.pi * 2 * progress, false, paint);
    final angle = -math.pi + math.pi * 2 * progress;
    final point = Offset(98 * math.cos(angle), 33 * math.sin(angle));
    canvas.drawCircle(point, 3 + 2 * amount, Paint()..color = end);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.amount != amount ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}
