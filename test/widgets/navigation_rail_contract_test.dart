import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/app_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../support/recording_app_controller.dart';

/// K4 — the desktop rail's contract, driven by the **production** item list.
///
/// The rail lives inside `AppSidebarContainer` (`lib/manager/app_manager.dart`),
/// a public `ConsumerWidget`, so it can be driven directly instead of pumping
/// the whole desktop shell.
///
/// ## Why this file no longer renders eight destinations
///
/// `Navigation.items` is the full information architecture — eight entries — and
/// that set is pinned in `test/common/navigation_contract_test.dart`. But the
/// rail does not render it: `currentNavigationItemsStateProvider`
/// (`lib/providers/state.dart:203`) drops every entry whose `modes` exclude the
/// current mode. On desktop that removes `resources` and `script` (both
/// `modes: [more]`), leaving **six**: dashboard, proxies, profiles, connections,
/// logs, tools.
///
/// Rendering all eight here (as this file used to) tested a tree production
/// never builds — it hid the fact that two destinations only ever reach the user
/// through the `more` group. [desktopItems] now runs the real filter instead of
/// restating its result.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  late RecordingAppController controller;
  var bound = false;

  setUp(() {
    bound = false;
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      viewSize: const Size(1200, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );
  });

  /// The destinations the rail actually renders at [width], produced by the
  /// production filter (`currentNavigationItemsStateProvider`) rather than by a
  /// hand-written list.
  ///
  /// Only `navigationItemsStateProvider` is stubbed — with the same call
  /// production makes (`getItems(openLogs:, hasProxies: true)`) — because the
  /// real one also reads `appSettingProvider`, which needs persisted settings.
  /// The mode filter under test is the real one.
  List<NavigationItem> desktopItems({double width = 1200}) {
    final container = ProviderContainer(
      overrides: [
        viewWidthProvider.overrideWith((ref) => width),
        navigationItemsStateProvider.overrideWith(
          (ref) => NavigationItemsState(
            value: navigation.getItems(openLogs: false, hasProxies: true),
          ),
        ),
      ],
    );
    // Read once and dispose immediately: a container parked until teardown
    // keeps its subscriptions (and any timer they own) alive past the widget
    // tree, which `flutter_test` reports as "A Timer is still pending".
    final items = container.read(currentNavigationItemsStateProvider).value;
    container.dispose();
    return items;
  }

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpRail(
    WidgetTester tester, {
    int currentIndex = 0,
    Brightness brightness = Brightness.dark,
    ViewMode viewMode = ViewMode.desktop,
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = desktopItems(width: width);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider.overrideWith(
            (ref) => NavigationState(
              pageLabel: items[currentIndex].label,
              navigationItems: items,
              viewMode: viewMode,
              locale: 'zh_CN',
              currentIndex: currentIndex,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF29D6C7),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) {
                // Bind once per test: the rail's callbacks reach the controller
                // through `globalState`, so it has to exist before the first
                // tap. Rebinding on every rebuild would hand each assertion a
                // fresh recorder.
                if (!bound) {
                  bound = true;
                  controller = RecordingAppController(ctx, ref);
                  globalState.appController = controller;
                }
                return seedGlobals(
                  AppSidebarContainer(child: const SizedBox.expand()),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  AuroraNavigationRail railOf(WidgetTester tester) =>
      tester.widget<AuroraNavigationRail>(find.byType(AuroraNavigationRail));

  group('K4 — destinations', () {
    testWidgets('the rail renders exactly the production desktop subset', (
      tester,
    ) async {
      await pumpRail(tester);

      final labels = railOf(tester).destinations.map((d) => d.label).toList();
      final expected = desktopItems();

      expect(labels.length, expected.length);
      expect(
        labels,
        expected.map((e) => e.label.localizedName).toList(),
        reason: 'the rail must follow the production filter, in order',
      );
    });

    testWidgets('the desktop subset is six of the eight K4 destinations', (
      tester,
    ) async {
      // Stated as a relation, not as a literal list: the full architecture is
      // eight, and exactly the `more`-only entries are withheld from the rail.
      final full = navigation.getItems(openLogs: false, hasProxies: true);
      final desktop = desktopItems();
      final moreOnly = full
          .where(
            (e) =>
                e.modes.isNotEmpty &&
                !e.modes.contains(NavigationItemMode.desktop),
          )
          .map((e) => e.label)
          .toSet();

      expect(full.length, 8);
      expect(desktop.length, 6);
      expect(moreOnly, {PageLabel.resources, PageLabel.script});

      final desktopLabels = desktop.map((e) => e.label).toSet();
      for (final label in moreOnly) {
        expect(
          desktopLabels,
          isNot(contains(label)),
          reason: '$label is `more`-only and must not sit in the desktop rail',
        );
      }
    });

    testWidgets('selectedIndex follows the current page', (tester) async {
      await pumpRail(tester, currentIndex: 3);

      expect(railOf(tester).selectedIndex, 3);
    });
  });

  // ── The Aurora visual contract ────────────────────────────────────────────
  //
  // These replace the pre-Phase-02 assertions that read `NavigationRail`'s own
  // parameters (`indicatorColor`, `indicatorShape`, `labelType`). The rail is a
  // custom widget now, so the contract is stated against what actually renders:
  // the pill's colour, the icon theme at the icon, the label's style, and the
  // accent bar's presence. Behaviour coverage is unchanged — the destination,
  // tap and keyboard groups below are untouched.

  group('K4 — Aurora selected / unselected state', () {
    testWidgets('the selected item paints the shared selection tint', (
      tester,
    ) async {
      await pumpRail(tester);

      final scheme = Theme.of(
        tester.element(find.byType(AuroraNavigationRail)),
      ).colorScheme;

      // The pill is the first `Material` inside the rail; its colour must be the
      // shared tint over the existing violet brand token.
      final pill = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AuroraNavigationRail),
              matching: find.byType(Material),
            ),
          )
          .firstWhere((m) => m.color != null);

      expect(
        pill.color,
        FluxoraColorSet.selectionTint(
          FluxoraColors.dark.tertiary,
          scheme.brightness,
        ),
      );
      expect(
        pill.shape,
        isA<RoundedRectangleBorder>(),
        reason: 'the pill is a rounded surface, not a bare rectangle',
      );
      expect(
        (pill.shape! as RoundedRectangleBorder).borderRadius,
        FluxoraRadius.mdAll,
        reason: 'the rail pill uses the card radius token',
      );
    });

    testWidgets('the selected item carries the Aurora accent bar', (
      tester,
    ) async {
      await pumpRail(tester, currentIndex: 2);

      expect(
        find.byKey(const ValueKey('aurora-rail-accent')),
        findsOneWidget,
        reason: 'exactly one destination is current, so exactly one bar',
      );
    });

    testWidgets('selected and unselected icons come from the scheme', (
      tester,
    ) async {
      await pumpRail(tester);

      final scheme = Theme.of(
        tester.element(find.byType(AuroraNavigationRail)),
      ).colorScheme;
      final items = desktopItems();

      // Selected icon: brand primary (a graphic — 3:1 is the threshold).
      final selectedIcon = items[0].icon.icon!;
      expect(
        IconTheme.of(tester.element(find.byIcon(selectedIcon))).color,
        FluxoraColors.dark.tertiary,
      );

      // Unselected icon: the muted role.
      final unselectedIcon = items[1].icon.icon!;
      expect(
        IconTheme.of(tester.element(find.byIcon(unselectedIcon))).color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('the selected label is readable, not brand-tinted', (
      tester,
    ) async {
      // `primary` on the tinted pill is ~4.1:1 in the light theme, so the label
      // deliberately stays on `onSurface` and the icon carries the brand. This
      // pins the decision so a later "make it more branded" tweak has to argue
      // with a failing test.
      await pumpRail(tester);

      final scheme = Theme.of(
        tester.element(find.byType(AuroraNavigationRail)),
      ).colorScheme;
      final items = desktopItems();

      final selectedLabel = tester.widget<Text>(
        find.text(items[0].label.localizedName),
      );
      expect(selectedLabel.style?.color, scheme.onSurface);
      expect(selectedLabel.style?.fontWeight, FontWeight.w600);

      final unselectedLabel = tester.widget<Text>(
        find.text(items[1].label.localizedName),
      );
      expect(unselectedLabel.style?.color, scheme.onSurfaceVariant);
      expect(unselectedLabel.style?.fontWeight, FontWeight.w500);
    });
  });

  group('K4 — hover and focus are distinguishable from selection', () {
    Material pillOf(WidgetTester tester, String label) {
      return tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
    }

    testWidgets('hovering an unselected item adds a wash, not a selection', (
      tester,
    ) async {
      await pumpRail(tester);
      final scheme = Theme.of(
        tester.element(find.byType(AuroraNavigationRail)),
      ).colorScheme;
      final items = desktopItems();
      final target = items[1].label.localizedName;

      expect(pillOf(tester, target).color, Colors.transparent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text(target)));
      await tester.pump();

      final hovered = pillOf(tester, target);
      expect(
        hovered.color,
        isNot(Colors.transparent),
        reason: 'hover must be visible',
      );
      expect(
        hovered.color,
        isNot(
          FluxoraColorSet.selectionTint(
            FluxoraColors.dark.tertiary,
            scheme.brightness,
          ),
        ),
        reason: 'hover must not look like selection',
      );
      // Hover never adds the accent bar.
      expect(find.byKey(const ValueKey('aurora-rail-accent')), findsOneWidget);
    });

    testWidgets('keyboard focus draws a ring, not a filled pill', (
      tester,
    ) async {
      await pumpRail(tester);
      final scheme = Theme.of(
        tester.element(find.byType(AuroraNavigationRail)),
      ).colorScheme;
      final items = desktopItems();
      final target = items[1].label.localizedName;

      // Tab moves into the rail; the first stop is the first unselected item
      // after the current one, which is enough to prove the ring exists.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusedPill = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AuroraNavigationRail),
              matching: find.byType(Material),
            ),
          )
          .where((m) => m.shape is RoundedRectangleBorder)
          .map((m) => m.shape! as RoundedRectangleBorder)
          .where((s) => s.side.width > 0);

      expect(
        focusedPill,
        isNotEmpty,
        reason: 'a focused destination must draw a visible ring',
      );
      expect(focusedPill.first.side.color, scheme.primary);
      // And the ring is not the selected pill's fill.
      expect(pillOf(tester, target).color, Colors.transparent);
    });

    // O5 — the test above proves a ring exists (`side.width > 0`) and that it
    // is not the selected fill, but it does not pin the declared width, does
    // not prove the ring clears when focus leaves, and does not prove the
    // selection survives a sibling taking focus. This closes those three gaps
    // against the value the component actually ships: `BorderSide(width: 2)`
    // in `lib/widgets/aurora_navigation_rail.dart`. It deliberately asserts
    // 2 px rather than the 3 px written in the A3-3 acceptance text — that
    // entry is a TV/visual criterion (ring legibility at ~3 m) which no widget
    // test can speak to, and A3-3 stays NOT_STARTED.
    testWidgets(
      'the focus ring keeps its declared width, clears on blur, and leaves '
      'selection untouched',
      (tester) async {
        await pumpRail(tester);
        final scheme = Theme.of(
          tester.element(find.byType(AuroraNavigationRail)),
        ).colorScheme;
        final items = desktopItems();
        final selectedLabel = items[0].label.localizedName;

        Iterable<RoundedRectangleBorder> ringedShapes() => tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(AuroraNavigationRail),
                matching: find.byType(Material),
              ),
            )
            .where((m) => m.shape is RoundedRectangleBorder)
            .map((m) => m.shape! as RoundedRectangleBorder)
            .where((s) => s.side.width > 0);

        expect(
          ringedShapes(),
          isEmpty,
          reason: 'nothing is ringed before keyboard focus enters the rail',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final ringed = ringedShapes().toList();
        expect(ringed.length, 1, reason: 'exactly one item owns the ring');
        expect(ringed.first.side.color, scheme.primary);
        expect(
          ringed.first.side.width,
          2.0,
          reason: 'the rail declares a 2 px ring, not a 3 px one',
        );

        // A sibling taking focus must not erase the selected item's styling.
        expect(
          pillOf(tester, selectedLabel).color,
          isNot(Colors.transparent),
          reason: 'focus must not replace the selection tint',
        );

        // Drop focus out of the rail entirely.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        expect(
          ringedShapes(),
          isEmpty,
          reason: 'the ring must not outlive the focus that drew it',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ── Keyboard reachability ────────────────────────────────────────────────
  //
  // Phase 02.5 asks whether the rail stays operable without a pointer. The
  // arrow-key shortcuts are covered above; this pins the other half — Tab must
  // walk the destinations in visual order, and the focus ring must be drawn
  // inside the item so nothing clips it.

  group('K4 — keyboard reachability', () {
    testWidgets('Tab visits the destinations in visual order', (tester) async {
      await pumpRail(tester);
      final items = desktopItems();

      final visited = <String>[];
      for (var i = 0; i < items.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // Whichever label currently owns focus.
        for (final item in items) {
          final node = Focus.of(
            tester.element(find.text(item.label.localizedName)),
          );
          if (node.hasFocus && !visited.contains(item.label.name)) {
            visited.add(item.label.name);
          }
        }
      }

      expect(
        visited,
        items.map((e) => e.label.name).toList(),
        reason: 'Tab order must match the rendered order, top to bottom',
      );
    });

    testWidgets('the focus ring is drawn inside the item, never clipped', (
      tester,
    ) async {
      await pumpRail(tester);

      // Focus the second destination so the ring is not on the selected pill.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final items = desktopItems();
      final itemRect = tester.getRect(
        find
            .ancestor(
              of: find.text(items[1].label.localizedName),
              matching: find.byType(Material),
            )
            .first,
      );

      // The ring is a border on that material, so it is inside by construction;
      // assert the box is tall enough for it and that nothing was clipped.
      expect(itemRect.height, greaterThan(8));
      expect(
        tester.takeException(),
        isNull,
        reason: 'a clipped ring would surface as an overflow/assertion',
      );
    });
  });

  group('K4 — label presentation', () {
    testWidgets('the default expanded rail shows labels beside icons', (
      tester,
    ) async {
      await pumpRail(tester);
      expect(railOf(tester).extended, isTrue);
      for (final item in desktopItems()) {
        expect(find.text(item.label.localizedName), findsOneWidget);
      }
    });
  });

  group('K4 — mobile view falls through', () {
    testWidgets('in mobile view the rail is not built at all', (tester) async {
      // `AppSidebarContainer` returns its child unchanged on mobile; the bottom
      // bar takes over. Pinning it stops the rail from leaking onto phones.
      await pumpRail(tester, viewMode: ViewMode.mobile);

      expect(find.byType(AuroraNavigationRail), findsNothing);
    });

    testWidgets('the mobile subset is a strict subset of the desktop one', (
      tester,
    ) async {
      // Mobile drops `connections` and `logs` (desktop-only) and keeps the rest,
      // so switching shells narrows the rail rather than reshuffling it.
      final mobile = desktopItems(width: 600);
      final desktop = desktopItems();

      expect(mobile, isNotEmpty);
      expect(
        mobile.map((e) => e.label).toSet(),
        isNot(equals(desktop.map((e) => e.label).toSet())),
        reason: 'the two modes must not resolve to the same set',
      );
      for (final item in mobile) {
        expect(
          desktop.map((e) => e.label),
          contains(item.label),
          reason: '${item.label} is in the mobile set but not the desktop set',
        );
      }
    });
  });
  // ── K4 — the rail actually navigates ──────────────────────────────────────
  //
  // `onDestinationSelected` reaches the shell through
  // `globalState.appController.toPage(label)`. A widget test has no root
  // navigator, so the recording controller is what makes "this destination maps
  // to that page" observable.

  group('K4 — destination taps', () {
    testWidgets('tapping a destination requests its own page', (tester) async {
      await pumpRail(tester);

      await tester.tap(find.byIcon(Icons.folder_open_outlined)); // profiles
      await tester.pump();

      expect(controller.pages, [PageLabel.profiles]);
    });

    testWidgets('every destination maps to the label it was built from', (
      tester,
    ) async {
      // Walk the rendered rail and check the page requested at each position
      // against the production list — the mapping must never be positional-only.
      // The icons come from the items themselves, so this stays correct when the
      // subset changes.
      final items = desktopItems();

      for (var i = 0; i < items.length; i++) {
        await pumpRail(tester, currentIndex: 0);
        controller.pages.clear();

        final icon = (items[i].icon).icon;
        await tester.tap(find.byIcon(icon!));
        await tester.pump();

        expect(controller.pages, [
          items[i].label,
        ], reason: 'destination $i must request ${items[i].label}');
      }
    });

    testWidgets('re-tapping the current destination still routes to it', (
      tester,
    ) async {
      // Production pops that page back to its root first (a "return to top"
      // gesture), then switches. The request must still be issued.
      await pumpRail(tester, currentIndex: 2);

      await tester.tap(find.byIcon(Icons.folder_open_outlined));
      await tester.pump();

      expect(controller.pages, [PageLabel.profiles]);
    });
  });

  // ── K4 — arrow-key navigation ─────────────────────────────────────────────
  //
  // The rail wraps itself in `CallbackShortcuts` bound to arrowUp / arrowDown,
  // and moves by **one index** from the current page. These are the shortcuts
  // that exist in the implementation; `select` / `enter` are bound to no-ops and
  // are not asserted here.

  group('K4 — arrow keys', () {
    testWidgets('arrowDown moves to the next destination', (tester) async {
      await pumpRail(tester, currentIndex: 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.pages, [PageLabel.proxies]);
    });

    testWidgets('arrowUp moves to the previous destination', (tester) async {
      await pumpRail(tester, currentIndex: 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.pages, [PageLabel.proxies]);
    });

    testWidgets('arrowUp at the first destination does nothing', (
      tester,
    ) async {
      await pumpRail(tester, currentIndex: 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(controller.pages, isEmpty);
    });

    testWidgets('arrowDown at the last destination does nothing', (
      tester,
    ) async {
      final last = desktopItems().length - 1;
      await pumpRail(tester, currentIndex: last);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.pages, isEmpty);
    });
  });
  // ── K4 — the rail must stay discoverable when the window is short ─────────
  //
  // With the six production destinations the rail's content is ~424 px at 1.0x,
  // which fits the 492 px minimum window height (`lib/common/window.dart:20`) —
  // so at default text size nothing scrolls. Large text is the case that still
  // overflows, which is why `ShowBarScrollBehavior` stays: it costs nothing when
  // there is nothing to scroll and is the only affordance when there is.

  group('K4 — short window scroll affordance', () {
    Future<void> pumpRailFrame(
      WidgetTester tester, {
      required Size size,
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      globalState.appState = AppState(
        viewSize: size,
        brightness: Brightness.dark,
        requests: FixedList(10),
        version: 1,
        logs: FixedList(10),
        traffics: FixedList(10),
        totalTraffic: Traffic(),
        systemUiOverlayStyle: const SystemUiOverlayStyle(),
        pageLabel: PageLabel.dashboard,
      );

      final items = desktopItems();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navigationStateProvider.overrideWith(
              (ref) => NavigationState(
                pageLabel: PageLabel.dashboard,
                navigationItems: items,
                viewMode: ViewMode.desktop,
                locale: 'zh_CN',
                currentIndex: 0,
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                globalState.theme = CommonTheme.of(ctx, 1.0);
                globalState.measure = Measure.of(ctx, 1.0);
                return MediaQuery(
                  data: MediaQuery.of(
                    ctx,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: Scaffold(
                    body: AppSidebarContainer(
                      child: CommonScaffold(
                        title: 'rail-frame',
                        body: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    ScrollPosition railScrollPosition(WidgetTester tester) {
      final scrollable = find
          .ancestor(
            of: find.byType(AuroraNavigationRail),
            matching: find.byType(Scrollable),
          )
          .first;
      return tester.state<ScrollableState>(scrollable).position;
    }

    testWidgets('a tall window does not need to scroll the rail', (
      tester,
    ) async {
      await pumpRailFrame(tester, size: const Size(1200, 800));

      expect(railScrollPosition(tester).maxScrollExtent, 0);
    });

    testWidgets('the minimum legal window height at 1.0x still fits', (
      tester,
    ) async {
      // 492 is the floor `lib/common/window.dart` enforces, so this is the
      // shortest window a user can actually have. Six destinations fit.
      await pumpRailFrame(tester, size: const Size(1200, 492));

      expect(railScrollPosition(tester).maxScrollExtent, 0);
    });

    testWidgets('the minimum legal window height at 1.4x now fits', (
      tester,
    ) async {
      // Phase 02 replaced the 64 px Material item with a 52 px Aurora item, so
      // the overflow threshold moved out. Six destinations at 1.4x fit the
      // shortest legal window — which is the better outcome: no destination is
      // hidden at a text scale the OS actually offers.
      await pumpRailFrame(tester, size: const Size(1200, 492), textScale: 1.4);

      expect(
        railScrollPosition(tester).maxScrollExtent,
        0,
        reason: 'the compact rail must fit six destinations at 1.4x',
      );
    });

    testWidgets('a 2.0x text scale still fits the shortest legal window', (
      tester,
    ) async {
      // 2.0 is the largest scale Windows' accessibility settings offer. The
      // compact item keeps all six destinations visible even there — which is
      // the point of the redesign.
      await pumpRailFrame(tester, size: const Size(1200, 492), textScale: 2.0);

      expect(railScrollPosition(tester).maxScrollExtent, 0);
    });

    testWidgets('an extreme text scale still scrolls instead of clipping', (
      tester,
    ) async {
      // Beside-icon labels fit larger scales; stress scrolling at 4x.
      await pumpRailFrame(tester, size: const Size(1200, 492), textScale: 4);

      expect(
        railScrollPosition(tester).maxScrollExtent,
        greaterThan(0),
        reason: 'the rail must scroll rather than clip at extreme scales',
      );
    });

    testWidgets('the scrollbar is wired to the rail, not to some other scroll', (
      tester,
    ) async {
      // The affordance, not just the ability to scroll: without it the clipped
      // destinations are invisible. And it has to track the *rail's* position —
      // `ScrollBehavior.buildScrollbar` can hand over a null controller, which
      // makes `Scrollbar` fall back to `PrimaryScrollController` and show the
      // position of an unrelated scrollable.
      await pumpRailFrame(tester, size: const Size(1200, 492), textScale: 4);

      final bar = tester.widget<Scrollbar>(
        find
            .ancestor(
              of: find.byType(AuroraNavigationRail),
              matching: find.byType(Scrollbar),
            )
            .first,
      );

      expect(bar.controller, isNotNull);
      expect(bar.thumbVisibility, isFalse, reason: 'hover/scroll only');
      expect(
        identical(bar.controller!.position, railScrollPosition(tester)),
        isTrue,
        reason: 'the scrollbar must track the rail, not a parent scrollable',
      );
    });

    testWidgets('nothing scrolls in a tall window, so no thumb appears', (
      tester,
    ) async {
      // The bar is always in the tree; it only paints when there is something to
      // scroll. This is what keeps the change invisible at normal heights.
      await pumpRailFrame(tester, size: const Size(1200, 800));

      final bar = tester.widget<Scrollbar>(
        find
            .ancestor(
              of: find.byType(AuroraNavigationRail),
              matching: find.byType(Scrollbar),
            )
            .first,
      );
      expect(bar.controller!.position.maxScrollExtent, 0);
    });
  });
}
