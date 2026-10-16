import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/views/proxies/list.dart';

/// item 6 (Bettbox 1.19.4 alignment) — the proxy group sort cache.
///
/// `_buildRowsSliver` used to re-run `getSortProxies` for **every expanded
/// group** on every build, so any unrelated rebuild (the 1 s tick, a delay
/// update, a selection change) repeated an O(n log n) sort per group.
///
/// The cache is only safe if a stale entry can never be served, so what is
/// pinned here is the **invalidation contract** — every input that changes the
/// built sliver must change the key. The rendered output itself is covered by
/// the narrow-layout harness, which pumps the real list.
void main() {
  Object key({
    bool isExpand = true,
    ProxiesSortType sortType = ProxiesSortType.delay,
    int columns = 2,
    double itemHeight = 84.0,
    Object? delayMap = const <String, Object?>{},
  }) => groupSliverCacheKey(
    isExpand: isExpand,
    sortType: sortType,
    columns: columns,
    itemHeight: itemHeight,
    delayMap: delayMap,
  );

  group('groupSliverCacheKey — identical inputs reuse the cache', () {
    test('the same inputs produce an equal key', () {
      expect(key(), key());
    });

    test('the same delayMap instance still reuses the cache', () {
      final shared = <String, Object?>{'http://g.co/g': {'A': 100}};
      expect(key(delayMap: shared), key(delayMap: shared));
    });
  });

  group('groupSliverCacheKey — every input invalidates', () {
    test('expanding or collapsing the group invalidates', () {
      expect(key(isExpand: true), isNot(key(isExpand: false)));
    });

    test('a sort-type change invalidates', () {
      expect(
        key(sortType: ProxiesSortType.delay),
        isNot(key(sortType: ProxiesSortType.name)),
      );
      expect(
        key(sortType: ProxiesSortType.name),
        isNot(key(sortType: ProxiesSortType.none)),
      );
    });

    test('a column-count change invalidates', () {
      expect(key(columns: 2), isNot(key(columns: 4)));
    });

    test('an item-height change invalidates', () {
      expect(key(itemHeight: 84.0), isNot(key(itemHeight: 100.0)));
    });
  });

  // The one that is easy to miss: a delay update produces a NEW delayMap while
  // the `Group` instance stays identical, so `identical(cached.$1, group)`
  // alone would happily serve a stale sort order.
  //
  // The maps here are built at runtime (`Map.from`) because that is what
  // `AppState.copyWith(delayMap: …)` produces on every probe result — two
  // distinct instances even when the payload happens to match. A `const {}`
  // would be canonicalised to one instance and could not model this.
  group('groupSliverCacheKey — a delay update invalidates', () {
    test('a new delayMap instance invalidates even for an equal payload', () {
      expect(
        key(delayMap: Map<String, Object?>.from(const {})),
        isNot(key(delayMap: Map<String, Object?>.from(const {}))),
        reason:
            'two distinct map instances must not compare equal, otherwise a '
            'delay probe would leave the sort order frozen',
      );
    });

    test('a null delayMap is distinguishable from an empty one', () {
      expect(
        key(delayMap: null),
        isNot(key(delayMap: Map<String, Object?>.from(const {}))),
      );
    });
  });
}
