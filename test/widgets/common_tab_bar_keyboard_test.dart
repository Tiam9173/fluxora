import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Phase 04.3 — keyboard support for [CommonTabBar].
///
/// Before this the segmented control had complete screen-reader semantics
/// (`button`, `selected`, `inMutuallyExclusiveGroup`) but **no `Focus` at all**,
/// so a keyboard user could not reach it: the only way in was a pointer. It is
/// used by the dashboard's outbound-mode selector.
///
/// The contract implemented here follows the WAI-ARIA "roving tabindex" pattern:
/// only the selected segment is a Tab stop, arrows move focus inside the group
/// without committing, and Enter/Space activates. Focus is shown with a 2 px
/// border in the theme's `primary` — a shape, not a colour wash, and always
/// present (transparent when unfocused) so gaining focus never shifts layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The 2 px focus ring around [label], or null when the segment is unfocused.
  BoxBorder? ringOf(WidgetTester tester, String label) {
    final boxes = tester.widgetList<DecoratedBox>(
      find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)),
    );
    for (final box in boxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.border != null) {
        return decoration.border;
      }
    }
    return null;
  }

  Color? ringColour(WidgetTester tester, String label) {
    final border = ringOf(tester, label);
    if (border is! Border) return null;
    return border.top.color;
  }

  Widget app({
    required ValueChanged<int?> onChanged,
    int? value,
    Brightness brightness = Brightness.dark,
    Set<int> disabled = const <int>{},
  }) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF29D6C7),
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 320,
                child: CommonTabBar<int>(
                  groupValue: value,
                  onValueChanged: onChanged,
                  thumbColor: const Color(0xFF29D6C7),
                  disabledChildren: disabled,
                  children: const {
                    0: Text('one'),
                    1: Text('two'),
                    2: Text('three'),
                  },
                ),
              ),
              // A second focusable so "Tab leaves the bar" has somewhere to go.
              TextButton(onPressed: () {}, child: const Text('after')),
            ],
          ),
        ),
      ),
    );
  }

  group('focus entry', () {
    testWidgets('Tab reaches the selected segment', (tester) async {
      await tester.pumpWidget(app(value: 1, onChanged: (_) {}));
      await tester.pump();

      expect(ringColour(tester, 'two'), const Color(0x00000000));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        ringColour(tester, 'two'),
        Theme.of(tester.element(find.text('two'))).colorScheme.primary,
        reason: 'Tab stops on the selected segment and draws the ring',
      );
    });

    testWidgets('Tab does not stop on unselected segments', (tester) async {
      // Roving tabindex: one stop for the whole control, not three.
      await tester.pumpWidget(app(value: 1, onChanged: (_) {}));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        ringColour(tester, 'two'),
        const Color(0x00000000),
        reason: 'the second Tab left the control entirely',
      );
    });
  });

  group('arrow keys', () {
    testWidgets('ArrowRight moves focus without selecting', (tester) async {
      final changes = <int?>[];
      await tester.pumpWidget(app(value: 0, onChanged: changes.add));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.text('two'))).colorScheme;
      expect(
        ringColour(tester, 'two'),
        scheme.primary,
        reason: 'focus moved to the next segment',
      );
      expect(
        ringColour(tester, 'one'),
        const Color(0x00000000),
        reason: 'and left the previous one',
      );
      expect(changes, isEmpty, reason: 'arrows look, they do not commit');
    });

    testWidgets('ArrowLeft moves focus back', (tester) async {
      await tester.pumpWidget(app(value: 1, onChanged: (_) {}));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.text('one'))).colorScheme;
      expect(ringColour(tester, 'one'), scheme.primary);
    });

    testWidgets('arrows skip disabled segments', (tester) async {
      await tester.pumpWidget(
        app(value: 0, onChanged: (_) {}, disabled: const {1}),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.text('three'))).colorScheme;
      expect(
        ringColour(tester, 'three'),
        scheme.primary,
        reason: 'the disabled middle segment is not a focus target',
      );
    });
  });

  group('activation', () {
    testWidgets('Enter activates the focused segment exactly once', (
      tester,
    ) async {
      final changes = <int?>[];
      await tester.pumpWidget(app(value: 0, onChanged: changes.add));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(changes, [1], reason: 'one activation, one callback');
    });

    testWidgets('Space activates the focused segment', (tester) async {
      final changes = <int?>[];
      await tester.pumpWidget(app(value: 0, onChanged: changes.add));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(changes, [1]);
    });

    testWidgets('a disabled segment cannot be activated by keyboard', (
      tester,
    ) async {
      final changes = <int?>[];
      await tester.pumpWidget(
        app(value: 0, onChanged: changes.add, disabled: const {1}),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Arrow skips 1, so focus sits on 2; Enter must activate 2, not 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(changes, [2]);
    });
  });

  group('focus is not selection', () {
    testWidgets('the ring moves while groupValue stays put', (tester) async {
      await tester.pumpWidget(app(value: 0, onChanged: (_) {}));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.text('two'))).colorScheme;
      expect(ringColour(tester, 'two'), scheme.primary);
      expect(
        ringColour(tester, 'one'),
        const Color(0x00000000),
        reason: 'the selected segment lost focus, so its ring is gone',
      );
    });

    testWidgets('the ring is a border, not a fill', (tester) async {
      await tester.pumpWidget(app(value: 1, onChanged: (_) {}));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final border = ringOf(tester, 'two');
      expect(border, isA<Border>());
      expect(
        (border! as Border).top.width,
        2.0,
        reason: 'a visible stroke — focus is a shape, not just a colour',
      );
    });

    // One test per theme: focus survives a `pumpWidget` that only changes the
    // theme, so looping inside a single test would carry the focus state over.
    for (final brightness in Brightness.values) {
      testWidgets('the ring uses the theme primary ($brightness)', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(value: 0, onChanged: (_) {}, brightness: brightness),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final scheme = Theme.of(tester.element(find.text('one'))).colorScheme;
        expect(
          ringColour(tester, 'one'),
          scheme.primary,
          reason: 'semantic token, not a hardcoded colour',
        );
        expect(
          ringColour(tester, 'one'),
          isNot(const Color(0xFF29D6C7)),
          reason: 'the thumb seed colour is not reused for focus',
        );
      });
    }
  });

  group('pointer paths are untouched', () {
    testWidgets('a tap still selects and fires once', (tester) async {
      final changes = <int?>[];
      await tester.pumpWidget(app(value: 0, onChanged: changes.add));
      await tester.pump();

      await tester.tap(find.text('two'));
      await tester.pump();

      expect(changes, [1]);
    });

    testWidgets('a tap does not need focus first', (tester) async {
      final changes = <int?>[];
      await tester.pumpWidget(app(value: 0, onChanged: changes.add));
      await tester.pump();

      await tester.tap(find.text('three'));
      await tester.pump();
      expect(changes, [2]);
    });
  });

  group('segment lifecycle', () {
    testWidgets('replacing the segments keeps keyboard support', (tester) async {
      // The focus nodes are owned by the bar, so a new set of segments retires
      // the old ones. Disposing them while the outgoing `Focus` widgets are
      // still mounted would throw on detach; this pins the ordering.
      Widget bar(Map<int, Widget> children) => MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF29D6C7),
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: CommonTabBar<int>(
                groupValue: children.keys.first,
                onValueChanged: (_) {},
                thumbColor: const Color(0xFF29D6C7),
                children: children,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(bar(const {0: Text('one'), 1: Text('two')}));
      await tester.pump();
      // Focus first: retiring a node that currently has focus is the risky
      // path, not the idle one.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.pumpWidget(bar(const {2: Text('three'), 3: Text('four')}));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('one'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        ringColour(tester, 'three'),
        Theme.of(tester.element(find.text('three'))).colorScheme.primary,
        reason: 'the new segments are reachable by keyboard too',
      );
    });
  });

  group('reduced motion', () {
    testWidgets('the ring appears with no animation', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(app(value: 0, onChanged: (_) {}));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.text('one'))).colorScheme;
      expect(
        ringColour(tester, 'one'),
        scheme.primary,
        reason: 'the ring is a static border — nothing to shorten',
      );
    });
  });
}
