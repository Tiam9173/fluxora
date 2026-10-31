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

/// Phase 05.3 — window size adaptation.
///
/// `desktop_layout_baseline_test` pinned the shell geometry at three *comfortable*
/// widths. This file covers the edges: the real minimum window, the breakpoint,
/// a 16:9 window, a window that is too short, and what a resize does to page
/// state. Every assertion is a measured `RenderBox` value or a scroll metric —
/// "the widget exists" would not have caught anything here.
///
/// The minimum is not a guess: `lib/common/window.dart:20` sets
/// `minimumSize = Size(372, 492)` on the desktop window, so 372×492 is the
/// smallest frame a user can actually produce.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  /// Counts `initState` calls so a resize can be checked for remounting.
  final inits = <String>[];

  Widget page({Brightness brightness = Brightness.dark}) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF29D6C7),
          brightness: brightness,
        ),
      ),
      home: Builder(
        builder: (ctx) {
          globalState.theme = CommonTheme.of(ctx, 1.0);
          globalState.measure = Measure.of(ctx, 1.0);
          return Scaffold(
            body: AppSidebarContainer(
              child: CommonScaffold(
                title: 'page-title',
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.save_as_outlined),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
                body: generateListView([
                  _Probe(inits: inits),
                  for (var i = 0; i < 40; i++)
                    ListTile(title: Text('row-$i')),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    final items = navigation.getItems();
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
        child: page(brightness: brightness),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The scroll metrics of the page list — the only honest way to say "the
  /// content is still reachable" instead of "a ListView exists".
  ScrollPosition listPosition(WidgetTester tester) {
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CommonScaffold),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    return scrollable.position;
  }

  group('desktop shell at the edges', () {
    // 372×492 is the real minimum (`window.dart`), 601 is the mobile/desktop
    // breakpoint + 1, 1200×520 is wide but short, 1920×1080 is 16:9.
    for (final size in const [
      Size(372, 492),
      Size(601, 800),
      Size(1200, 520),
      Size(1920, 1080),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} keeps the shell intact', (
        tester,
      ) async {
        await pumpAt(tester, size);

        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at ${size.width.toInt()}x${size.height.toInt()}',
        );

        // The rail is a fixed 80 px and the content column starts right after
        // its 1 px border — at every width, including the minimum.
        // The rail *widget* is the destination list inside the shell column
        // (the column also holds the app mark and the bottom section), so the
        // honest assertions are its fixed width and that it stays inside the
        // window at every height.
        final rail = tester.getRect(find.byType(AuroraNavigationRail));
        expect(rail.width, 80);
        expect(rail.top, greaterThanOrEqualTo(0));
        // A short window is allowed to overflow the rail — it lives inside a
        // scroll view (`K4 — short window scroll affordance` covers the bar).
        // What must hold is that it is then *scrollable* and not clipped with
        // no way to reach the last destination.
        final railScroll = tester.state<ScrollableState>(
          find
              .ancestor(
                of: find.byType(AuroraNavigationRail),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        if (rail.bottom > size.height) {
          expect(
            railScroll.position.maxScrollExtent,
            greaterThan(0),
            reason: 'the rail overflows ${size.height}px but cannot scroll',
          );
        } else {
          expect(railScroll.position.maxScrollExtent, 0);
        }

        final contentLeft = tester.getTopLeft(find.byType(CommonScaffold)).dx;
        expect(contentLeft, 81);

        // The trailing actions must stay inside the window.
        final actionRight = tester
            .getBottomRight(find.byIcon(Icons.delete_outline))
            .dx;
        expect(
          actionRight,
          lessThanOrEqualTo(size.width - 8),
          reason: 'the last toolbar action is not clipped by the window edge',
        );

        // The list is reachable: it overflows (12 rows) and can scroll.
        final position = listPosition(tester);
        expect(position.maxScrollExtent, greaterThan(0));
        expect(position.viewportDimension, greaterThan(0));
        expect(
          tester.getSize(find.byType(CommonScaffold)).height,
          lessThanOrEqualTo(size.height),
        );
      });
    }

    testWidgets('the 601 breakpoint is not a cliff', (tester) async {
      // 600 → 601 flips `isMobileView`; the shell must still lay out with the
      // same rail width on the desktop side of the line.
      await pumpAt(tester, const Size(600, 800));
      expect(tester.takeException(), isNull);
      await pumpAt(tester, const Size(601, 800));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AuroraNavigationRail)).width, 80);
    });
  });

  group('resize', () {
    testWidgets('resizing does not remount the page', (tester) async {
      inits.clear();
      await pumpAt(tester, const Size(1200, 800));
      expect(inits, ['probe'], reason: 'mounted once');

      // Grow, then shrink to the minimum. `pumpAt` re-pumps the same tree, so a
      // remount would show up as a second `initState`.
      await pumpAt(tester, const Size(1920, 1080));
      await pumpAt(tester, const Size(372, 492));

      expect(
        inits,
        ['probe'],
        reason: 'the page kept its State across two size changes',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list keeps its scroll offset across a resize', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1200, 800));
      final position = listPosition(tester);
      // 120 is inside the scrollable range at *both* sizes, so a changed value
      // means the position was thrown away rather than clamped by the new
      // extent.
      position.jumpTo(120);
      await tester.pump();
      expect(position.pixels, 120);

      await pumpAt(tester, const Size(900, 700));

      expect(
        listPosition(tester).pixels,
        120,
        reason: 'a narrower window does not throw the scroll position away',
      );
    });
  });

  group('theme does not change geometry', () {
    testWidgets('light and dark lay out identically', (tester) async {
      await pumpAt(tester, const Size(1200, 800));
      final darkRail = tester.getSize(find.byType(AuroraNavigationRail));
      final darkContent = tester.getTopLeft(find.byType(CommonScaffold));

      await pumpAt(tester, const Size(1200, 800), brightness: Brightness.light);
      expect(tester.takeException(), isNull);

      expect(tester.getSize(find.byType(AuroraNavigationRail)), darkRail);
      expect(tester.getTopLeft(find.byType(CommonScaffold)), darkContent);
    });
  });

  group('TV bar geometry', () {
    Future<void> pumpTv(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final nodes = List<FocusNode>.generate(4, (_) => FocusNode());
      addTearDown(() {
        for (final node in nodes) {
          node.dispose();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF29D6C7),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AuroraTvNavBar(
                selectedIndex: 0,
                focusNodes: nodes,
                onSelect: (_) {},
                destinations: const [
                  AuroraRailDestination(icon: Icon(Icons.dashboard), label: 'a'),
                  AuroraRailDestination(icon: Icon(Icons.folder), label: 'b'),
                  AuroraRailDestination(icon: Icon(Icons.construction), label: 'c'),
                  AuroraRailDestination(icon: Icon(Icons.settings), label: 'd'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} keeps every target on screen', (
        tester,
      ) async {
        await pumpTv(tester, size);

        expect(tester.takeException(), isNull);

        // A remote has to be able to land on each destination: the bar must be
        // tall enough to be a real target and stay inside the viewport.
        final bar = tester.getRect(find.byType(AuroraTvNavBar));
        expect(bar.height, greaterThanOrEqualTo(44));
        expect(bar.left, greaterThanOrEqualTo(0));
        expect(bar.right, lessThanOrEqualTo(size.width));

        for (final label in ['a', 'b', 'c', 'd']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: 'label $label');
          expect(rect.right, lessThanOrEqualTo(size.width), reason: 'label $label');
        }
      });
    }
  });
}

/// Records its own `initState` so a resize can be proven not to remount it.
class _Probe extends StatefulWidget {
  const _Probe({required this.inits});

  final List<String> inits;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.inits.add('probe');
  }

  @override
  Widget build(BuildContext context) =>
      const ListTile(title: Text('probe'), dense: true);
}
