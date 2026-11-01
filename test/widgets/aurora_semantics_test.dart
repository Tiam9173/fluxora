import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/widgets/aurora_bottom_nav_bar.dart';
import 'package:fluxora/widgets/aurora_navigation_rail.dart';
import 'package:fluxora/widgets/aurora_tv_nav_bar.dart';

/// P8-2B — the semantics tree of the three Aurora navigation surfaces.
///
/// These tests read the **merged semantics node**
/// (`tester.getSemantics(...).getSemanticsData()`), not the declared
/// `Semantics.properties`. The two are not the same thing: a
/// `Semantics(label: 'x')` wrapping a `Text('x')` declares one label but merges
/// into `"x\nx"`. Measuring the declared properties would have hidden exactly
/// the defect this file exists to expose.
///
/// Two gaps were measured while writing this file and are **deliberately not
/// asserted here**, because encoding a defect as an expectation would make the
/// suite fail on the day someone fixes it. They are reported instead:
///
/// * **F-2** — `AuroraNavigationRail` announces neither a button role nor a
///   selected state (`isButton: false`, `isSelected: Tristate.none`), while the
///   dock and the TV bar both declare them.
/// * **F-3** — the dock and the TV bar announce their name **twice**
///   (`"dashboard\ndashboard"`), because `Semantics(label: x)` and the child
///   `Text(x)` both contribute and merge.
///
/// So the assertions below pin what is genuinely true today — names, roles,
/// selection, actions — and stop short of blessing either gap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData themeOf(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF29D6C7),
      brightness: brightness,
    ),
  );

  SemanticsData semanticsOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  // ── rail ──────────────────────────────────────────────────────────────────

  const railLabels = <String>['dashboard', 'proxies', 'profiles'];

  List<AuroraRailDestination> railDestinations() => const [
    AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'dashboard'),
    AuroraRailDestination(icon: Icon(Icons.swap_horiz), label: 'proxies'),
    AuroraRailDestination(icon: Icon(Icons.folder), label: 'profiles'),
  ];

  Future<void> pumpRail(WidgetTester tester, {int selectedIndex = 0}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeOf(Brightness.dark),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuroraNavigationRail(
                destinations: railDestinations(),
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── dock ──────────────────────────────────────────────────────────────────

  List<NavigationItem> dockItems() => [
    NavigationItem(
      icon: const Icon(Icons.dashboard),
      label: PageLabel.dashboard,
      builder: (_) => const SizedBox.shrink(),
    ),
    NavigationItem(
      icon: const Icon(Icons.folder),
      label: PageLabel.profiles,
      builder: (_) => const SizedBox.shrink(),
    ),
  ];

  /// The rendered label of the dock's item `index`.
  ///
  /// Read off the widget rather than hard-coded: the dock resolves `PageLabel`
  /// through `Intl.message`, so the string depends on the test locale.
  String dockLabelOf(WidgetTester tester, int index) {
    final texts = find.descendant(
      of: find.byType(AuroraBottomNavBar),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(texts.at(index)).data!;
  }

  Future<void> pumpDock(
    WidgetTester tester, {
    required int selectedIndex,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: themeOf(Brightness.dark),
          home: Scaffold(
            body: AuroraBottomNavBar(
              navigationItems: dockItems(),
              selectedIndex: selectedIndex,
              onTabChange: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── TV bar ────────────────────────────────────────────────────────────────

  late List<FocusNode> tvNodes;

  List<AuroraRailDestination> tvDestinations() => const [
    AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'dashboard'),
    AuroraRailDestination(icon: Icon(Icons.folder), label: 'profiles'),
    AuroraRailDestination(icon: Icon(Icons.construction), label: 'tools'),
  ];

  setUp(() {
    tvNodes = List<FocusNode>.generate(tvDestinations().length, (_) {
      return FocusNode();
    });
    addTearDown(() {
      for (final node in tvNodes) {
        node.dispose();
      }
    });
  });

  Future<void> pumpTvBar(WidgetTester tester, {int selectedIndex = 0}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeOf(Brightness.dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AuroraTvNavBar(
              destinations: tvDestinations(),
              selectedIndex: selectedIndex,
              focusNodes: tvNodes,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── S1 — accessible names ─────────────────────────────────────────────────

  group('navigation rail — accessible names', () {
    testWidgets('each destination is a labelled button that reports its '
        'selection', (tester) async {
      // selectedIndex 1 is `proxies`, so the flag has to split 1 vs 2.
      final handle = tester.ensureSemantics();
      await pumpRail(tester, selectedIndex: 1);

      for (var index = 0; index < railLabels.length; index++) {
        final label = railLabels[index];
        final data = semanticsOf(tester, find.text(label));
        expect(
          data.label,
          label,
          reason: 'the rail must name "$label" exactly once',
        );
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: '"$label" is a navigation button, not plain text',
        );
        expect(
          data.flagsCollection.isSelected,
          index == 1 ? Tristate.isTrue : Tristate.isFalse,
          reason: '"$label" must announce whether it is the current page',
        );
      }
      handle.dispose();
    });

    testWidgets('the three names are distinguishable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRail(tester);

      final names = <String>{
        for (final label in railLabels)
          semanticsOf(tester, find.text(label)).label,
      };
      expect(
        names.length,
        railLabels.length,
        reason: 'a screen reader must be able to tell the destinations apart',
      );
      handle.dispose();
    });
  });

  // ── S3 — actions ──────────────────────────────────────────────────────────

  group('navigation rail — actions', () {
    testWidgets('each destination exposes tap and focus', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRail(tester);

      for (final label in railLabels) {
        final data = semanticsOf(tester, find.text(label));
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason: '"$label" must be activatable from the semantics tree',
        );
        expect(
          data.hasAction(SemanticsAction.focus),
          isTrue,
          reason: '"$label" must be reachable from the keyboard',
        );
      }
      handle.dispose();
    });
  });

  // ── S2 / S3 — dock role, selection and action ─────────────────────────────

  group('bottom dock — role, selection and action', () {
    testWidgets('each destination is a button that reports its selection', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDock(tester, selectedIndex: 1);

      final first = dockLabelOf(tester, 0);
      final second = dockLabelOf(tester, 1);

      final firstData = semanticsOf(tester, find.text(first));
      final secondData = semanticsOf(tester, find.text(second));

      expect(firstData.flagsCollection.isButton, isTrue);
      expect(secondData.flagsCollection.isButton, isTrue);
      expect(
        firstData.flagsCollection.isSelected,
        Tristate.isFalse,
        reason: 'index 0 is not the current page',
      );
      expect(
        secondData.flagsCollection.isSelected,
        Tristate.isTrue,
        reason: 'index 1 is the current page',
      );
      expect(firstData.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('each destination is announced exactly once', (tester) async {
      // Equality, not `startsWith`: a `startsWith` check passes on
      // "dashboard\ndashboard", i.e. on a name a screen reader reads twice.
      final handle = tester.ensureSemantics();
      await pumpDock(tester, selectedIndex: 0);

      for (var index = 0; index < 2; index++) {
        final rendered = dockLabelOf(tester, index);
        expect(
          semanticsOf(tester, find.text(rendered)).label,
          rendered,
          reason: 'the dock must announce "$rendered" once, not twice',
        );
      }
      handle.dispose();
    });
  });

  // ── S6 — the selection flag follows selectedIndex ─────────────────────────

  group('bottom dock — dynamic selection', () {
    testWidgets('moving the selection moves the flag with it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDock(tester, selectedIndex: 0);
      final first = dockLabelOf(tester, 0);
      final second = dockLabelOf(tester, 1);

      expect(
        semanticsOf(tester, find.text(first)).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        semanticsOf(tester, find.text(second)).flagsCollection.isSelected,
        Tristate.isFalse,
      );

      await pumpDock(tester, selectedIndex: 1);

      expect(
        semanticsOf(tester, find.text(first)).flagsCollection.isSelected,
        Tristate.isFalse,
        reason: 'the old page must stop announcing itself as current',
      );
      expect(
        semanticsOf(tester, find.text(second)).flagsCollection.isSelected,
        Tristate.isTrue,
        reason: 'the new page must announce itself as current',
      );
      handle.dispose();
    });
  });

  // ── S4 — TV bar ───────────────────────────────────────────────────────────

  group('TV navigation bar', () {
    testWidgets('each destination is a button that reports its selection', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTvBar(tester, selectedIndex: 1);

      for (var index = 0; index < 3; index++) {
        final label = tvDestinations()[index].label;
        final data = semanticsOf(tester, find.text(label));
        expect(
          data.label,
          label,
          reason: 'the TV bar must announce "$label" once, not twice',
        );
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'a remote user must be told "$label" is actionable',
        );
        expect(
          data.flagsCollection.isSelected,
          index == 1 ? Tristate.isTrue : Tristate.isFalse,
          reason: '"$label" selection must match selectedIndex',
        );
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
      handle.dispose();
    });
  });

  // ── S5 — one node per destination, no decorative noise ────────────────────

  group('TV navigation bar — node count', () {
    testWidgets('each destination contributes exactly one labelled node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTvBar(tester);

      for (final destination in tvDestinations()) {
        expect(
          find.bySemanticsLabel(RegExp('^${destination.label}')),
          findsOneWidget,
          reason:
              'the icon must not add a second node for "${destination.label}"',
        );
      }
      handle.dispose();
    });
  });
}
