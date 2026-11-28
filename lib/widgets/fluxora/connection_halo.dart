import 'package:flutter/material.dart';
import 'package:fluxora/common/common.dart';
import 'fluxora_status.dart';

/// A bounded status ring; only state changes animate, never an idle connection.
class ConnectionHalo extends StatelessWidget {
  const ConnectionHalo({super.key, required this.status, required this.child});

  final FluxoraStatusKind status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = status == FluxoraStatusKind.disconnected
        ? scheme.primary
        : FluxoraStatus.colorOf(context, status);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: accent),
      duration: FluxoraMotion.ofContext(context).fast,
      child: Padding(padding: const EdgeInsets.all(8), child: child),
      builder: (_, color, child) => CustomPaint(
        painter: _HaloPainter(color ?? accent, scheme),
        child: child,
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.accent, this.scheme);
  final Color accent;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = bounds.center;
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0), accent.withValues(alpha: .15)],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .24),
    );
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(
          colors: [
            accent.withValues(alpha: .12),
            accent,
            Color.lerp(accent, scheme.onSurface, .38)!,
            scheme.primary.withValues(alpha: .65),
            accent.withValues(alpha: .12),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.accent != accent || old.scheme != scheme;
}
