import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';

/// RC.7 — direction toggle for the proxies page's delay sort.
///
/// The rule under test lives in `AppController._sortOfDelay` /
/// `getSortProxies`, reached through the real controller the proxies page uses —
/// not a copy of it. Two things must hold in both directions:
///   · measured delays order by value (ascending / descending);
///   · an unknown or failed delay (`null` / `-1`) always sinks to the END, so
///     flipping to descending never floats unmeasured nodes to the top.
void main() {
  group('RC.7 — delaySortDescendingProvider', () {
    test('defaults to ascending', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(delaySortDescendingProvider), isFalse);
    });

    test('toggle flips the direction and is repeatable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(delaySortDescendingProvider.notifier).toggle();
      expect(container.read(delaySortDescendingProvider), isTrue);

      container.read(delaySortDescendingProvider.notifier).toggle();
      expect(container.read(delaySortDescendingProvider), isFalse);
    });

    test('set assigns an explicit direction', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(delaySortDescendingProvider.notifier).set(true);
      expect(container.read(delaySortDescendingProvider), isTrue);
    });
  });

  group('RC.7 — getSortProxies honours the delay direction', () {
    late ProviderContainer container;
    late AppController controller;

    /// Delays are read through `getDelayProvider`, which resolves the URL and
    /// the card state, so the fixture seeds the map for the empty test URL the
    /// controller falls back to.
    AppState appStateWith(Map<String, Map<String, int?>> delayMap) => AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      delayMap: delayMap,
    );

    /// Delays are keyed by the **resolved** test URL (`appSettingProvider.testUrl`
    /// by default), so the fixture reads that URL from the container rather than
    /// guessing it, then invalidates the data source so the new map is observed.
    Future<void> pumpWith(WidgetTester tester, Map<String, int?> delays) async {
      globalState.appState = appStateWith(const {});

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox).first);
      container = ProviderScope.containerOf(context);
      controller = AppController(context, capturedRef);

      final resolvedUrl = container.read(getRealTestUrlProvider(''));
      globalState.appState = appStateWith(<String, Map<String, int?>>{
        resolvedUrl: delays,
      });
      container.invalidate(delayDataSourceProvider);
    }

    List<Proxy> proxies() => const [
      Proxy(name: 'Bravo', type: 'vless'),
      Proxy(name: 'Alpha', type: 'vless'),
      Proxy(name: 'Charlie', type: 'vless'),
      Proxy(name: 'Delta', type: 'vless'),
    ];

    List<String> order({required bool descending}) => controller
        .getSortProxies(
          proxies: proxies(),
          sortType: ProxiesSortType.delay,
          delayDescending: descending,
        )
        .map((p) => p.name)
        .toList();

    testWidgets('ascending: measured delays low to high', (tester) async {
      await pumpWith(tester, {'Alpha': 300, 'Bravo': 100, 'Charlie': 200, 'Delta': 50});

      expect(order(descending: false), ['Delta', 'Bravo', 'Charlie', 'Alpha']);
    });

    testWidgets('descending: measured delays high to low', (tester) async {
      await pumpWith(tester, {'Alpha': 300, 'Bravo': 100, 'Charlie': 200, 'Delta': 50});

      expect(order(descending: true), ['Alpha', 'Charlie', 'Bravo', 'Delta']);
    });

    testWidgets('unknown and failed delays sink to the end in BOTH directions',
        (tester) async {
      // `-1` is the failure sentinel `_testProxyDelay` writes; `null` means the
      // node was never tested; `Alpha` is absent from the map entirely. None of
      // them may be treated as "fast".
      await pumpWith(tester, {'Bravo': 100, 'Charlie': null, 'Delta': -1});

      final ascending = order(descending: false);
      expect(
        ascending.first,
        'Bravo',
        reason: 'the only measured node leads when ascending',
      );
      expect(ascending.sublist(1).toSet(), {'Alpha', 'Charlie', 'Delta'});

      final descending = order(descending: true);
      expect(
        descending.first,
        'Bravo',
        reason: 'the measured node still leads when descending',
      );
      expect(
        descending.sublist(1).toSet(),
        {'Alpha', 'Charlie', 'Delta'},
        reason:
            'an unknown / failed delay must NOT float to the top when the '
            'direction is flipped',
      );
    });

    testWidgets('equal delays keep a deterministic order across calls',
        (tester) async {
      await pumpWith(tester, {'Alpha': 100, 'Bravo': 100, 'Charlie': 100, 'Delta': 100});

      final first = order(descending: false);
      for (var i = 0; i < 5; i++) {
        expect(order(descending: false), first);
      }
    });

    testWidgets('the name and none sorts ignore the direction', (tester) async {
      await pumpWith(tester, {'Alpha': 300, 'Bravo': 100, 'Charlie': 200, 'Delta': 50});

      final asc = controller
          .getSortProxies(
            proxies: proxies(),
            sortType: ProxiesSortType.name,
            delayDescending: false,
          )
          .map((p) => p.name)
          .toList();
      final desc = controller
          .getSortProxies(
            proxies: proxies(),
            sortType: ProxiesSortType.name,
            delayDescending: true,
          )
          .map((p) => p.name)
          .toList();

      expect(desc, asc);
    });

    testWidgets('none returns the input order untouched', (tester) async {
      await pumpWith(tester, {'Alpha': 300});

      final result = controller
          .getSortProxies(
            proxies: proxies(),
            sortType: ProxiesSortType.none,
            delayDescending: true,
          )
          .map((p) => p.name)
          .toList();

      expect(result, ['Bravo', 'Alpha', 'Charlie', 'Delta']);
    });
  });

  // ── NOT VERIFIED (deliberately not asserted) ───────────────────────────────
  //
  // The 「升序 / 降序」 control's *rendering* inside `ProxiesSetting` is not
  // asserted here: pumped standalone, the settings page builds an empty tree
  // (`tester.widgetList<Text>()` is empty) because it needs the full application
  // context, so `find.text('升序')` can never match. The control's **behaviour**
  // is covered above through the real `AppController.getSortProxies`; only its
  // placement in the settings list remains unverified.
}
