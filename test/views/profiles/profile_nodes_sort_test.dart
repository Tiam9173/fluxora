import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/profiles/profile_nodes_view.dart';

/// The **profile nodes page** sort, driven through the real widget.
///
/// `ProfileNodesView` applies its sort inside the private `_sortedProxies`
/// getter, so the only honest way to test it is to pump the page and read the
/// order it actually renders.
///
/// Two rules are pinned here, and they are **not** the proxies page's rules:
///
///   · `_NodeSortMode.name` compares the **whole name** with
///     `String.compareTo` — code-point order, case-**sensitive**, no pinyin.
///     (The proxies page sorts by first-character pinyin; see
///     `test/views/proxies/proxies_name_sort_test.dart`.)
///   · `_NodeSortMode.delay` buckets by `rank(null)=2`, `rank(<=0)=1`,
///     `rank(>0)=0`, ascending inside rank 0, and returns `0` for every other
///     tie. There is **no descending** mode.
///
/// Both data sources are normally unreachable from a widget test: the proxy
/// list is parsed on a background isolate (`compute`, which never completes in
/// the fake-async zone) and `_delays` is written only from
/// `clashCore.getDelay` (no live core). The two `@visibleForTesting` overrides
/// on `ProfileNodesView` supply them instead; production never sets them and
/// every test clears them again.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    ProfileNodesView.delaysOverrideForTest = null;
    ProfileNodesView.proxiesOverrideForTest = null;
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  tearDown(() {
    ProfileNodesView.delaysOverrideForTest = null;
    ProfileNodesView.proxiesOverrideForTest = null;
  });

  /// Pumps the page on [names] (in the given order).
  Future<void> pumpNodes(WidgetTester tester, List<String> names) async {
    ProfileNodesView.proxiesOverrideForTest = [
      for (final name in names)
        <String, dynamic>{
          'name': name,
          'type': 'vless',
          'server': '127.0.0.1',
          'port': 443,
        },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProfileNodesView(
            profile: Profile(
              id: 'r7123-nodes',
              label: 'R7123',
              autoUpdateDuration: const Duration(days: 1),
            ),
          ),
        ),
      ),
    );
    // `_loadProxies` runs from `initState`; its `setState` lands on the next
    // frame.
    await tester.pump();
    await tester.pump();
  }

  /// Opens the overflow menu and taps the sort entry labelled [label].
  Future<void> chooseSort(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(appLocalizations.more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // The label is a `Text` inside a `_MenuItem`, so the tap offset is computed
    // from the paragraph, which is not itself hit-testable — the menu item
    // underneath is. `warnIfMissed: false` silences that false alarm; the
    // assertions in each test are what prove the selection actually landed.
    await tester.tap(find.text(label).last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Node names in the order the page renders them.
  ///
  /// Cards are laid out in list order, so tree order is visual order.
  List<String> renderedNames(WidgetTester tester, List<String> known) => [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null && known.contains(text.data)) text.data!,
  ];

  group('_NodeSortMode.name — whole-string code-point order', () {
    testWidgets('Chinese names sort by code point, not by pinyin',
        (tester) async {
      // code point: 上(U+4E0A) < 中(U+4E2D) < 北(U+5317) < 香(U+9999)
      // pinyin would be: 北(bei) < 上(shang) < 香(xiang) < 中(zhong)
      const names = ['中', '北', '香', '上'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(
        renderedNames(tester, names),
        ['上', '中', '北', '香'],
        reason: 'the page must not borrow the proxies page\'s pinyin rule',
      );
    });

    testWidgets('compares the whole string, so a prefix sorts first',
        (tester) async {
      const names = ['abc', 'ab'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['ab', 'abc']);
    });

    testWidgets('is case-sensitive (upper case sorts first)', (tester) async {
      // 'B' (0x42) < 'a' (0x61); a case-insensitive sort would put alpha first.
      const names = ['alpha', 'Beta'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['Beta', 'alpha']);
    });

    testWidgets('digits sort before letters', (tester) async {
      const names = ['Zulu', '5G'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['5G', 'Zulu']);
    });
  });

  group('_NodeSortMode.delay — rank buckets from the injected map', () {
    const names = ['Node-A', 'Node-B', 'Node-C', 'Node-D', 'Node-E'];

    testWidgets('positive latencies ascend; everything else sinks by rank',
        (tester) async {
      ProfileNodesView.delaysOverrideForTest = const {
        'Node-A': 30,
        'Node-B': 10,
        'Node-C': 0,
        'Node-D': -1,
        'Node-E': null,
      };
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      final rendered = renderedNames(tester, names);

      // rank 0: the two measured nodes, ascending → 10 before 30.
      expect(
        rendered.take(2).toList(),
        ['Node-B', 'Node-A'],
        reason: 'positive delays sort ascending, so 10 precedes 30',
      );

      // rank 1: `0` (testing) and `-1` (failed) share a bucket and the
      // comparator returns 0 between them, so only membership is asserted.
      expect(rendered.sublist(2, 4).toSet(), {'Node-C', 'Node-D'});

      // rank 2: never tested → always last.
      expect(rendered.last, 'Node-E');
      expect(rendered.length, 5);
    });

    testWidgets('a single measured node leads the rest', (tester) async {
      ProfileNodesView.delaysOverrideForTest = const {'Node-D': 5};
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      final rendered = renderedNames(tester, names);

      expect(rendered.first, 'Node-D');
      expect(
        rendered.sublist(1).toSet(),
        {'Node-A', 'Node-B', 'Node-C', 'Node-E'},
        reason: 'the four unmeasured nodes all land in rank 2',
      );
    });

    testWidgets('0 and -1 are the same bucket, not "measured"', (tester) async {
      ProfileNodesView.delaysOverrideForTest = const {
        'Node-A': 0,
        'Node-B': -1,
        'Node-C': 40,
      };
      const three = ['Node-A', 'Node-B', 'Node-C'];
      await pumpNodes(tester, three);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      final rendered = renderedNames(tester, three);

      // Only the positive value reaches rank 0.
      expect(rendered.first, 'Node-C');
      expect(rendered.sublist(1).toSet(), {'Node-A', 'Node-B'});
    });
  });

  group('override isolation', () {
    const names = ['Node-A', 'Node-B', 'Node-C'];

    testWidgets('unset delay override falls back to the real (empty) map',
        (tester) async {
      expect(ProfileNodesView.delaysOverrideForTest, isNull);

      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      // `_delays` is empty in a widget test, so every node is rank 2 and the
      // comparator returns 0 for all pairs — only membership is defined.
      final rendered = renderedNames(tester, names);
      expect(rendered.length, 3);
      expect(rendered.toSet(), names.toSet());
    });

    testWidgets('an empty map is a valid override, not "disabled"',
        (tester) async {
      ProfileNodesView.delaysOverrideForTest = const <String, int?>{};

      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      final rendered = renderedNames(tester, names);
      expect(rendered.length, 3);
      expect(rendered.toSet(), names.toSet());
    });

    testWidgets('both overrides are cleared between tests', (tester) async {
      // Relies on `tearDown` resetting the seams; a leak from a previous test
      // would leave these non-null.
      expect(ProfileNodesView.delaysOverrideForTest, isNull);
      expect(ProfileNodesView.proxiesOverrideForTest, isNull);

      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      expect(renderedNames(tester, names).toSet(), names.toSet());
    });
  });
}
