import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/profiles/profile_nodes_view.dart';

/// The **profile nodes page** sort, driven through the real widget.
///
/// `ProfileNodesView` applies its sort inside the private `_sortedProxies`
/// getter, so the only honest way to test it is to pump the page and read the
/// order it actually renders.
///
/// Two rules are pinned here:
///
///   · `_NodeSortMode.name` uses the **same rule as the proxies page** (E4):
///     the first character's pinyin compared case-insensitively, then the whole
///     name by `String.compareTo`. See
///     `test/views/proxies/proxies_name_sort_test.dart`, and the cross-page
///     agreement test at the bottom of this file.
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

  /// Pumps the page on `(name, type)` pairs, preserving the given order.
  ///
  /// `_NodeSortMode.protocol` compares `type`, so the protocol tests need it to
  /// vary independently of the name.
  /// The `WidgetRef` of the tree [pumpTypedNodes] built, so a test can also
  /// drive the proxies page's real entry point (`getSortProxies`).
  WidgetRef? capturedRef;

  Future<void> pumpTypedNodes(
    WidgetTester tester,
    List<(String, String)> nodes,
  ) async {
    capturedRef = null;
    ProfileNodesView.proxiesOverrideForTest = [
      for (final (name, type) in nodes)
        <String, dynamic>{
          'name': name,
          'type': type,
          'server': '127.0.0.1',
          'port': 443,
        },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return ProfileNodesView(
                profile: Profile(
                  id: 'r7123-nodes',
                  label: 'R7123',
                  autoUpdateDuration: const Duration(days: 1),
                ),
              );
            },
          ),
        ),
      ),
    );
    // `_loadProxies` runs from `initState`; its `setState` lands on the next
    // frame.
    await tester.pump();
    await tester.pump();
  }

  /// Pumps the page on [names] (in the given order), every node typed `vless`.
  Future<void> pumpNodes(WidgetTester tester, List<String> names) =>
      pumpTypedNodes(tester, [for (final name in names) (name, 'vless')]);

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

  group('_NodeSortMode.name — first-character pinyin, then code point', () {
    testWidgets('Chinese names sort by pinyin, not by code point', (
      tester,
    ) async {
      // pinyin: 北(bei) < 上(shang) < 香(xiang) < 中(zhong)
      // code point would give: 上(U+4E0A) < 中(U+4E2D) < 北(U+5317) < 香(U+9999)
      const names = ['中', '北', '香', '上'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), [
        '北',
        '上',
        '香',
        '中',
      ], reason: 'E4: the profile page now shares the proxies page rule');
    });

    testWidgets('a shared first character falls back to the whole name', (
      tester,
    ) async {
      // 'ab' is a prefix of 'abc', so the code-point tie-break puts it first.
      const names = ['abc', 'ab'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['ab', 'abc']);
    });

    testWidgets('the primary comparison is case-insensitive', (tester) async {
      // Keys are 'a' vs 'b' — case-insensitively 'a' < 'b', so alpha leads.
      // A case-sensitive (code-point) primary would give 'B'(0x42) < 'a'(0x61).
      const names = ['alpha', 'Beta'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['alpha', 'Beta']);
    });

    testWidgets('digits sort before letters', (tester) async {
      const names = ['Zulu', '5G'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['5G', 'Zulu']);
    });

    testWidgets('punctuation, digits and letters interleave by key', (
      tester,
    ) async {
      // '-' (0x2D) < '5' (0x35) < 'a' < 'zhong' — the same fixture the proxies
      // page uses in `test/views/proxies/proxies_name_sort_test.dart`.
      const names = ['中', 'apple', '5G', '-dash'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), [
        '-dash',
        '5G',
        'apple',
        '中',
      ]);
    });

    testWidgets('two nodes sharing a pinyin key fall back to code point', (
      tester,
    ) async {
      // Both keys are 'xiang'; '香港01' < '香港02' by `String.compareTo`.
      const names = ['香港02', '香港01'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);

      expect(renderedNames(tester, names), ['香港01', '香港02']);
    });

    testWidgets('the profile page and the proxies page agree on one order', (
      tester,
    ) async {
      // Five nodes: the page is a lazy `ListView`, so anything past the
      // viewport is never built and would be missing from the rendered order.
      const names = ['中', '北', 'Beta', '5G', '-dash'];
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortName);
      final fromPage = renderedNames(tester, names);

      final controller = AppController(
        tester.element(find.byType(ProfileNodesView)),
        capturedRef!,
      );
      final fromController = controller
          .getSortProxies(
            proxies: [
              for (final name in names) Proxy(name: name, type: 'vless'),
            ],
            sortType: ProxiesSortType.name,
          )
          .map((p) => p.name)
          .toList();

      expect(fromPage, fromController, reason: 'E4: one rule, two pages');
    });
  });

  group('_NodeSortMode.delay — rank buckets from the injected map', () {
    const names = ['Node-A', 'Node-B', 'Node-C', 'Node-D', 'Node-E'];

    testWidgets('positive latencies ascend; everything else sinks by rank', (
      tester,
    ) async {
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
      expect(rendered.take(2).toList(), [
        'Node-B',
        'Node-A',
      ], reason: 'positive delays sort ascending, so 10 precedes 30');

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
      expect(rendered.sublist(1).toSet(), {
        'Node-A',
        'Node-B',
        'Node-C',
        'Node-E',
      }, reason: 'the four unmeasured nodes all land in rank 2');
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

    testWidgets('the profile page and the proxies page agree on delay tiers', (
      tester,
    ) async {
      // Node-A 30 ms, Node-B 10 ms, Node-C failed (-1), Node-D never tested.
      const names = ['Node-A', 'Node-B', 'Node-C', 'Node-D'];
      const delays = <String, int?>{'Node-A': 30, 'Node-B': 10, 'Node-C': -1};

      ProfileNodesView.delaysOverrideForTest = delays;
      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);
      final fromPage = renderedNames(tester, names);

      // The same fixture through the proxies page's real entry point. Its map
      // is keyed by the **resolved** test URL, so read that URL rather than
      // guessing it, then invalidate the data source so the new map is seen.
      final context = tester.element(find.byType(ProfileNodesView));
      final container = ProviderScope.containerOf(context);
      final resolvedUrl = container.read(getRealTestUrlProvider(''));
      globalState.appState = globalState.appState.copyWith(
        delayMap: <String, Map<String, int?>>{resolvedUrl: delays},
      );
      container.invalidate(delayDataSourceProvider);

      final controller = AppController(context, capturedRef!);
      final fromController = controller
          .getSortProxies(
            proxies: [
              for (final name in names) Proxy(name: name, type: 'vless'),
            ],
            sortType: ProxiesSortType.delay,
          )
          .map((p) => p.name)
          .toList();

      // The tiers themselves, so the agreement below cannot be vacuous.
      expect(
        fromPage.take(2).toList(),
        ['Node-B', 'Node-A'],
        reason: 'measured delays still ascend',
      );
      expect(
        fromPage.sublist(2),
        ['Node-C', 'Node-D'],
        reason: 'E5: failed (-1) must precede never-tested (absent)',
      );

      expect(fromPage, fromController, reason: 'E5: one rule, two pages');
    });
  });

  group('_NodeSortMode.original — the loaded order, untouched', () {
    testWidgets('renders the injected order even when it is not sorted', (
      tester,
    ) async {
      // Reverse alphabetical, so both the code-point rule and the pinyin rule
      // would reorder it. `original` must not sort at all.
      const names = ['charlie', 'alpha', 'bravo'];
      await pumpNodes(tester, names);

      expect(renderedNames(tester, names), [
        'charlie',
        'alpha',
        'bravo',
      ], reason: 'the default mode is "no sort", not "sort by something"');
    });

    testWidgets('switching to another mode and back restores the order', (
      tester,
    ) async {
      const names = ['charlie', 'alpha', 'bravo'];
      await pumpNodes(tester, names);

      await chooseSort(tester, appLocalizations.nodeSortName);
      expect(renderedNames(tester, names), [
        'alpha',
        'bravo',
        'charlie',
      ], reason: 'precondition: the name sort really did reorder the page');

      await chooseSort(tester, appLocalizations.nodeSortDefault);
      expect(renderedNames(tester, names), [
        'charlie',
        'alpha',
        'bravo',
      ], reason: 'sorting must run on a copy, never mutate the loaded list');
    });
  });

  group('_NodeSortMode.protocol — by `type`, code-point ascending', () {
    testWidgets('groups the nodes by protocol', (tester) async {
      // 'ss' (0x73) < 'trojan' (0x74) < 'vless' (0x76)
      const nodes = [
        ('Alpha', 'vless'),
        ('Bravo', 'trojan'),
        ('Charlie', 'ss'),
      ];
      await pumpTypedNodes(tester, nodes);
      await chooseSort(tester, appLocalizations.nodeSortProtocol);

      expect(renderedNames(tester, [for (final node in nodes) node.$1]), [
        'Charlie',
        'Bravo',
        'Alpha',
      ]);
    });

    testWidgets('sorts by type, not by name', (tester) async {
      // By name: Alpha < Zebra. By type: trojan (Zebra) < vless (Alpha).
      const nodes = [('Alpha', 'vless'), ('Zebra', 'trojan')];
      await pumpTypedNodes(tester, nodes);
      await chooseSort(tester, appLocalizations.nodeSortProtocol);

      expect(renderedNames(tester, const ['Alpha', 'Zebra']), [
        'Zebra',
        'Alpha',
      ], reason: 'a name-ordered result would be [Alpha, Zebra]');
    });
  });

  group('override isolation', () {
    const names = ['Node-A', 'Node-B', 'Node-C'];

    testWidgets('unset delay override falls back to the real (empty) map', (
      tester,
    ) async {
      expect(ProfileNodesView.delaysOverrideForTest, isNull);

      await pumpNodes(tester, names);
      await chooseSort(tester, appLocalizations.nodeSortDelay);

      // `_delays` is empty in a widget test, so every node is rank 2 and the
      // comparator returns 0 for all pairs — only membership is defined.
      final rendered = renderedNames(tester, names);
      expect(rendered.length, 3);
      expect(rendered.toSet(), names.toSet());
    });

    testWidgets('an empty map is a valid override, not "disabled"', (
      tester,
    ) async {
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
