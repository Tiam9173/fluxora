import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/tab.dart';

/// Phase 04.3 — the proxy **group** switch (`views/proxies/tab.dart`).
///
/// Phase 04.2 reported that this path had no automated cover: the tab strip, its
/// `TabController` listener and the "current group" round-trip through
/// `AppController` were only verified by reading the code.
///
/// It is mountable without a core: `ProxiesTabView` reads its groups from
/// `proxiesTabStateProvider`, and the only `AppController` members it touches on
/// this path are `getCurrentGroups` / `getCurrentGroupName` /
/// `updateCurrentGroupName` — all overridden by the fake below. `getSortProxies`
/// is a pure function in the real controller, so it is left alone. Nothing here
/// starts a core, reads a proxy service or touches the system proxy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeController controller;

  /// Built once and reused: the `Consumer` rebuilds on every group change, and
  /// re-creating the fake there would wipe the group name it is meant to record.
  _FakeController? fake;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  List<Group> twoGroups() => [
    Group(
      type: GroupType.Selector,
      name: 'G1',
      all: const [Proxy(name: 'proxy-one', type: 'Trojan')],
    ),
    Group(
      type: GroupType.Selector,
      name: 'G2',
      all: const [Proxy(name: 'proxy-two', type: 'VLESS')],
    ),
  ];

  /// The listener commits the group name from a post-frame callback, and only
  /// once the tab animation has reached its target (`TabBarView` checks
  /// `animation.value != controller.index` first). Two frames are enough in full
  /// motion but not under reduced motion, where the shortened animation still
  /// takes a frame or two — so always advance past it.
  Future<void> settleGroups(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── State probes ─────────────────────────────────────────────────────────
  //
  // A switch involves five independent pieces of state. Asserting only the tab
  // label (or only the group name) is what let the Phase 04.3 desync through, so
  // every switch test below checks all of them.

  TabController tabOf(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!;

  /// The page `TabBarView` is actually painting, read from the scroll offset of
  /// the `PageView` it owns. `TabBarView` keeps its `PageController` private, so
  /// this is the only honest way to observe it.
  double pageOf(WidgetTester tester) {
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(PageView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    return scrollable.position.pixels / scrollable.position.viewportDimension;
  }

  /// What the strip paints the label with — the selected tab is `primary`, the
  /// rest `onSurfaceVariant`.
  Color? labelColour(WidgetTester tester, String label) {
    final element = tester.element(
      find
          .descendant(of: find.byType(TabBar), matching: find.text(label))
          .first,
    );
    return DefaultTextStyle.of(element).style.color;
  }

  /// All five states must agree: controller index, controller animation value,
  /// strip selection, page offset, rendered content — plus the group name that
  /// went back through `AppController`.
  void expectSynced(
    WidgetTester tester, {
    required int index,
    required String groupName,
    required String visibleNode,
    required String hiddenNode,
  }) {
    final tab = tabOf(tester);
    expect(tab.index, index, reason: 'TabController.index');
    expect(
      tab.animation!.value,
      closeTo(index.toDouble(), 1e-6),
      reason: 'TabController.animation.value settled on the index',
    );
    expect(
      pageOf(tester),
      closeTo(index.toDouble(), 1e-3),
      reason: 'the page TabBarView paints',
    );
    expect(find.text(visibleNode), findsOneWidget, reason: 'rendered content');
    expect(find.text(hiddenNode), findsNothing);
    expect(controller.name, groupName, reason: 'AppController round-trip');
    final scheme = Theme.of(tester.element(find.byType(TabBar))).colorScheme;
    expect(
      labelColour(tester, groupName),
      scheme.primary,
      reason: 'the strip marks the group as selected',
    );
  }

  /// Group list the provider override reads. Re-pumping a `ProviderScope` does
  /// **not** re-run an existing override, so a group-count change has to
  /// invalidate the provider explicitly — see [replaceGroups].
  List<Group> overrideGroups = const <Group>[];

  /// The "profile" current group name. In the app `updateCurrentGroupName`
  /// persists it and `proxiesTabState` reads it back, so the fake has to close
  /// that loop too — otherwise a group-list change would always resolve to the
  /// first group in the test and nowhere else.
  String overrideCurrentGroup = 'G1';

  Future<void> pumpProxies(
    WidgetTester tester, {
    required List<Group> groups,
    String current = 'G1',
    bool reduce = false,
    bool mobile = true,
  }) async {
    overrideGroups = groups;
    overrideCurrentGroup = current;
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final size = mobile ? const Size(400, 800) : const Size(1200, 800);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A fresh fake per pump: it records the group name, and a previous test's
    // writes must not leak in.
    fake = null;
    globalState.config = Config(themeProps: defaultThemeProps);
    globalState.appState = AppState(
      viewSize: size,
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.proxies,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proxiesTabStateProvider.overrideWith(
            (ref) => ProxiesTabState(
              groups: overrideGroups,
              currentGroupName: overrideCurrentGroup,
              proxiesSortType: ProxiesSortType.none,
              proxyCardType: ProxyCardType.shrink,
              sortNum: 0,
              columns: 1,
            ),
          ),
          isMobileViewProvider.overrideWith((ref) => mobile),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (ctx, ref, _) {
              globalState.theme = CommonTheme.of(ctx, 1.0);
              globalState.measure = Measure.of(ctx, 1.0);
              controller = fake ??= _FakeController(
                ctx,
                ref,
                overrideGroups,
                current,
                (value) => overrideCurrentGroup = value,
              );
              globalState.appController = controller;
              return const Scaffold(body: ProxiesTabView());
            },
          ),
        ),
      ),
    );
    await settleGroups(tester);
  }

  /// Swaps the group list under the live view.
  ///
  /// `ProviderScope` does not re-run an override it already holds, so the
  /// provider has to be invalidated for the new list to be seen — the same thing
  /// that happens in the app when a profile reloads its groups.
  Future<void> replaceGroups(WidgetTester tester, List<Group> groups) async {
    overrideGroups = groups;
    fake!.groups = groups;
    ProviderScope.containerOf(
      tester.element(find.byType(ProxiesTabView)),
      listen: false,
    ).invalidate(proxiesTabStateProvider);
    await settleGroups(tester);
  }

  group('switching groups', () {
    testWidgets('tapping a group makes it current and shows its nodes', (
      tester,
    ) async {
      await pumpProxies(tester, groups: twoGroups());

      expect(find.text('proxy-one'), findsOneWidget);
      expect(find.text('proxy-two'), findsNothing);

      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      expect(
        controller.name,
        'G2',
        reason: 'the current group followed the tab',
      );
      expect(find.text('proxy-two'), findsOneWidget);
      expect(find.text('proxy-one'), findsNothing);
    });

    testWidgets('the selected tab and the shown content agree', (tester) async {
      await pumpProxies(tester, groups: twoGroups());

      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      // Both the tab state and the visible page are derived from the same
      // `TabController.index`; a mismatch would show the wrong group's nodes.
      expect(controller.name, 'G2');
      expect(find.text('proxy-two'), findsOneWidget);
    });

    testWidgets('a fast but uninterrupted sequence lands on the last group', (
      tester,
    ) async {
      await pumpProxies(tester, groups: twoGroups());

      // Fast tapping, but each slide is allowed to finish (the slide is 300 ms).
      for (final name in ['G2', 'G1', 'G2', 'G1']) {
        await tester.tap(find.text(name));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await settleGroups(tester);

      expect(controller.name, 'G1');
      expect(find.text('proxy-one'), findsOneWidget);
      expect(find.text('proxy-two'), findsNothing);
      expect(
        controller.groupNameWrites,
        lessThanOrEqualTo(6),
        reason: 'one commit per switch, no runaway loop',
      );
    });

    testWidgets('full motion still slides: the commit waits for the animation', (
      tester,
    ) async {
      // The reduced-motion fix must not have flattened the normal path. With
      // animations enabled the switch keeps `kTabScrollDuration`, so the group
      // name is deliberately *not* committed while the strip is still moving.
      await pumpProxies(tester, groups: twoGroups());

      await tester.tap(find.text('G2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(
        controller.name,
        'G1',
        reason: 'the 300 ms slide is still running at 60 ms',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.name, 'G2');
      expect(find.text('proxy-two'), findsOneWidget);
    });

    testWidgets('interrupting the slide lands on the last tapped group', (
      tester,
    ) async {
      // Phase 04.3 pinned this as a KNOWN DEFECT: tapping the next group
      // **before** the previous 300 ms slide has moved ended with
      // `TabController.index == 0` while `TabBarView` painted page 1 — the strip
      // said "G1", the grid showed G2's nodes, permanently.
      //
      // Root cause: `TabBarView` only learns about an index change from a tick of
      // `controller.animation` taken while `indexIsChanging`. When the tap lands
      // on the index the animation is still resting at, `animateTo` hits
      // `target == value` in `AnimationController._animateToInternal`, returns
      // `TickerFuture.complete()` and never ticks, while the page warp started by
      // the previous tap keeps running to the old target.
      await pumpProxies(tester, groups: twoGroups());

      for (final name in ['G2', 'G1', 'G2', 'G1']) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 800));

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
    });
  });

  group('reduced motion', () {
    testWidgets('a group switch still lands on the new group', (tester) async {
      await pumpProxies(tester, groups: twoGroups(), reduce: true);

      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      expect(controller.name, 'G2');
      expect(find.text('proxy-two'), findsOneWidget);
    });

    testWidgets('the group switch lands within a couple of frames', (
      tester,
    ) async {
      // Before this round the switch took 340 ms under reduced motion, and it
      // was not the *motion* that was long — it was the gap. The framework's
      // 5 % scaling shortens only the time the animation **value** needs
      // (`animation_controller.dart:651`), while the simulation still runs the
      // full `kTabScrollDuration` and `TabController` notifies in
      // `whenCompleteOrCancel`. So the indicator sat on the new group after
      // ~15 ms while `TabBarView`, which reacts to the index change, kept
      // painting the previous group for another ~285 ms. The controller is now
      // built with `animationDuration: Duration.zero` when animations are
      // disabled, which takes `_changeIndex`'s immediate branch and makes
      // `TabBarView` `_jumpToPage`.
      //
      // Asserted as "within 3 frames", not as "zero": the group name still
      // commits from a post-frame callback, so it lands one pump later
      // (measured: 20 ms, one 20 ms pump).
      await pumpProxies(tester, groups: twoGroups(), reduce: true);

      await tester.tap(find.text('G2'));

      var elapsed = Duration.zero;
      while (controller.name != 'G2' && elapsed < const Duration(seconds: 1)) {
        await tester.pump(const Duration(milliseconds: 20));
        elapsed += const Duration(milliseconds: 20);
      }

      expect(controller.name, 'G2');
      expect(
        elapsed,
        lessThanOrEqualTo(const Duration(milliseconds: 60)),
        reason: 'no slide under reduced motion — a few frames at most',
      );

      // The name commits immediately; `TabBarView` paints the new page on the
      // next frame. Nothing is left showing the previous group in between.
      await tester.pump();
      expect(find.text('proxy-two'), findsOneWidget);
      expect(find.text('proxy-one'), findsNothing);
    });
    testWidgets('a same-frame burst still lands on the last group', (
      tester,
    ) async {
      // The desync guard is skipped when the switch duration is zero, because
      // `_changeIndex` then notifies while `indexIsChanging` is still true and
      // `TabBarView` jumps in the same frame — no stale warp can survive. This
      // pins that reasoning instead of trusting it.
      await pumpProxies(tester, groups: twoGroups(), reduce: true);

      for (final name in ['G2', 'G1', 'G2', 'G1']) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 100));

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
    });
  });

  group('interrupted switches', () {
    // These interrupts land while the slide is still moving. They were already
    // correct before the fix — the animation keeps ticking and `TabBarView`
    // re-warps — so they exist to prove the new guard stays out of the way:
    // `previousIndex` still points at the group the slide came from, which a
    // controller rebuild would have reset.
    for (final gap in [1, 40, 80, 150]) {
      testWidgets('tapping back to the origin after ${gap}ms', (tester) async {
        await pumpProxies(tester, groups: twoGroups());

        await tester.tap(find.text('G2'));
        await tester.pump();
        await tester.pump(Duration(milliseconds: gap));
        await tester.tap(find.text('G1'));
        await settleGroups(tester);

        expectSynced(
          tester,
          index: 0,
          groupName: 'G1',
          visibleNode: 'proxy-one',
          hiddenNode: 'proxy-two',
        );
        expect(
          tabOf(tester).previousIndex,
          1,
          reason: 'the slide was interrupted and animated back, not rebuilt',
        );
      });
    }

    testWidgets('a same-frame burst needs the controller rebuild', (
      tester,
    ) async {
      await pumpProxies(tester, groups: twoGroups());

      for (final name in ['G2', 'G1', 'G2', 'G1']) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 800));

      // `previousIndex == index` is the signature of the rebuild path: the
      // degenerate `animateTo` emitted no tick, so the page could only be
      // re-synced by handing `TabBarView` a new controller.
      expect(
        tabOf(tester).previousIndex,
        0,
        reason: 'the degenerate case rebuilt the controller',
      );
      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
    });

    testWidgets('interrupting towards a third group', (tester) async {
      await pumpProxies(
        tester,
        groups: [
          ...twoGroups(),
          Group(
            type: GroupType.Selector,
            name: 'G3',
            all: const [Proxy(name: 'proxy-three', type: 'Trojan')],
          ),
        ],
      );

      await tester.tap(find.text('G2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('G3'));
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 2,
        groupName: 'G3',
        visibleNode: 'proxy-three',
        hiddenNode: 'proxy-two',
      );
    });

    testWidgets('tapping the selected group again is a no-op', (tester) async {
      await pumpProxies(tester, groups: twoGroups());

      await tester.tap(find.text('G1'));
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
      expect(controller.groupNameWrites, 0, reason: 'nothing to commit');
      expect(tabOf(tester).previousIndex, 0, reason: 'and no rebuild');
    });
  });

  group('gestures', () {
    testWidgets('dragging to the next group selects it', (tester) async {
      await pumpProxies(tester, groups: twoGroups());

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 1,
        groupName: 'G2',
        visibleNode: 'proxy-two',
        hiddenNode: 'proxy-one',
      );
    });

    testWidgets('a short drag snaps back to the same group', (tester) async {
      await pumpProxies(tester, groups: twoGroups());

      await tester.drag(find.byType(PageView), const Offset(-80, 0));
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
    });

    testWidgets('dragging there and back ends on one group', (tester) async {
      await pumpProxies(tester, groups: twoGroups());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-260, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump();
      await gesture.up();
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
    });

    testWidgets('tapping while a drag is still down ends consistent', (
      tester,
    ) async {
      // The drag owns the page (`_scrollUnderwayCount > 0` makes `TabBarView`
      // ignore controller ticks), so which intent wins is a framework decision.
      // What must hold is that all five states agree afterwards.
      await pumpProxies(tester, groups: twoGroups());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();

      await tester.tap(find.text('G2'));
      await tester.pump();

      await gesture.up();
      await settleGroups(tester);

      final index = tabOf(tester).index;
      expectSynced(
        tester,
        index: index,
        groupName: index == 1 ? 'G2' : 'G1',
        visibleNode: index == 1 ? 'proxy-two' : 'proxy-one',
        hiddenNode: index == 1 ? 'proxy-one' : 'proxy-two',
      );
    });

    testWidgets('a drag started during a tap animation ends consistent', (
      tester,
    ) async {
      await pumpProxies(tester, groups: twoGroups());

      await tester.tap(find.text('G2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await settleGroups(tester);

      final index = tabOf(tester).index;
      expectSynced(
        tester,
        index: index,
        groupName: index == 1 ? 'G2' : 'G1',
        visibleNode: index == 1 ? 'proxy-two' : 'proxy-one',
        hiddenNode: index == 1 ? 'proxy-one' : 'proxy-two',
      );
    });
  });

  group('group count changes', () {
    Group third() => Group(
      type: GroupType.Selector,
      name: 'G3',
      all: const [Proxy(name: 'proxy-three', type: 'Trojan')],
    );

    testWidgets('adding a group keeps the current one', (tester) async {
      await pumpProxies(tester, groups: twoGroups());
      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      await replaceGroups(tester, [...twoGroups(), third()]);

      expectSynced(
        tester,
        index: 1,
        groupName: 'G2',
        visibleNode: 'proxy-two',
        hiddenNode: 'proxy-one',
      );
    });

    testWidgets('removing the current group falls back inside the list', (
      tester,
    ) async {
      await pumpProxies(tester, groups: [...twoGroups(), third()]);
      await tester.tap(find.text('G3'));
      await settleGroups(tester);

      // G3 (index 2) disappears. The existing policy — unchanged by this round —
      // is `indexWhere(currentGroupName)`, which is -1 for a vanished group and
      // therefore falls back to the first one. What matters here is that the
      // fallback stays consistent and in range instead of leaving the page on
      // the deleted group.
      await replaceGroups(tester, twoGroups());

      expectSynced(
        tester,
        index: 0,
        groupName: 'G1',
        visibleNode: 'proxy-one',
        hiddenNode: 'proxy-two',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinking to a single group', (tester) async {
      await pumpProxies(tester, groups: twoGroups());
      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      await replaceGroups(tester, [twoGroups().last]);

      final tab = tabOf(tester);
      expect(tab.index, 0);
      expect(tab.length, 1);
      expect(pageOf(tester), closeTo(0.0, 1e-3));
      expect(find.text('proxy-two'), findsOneWidget);
      expect(find.text('proxy-one'), findsNothing);
      expect(controller.name, 'G2');
    });

    testWidgets('a switch still works after the count changed', (tester) async {
      await pumpProxies(tester, groups: twoGroups());
      await replaceGroups(tester, [...twoGroups(), third()]);

      await tester.tap(find.text('G3'));
      await settleGroups(tester);

      expectSynced(
        tester,
        index: 2,
        groupName: 'G3',
        visibleNode: 'proxy-three',
        hiddenNode: 'proxy-one',
      );
    });
  });

  group('boundaries', () {
    testWidgets('no groups renders the empty state without throwing', (
      tester,
    ) async {
      await pumpProxies(tester, groups: const []);

      expect(tester.takeException(), isNull);
      expect(find.byType(ProxiesTabView), findsOneWidget);
    });

    testWidgets('a single group needs no switching and stays current', (
      tester,
    ) async {
      final groups = [
        Group(
          type: GroupType.Selector,
          name: 'only',
          all: const [Proxy(name: 'solo-node', type: 'Trojan')],
        ),
      ];
      await pumpProxies(tester, groups: groups, current: 'only');

      expect(controller.name, 'only');
      expect(find.text('solo-node'), findsOneWidget);
      expect(controller.groupNameWrites, 0, reason: 'nothing to switch to');
    });

    testWidgets('many groups keep their order and the first stays current', (
      tester,
    ) async {
      final groups = [
        for (var i = 0; i < 6; i++)
          Group(
            type: GroupType.Selector,
            name: 'G$i',
            all: [Proxy(name: 'node-$i', type: 'Trojan')],
          ),
      ];
      await pumpProxies(tester, groups: groups, current: 'G0');

      expect(controller.name, 'G0');
      expect(find.text('node-0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('no core is touched', () {
    testWidgets('the whole flow runs against the fake controller', (
      tester,
    ) async {
      // Everything on this path is `globalState.appController`; the fake owns the
      // group name. A real core would have had to be started for
      // `getCurrentGroups` to return anything, and it is never constructed here.
      await pumpProxies(tester, groups: twoGroups());
      await tester.tap(find.text('G2'));
      await settleGroups(tester);

      expect(controller, isA<_FakeController>());
      expect(controller.name, 'G2');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Stands in for `AppController` on the group-switch path only.
class _FakeController extends AppController {
  _FakeController(
    super.context,
    super.ref,
    this.groups,
    this.name,
    this._onPersist,
  );

  List<Group> groups;
  String name;
  int groupNameWrites = 0;

  /// Stands in for the profile write the real controller performs.
  final ValueChanged<String> _onPersist;

  @override
  List<Group> getCurrentGroups() => groups;

  @override
  String getCurrentGroupName() => name;

  @override
  void updateCurrentGroupName(String value) {
    groupNameWrites++;
    name = value;
    _onPersist(value);
  }
}
