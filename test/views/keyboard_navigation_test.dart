import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/aurora_navigation_rail.dart';
import 'package:fluxora/widgets/aurora_tv_nav_bar.dart';

/// P8-2A — keyboard and TV focus navigation.
///
/// ## What this file does *not* re-test
///
/// Three component tests already pin most of the traversal contract, and this
/// file deliberately does not repeat them:
///
/// * `test/widgets/navigation_rail_contract_test.dart` — forward `Tab` order,
///   `arrowDown` / `arrowUp` and both edges.
/// * `test/widgets/aurora_tv_nav_bar_test.dart` — `arrowRight` / `arrowLeft`,
///   both edges, and `arrowDown` being swallowed.
/// * `test/widgets/aurora_bottom_nav_bar_test.dart` — the dock's focus ring.
///
/// What was **not** covered anywhere, and is added here:
///
/// 1. reverse traversal (`shift`+`Tab`) — only forward `Tab` was asserted;
/// 2. keyboard **activation** (`enter` / `space`) — every existing activation
///    test used `tester.tap`, i.e. the pointer path, never the key path;
/// 3. `Tab` order across `AuroraTvNavBar`'s `FocusTraversalOrder`;
/// 4. `arrowUp` on the TV bar (only `arrowDown` was pinned);
/// 5. key-state hygiene — no modifier left pressed after a reverse traversal.
///
/// Every assertion below reads **real focus state** (`FocusNode.hasFocus` or
/// `Focus.of(context).hasFocus`), never "the key event did not throw".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const railLabels = <String>['dashboard', 'proxies', 'profiles'];

  List<AuroraRailDestination> railDestinations() => const [
    AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'dashboard'),
    AuroraRailDestination(icon: Icon(Icons.swap_horiz), label: 'proxies'),
    AuroraRailDestination(icon: Icon(Icons.folder), label: 'profiles'),
  ];

  ThemeData themeOf(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF29D6C7),
      brightness: brightness,
    ),
  );

  // ── rail harness ──────────────────────────────────────────────────────────

  /// The rail item that currently owns focus, by label; `null` when none does.
  ///
  /// `InkWell` builds its own `Focus` inside itself, so `Focus.of` on the label
  /// resolves to *that* node — the same technique the existing rail contract
  /// test uses.
  String? focusedRailLabel(WidgetTester tester) {
    for (final label in railLabels) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) continue;
      if (Focus.of(tester.element(finder)).hasFocus) return label;
    }
    return null;
  }

  Future<void> pumpRail(
    WidgetTester tester, {
    ValueChanged<int>? onSelected,
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeOf(brightness),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuroraNavigationRail(
                destinations: railDestinations(),
                selectedIndex: 0,
                onDestinationSelected: onSelected ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pressTab(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
  }

  /// `shift`+`Tab`, released in the same order a real keyboard does.
  Future<void> pressShiftTab(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  // ── TV harness ────────────────────────────────────────────────────────────

  late List<FocusNode> tvNodes;

  /// Lives outside the bar. It exists so a test can establish "keyboard focus
  /// starts outside the bar" for real, instead of assuming that whatever the
  /// first `Tab` hits is the bar.
  late FocusNode outsideNode;

  List<AuroraRailDestination> tvDestinations() => const [
    AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'dashboard'),
    AuroraRailDestination(icon: Icon(Icons.folder), label: 'profiles'),
    AuroraRailDestination(icon: Icon(Icons.construction), label: 'tools'),
  ];

  setUp(() {
    tvNodes = List<FocusNode>.generate(tvDestinations().length, (_) {
      return FocusNode();
    });
    outsideNode = FocusNode(debugLabel: 'outside-the-bar');
    addTearDown(() {
      for (final node in tvNodes) {
        node.dispose();
      }
      outsideNode.dispose();
    });
  });

  Future<void> pumpTvBar(
    WidgetTester tester, {
    int selectedIndex = 0,
    ValueChanged<int>? onSelect,
    bool withOutsideFocus = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeOf(Brightness.dark),
        home: Scaffold(
          body: Column(
            children: [
              // A real, focusable widget outside the bar — the only honest way
              // to say "the keyboard comes in from outside".
              if (withOutsideFocus)
                TextButton(
                  focusNode: outsideNode,
                  onPressed: () {},
                  child: const Text('outside'),
                ),
              const Spacer(),
              AuroraTvNavBar(
                destinations: tvDestinations(),
                selectedIndex: selectedIndex,
                focusNodes: tvNodes,
                onSelect: onSelect ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Focus changes land in a microtask, then `AnimatedBuilder` rebuilds on the
  /// next frame — one `pump` is not enough.
  Future<void> focusTvItem(WidgetTester tester, int index) async {
    tvNodes[index].requestFocus();
    await tester.pump();
    await tester.pump();
  }

  int? focusedTvIndex() {
    final index = tvNodes.indexWhere((node) => node.hasFocus);
    return index < 0 ? null : index;
  }

  // ── T2 — reverse traversal ────────────────────────────────────────────────

  group('reverse traversal', () {
    testWidgets('shift+Tab walks the rail back one destination', (tester) async {
      await pumpRail(tester);

      await pressTab(tester, times: 3);
      expect(
        focusedRailLabel(tester),
        'profiles',
        reason: 'precondition: forward Tab reaches the last destination',
      );

      await pressShiftTab(tester);

      expect(
        focusedRailLabel(tester),
        'proxies',
        reason: 'shift+Tab must undo exactly one forward step',
      );
    });

    testWidgets('shift+Tab leaves no modifier pressed behind', (tester) async {
      await pumpRail(tester);
      await pressTab(tester, times: 2);

      await pressShiftTab(tester);

      expect(
        HardwareKeyboard.instance.logicalKeysPressed,
        isEmpty,
        reason: 'the shift key must be released, not left down for the next test',
      );
    });

    testWidgets('shift+Tab walks the TV bar back one destination', (
      tester,
    ) async {
      await pumpTvBar(tester);
      await focusTvItem(tester, 2);

      await pressShiftTab(tester);

      expect(
        focusedTvIndex(),
        1,
        reason: 'reverse traversal must move focus, not just consume the key',
      );
    });
  });

  // ── T3 — keyboard activation ──────────────────────────────────────────────

  group('keyboard activation', () {
    testWidgets('enter activates the focused rail destination', (tester) async {
      final reported = <int>[];
      await pumpRail(tester, onSelected: reported.add);

      await pressTab(tester, times: 2);
      expect(focusedRailLabel(tester), 'proxies');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        reported,
        [1],
        reason: 'enter must reach the focused item, not just the page',
      );
    });

    testWidgets('space activates the focused rail destination', (tester) async {
      final reported = <int>[];
      await pumpRail(tester, onSelected: reported.add);

      await pressTab(tester, times: 3);
      expect(focusedRailLabel(tester), 'profiles');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(
        reported,
        [2],
        reason: 'space is the other standard activation key for a button',
      );
    });

    testWidgets('enter activates the focused TV destination', (tester) async {
      final reported = <int>[];
      await pumpTvBar(tester, onSelect: reported.add);
      await focusTvItem(tester, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        reported,
        [1],
        reason: 'the remote select button arrives as enter on the TV bar',
      );
    });
  });

  // ── T1 / T4 — TV traversal order and the unhandled direction ──────────────

  group('TV bar traversal', () {
    testWidgets('the first Tab enters destination 0, then walks in order', (
      tester,
    ) async {
      await pumpTvBar(tester, withOutsideFocus: true);

      // Precondition, asserted rather than assumed: focus starts on a real
      // widget *outside* the bar, and nothing inside it owns focus yet.
      outsideNode.requestFocus();
      await tester.pump();
      expect(
        focusedTvIndex(),
        isNull,
        reason: 'precondition: the keyboard starts outside the bar',
      );

      // F-1 — the bar's own `Focus` (the arrow-key handler) used to be the
      // first stop, so the first Tab landed on a node that paints nothing.
      // It must go straight to the first destination.
      await pressTab(tester);
      expect(
        focusedTvIndex(),
        0,
        reason: 'the first Tab must enter the first destination, '
            'not an invisible stop on the bar itself',
      );

      await pressTab(tester);
      expect(
        focusedTvIndex(),
        1,
        reason: 'FocusTraversalOrder follows the destination index',
      );

      await pressTab(tester);
      expect(
        focusedTvIndex(),
        2,
        reason: 'FocusTraversalOrder follows the destination index',
      );
    });

    testWidgets('arrowUp is not handled, so focus stays put', (tester) async {
      await pumpTvBar(tester);
      await focusTvItem(tester, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        focusedTvIndex(),
        1,
        reason: 'the bar only implements left/right; up must not move focus',
      );
    });
  });
}
