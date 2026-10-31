import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';

/// The **proxies page name sort**, reached through the real controller.
///
/// `AppController.getSortProxies(sortType: ProxiesSortType.name)` delegates to
/// `_sortOfName` (`controller.dart:2281`), which sorts with
/// `utils.sortByChar(utils.getPinyin(a.name), utils.getPinyin(b.name))` —
/// i.e. **by the pinyin of the first character, case-insensitively**, with no
/// tie-break. This file exercises that production entry point, not a copy of it.
///
/// Several fixtures are chosen so that a pinyin sort and a code-point sort give
/// **different** answers — a regression to `String.compareTo` (the profile page's
/// rule) would turn them red. `utils.getPinyin` / `utils.sortByChar` themselves
/// are covered separately in `test/common/pinyin_sort_utils_test.dart`.
///
/// Deliberately **not** asserted:
///   · the relative order of names that share a first character — `_sortOfName`
///     has no tie-break and `List.sort` is not guaranteed stable, so there is no
///     contract to pin;
///   · any descending name order — `ProxiesSortType.name` has no direction.
void main() {
  group('getSortProxies — ProxiesSortType.name', () {
    late AppController controller;

    AppState emptyAppState() => AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      delayMap: const {},
    );

    Future<void> pumpController(WidgetTester tester) async {
      globalState.appState = emptyAppState();

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
      controller = AppController(context, capturedRef);
    }

    List<Proxy> proxiesOf(List<String> names) => [
      for (final name in names) Proxy(name: name, type: 'vless'),
    ];

    List<String> sortedNames(List<String> names) => controller
        .getSortProxies(
          proxies: proxiesOf(names),
          sortType: ProxiesSortType.name,
        )
        .map((p) => p.name)
        .toList();

    testWidgets('Chinese names sort by pinyin, not by code point',
        (tester) async {
      await pumpController(tester);

      // pinyin: 北(bei) < 上(shang) < 香(xiang) < 中(zhong)
      // code point would give: 上(4E0A) < 中(4E2D) < 北(5317) < 香(9999)
      expect(
        sortedNames(['中', '北', '香', '上']),
        ['北', '上', '香', '中'],
      );
    });

    testWidgets('Latin names sort case-insensitively', (tester) async {
      await pumpController(tester);

      // lowercase: alpha < beta  →  ['alpha', 'Beta']
      // code point would give: 'Beta'(B=0x42) < 'alpha'(a=0x61)
      expect(sortedNames(['Beta', 'alpha']), ['alpha', 'Beta']);
    });

    testWidgets('Chinese and Latin interleave by their first letter',
        (tester) async {
      await pumpController(tester);

      // keys: 北→'bei', gamma→'gamma', 中→'zhong'
      expect(sortedNames(['gamma', '中', '北']), ['北', 'gamma', '中']);
    });

    testWidgets('only the first character decides the pinyin key',
        (tester) async {
      await pumpController(tester);

      // 上海→'shang', 北京→'bei', 香港→'xiang' (the rest of the name is ignored)
      expect(
        sortedNames(['上海', '北京', '香港']),
        ['北京', '上海', '香港'],
      );
    });

    testWidgets('digits and punctuation take part in the ordering',
        (tester) async {
      await pumpController(tester);

      // '-' (0x2D) < '5' (0x35) < 'A' (0x41) < 'zhong'
      expect(
        sortedNames(['中', 'apple', '5G', '-dash']),
        ['-dash', '5G', 'apple', '中'],
      );
    });

    testWidgets('names sharing a first character are left unordered',
        (tester) async {
      await pumpController(tester);

      // Both keys are 'xiang'. `_sortOfName` has no tie-break, so only the
      // membership and the determinism of repeated calls may be asserted —
      // never which one comes first.
      final first = sortedNames(['香港01', '香港02']);
      expect(first.toSet(), {'香港01', '香港02'});
      expect(first.length, 2);

      for (var i = 0; i < 5; i++) {
        expect(sortedNames(['香港01', '香港02']), first);
      }
    });

    testWidgets('sortType none returns the input order untouched',
        (tester) async {
      await pumpController(tester);

      final result = controller
          .getSortProxies(
            proxies: proxiesOf(['中', 'apple']),
            sortType: ProxiesSortType.none,
          )
          .map((p) => p.name)
          .toList();

      expect(result, ['中', 'apple']);
    });

    testWidgets('the caller\'s list is not mutated', (tester) async {
      await pumpController(tester);

      final input = proxiesOf(['中', '北', 'apple']);
      controller.getSortProxies(
        proxies: input,
        sortType: ProxiesSortType.name,
      );

      expect(
        input.map((p) => p.name).toList(),
        ['中', '北', 'apple'],
        reason: '_sortOfName sorts a copy (`List.of`), never the argument',
      );
    });
  });
}
