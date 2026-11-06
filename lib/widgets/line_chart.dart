import 'dart:ui';
import 'package:fluxora/common/color.dart';
import 'package:fluxora/common/tokens/fluxora_motion.dart';
import 'package:flutter/material.dart';

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}

class LineChart extends StatefulWidget {
  final List<Point> points;
  final Color color;
  final Duration duration;
  final bool gradient;

  const LineChart({
    super.key,
    this.gradient = false,
    required this.points,
    required this.color,
    this.duration = FluxoraMotion.slow,
  });

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late List<Point> _previous;
  late List<Point> _points;
  bool _previousNormalized = false;
  bool _reduced = false;
  bool _visible = true;

  bool get _animated =>
      !_reduced && _visible && widget.duration > Duration.zero;
  double get _progress =>
      FluxoraMotion.standard.transform(_controller?.value ?? 1);

  @override
  void initState() {
    super.initState();
    _previous = _points = widget.points;
  }

  void _syncController() {
    if (_animated) {
      _controller ??= AnimationController(vsync: this, value: 1);
      _controller!.duration = widget.duration;
    } else {
      _controller?.stop();
      _controller?.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = FluxoraMotion.ofContext(context).reduceMotion;
    _visible = TickerMode.valuesOf(context).enabled;
    _syncController();
  }

  @override
  void didUpdateWidget(covariant LineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
    if (widget.points == _points) return;
    // Retarget from the painted geometry when samples arrive during a tween.
    _previous = _painter().getInterpolatePoints(_previous, _points, _progress);
    _previousNormalized = true;
    _points = widget.points;
    if (_animated && _points.isNotEmpty) {
      _controller!.forward(from: 0);
    } else {
      _controller?.value = 1;
    }
  }

  LineChartPainter _painter() => LineChartPainter(
    prevPoints: _previous,
    points: _points,
    progress: _animated ? _progress : 1,
    color: widget.color,
    gradient: widget.gradient,
    hasAnimation: _animated,
    previousNormalized: _previousNormalized,
  );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (!_animated) return CustomPaint(painter: _painter(), size: size);
      return AnimatedBuilder(
        animation: _controller!,
        builder: (_, _) => CustomPaint(painter: _painter(), size: size),
      );
    },
  );
}

class LineChartPainter extends CustomPainter {
  final List<Point> prevPoints;
  final List<Point> points;
  final double progress;
  final Color color;
  final bool gradient;
  final bool hasAnimation;
  final bool previousNormalized;

  LineChartPainter({
    required this.prevPoints,
    required this.points,
    required this.progress,
    required this.color,
    required this.gradient,
    this.hasAnimation = true,
    this.previousNormalized = false,
  });

  List<Point> getRenderPoints(List<Point> points) {
    if (points.isEmpty) return [];
    double maxX = points[0].x;
    double minX = points[0].x;
    double maxY = points[0].y;
    double minY = points[0].y;

    for (final point in points) {
      if (point.x > maxX) maxX = point.x;
      if (point.x < minX) minX = point.x;
      if (point.y > maxY) maxY = point.y;
      if (point.y < minY) minY = point.y;
    }

    return points.map((e) {
      var x = (e.x - minX) / (maxX - minX);
      if (x.isNaN) x = 0;
      var y = (e.y - minY) / (maxY - minY);
      if (y.isNaN) y = 0;
      return Point(x, y);
    }).toList();
  }

  List<Point> getInterpolatePoints(
    List<Point> prevPoints,
    List<Point> points,
    double t,
  ) {
    final renderPrevPoints = previousNormalized
        ? prevPoints
        : getRenderPoints(prevPoints);
    final renderPoints = getRenderPoints(points);

    return List.generate(renderPoints.length, (i) {
      if (i > renderPrevPoints.length - 1) {
        return renderPoints[i];
      }
      final x = lerpDouble(renderPrevPoints[i].x, renderPoints[i].x, t)!;
      final y = lerpDouble(renderPrevPoints[i].y, renderPoints[i].y, t)!;
      return Point(x, y);
    });
  }

  Path getPath(List<Point> points, Size size) {
    if (points.isEmpty) return Path();
    final path = Path()
      ..moveTo(points[0].x * size.width, (1 - points[0].y) * size.height);

    for (var i = 1; i < points.length - 1; i++) {
      final nextPoint = points[i + 1];
      final currentPoint = points[i];
      final midX = (currentPoint.x + nextPoint.x) / 2;
      final midY = (currentPoint.y + nextPoint.y) / 2;

      path.quadraticBezierTo(
        currentPoint.x * size.width,
        (1 - currentPoint.y) * size.height,
        midX * size.width,
        (1 - midY) * size.height,
      );
    }

    path.lineTo(points.last.x * size.width, (1 - points.last.y) * size.height);
    return path;
  }

  Path getAnimatedPath(Size size) {
    final interpolatedPoints = getInterpolatePoints(
      prevPoints,
      points,
      progress,
    );
    return getPath(interpolatedPoints, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const strokeWidth = 2.0;
    final chartSize = Size(size.width, size.height * 0.7);

    // Fast path without animation
    final Path path;
    if (!hasAnimation || progress >= 1.0) {
      // Direct render without interpolation
      final renderPoints = getRenderPoints(points);
      path = getPath(renderPoints, chartSize);
    } else {
      // Animated path
      path = getAnimatedPath(chartSize);
    }

    if (gradient) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height + strokeWidth * 2);
      fillPath.lineTo(0, size.height + strokeWidth * 2);
      fillPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.opacity38, color.opacity10],
      );

      final shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height + strokeWidth * 2),
      );

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.hasAnimation != hasAnimation ||
        oldDelegate.previousNormalized != previousNormalized ||
        oldDelegate.progress != progress ||
        oldDelegate.prevPoints != prevPoints ||
        oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.gradient != gradient;
  }
}
