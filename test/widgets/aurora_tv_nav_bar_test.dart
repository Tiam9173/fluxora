import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/aurora_navigation_rail.dart';
import 'package:fluxora/widgets/aurora_tv_nav_bar.dart';

/// The TV bar's focus contract.
///
/// `globalState.isAndroidTV` can never be true on a Windows test host (it is set
/// inside `GlobalState.init()` behind `if (system.isAndroid)`), so the bar was
/// extracted into `AuroraTvNavBar` precisely so it can be driven here without a
/// production debug setter. The shell keeps ownership of the `FocusNode`s and of
/// the `toPage` mapping; this file owns the visuals and the traversal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FocusNode> nodes;

  const labels = ['dashboard', 'profiles', 'tools'];

  setUp(() {
    nodes = List<FocusNode>.generate(labels.length, (_) => FocusNode());
  });

  tearDown(() {
    for (final node in nodes) {
      node.dispose();
    }
  });

  List<AuroraRailDestination> destinations() => const [
    AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'dashboard'),
    AuroraRailDestination(icon: Icon(Icons.folder), label: 'profiles'),
    AuroraRailDestination(icon: Icon(Icons.construction), label: 'tools'),
  ];

  /// Focus changes land in a microtask, then the `AnimatedBuilder` rebuilds on
  /// the next frame — one `pump` is not enough.
  Future<void> focusOn(WidgetTester tester, int index) async {
    nodes[index].requestFocus();
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    int selectedIndex = 0,
    Brightness brightness = Brightness.dark,
    ValueChanged<int>? onSelect,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF29D6C7),
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AuroraTvNavBar(
              destinations: destinations(),
              selectedIndex: selectedIndex,
              focusNodes: nodes,
              onSelect: onSelect ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AuroraTvNavBar))).colorScheme;

  BoxDecoration itemDecoration(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('selected vs idle', () {
    testWidgets('the current page takes the brand wash and the accent tick', (
      tester,
    ) async {
      await pumpBar(tester);
      final scheme = schemeOf(tester);

      expect(
        itemDecoration(tester, 'dashboard').color,
        FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness),
      );
      expect(
        find.byKey(const ValueKey('aurora-tv-accent')),
        findsOneWidget,
        reason: 'only the current page carries the tick',
      );
    });

    testWidgets('idle destinations stay quiet', (tester) async {
      await pumpBar(tester);

      for (final label in ['profiles', 'tools']) {
        expect(
          itemDecoration(tester, label).color,
          Colors.transparent,
          reason: '$label is neither current nor focused',
        );
      }
    });

    testWidgets('the selected icon is brand, the label is neutral', (
      tester,
    ) async {
      await pumpBar(tester);
      final scheme = schemeOf(tester);

      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.dashboard))).color,
        scheme.primary,
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.folder))).color,
        scheme.onSurfaceVariant,
      );

      final selectedLabel = tester.widget<Text>(find.text('dashboard'));
      expect(selectedLabel.style?.color, scheme.onSurface);
      expect(selectedLabel.style?.fontWeight, FontWeight.w600);

      final idleLabel = tester.widget<Text>(find.text('profiles'));
      expect(idleLabel.style?.color, scheme.onSurfaceVariant);
      expect(idleLabel.style?.fontWeight, FontWeight.w500);
    });
  });

  group('focus is stronger than selection', () {
    testWidgets('a focused item draws the 3 px ring', (tester) async {
      await pumpBar(tester);
      final scheme = schemeOf(tester);

      await focusOn(tester, 1);

      final decoration = itemDecoration(tester, 'profiles');
      final border = decoration.border! as Border;
      expect(border.top.width, AuroraTvNavBar.focusRingWidth);
      expect(border.top.width, 3, reason: '2 px was a hairline at 3 metres');
      expect(border.top.color, scheme.primary);
    });

    testWidgets('focus and selection stay distinguishable', (tester) async {
      // Focus sits on item 1 while item 0 is the current page: the two states
      // must not look the same, and the other idle items must stay flat.
      await pumpBar(tester);
      final scheme = schemeOf(tester);

      await focusOn(tester, 1);

      final focused = itemDecoration(tester, 'profiles');
      expect(
        focused.color,
        scheme.primary.withValues(alpha: 0.10),
        reason: 'focus gets a wash, not the selection tint',
      );
      expect(
        focused.color,
        isNot(FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness)),
      );

      // The current page keeps its tint and does *not* get a ring.
      expect(
        itemDecoration(tester, 'dashboard').color,
        FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness),
      );
      expect(
        (itemDecoration(tester, 'dashboard').border! as Border).top.color,
        Colors.transparent,
      );

      // The third item is neither: flat, no ring.
      expect(itemDecoration(tester, 'tools').color, Colors.transparent);
      expect(
        (itemDecoration(tester, 'tools').border! as Border).top.color,
        Colors.transparent,
      );
    });

    testWidgets('the ring is reserved, so gaining focus never shifts the row', (
      tester,
    ) async {
      await pumpBar(tester);
      final before = tester.getRect(find.text('profiles'));

      await focusOn(tester, 1);

      final after = tester.getRect(find.text('profiles'));
      expect(after, before, reason: 'the 3 px border is always present');
    });
  });

  group('remote traversal', () {
    testWidgets('arrowRight moves focus to the next destination', (
      tester,
    ) async {
      await pumpBar(tester);
      await focusOn(tester, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(nodes[1].hasFocus, isTrue);
    });

    testWidgets('arrowLeft moves focus back', (tester) async {
      await pumpBar(tester);
      await focusOn(tester, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(nodes[1].hasFocus, isTrue);
    });

    testWidgets('the left edge does not wrap', (tester) async {
      await pumpBar(tester);
      await focusOn(tester, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(nodes[0].hasFocus, isTrue, reason: 'no wrap to the last item');
    });

    testWidgets('the right edge does not wrap', (tester) async {
      await pumpBar(tester);
      await focusOn(tester, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(nodes[2].hasFocus, isTrue);
    });

    testWidgets('arrowDown is swallowed by the bar', (tester) async {
      // The bar is the bottom-most stop; letting the event bubble would move
      // focus into the page behind it.
      await pumpBar(tester);
      await focusOn(tester, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(nodes[1].hasFocus, isTrue);
    });
  });

  group('behaviour and layout', () {
    testWidgets('a tap reports the tapped index', (tester) async {
      final taps = <int>[];
      await pumpBar(tester, onSelect: taps.add);

      await tester.tap(find.byIcon(Icons.folder));
      await tester.pump();

      expect(taps, [1]);
    });

    testWidgets('every destination renders at its minimum width', (
      tester,
    ) async {
      await pumpBar(tester);

      for (final label in labels) {
        final rect = tester.getRect(find.text(label));
        expect(rect.width, greaterThan(0));
      }
      // Three items at 120 px minimum must fit a 1920-wide panel without
      // overflowing — the bar is laid out at the test surface width.
      expect(tester.takeException(), isNull);
      expect(
        find.byType(AuroraTvNavBar),
        findsOneWidget,
      );
    });

    testWidgets('light theme keeps the same semantic roles', (tester) async {
      await pumpBar(tester, brightness: Brightness.light);
      final scheme = schemeOf(tester);

      await focusOn(tester, 1);

      expect(
        (itemDecoration(tester, 'profiles').border! as Border).top.color,
        scheme.primary,
      );
      expect(
        itemDecoration(tester, 'dashboard').color,
        FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness),
      );
    });
  });
}
