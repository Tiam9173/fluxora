import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/views/proxies/chain_proxy_view.dart';

/// P2.3-A (B-1) — fallback-pool stale detection.
///
/// The production UI derives a candidate's `节点不存在` state from
/// `_realProxyNames()` (the `groupsProvider` node universe) via
/// [isFallbackCandidateStale]. These tests pin the decision that drives the UI:
///
///   * a **known** universe flags a candidate stale iff the node is absent;
///   * an **unknown** universe (core not running / groups not loaded) must
///     NEVER flag a candidate stale — otherwise stopping the core would show
///     `节点不存在` for every configured candidate and disable its controls.
void main() {
  group('P2.3-A (B-1) — fallback-pool stale detection', () {
    // ── 1. core running + groups loaded + node exists → NOT stale ───────────
    test('1. known universe + node present → not stale', () {
      final universe = chainNodeUniverse({'HK-01', 'US-01'});
      expect(universe, isNotNull);
      expect(isFallbackCandidateStale(universe, 'HK-01'), isFalse);
    });

    // ── 2. core running + groups loaded + node missing → stale ─────────────
    test('2. known universe + node missing → stale (节点不存在)', () {
      final universe = chainNodeUniverse({'HK-01', 'US-01'});
      expect(isFallbackCandidateStale(universe, 'GONE-99'), isTrue);
    });

    // ── 3. core not running / groups unavailable → NOT stale ───────────────
    test('3. empty groups (core not running) → unknown universe → not stale', () {
      // `groupsProvider == []` is exactly the "core not running / not loaded"
      // situation; it must collapse to `null` (unknown), never to an empty set.
      final universe = chainNodeUniverse(<String>{});
      expect(universe, isNull);
      expect(isFallbackCandidateStale(universe, 'HK-01'), isFalse);
    });

    test('3b. null universe → never stale for any node', () {
      expect(isFallbackCandidateStale(null, 'HK-01'), isFalse);
      expect(isFallbackCandidateStale(null, ''), isFalse);
    });

    // ── 4. the exact UI branch: no false `节点不存在` when unknown ───────────
    test('4. fallback pool UI must not show 节点不存在 while the core is down', () {
      // Reproduce the UI expression: `isStale ? '节点不存在' : null`.
      String? subtitleFor(Set<String>? universe, String nodeName) =>
          isFallbackCandidateStale(universe, nodeName) ? '节点不存在' : null;

      final downUniverse = chainNodeUniverse(<String>{});
      for (final node in ['HK-01', 'US-01', 'stale-from-a-previous-sub']) {
        expect(
          subtitleFor(downUniverse, node),
          isNull,
          reason: 'core down must never render 节点不存在 for $node',
        );
      }

      // …while a genuinely missing node in a known universe still does.
      final upUniverse = chainNodeUniverse({'HK-01'});
      expect(subtitleFor(upUniverse, 'HK-01'), isNull);
      expect(subtitleFor(upUniverse, 'GONE-99'), '节点不存在');
    });

    // ── regression guard: a known universe is a non-null, non-empty set ────
    test('5. known universe is preserved verbatim', () {
      final universe = chainNodeUniverse({'A', 'B'});
      expect(universe, equals({'A', 'B'}));
      expect(isFallbackCandidateStale(universe, 'A'), isFalse);
      expect(isFallbackCandidateStale(universe, 'B'), isFalse);
      expect(isFallbackCandidateStale(universe, 'C'), isTrue);
    });
  });
}
