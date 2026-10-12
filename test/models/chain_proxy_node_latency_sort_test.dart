import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/services/chain_adaptive_ranking_cache_service.dart';

/// P1.3-C4-Step5 — the 「延迟」 sort rule (`ChainProxyNodeViewModel.compareByLatency`).
///
/// Decision Q1 + Q7: the rule is extracted so it is independently testable (no
/// provider harness needed), and it must:
///   · rank nodes that have a valid latency first, ascending;
///   · sink unknowns (`latencyMs == null`) to the end;
///   · keep unknowns — and equal values — in a deterministic name order, since
///     `List.sort` is not stable;
///   · never treat `null` as `0 ms`.
///
/// P2 (option 3) adds the no-data contract on top: with nothing measured the
/// fallback must stay the documented name order (never a fabricated value, never
/// a silent switch to the Smart order), and the sort mode must be part of the
/// cache identity so one mode can never serve another mode's cached list.
void main() {
  ChainProxyNodeViewModel node(String name, int? latencyMs) {
    return ChainProxyNodeViewModel(
      proxy: Proxy(name: name, type: 'SS'),
      nodeName: name,
      latencyMs: latencyMs,
    );
  }

  List<String> sortedNames(List<ChainProxyNodeViewModel> nodes) {
    final list = [...nodes]..sort(ChainProxyNodeViewModel.compareByLatency);
    return list.map((n) => n.nodeName).toList();
  }

  group('ChainProxyNodeViewModel.compareByLatency — Step5 latency sort', () {
    test('C1. valid latencies first (ascending), unknown sinks to the end', () {
      expect(
        sortedNames([node('C-unknown', null), node('B-200ms', 200), node('A-50ms', 50)]),
        ['A-50ms', 'B-200ms', 'C-unknown'],
      );
    });

    test('C2. unknowns keep a deterministic (name) order — List.sort is unstable',
        () {
      expect(
        sortedNames([node('UnknownB', null), node('UnknownA', null)]),
        ['UnknownA', 'UnknownB'],
      );
    });

    test('C3. equal latencies fall back to name order', () {
      expect(
        sortedNames([node('Zeta', 100), node('Alpha', 100)]),
        ['Alpha', 'Zeta'],
      );
    });

    test('C4. null is NOT treated as 0 ms', () {
      expect(
        sortedNames([node('Unknown', null), node('Zero', 0)]),
        ['Zero', 'Unknown'],
        reason: 'a 0 ms reading must still outrank a missing one',
      );
    });
  });

  // ── P2 (option 3): the no-data case must be honest ────────────────────────
  group('P2 — latency sort with missing data', () {
    test('D1. all-unknown falls back to a stable name order', () {
      expect(
        sortedNames([
          node('Charlie', null),
          node('Alpha', null),
          node('Bravo', null),
        ]),
        ['Alpha', 'Bravo', 'Charlie'],
        reason:
            'no measurement → the documented name-order fallback, never a '
            'fabricated 0 ms and never the Smart order',
      );
    });

    test('D2. partial data: measured nodes ascend, unmeasured sink in name order',
        () {
      expect(
        sortedNames([
          node('Z-unmeasured', null),
          node('B-300', 300),
          node('A-unmeasured', null),
          node('C-100', 100),
        ]),
        ['C-100', 'B-300', 'A-unmeasured', 'Z-unmeasured'],
      );
    });

    test('D3. repeated sorts of the same input are identical (List.sort is unstable)',
        () {
      final input = [
        node('B', null),
        node('A', null),
        node('D', 10),
        node('C', null),
      ];
      final first = sortedNames(input);
      for (var i = 0; i < 5; i++) {
        expect(sortedNames(input), first);
      }
    });

    test('D4. a measured latency that becomes available reorders the list', () {
      final unmeasured = sortedNames([node('Alpha', null), node('Zulu', null)]);
      final measured = sortedNames([node('Alpha', 500), node('Zulu', 20)]);

      expect(unmeasured, ['Alpha', 'Zulu'], reason: 'name order while unknown');
      expect(
        measured,
        ['Zulu', 'Alpha'],
        reason: 'real values must take over once they exist',
      );
    });
  });

  // ── P2: the sort mode is part of the cache identity ───────────────────────
  group('P2 — switching sort mode cannot reuse another mode\'s result', () {
    ChainAdaptiveRankingCacheKey key(String sortMode) =>
        ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.exit,
          networkFingerprint: 'net-1',
          sortMode: sortMode,
        );

    test('E1. the same role+network with a different sortMode is a different key',
        () {
      expect(key('latency') == key('adaptive'), isFalse);
      expect(key('latency') == key('name'), isFalse);
      expect(key('adaptive') == key('name'), isFalse);
    });

    test('E2. the same sortMode is the same key (and hashes equal)', () {
      expect(key('latency') == key('latency'), isTrue);
      expect(key('latency').hashCode, key('latency').hashCode);
    });

    test('E3. a different role or network is still a different key', () {
      final base = ChainAdaptiveRankingCacheKey(
        role: FallbackCandidateRole.exit,
        networkFingerprint: 'net-1',
        sortMode: 'latency',
      );
      expect(
        base ==
            ChainAdaptiveRankingCacheKey(
              role: FallbackCandidateRole.entry,
              networkFingerprint: 'net-1',
              sortMode: 'latency',
            ),
        isFalse,
      );
      expect(
        base ==
            ChainAdaptiveRankingCacheKey(
              role: FallbackCandidateRole.exit,
              networkFingerprint: 'net-2',
              sortMode: 'latency',
            ),
        isFalse,
      );
    });
  });
}
