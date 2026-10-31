import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/popup.dart';
import 'package:fluxora/widgets/side_sheet.dart';

/// Phase 04.4 — dialogs, side sheets, popups and tooltips.
///
/// The audit split these into "Flutter already gets this right" and "the project
/// gets it wrong". Everything asserted here is an observable behaviour of the
/// real widgets: who owns the keyboard, the barrier colour actually painted,
/// which dismiss paths work, and the values the route feeds its transition.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData themeOf(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF29D6C7),
      brightness: brightness,
    ),
  );

  /// A page whose first button opens an overlay and whose second button is a
  /// different focus target, so "focus came back to the trigger" is not
  /// indistinguishable from "focus fell somewhere in the page".
  Widget host({
    required Future<void> Function(BuildContext context) open,
    required FocusNode triggerNode,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
  }) {
    return MaterialApp(
      theme: themeOf(brightness),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    focusNode: triggerNode,
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                  const TextButton(onPressed: null, child: Text('after')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) open,
    required FocusNode triggerNode,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The real source of truth: a `MediaQuery` placed inside `home` does not
    // reach routes pushed on the navigator above it, so the preference has to be
    // set at the platform level for overlay transitions to see it.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      host(
        open: open,
        triggerNode: triggerNode,
        brightness: brightness,
        reduceMotion: reduceMotion,
      ),
    );
    // `globalState.theme` backs the `.ap` text scaling; the overlays themselves
    // read `Theme.of`.
    globalState.theme = CommonTheme.of(
      tester.element(find.byType(Scaffold)),
      1.0,
    );
    await tester.pump();
  }

  /// Whether the keyboard is inside the subtree rooted at [scope].
  ///
  /// `FocusScopeNode.hasFocus` is true when the node *or any descendant* owns
  /// primary focus, which is exactly "the modal has the keyboard".
  bool scopeHasFocus(WidgetTester tester, Finder scope) {
    if (scope.evaluate().isEmpty) return false;
    return FocusScope.of(tester.element(scope)).hasFocus;
  }

  group('dialog', () {
    testWidgets('Escape closes it', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('dlg')),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('dlg'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('dlg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the barrier closes it', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('dlg')),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text('dlg'), findsNothing);
    });

    testWidgets('the modal owns the keyboard, and the trigger gets it back', (
      tester,
    ) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('dlg'),
            actions: [TextButton(onPressed: () {}, child: const Text('ok'))],
          ),
        ),
      );

      trigger.requestFocus();
      await tester.pump();
      expect(trigger.hasFocus, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        scopeHasFocus(tester, find.byType(AlertDialog)),
        isTrue,
        reason: 'the dialog scope owns the keyboard while it is open',
      );
      expect(
        trigger.hasFocus,
        isFalse,
        reason: 'the page behind the barrier is out of reach',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('dlg'), findsNothing);
      expect(
        trigger.hasFocus,
        isTrue,
        reason: 'closing the modal returns the keyboard to the trigger',
      );
    });
  });

  group('side sheet', () {
    testWidgets('the barrier dims the page as much as a dialog does', (
      tester,
    ) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => showModalSideSheet<void>(
          context: context,
          builder: (_) => const SizedBox(width: 320, child: Text('panel')),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('panel'), findsOneWidget);

      final barrier = tester.widget<AnimatedModalBarrier>(
        find.byType(AnimatedModalBarrier),
      );
      expect(
        barrier.color.value,
        const Color(0x8A000000),
        reason: 'same scrim as the framework uses for dialogs and bottom sheets',
      );
    });

    testWidgets('Escape closes it', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => showModalSideSheet<void>(
          context: context,
          builder: (_) => const SizedBox(width: 320, child: Text('panel')),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('panel'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('panel'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: the panel is in place on the first frame', (
      tester,
    ) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        reduceMotion: true,
        open: (context) => showModalSideSheet<void>(
          context: context,
          builder: (_) => const SizedBox(width: 320, child: Text('panel')),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();

      expect(find.text('panel'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('panel')).dx,
        greaterThan(600),
        reason: 'the panel sits at its final position, not part-way across',
      );
    });
  });

  group('popup', () {
    /// The opacity and scale the popup content is currently painted with.
    ({double opacity, double scale}) popupStart(WidgetTester tester) {
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('menu'),
              matching: find.byType(Opacity),
            ),
          )
          .first
          .opacity;
      // `.last` is the outermost `Transform` — the scale. The inner one is a
      // pure translation, whose matrix diagonal is 1.0 and would pass any
      // scale assertion.
      final transform = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('menu'),
              matching: find.byType(Transform),
            ),
          )
          .last;
      return (opacity: opacity, scale: transform.transform.storage[0]);
    }

    Future<void> openPopup(WidgetTester tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        open: (context) => Navigator.of(context).push(
          CommonPopupRoute<void>(
            barrierLabel: 'popup',
            offsetNotifier: ValueNotifier<Offset>(const Offset(200, 200)),
            builder: (_) => const SizedBox(width: 200, child: Text('menu')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('the first frame is transparent, not 10% visible', (
      tester,
    ) async {
      await openPopup(tester);

      expect(find.text('menu'), findsOneWidget);
      expect(
        popupStart(tester).opacity,
        0.0,
        reason: 'an overlay that starts at 10% flashes on open',
      );
    });

    testWidgets('the scale stays inside the 1.1x Aurora limit', (tester) async {
      await openPopup(tester);

      final start = popupStart(tester).scale;
      expect(start, greaterThan(0.9));
      expect(
        start,
        lessThanOrEqualTo(1.0),
        reason: 'a 0.7 -> 1.0 pop is a 1.43x change, forbidden by §10.4',
      );
    });

    testWidgets('it settles at full opacity and scale', (tester) async {
      await openPopup(tester);
      await tester.pumpAndSettle();

      final settled = popupStart(tester);
      expect(settled.opacity, 1.0);
      expect(settled.scale, closeTo(1.0, 1e-6));
    });

    testWidgets('reduced motion: it appears in its final state', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpHost(
        tester,
        triggerNode: trigger,
        reduceMotion: true,
        open: (context) => Navigator.of(context).push(
          CommonPopupRoute<void>(
            barrierLabel: 'popup',
            offsetNotifier: ValueNotifier<Offset>(const Offset(200, 200)),
            builder: (_) => const SizedBox(width: 200, child: Text('menu')),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      final start = popupStart(tester);
      expect(start.opacity, 1.0);
      expect(start.scale, closeTo(1.0, 1e-6));
    });
  });

  group('tooltip', () {
    testWidgets('hover shows it and it does not swallow the tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: themeOf(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: Tooltip(
                message: 'hint',
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('target'),
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('target')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('hint'), findsOneWidget);

      await tester.tap(find.text('target'));
      await tester.pump();
      expect(taps, 1, reason: 'the tooltip must not swallow the tap');
    });
  });
}
