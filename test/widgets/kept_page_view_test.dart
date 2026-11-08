import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/tokens/fluxora_motion.dart';
import 'package:fluxora/widgets/widgets.dart';

/// `KeptPageView` — the mobile page host introduced in Phase 04.3.
///
/// The problem it solves: `AnimatedSwitcher` disposes the outgoing child when
/// its fade ends, so every mobile page switch threw the page's `State` away
/// (scroll offset, in-page selection, form text) and the next visit re-ran
/// `initState`. The desktop host kept pages alive via `KeepScope`, so the two
/// platforms disagreed.
///
/// These tests pin the four properties that make the replacement safe:
/// laziness, retention, inertness, and that the transition still obeys the
/// motion tokens.
void main() {
  late _Log log;

  /// The probe pages run a repeating animation, so `pumpAndSettle` would never
  /// return. Advance past the longest transition explicitly instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() => log = _Log());

  Widget host({
    required int index,
    required List<String> tags,
    Duration duration = FluxoraMotion.slow,
    Offset enterOffset = FluxoraMotion.enterOffset,
    bool stableKeys = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: KeptPageView(
          pageKeys: stableKeys ? tags : null,
          index: index,
          duration: duration,
          inCurve: FluxoraMotion.enter,
          outCurve: FluxoraMotion.exit,
          enterOffset: enterOffset,
          pageBuilder: (_, i) => _Probe(tag: tags[i], log: log),
        ),
      ),
    );
  }

  group('laziness', () {
    testWidgets('responsive navigation changes retain state by page identity', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(index: 0, tags: const ['a', 'b', 'c'], stableKeys: true),
      );
      await settle(tester);
      await tester.tap(find.text('page-a'));
      await tester.pump();
      await tester.pumpWidget(
        host(index: 2, tags: const ['a', 'b', 'c'], stableKeys: true),
      );
      await settle(tester);
      await tester.pumpWidget(
        host(index: 1, tags: const ['a', 'c'], stableKeys: true),
      );
      await settle(tester);
      expect(find.text('page-c'), findsOneWidget);
      expect(log.inits, ['a', 'c']);
      await tester.pumpWidget(
        host(index: 0, tags: const ['a', 'c'], stableKeys: true),
      );
      await settle(tester);
      expect(find.text('page-a:1'), findsOneWidget);
      expect(log.disposes, isEmpty);
    });
    testWidgets('only the first page is built', (tester) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b', 'c']));
      await settle(tester);

      expect(log.inits, ['a']);
      expect(
        find.text('page-b', skipOffstage: false),
        findsNothing,
        reason: 'an unvisited page must not be built at all',
      );
    });

    testWidgets('a page is built on its first visit, not before', (
      tester,
    ) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);
      expect(log.inits, ['a']);

      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await settle(tester);

      expect(log.inits, ['a', 'b']);
      expect(find.text('page-b'), findsOneWidget);
    });
  });

  group('retention', () {
    testWidgets('returning to a page keeps its state and does not re-init', (
      tester,
    ) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);

      // Mutate the page's own state.
      await tester.tap(find.text('page-a'));
      await tester.pump();
      expect(find.text('page-a:1'), findsOneWidget);

      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await settle(tester);
      expect(find.text('page-b'), findsOneWidget);

      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);

      expect(
        find.text('page-a:1'),
        findsOneWidget,
        reason: 'the in-page state survived the round trip',
      );
      expect(log.inits, ['a', 'b'], reason: 'no page was rebuilt');
      expect(log.disposes, isEmpty);
    });

    testWidgets('a scroll offset survives leaving and returning', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget scrolled(int index) => MaterialApp(
        home: Scaffold(
          body: KeptPageView(
            index: index,
            duration: FluxoraMotion.slow,
            inCurve: FluxoraMotion.enter,
            outCurve: FluxoraMotion.exit,
            enterOffset: FluxoraMotion.enterOffset,
            pageBuilder: (_, i) => i == 0
                ? ListView.builder(
                    controller: controller,
                    itemCount: 60,
                    itemExtent: 40,
                    itemBuilder: (_, r) => Text('row-$r'),
                  )
                : const Center(child: Text('page-b')),
          ),
        ),
      );

      await tester.pumpWidget(scrolled(0));
      await settle(tester);

      controller.jumpTo(400);
      await settle(tester);
      expect(controller.offset, 400);

      await tester.pumpWidget(scrolled(1));
      await settle(tester);
      await tester.pumpWidget(scrolled(0));
      await settle(tester);

      expect(
        controller.offset,
        400,
        reason: 'the list kept its position while the page was off-stage',
      );
    });
  });

  group('inertness', () {
    testWidgets('a hidden page is off-stage and does not advance tickers', (
      tester,
    ) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);

      final controllerA = log.controllerOf('a');
      // `isAnimating` stays true for a *muted* ticker (the future is still
      // pending), so the observable signal is whether the value still advances.
      final before = controllerA!.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(controllerA.value, isNot(before), reason: 'running while visible');

      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await settle(tester);

      expect(
        find.text('page-a', skipOffstage: true),
        findsNothing,
        reason: 'the hidden page is off-stage, so a normal finder misses it',
      );
      expect(
        find.text('page-a', skipOffstage: false),
        findsOneWidget,
        reason: 'but it is still mounted',
      );
      // `isAnimating` stays true for a *muted* ticker (the future is still
      // pending), so the observable signal is whether the value still advances.
      final parked = controllerA.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        controllerA.value,
        parked,
        reason: 'TickerMode(false) freezes the hidden page\'s animation',
      );
    });

    testWidgets('a hidden page cannot receive taps', (tester) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);
      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await settle(tester);

      // Off-stage widgets are not hit-testable; tapping their location must not
      // reach the page behind.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(log.tapsOf('a'), 0);
    });
  });

  group('transition', () {
    testWidgets('the entering page fades in with the token lift', (
      tester,
    ) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);

      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final slide = tester
          .widgetList<SlideTransition>(
            find.ancestor(
              of: find.text('page-b'),
              matching: find.byType(SlideTransition),
            ),
          )
          .first;
      expect(slide.position.value.dy, greaterThan(0.0));
      expect(slide.position.value.dy, lessThanOrEqualTo(4.0));

      await settle(tester);
      expect(
        tester
            .widgetList<SlideTransition>(
              find.ancestor(
                of: find.text('page-b'),
                matching: find.byType(SlideTransition),
              ),
            )
            .first
            .position
            .value
            .dy,
        0.0,
      );
    });

    testWidgets('the outgoing page fades out instead of vanishing', (
      tester,
    ) async {
      // `AnimatedSwitcher` handed the outgoing child a *reversed* animation, so
      // it started fully visible and faded to 0. Driving the same
      // `CurvedAnimation` forwards (the first version of this widget did) makes
      // the old page disappear on frame one and fade back in behind the new
      // one — the same endpoints at t=1, a visibly different transition.
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b']));
      await settle(tester);

      double opacityOf(String tag) => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('page-$tag', skipOffstage: false),
              matching: find.byType(FadeTransition),
            ),
          )
          .first
          .opacity
          .value;

      await tester.pumpWidget(host(index: 1, tags: const ['a', 'b']));
      await tester.pump();

      expect(opacityOf('a'), 1.0, reason: 'the old page starts fully visible');
      expect(opacityOf('b'), 0.0, reason: 'the new page starts from zero');

      await tester.pump(const Duration(milliseconds: 160));
      final mid = opacityOf('a');
      expect(mid, lessThan(1.0), reason: 'it is on its way out');
      expect(mid, greaterThan(0.0), reason: 'but not gone after one frame');

      await settle(tester);
      expect(find.text('page-a'), findsNothing, reason: 'off-stage once done');
    });

    testWidgets('zero duration switches in one frame', (tester) async {
      await tester.pumpWidget(
        host(
          index: 0,
          tags: const ['a', 'b'],
          duration: Duration.zero,
          enterOffset: Offset.zero,
        ),
      );
      await settle(tester);

      await tester.pumpWidget(
        host(
          index: 1,
          tags: const ['a', 'b'],
          duration: Duration.zero,
          enterOffset: Offset.zero,
        ),
      );
      await tester.pump();

      expect(find.text('page-b'), findsOneWidget);
      expect(find.text('page-a'), findsNothing);

      // The probe keeps a repeating ticker, so `hasRunningAnimations` is always
      // true here. The host's own contract is that the incoming page is already
      // at full opacity on the first frame — no ramp to sit on.
      final opacity = tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('page-b'),
              matching: find.byType(FadeTransition),
            ),
          )
          .first
          .opacity
          .value;
      expect(opacity, 1.0);
      expect(log.inits, ['a', 'b'], reason: 'state is kept either way');
    });
  });

  group('rapid switching', () {
    testWidgets('lands on the last page with no duplicate inits', (
      tester,
    ) async {
      await tester.pumpWidget(host(index: 0, tags: const ['a', 'b', 'c']));
      await settle(tester);

      for (final i in [1, 2, 0, 1]) {
        await tester.pumpWidget(host(index: i, tags: const ['a', 'b', 'c']));
        await tester.pump();
      }
      await settle(tester);

      expect(find.text('page-b'), findsOneWidget);
      expect(find.text('page-a'), findsNothing);
      expect(find.text('page-c'), findsNothing);
      expect(log.inits, ['a', 'b', 'c'], reason: 'each page built once');
    });
  });
}

class _Log {
  final List<String> inits = <String>[];
  final List<String> disposes = <String>[];
  final Map<String, AnimationController> controllers =
      <String, AnimationController>{};
  final Map<String, int> taps = <String, int>{};

  AnimationController? controllerOf(String tag) => controllers[tag];
  int tapsOf(String tag) => taps[tag] ?? 0;
}

/// A page with (a) countable lifecycle, (b) its own mutable state, and (c) a
/// repeating animation, so "kept" and "inert" are both observable.
class _Probe extends StatefulWidget {
  const _Probe({required this.tag, required this.log});

  final String tag;
  final _Log log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.log.inits.add(widget.tag);
    widget.log.controllers[widget.tag] = _controller;
  }

  @override
  void dispose() {
    widget.log.disposes.add(widget.tag);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.log.taps[widget.tag] = (widget.log.taps[widget.tag] ?? 0) + 1;
        setState(() => _count++);
      },
      child: Center(
        child: Text(
          _count == 0 ? 'page-${widget.tag}' : 'page-${widget.tag}:$_count',
        ),
      ),
    );
  }
}
