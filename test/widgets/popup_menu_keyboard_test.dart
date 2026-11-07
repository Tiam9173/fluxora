import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/widgets/popup.dart';

/// Phase 05.4 — `CommonPopupMenu` as a keyboard surface.
///
/// Before this round the menu was a `Column` of `InkWell`s: a pointer could use
/// it and a screen reader could read the text, but there was no `Focus` at all,
/// so a keyboard user could not reach, move through, or activate a row.
///
/// Everything here drives the real widget and asserts observable state — the
/// focus ring actually painted on a row, the callbacks that fired, the route
/// that popped — not internal fields.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PopupMenuItemData> menu({Set<int> disabled = const {}}) => [
    PopupMenuItemData(
      icon: Icons.copy,
      label: 'a',
      onPressed: disabled.contains(0) ? null : () {},
    ),
    PopupMenuItemData(
      label: 'b',
      onPressed: disabled.contains(1) ? null : () {},
    ),
    PopupMenuItemData(
      label: 'c',
      onPressed: disabled.contains(2) ? null : () {},
    ),
  ];

  /// The 2 px focus ring around [label], or null when the row is unfocused.
  Color? ringOf(WidgetTester tester, String label) {
    final boxes = tester.widgetList<DecoratedBox>(
      find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)),
    );
    for (final box in boxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.border != null) {
        return (decoration.border! as Border).top.color;
      }
    }
    return null;
  }

  Color primaryOf(WidgetTester tester, String label) =>
      Theme.of(tester.element(find.text(label))).colorScheme.primary;

  const transparent = Color(0x00000000);

  Future<FocusNode> openMenu(
    WidgetTester tester, {
    List<PopupMenuItemData>? items,
    bool reduceMotion = false,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final trigger = FocusNode();
    addTearDown(trigger.dispose);
    final offset = ValueNotifier<Offset>(const Offset(400, 200));
    addTearDown(offset.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                focusNode: trigger,
                onPressed: () => Navigator.of(ctx).push(
                  CommonPopupRoute<void>(
                    barrierLabel: 'menu',
                    offsetNotifier: offset,
                    builder: (_) => CommonPopupMenu(items: items ?? menu()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    trigger.requestFocus();
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return trigger;
  }

  group('focus entry and movement', () {
    testWidgets(
      'a short window scrolls the menu and keeps keyboard focus visible',
      (tester) async {
        tester.view.physicalSize = const Size(400, 240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await openMenu(
          tester,
          items: List.generate(
            12,
            (i) => PopupMenuItemData(label: 'row$i', onPressed: () {}),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(ringOf(tester, 'row11'), primaryOf(tester, 'row11'));
        expect(
          tester.getRect(find.text('row11')).bottom,
          lessThanOrEqualTo(240),
        );
      },
    );

    testWidgets('touch opening hides the ring and keyboard input reveals it', (
      tester,
    ) async {
      await openMenu(tester);

      expect(find.text('a'), findsOneWidget);
      expect(ringOf(tester, 'a'), transparent);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(ringOf(tester, 'a'), primaryOf(tester, 'a'));
      expect(ringOf(tester, 'b'), transparent);
    });

    testWidgets('ArrowDown moves to the next row', (tester) async {
      await openMenu(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(ringOf(tester, 'b'), primaryOf(tester, 'b'));
      expect(ringOf(tester, 'a'), transparent);
    });

    testWidgets('ArrowUp moves back', (tester) async {
      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(ringOf(tester, 'a'), primaryOf(tester, 'a'));
    });

    testWidgets('the list wraps at both ends', (tester) async {
      await openMenu(tester);

      // Down past the last row lands on the first.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(ringOf(tester, 'a'), primaryOf(tester, 'a'));

      // And up from the first lands on the last.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ringOf(tester, 'c'), primaryOf(tester, 'c'));
    });

    testWidgets('disabled rows are skipped', (tester) async {
      await openMenu(tester, items: menu(disabled: {1}));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        ringOf(tester, 'b'),
        transparent,
        reason: 'a disabled row cannot take focus',
      );
      expect(ringOf(tester, 'c'), primaryOf(tester, 'c'));
    });

    testWidgets('rapid arrows stay in step with the ring', (tester) async {
      await openMenu(tester);

      // Five downs from 'a' → b, c, a, b, c.
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }

      expect(ringOf(tester, 'c'), primaryOf(tester, 'c'));
      expect(ringOf(tester, 'a'), transparent);
      expect(ringOf(tester, 'b'), transparent);
    });
  });

  group('activation', () {
    testWidgets('Enter runs the focused row and closes the menu', (
      tester,
    ) async {
      var fired = <String>[];
      await openMenu(
        tester,
        items: [
          PopupMenuItemData(label: 'a', onPressed: () => fired.add('a')),
          PopupMenuItemData(label: 'b', onPressed: () => fired.add('b')),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(fired, ['b']);
      expect(find.text('b'), findsNothing, reason: 'the route popped');
    });

    testWidgets('Space runs the focused row too', (tester) async {
      var fired = <String>[];
      await openMenu(
        tester,
        items: [PopupMenuItemData(label: 'a', onPressed: () => fired.add('a'))],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(fired, ['a']);
    });
  });

  group('dismissal', () {
    testWidgets('Escape closes the menu and returns focus to the trigger', (
      tester,
    ) async {
      final trigger = await openMenu(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('a'), findsNothing);
      expect(
        trigger.hasFocus,
        isTrue,
        reason: 'the keyboard goes back where it came from',
      );
    });
  });

  group('degenerate menus', () {
    testWidgets('an empty menu renders and does not throw', (tester) async {
      await openMenu(tester, items: const []);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an all-disabled menu takes no focus and activates nothing', (
      tester,
    ) async {
      await openMenu(tester, items: menu(disabled: {0, 1, 2}));

      expect(tester.takeException(), isNull);
      expect(ringOf(tester, 'a'), transparent);
      expect(ringOf(tester, 'b'), transparent);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget, reason: 'still open, nothing ran');
    });
  });

  group('semantics', () {
    testWidgets('each row is a named button with a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await openMenu(tester);

      final data = tester.getSemantics(find.text('a')).getSemanticsData();
      expect(data.label, 'a', reason: 'the name comes from the title');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('a disabled row exposes no tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await openMenu(tester, items: menu(disabled: {1}));

      final enabled = tester.getSemantics(find.text('a')).getSemanticsData();
      final disabled = tester.getSemantics(find.text('b')).getSemanticsData();

      expect(enabled.hasAction(SemanticsAction.tap), isTrue);
      expect(
        disabled.hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'a row with no onPressed cannot be activated',
      );

      handle.dispose();
    });

    testWidgets('the icon does not repeat the row label', (tester) async {
      final handle = tester.ensureSemantics();
      await openMenu(tester);

      // 'a' is the row with an icon. A duplicated label would read "a a".
      expect(tester.getSemantics(find.text('a')).label, 'a');

      handle.dispose();
    });
  });

  group('pointer paths are untouched', () {
    testWidgets('a tap still activates the row', (tester) async {
      var fired = <String>[];
      await openMenu(
        tester,
        items: [
          PopupMenuItemData(label: 'a', onPressed: () => fired.add('a')),
          PopupMenuItemData(label: 'b', onPressed: () => fired.add('b')),
        ],
      );

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();

      expect(fired, ['b']);
    });

    testWidgets('a disabled row does not fire on tap', (tester) async {
      var fired = <String>[];
      await openMenu(
        tester,
        items: [
          PopupMenuItemData(label: 'a', onPressed: () => fired.add('a')),
          const PopupMenuItemData(label: 'b', onPressed: null),
        ],
      );

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
      expect(find.text('b'), findsOneWidget, reason: 'the menu stayed open');
    });

    testWidgets('reduced motion still opens in its final state', (
      tester,
    ) async {
      await openMenu(tester, reduceMotion: true);

      expect(find.text('a'), findsOneWidget);
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: find.text('a'), matching: find.byType(Opacity)),
          )
          .first
          .opacity;
      expect(opacity, 1.0, reason: 'no fade under reduced motion');
    });
  });
}
