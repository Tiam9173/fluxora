import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// RC.9 — `computeHideTimeout` unit tests.
///
/// Covers the behaviours that must be preserved:
///  * a proxy is hidden only when its **last** measurement is negative;
///  * `null` (never tested) and `0` (test in flight) are kept;
///  * the currently selected proxy is never hidden;
///  * unprobeable built-in adapters are never hidden;
///  * a group's own `testUrl` is honoured;
///  * a group whose members would all be hidden falls back to its full list;
///  * nested groups are resolved through the existing resolver.
void main() {
  const defaultUrl = 'http://default.test/';
  const otherUrl = 'http://other.test/';

  Proxy mkProxy(String name, {String type = 'Shadowsocks'}) =>
      Proxy(name: name, type: type);

  Group mkGroup(String name, List<Proxy> all, {String? testUrl}) =>
      Group(type: GroupType.Selector, name: name, all: all, testUrl: testUrl);

  List<String> visibleNames(List<Group> groups) =>
      groups.single.all.map((element) => element.name).toList();

  List<Group> run({
    required List<Group> groups,
    DelayMap delayMap = const {},
    SelectedMap selectedMap = const {},
    List<Group>? allGroups,
    String defaultTestUrl = defaultUrl,
  }) => computeHideTimeout(
    groups: groups,
    allGroups: allGroups ?? groups,
    delayMap: delayMap,
    selectedMap: selectedMap,
    defaultTestUrl: defaultTestUrl,
  );

  group('RC.9 computeHideTimeout', () {
    test('drops the proxies whose last probe timed out (negative)', () {
      final groups = [
        mkGroup('G', [mkProxy('ok'), mkProxy('dead')]),
      ];
      expect(
        visibleNames(
          run(groups: groups, delayMap: {defaultUrl: {'ok': 120, 'dead': -1}}),
        ),
        ['ok'],
      );
    });

    test('keeps a proxy that was never tested (null)', () {
      final groups = [
        mkGroup('G', [mkProxy('tested'), mkProxy('untested')]),
      ];
      expect(
        visibleNames(
          run(groups: groups, delayMap: {defaultUrl: {'tested': 80}}),
        ),
        ['tested', 'untested'],
      );
    });

    test('keeps a proxy whose test is in flight (0) — 0 is not a timeout', () {
      final groups = [
        mkGroup('G', [mkProxy('testing')]),
      ];
      expect(
        visibleNames(
          run(groups: groups, delayMap: {defaultUrl: {'testing': 0}}),
        ),
        ['testing'],
      );
    });

    test('keeps a timed-out proxy while it is the selected one', () {
      final groups = [
        mkGroup('G', [mkProxy('dead'), mkProxy('ok')]),
      ];
      expect(
        visibleNames(
          run(
            groups: groups,
            delayMap: {defaultUrl: {'dead': -1, 'ok': 40}},
            selectedMap: const {'G': 'dead'},
          ),
        ),
        ['dead', 'ok'],
      );
    });

    test('keeps built-in adapters a delay probe cannot reach', () {
      final groups = [
        mkGroup('G', [
          mkProxy('reject', type: 'Reject'),
          mkProxy('dns', type: 'Dns'),
          mkProxy('dead'),
        ]),
      ];
      expect(
        visibleNames(
          run(
            groups: groups,
            delayMap: {
              defaultUrl: {'reject': -1, 'dns': -1, 'dead': -1},
            },
          ),
        ),
        ['reject', 'dns'],
      );
    });

    test("reads a group's own test url", () {
      final groups = [
        mkGroup('G', [mkProxy('a'), mkProxy('b')], testUrl: otherUrl),
      ];
      expect(
        visibleNames(
          run(
            groups: groups,
            delayMap: {
              otherUrl: {'a': -1, 'b': 80},
              defaultUrl: {'a': 100, 'b': -1},
            },
          ),
        ),
        ['b'],
      );
    });

    test('falls back to the full member list instead of an empty group', () {
      final groups = [
        mkGroup('G', [mkProxy('a'), mkProxy('b')]),
      ];
      expect(
        visibleNames(
          run(groups: groups, delayMap: {defaultUrl: {'a': -1, 'b': -1}}),
        ),
        ['a', 'b'],
      );
    });

    test('resolves a nested group to the proxy it actually selects', () {
      // G1 contains the sub-group G2 (which selects `dead`) plus `ok`.
      final subGroup = Group(
        type: GroupType.Selector,
        name: 'G2',
        all: [mkProxy('dead')],
      );
      final topGroup = mkGroup('G1', [
        mkProxy('G2', type: 'Selector'),
        mkProxy('ok'),
      ]);
      expect(
        visibleNames(
          run(
            groups: [topGroup],
            allGroups: [topGroup, subGroup],
            delayMap: {
              defaultUrl: {'dead': -1, 'ok': 50},
            },
            selectedMap: const {'G2': 'dead'},
          ),
        ),
        ['ok'],
      );
    });
  });
}
