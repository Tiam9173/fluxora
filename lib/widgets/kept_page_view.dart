import 'package:flutter/material.dart';

/// A lazily-built, keep-alive page host with the Aurora cross-fade.
///
/// Replaces the `AnimatedSwitcher` that used to host the mobile pages. That
/// widget destroys the outgoing child as soon as its fade finishes, so every
/// switch threw the page's `State` away — scroll position, in-page selections
/// and form text — and the next visit re-ran `initState` (which, for the real
/// pages, means real work: dashboard cards call `SystemProxyReadbackService`
/// and `ClashHandlerInterface.getMemory`).
///
/// What this does instead:
///
/// * **Lazy** — a page is only built the first time it is selected. Nothing is
///   built ahead of time, so the cost stays at "one page per visited tab".
/// * **Kept** — once built, a page's element stays in the tree. Hidden pages are
///   wrapped in [Offstage], which skips layout, painting, hit-testing and
///   semantics but keeps the `State` alive.
/// * **Inert** — hidden pages also get `TickerMode(enabled: false)`, so a
///   page's own animations stop instead of running behind the visible one.
///   That is the part a naive `IndexedStack` gets wrong.
/// * **Same transition** — the incoming page fades in with the 4 px Aurora
///   lift; the outgoing one fades out. Both durations/curves/offsets come from
///   `FluxoraMotionSet`, so reduced motion collapses them to zero and the switch
///   is a single frame.
///
/// The page index is stable: children are keyed by their own index, so a
/// `pageBuilder` that is re-created on every parent build never remounts a page.
class KeptPageView extends StatefulWidget {
  const KeptPageView({
    super.key,
    required this.index,
    required this.pageBuilder,
    required this.duration,
    required this.inCurve,
    required this.outCurve,
    required this.enterOffset,
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
    if (status == AnimationStatus.completed && _leaving != null) {
      setState(() => _leaving = null);
    }
  }

  @override
  void didUpdateWidget(covariant KeptPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enterOffset != widget.enterOffset ||
        oldWidget.inCurve != widget.inCurve ||
        oldWidget.outCurve != widget.outCurve) {
      _resolveAnimations();
    }
    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.index != _current) {
      _leaving = _current;
      _current = widget.index;
      _built.add(_current);

      if (widget.duration == Duration.zero) {
        // Reduced motion (or a zero token): land on the final state now. The
        // outgoing page goes off-stage in the same frame.
        _controller.value = 1;
        _leaving = null;
      } else {
        _controller.forward(from: 0);
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
      key: ValueKey<int>(index),
      child: Offstage(
        // Hidden pages keep their element (state) but skip layout, painting,
        // hit-testing and semantics.
        offstage: !visible,
        child: TickerMode(
          // A hidden page must not keep animating behind the visible one.
          enabled: isCurrent,
          child: IgnorePointer(
            ignoring: !isCurrent,
            child: FadeTransition(
              opacity: isCurrent
                  ? _in
                  : (isLeaving ? _fadeOut : kAlwaysCompleteAnimation),
              child: SlideTransition(
                position: isCurrent ? _slide : _noSlide,
                child: widget.pageBuilder(context, index),
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

    return Stack(fit: StackFit.expand, children: children);
  }
}
