import 'package:fluxora/common/common.dart';
import 'package:flutter/material.dart';

/// Connection states rendered by [FluxoraFlowIndicator].
enum FluxoraFlowState { idle, connecting, connected, error }

/// The Fluxora "Flow" mark: a flow line running into a node.
///
/// This is the brand's core visual metaphor — two flow lines converging on a
/// node — rendered with **plain widgets** (a gradient-filled `Container` plus a
/// circular node). There is deliberately no `CustomPainter`, no shader, no
/// particle system and no network/provider binding; D4.5 only lays down the
/// static + lightweight-motion foundation.
///
/// All timings and curves come from [FluxoraMotion], and the animation is
/// disabled when the platform requests reduced motion
/// (`MediaQuery.disableAnimations`), falling back to a static indicator.
///
/// ```dart
/// FluxoraFlowIndicator(state: FluxoraFlowState.connected);
/// ```
class FluxoraFlowIndicator extends StatefulWidget {
  const FluxoraFlowIndicator({
    super.key,
    this.state = FluxoraFlowState.idle,
    this.width = 64,
    this.height = 16,
    this.semanticLabel,
  });

  final FluxoraFlowState state;

  /// Total width of line + gap + node.
  final double width;

  /// Drives the node diameter and the line thickness.
  final double height;

  final String? semanticLabel;

  @override
  State<FluxoraFlowIndicator> createState() => _FluxoraFlowIndicatorState();
}

class _FluxoraFlowIndicatorState extends State<FluxoraFlowIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxoraMotion.connectedLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant FluxoraFlowIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts the loop for looping states, or parks the controller for static ones.
  void _syncAnimation() {
    final loop = _loopDurationFor(context, widget.state);
    if (loop == null) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (_controller.duration != loop) {
      _controller.duration = loop;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  /// Loop length for [state], or null when the state is static.
  ///
  /// Also returns null under reduced motion — looping animations must stop
  /// entirely (`D4_BRAND_PROPOSAL.md` §10.5).
  static Duration? _loopDurationFor(BuildContext context, FluxoraFlowState state) {
    final motion = FluxoraMotionSet.of(
      reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
    if (!motion.loopEnabled) return null;
    return switch (state) {
      FluxoraFlowState.connected => motion.connectedLoop,
      FluxoraFlowState.connecting => motion.connectingLoop,
      FluxoraFlowState.idle || FluxoraFlowState.error => null,
    };
  }

  _FlowPalette _palette(FluxoraColorSet colors) {
    return switch (widget.state) {
      FluxoraFlowState.idle => (
        line: colors.outlineVariant,
        accent: colors.outline,
        node: colors.outline,
        fill: null,
      ),
      FluxoraFlowState.connecting => (
        line: colors.outlineVariant,
        accent: colors.info,
        node: colors.info,
        fill: null,
      ),
      FluxoraFlowState.connected => (
        line: colors.primary,
        accent: colors.primary,
        node: colors.primary,
        fill: colors.primary,
      ),
      FluxoraFlowState.error => (
        line: colors.outlineVariant,
        accent: colors.error,
        node: colors.error,
        fill: null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final motion = FluxoraMotionSet.of(
      reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
    final palette = _palette(FluxoraColorSet.of(Theme.of(context).brightness));
    final lineHeight = (widget.height * 0.18).clamp(2.0, 4.0).toDouble();
    final nodeSize = widget.height;

    final node = AnimatedContainer(
      duration: motion.connectingEnter,
      curve: motion.standard,
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.fill,
        border: Border.all(
          color: palette.node,
          // ~9% of the node diameter, in the spirit of the brand mark's
          // 88/1024 (8.33%) stroke. Clamped so it stays visible when tiny and
          // does not become heavy when large.
          width: (nodeSize * 0.09).clamp(1.0, 3.0).toDouble(),
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.state.name,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Container(
                  height: lineHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(lineHeight / 2),
                    gradient: _lineGradient(palette, _controller.value),
                  ),
                ),
              ),
            ),
            const SizedBox(width: FluxoraSpacing.sm),
            node,
          ],
        ),
      ),
    );
  }

  /// The flow line's gradient.
  ///
  /// * connected — a highlight band drifts along the line (looping)
  /// * connecting — the whole line breathes in and out
  /// * idle / error — a flat line
  LinearGradient _lineGradient(_FlowPalette palette, double t) {
    switch (widget.state) {
      case FluxoraFlowState.connected:
        // Slide a 3-stop band from left to right. Stops stay constant, so the
        // gradient is always well-formed.
        final shift = -2 + 4 * t;
        return LinearGradient(
          begin: Alignment(shift, 0),
          end: Alignment(shift + 1, 0),
          colors: [palette.line, palette.accent, palette.line],
          stops: const [0.0, 0.5, 1.0],
        );
      case FluxoraFlowState.connecting:
        // Triangle wave: 0 → 1 → 0, so the loop never snaps.
        final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
        final color = Color.lerp(
          palette.line,
          palette.accent,
          wave,
        )!.withValues(alpha: 0.45 + 0.55 * wave);
        return LinearGradient(colors: [color, color]);
      case FluxoraFlowState.idle:
      case FluxoraFlowState.error:
        return LinearGradient(colors: [palette.line, palette.line]);
    }
  }
}

/// Resolved colours for one [FluxoraFlowState].
typedef _FlowPalette = ({Color line, Color accent, Color node, Color? fill});
