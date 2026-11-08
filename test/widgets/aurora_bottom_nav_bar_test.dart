import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/aurora_bottom_nav_bar.dart';

/// The floating dock's visual contract.
///
/// Three things are pinned here:
///
/// 1. **Elevation** (F6): the bar takes its shadow from the ladder rather than
///    hand-rolling blur values — the old implementation stacked blur 30 + 10.
/// 2. **The Aurora language**: selected = tint + accent tick, hovered = wash
///    only, focused = ring only. Three states that must not collapse into one.
/// 3. **Behaviour**: labels are always visible, and a tap reports the tapped
///    index (the shell maps it to `toPage`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
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

  /// The rendered label, resolved exactly the way the bar resolves it.
  String labelOf(PageLabel label) => Intl.message(label.name);

  List<NavigationItem> items() => [
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

  Future<void> pumpNavBar(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    int selectedIndex = 0,
    ValueChanged<int>? onTabChange,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF29D6C7),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: AuroraBottomNavBar(
              navigationItems: items(),
              selectedIndex: selectedIndex,
              onTabChange: onTabChange ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The floating panel — the only decorated box in the bar that has a shadow.
  BoxDecoration panelDecoration(WidgetTester tester) {
    final boxes = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(AuroraBottomNavBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    for (final box in boxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.boxShadow != null) {
        return decoration;
      }
    }
    fail('no DecoratedBox in the dock carries a boxShadow');
  }

  Material pillOf(WidgetTester tester, String label) => tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AuroraBottomNavBar))).colorScheme;

  group('elevation ladder (F6)', () {
    testWidgets('light theme takes the menu rung of the light ladder', (
      tester,
    ) async {
      await pumpNavBar(tester, brightness: Brightness.light);
      expect(panelDecoration(tester).boxShadow, FluxoraElevation.light.menu);
    });

    testWidgets('dark theme takes the menu rung of the dark ladder', (
      tester,
    ) async {
      await pumpNavBar(tester);
      expect(panelDecoration(tester).boxShadow, FluxoraElevation.dark.menu);
    });

    testWidgets('the shadow is not hand-rolled', (tester) async {
      await pumpNavBar(tester, brightness: Brightness.light);
      final shadows = panelDecoration(tester).boxShadow!;
      expect(shadows.length, FluxoraElevation.light.menu.length);
      expect(shadows.map((s) => s.blurRadius), isNot(contains(30.0)));
    });
  });

  group('Aurora surface', () {
    testWidgets('the panel sits on surfaceContainer with capsule corners', (
      tester,
    ) async {
      await pumpNavBar(tester);
      final scheme = schemeOf(tester);
      final decoration = panelDecoration(tester);

      expect(decoration.color, scheme.surfaceContainer);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(FluxoraRadius.sheet),
        reason: 'the dock uses the shared 28px floating capsule radius',
      );
    });
  });

  group('selected / unselected', () {
    testWidgets('the selected pill uses a quiet neutral highlight', (
      tester,
    ) async {
      await pumpNavBar(tester, brightness: Brightness.light);
      final scheme = schemeOf(tester);

      expect(
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byKey(const ValueKey('aurora-dock-lens')),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color,
        scheme.onSurface.withValues(alpha: .06),
      );
      expect(
        pillOf(tester, labelOf(PageLabel.profiles)).color,
        Colors.transparent,
        reason: 'an unselected destination stays quiet',
      );
    });

    testWidgets('only the current page carries the selection highlight', (
      tester,
    ) async {
      await pumpNavBar(tester, selectedIndex: 1);

      expect(
        find.byKey(const ValueKey('aurora-dock-selection')),
        findsOneWidget,
        reason: 'exactly one destination is current',
      );
    });

    testWidgets('every destination keeps a visible label', (tester) async {
      // The old `GNav` only expanded the selected tab, so the bar changed
      // height on navigation and the other names were hidden.
      await pumpNavBar(tester);

      expect(find.text(labelOf(PageLabel.dashboard)), findsOneWidget);
      expect(find.text(labelOf(PageLabel.profiles)), findsOneWidget);
    });

    testWidgets('selected icon and label remain high contrast', (tester) async {
      await pumpNavBar(tester);
      final scheme = schemeOf(tester);

      final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.dashboard));
      expect(selectedIcon.color, scheme.onSurface);

      final unselectedIcon = tester.widget<Icon>(find.byIcon(Icons.folder));
      expect(unselectedIcon.color, scheme.onSurfaceVariant);

      final selectedLabel = tester.widget<Text>(
        find.text(labelOf(PageLabel.dashboard)),
      );
      expect(selectedLabel.style?.color, scheme.onSurface);
      expect(selectedLabel.style?.fontWeight, FontWeight.w600);

      final unselectedLabel = tester.widget<Text>(
        find.text(labelOf(PageLabel.profiles)),
      );
      expect(unselectedLabel.style?.color, scheme.onSurfaceVariant);
      expect(unselectedLabel.style?.fontWeight, FontWeight.w500);
    });
  });

  group('hover and focus stay distinct from selection', () {
    testWidgets('hovering an unselected item adds a wash, not a tint', (
      tester,
    ) async {
      await pumpNavBar(tester);
      final scheme = schemeOf(tester);

      expect(
        pillOf(tester, labelOf(PageLabel.profiles)).color,
        Colors.transparent,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.text(labelOf(PageLabel.profiles))),
      );
      await tester.pump();

      final hovered = pillOf(tester, labelOf(PageLabel.profiles)).color;
      expect(hovered, isNot(Colors.transparent), reason: 'hover must show');
      expect(
        hovered,
        isNot(FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness)),
        reason: 'hover must not look like the current page',
      );
      expect(
        find.byKey(const ValueKey('aurora-dock-selection')),
        findsOneWidget,
      );
    });

    testWidgets('keyboard focus draws a ring, not a filled pill', (
      tester,
    ) async {
      await pumpNavBar(tester);
      final scheme = schemeOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final ringed = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AuroraBottomNavBar),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.shape)
          .whereType<RoundedRectangleBorder>()
          .where((s) => s.side.width > 0);

      expect(
        ringed,
        isNotEmpty,
        reason: 'a focused destination must draw a visible ring',
      );
      expect(ringed.first.side.color, scheme.primary);
      expect(
        pillOf(tester, labelOf(PageLabel.profiles)).color,
        Colors.transparent,
      );
    });
  });

  group('behaviour', () {
    testWidgets('a tap reports the tapped index', (tester) async {
      final taps = <int>[];
      await pumpNavBar(tester, onTabChange: taps.add);

      await tester.tap(find.byIcon(Icons.folder));
      await tester.pump();

      expect(taps, [1]);
    });

    testWidgets('tapping the current destination still reports it', (
      tester,
    ) async {
      // The shell decides what a repeat tap means (return to the page root);
      // the bar must not swallow it.
      final taps = <int>[];
      await pumpNavBar(tester, onTabChange: taps.add);

      await tester.tap(find.byIcon(Icons.dashboard));
      await tester.pump();

      expect(taps, [0]);
    });
  });
}
