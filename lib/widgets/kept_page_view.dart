import 'package:flutter/material.dart';

/// Lazily retains visited pages and pauses hidden tickers, focus and semantics.
/// Horizontal mode transitions directly to any tab and supports touch scrubbing.
/// Other callers retain their existing fade and offset transitions.
class KeptPageView extends StatefulWidget {
  const KeptPageView({
    super.key,
    required this.index,
    required this.pageBuilder,
    required this.duration,
    required this.inCurve,
    required this.outCurve,
    required this.enterOffset,
    this.horizontal = false,
    this.depth = false,
    this.intensity = .5,
    this.pageCount,
    this.onIndexChanged,
    this.pageKeys,
  });

  /// The page that should be visible.
  final int index;

  final Widget Function(BuildContext context, int index) pageBuilder;

  /// Cross-fade duration. `Duration.zero` makes the switch a single frame.
  final Duration duration;

  final Curve inCurve;
  final Curve outCurve;

  /// The §10.2 lift applied to the entering page; [Offset.zero] under reduced
  /// motion.
  final Offset enterOffset;
  final bool horizontal;
  final bool depth;
  final double intensity;
  final int? pageCount;
  final ValueChanged<int>? onIndexChanged;
  final List<Object>? pageKeys;

  @override
  State<KeptPageView> createState() => _KeptPageViewState();
}

class _KeptPageViewState extends State<KeptPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  /// Pages that have ever been shown, in first-visit order.
  final Set<int> _built = <int>{};

  late int _current;
  int? _leaving;
  double _direction = 1;
  bool _dragging = false;
  int? _dragOrigin;

  double get _readingDirection =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  late CurvedAnimation _in;
  late CurvedAnimation _out;
  late Animation<Offset> _slide;

  /// The leaving page's opacity. `AnimatedSwitcher` — what this replaced — hands
  /// the outgoing child a *reversed* animation, so it starts at 1 and fades to
  /// 0. Driving it with [_out] directly would invert that: the old page would
  /// vanish on the first frame and fade back in behind the new one.
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    _built.add(_current);
    _resolveAnimations();
    _controller.addStatusListener(_onStatus);
  }

  void _resolveAnimations() {
    _in = CurvedAnimation(parent: _controller, curve: widget.inCurve);
    _out = CurvedAnimation(parent: _controller, curve: widget.outCurve);
    _fadeOut = ReverseAnimation(_out);
    _slide = Tween<Offset>(
      begin: widget.enterOffset,
      end: Offset.zero,
    ).animate(_in);
  }

  void _onStatus(AnimationStatus status) {
    // Once the cross-fade has finished the outgoing page can go off-stage: it
    // stays mounted (state kept) but stops costing a paint.
    if (status == AnimationStatus.completed && _leaving != null && !_dragging) {
      setState(() => _leaving = null);
    }
  }

  @override
  void didUpdateWidget(covariant KeptPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.pageKeys, after = widget.pageKeys;
    if (before != null &&
        after != null &&
        (before.length != after.length ||
            before.asMap().entries.any((e) => e.value != after[e.key]))) {
      final kept = <int>{
        for (final index in _built)
          if (index < before.length && after.contains(before[index]))
            after.indexOf(before[index]),
      };
      _built
        ..clear()
        ..addAll(kept)
        ..add(widget.index);
      _current = widget.index;
      _leaving = null;
      _dragging = false;
      _controller.value = 1;
    }

    if (oldWidget.enterOffset != widget.enterOffset ||
        oldWidget.inCurve != widget.inCurve ||
        oldWidget.outCurve != widget.outCurve) {
      _in.dispose();
      _out.dispose();
      _resolveAnimations();
    }
    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.duration == Duration.zero) {
      _controller.value = 1;
      _leaving = null;
    }
    if (widget.index != _current &&
        (!_dragging || oldWidget.index != widget.index)) {
      _dragging = false;
      _direction = (widget.index > _current ? 1 : -1) * _readingDirection;
      _leaving = _current;
      _current = widget.index;
      _built.add(_current);

      if (widget.duration == Duration.zero) {
        // Reduced motion (or a zero token): land on the final state now. The
        // outgoing page goes off-stage in the same frame.
        _controller.value = 1;
        _leaving = null;
      } else {
        _controller.value = 0;
        if (widget.horizontal) {
          _controller.animateTo(1, curve: widget.inCurve);
        } else {
          _controller.forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _in.dispose();
    _out.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// A constant slide for pages that are not entering, so every slot keeps the
  /// same wrapper chain.
  static const _noSlide = AlwaysStoppedAnimation<Offset>(Offset.zero);

  /// One page slot.
  ///
  /// **The wrapper chain is identical for every page and never changes** — only
  /// its properties do. That matters: if a page were wrapped in
  /// `Offstage > TickerMode > FadeTransition` while hidden and in
  /// `FadeTransition > SlideTransition` while current, the widget type in those
  /// slots would change on every switch and Flutter would remount the page,
  /// which is exactly the state loss this widget exists to prevent.
  Widget _slot(BuildContext context, int index) {
    final isCurrent = index == _current;
    final isLeaving = index == _leaving;
    final visible = isCurrent || isLeaving;

    return KeyedSubtree(
      key: ValueKey<Object>(widget.pageKeys?[index] ?? index),
      child: Offstage(
        // Hidden pages retain state without painting or receiving input.
        offstage: !visible,
        child: TickerMode(
          // A hidden page must not keep animating behind the visible one.
          enabled: isCurrent,
          child: IgnorePointer(
            ignoring: !isCurrent,
            child: ExcludeFocus(
              excluding: !isCurrent,
              child: ExcludeSemantics(
                excluding: !isCurrent,
                child: FadeTransition(
                  opacity: isCurrent
                      ? (widget.horizontal && !widget.depth
                            ? kAlwaysCompleteAnimation
                            : _in)
                      : (isLeaving ? _fadeOut : kAlwaysCompleteAnimation),
                  child: SlideTransition(
                    position: isCurrent && !widget.horizontal
                        ? _slide
                        : _noSlide,
                    child: LayoutBuilder(
                      builder: (context, constraints) => AnimatedBuilder(
                        animation: _controller,
                        child: RepaintBoundary(
                          child: widget.pageBuilder(context, index),
                        ),
                        builder: (context, child) {
                          final progress = widget.horizontal
                              ? _controller.value
                              : _in.value;
                          final dx = !widget.horizontal
                              ? 0.0
                              : constraints.maxWidth *
                                    _direction *
                                    (isCurrent ? 1 - progress : -progress);
                          final scale = widget.depth && widget.horizontal
                              ? 1 -
                                    (isCurrent ? 1 - progress : progress) *
                                        .035 *
                                        widget.intensity
                              : 1.0;
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: Transform.scale(scale: scale, child: child),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paint order: hidden pages first, then the one fading out, then the one
    // fading in. The slots are keyed, so re-ordering reuses the elements instead
    // of rebuilding them.
    final leaving = _leaving;
    final children = <Widget>[
      for (final index in _built)
        if (index != _current && index != leaving) _slot(context, index),
      if (leaving != null) _slot(context, leaving),
      _slot(context, _current),
    ];

    return GestureDetector(
      onHorizontalDragStart: widget.onIndexChanged == null
          ? null
          : (_) {
              _dragOrigin = _current;
            },
      onHorizontalDragUpdate: widget.onIndexChanged == null
          ? null
          : (details) {
              final width = context.size?.width ?? 0;
              if (width == 0) return;
              if (!_dragging) {
                if (_controller.isAnimating) return;
                final origin = _dragOrigin ?? _current;
                final step = details.delta.dx * _readingDirection < 0 ? 1 : -1;
                final target = origin + step;
                if (target < 0 || target >= (widget.pageCount ?? 0)) return;
                setState(() {
                  _dragging = true;
                  _leaving = origin;
                  _current = target;
                  _built.add(target);
                  _direction = step * _readingDirection;
                  _controller.value = 0;
                });
              }
              _controller.value =
                  (_controller.value - details.delta.dx * _direction / width)
                      .clamp(0, 1);
            },
      onHorizontalDragEnd: widget.onIndexChanged == null
          ? null
          : (details) {
              _finishDrag(details.primaryVelocity ?? 0);
            },
      onHorizontalDragCancel: widget.onIndexChanged == null
          ? null
          : () => _finishDrag(0, cancel: true),
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: children),
      ),
    );
  }

  Future<void> _finishDrag(double velocity, {bool cancel = false}) async {
    if (!_dragging) return;
    final origin = _dragOrigin;
    final target = _current;
    final complete =
        !cancel && (_controller.value > .28 || velocity * _direction < -450);
    if (complete) {
      _dragging = false;
      widget.onIndexChanged?.call(target);
      if (mounted) _controller.animateTo(1, curve: widget.inCurve);
    } else {
      await _controller.animateBack(0, curve: widget.outCurve);
      if (!mounted || !_dragging || _current != target) return;
      setState(() {
        _dragging = false;
        _current = origin ?? widget.index;
        _leaving = null;
        _controller.value = 1;
      });
    }
  }
}
