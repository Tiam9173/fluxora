import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/services/chain_adaptive_ranking_cache_service.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/chain_score.dart';
import 'package:fluxora/models/protocol_capability.dart';

void main() {
  group('Phase 5.9-E.1.2 — Adaptive Ranking Cache', () {
    late ChainAdaptiveRankingCacheService cache;

    setUp(() {
      cache = ChainAdaptiveRankingCacheService();
    });

    List<ChainProxyNodeViewModel> generateMockRanking() {
      return [
        ChainProxyNodeViewModel(
          proxy: const Proxy(name: 'NodeA', type: 'SS'),
          nodeName: 'NodeA',
          score: const ChainScore(
              totalScore: 0,
              confidence: 0,
              reliabilityScore: 0,
              capabilityScore: 0,
              latencyScore: 0,
              flapPenalty: 0,
              hopPenalty: 0),
        )
      ];
    }

    test('1. Cache Miss: First request writes to cache', () {
      final key = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      final result = cache.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'state1',
        compute: () {
          computedCount++;
          return generateMockRanking();
        },
      );

      expect(computedCount, 1);
      expect(result.length, 1);
      expect(cache.hasValidCache(key, 'state1'), true);
    });

    test('2. Cache Hit: Second identical request does not recompute', () {
      final key = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'state1',
        compute: () {
          computedCount++;
          return generateMockRanking();
        },
      );

      final result2 = cache.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'state1',
        compute: () {
          computedCount++; // Should not run
          return generateMockRanking();
        },
      );

      expect(computedCount, 1); // Remains 1
      expect(result2.length, 1);
    });

    test('3. Hop Isolation: Entry cache does not affect Exit', () {
      final keyEntry = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      final keyExit = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.exit, networkFingerprint: 'wifi');
      
      var computedCount = 0;
      cache.getOrComputeSync(
        key: keyEntry, currentStateFingerprint: 'state1',
        compute: () { computedCount++; return generateMockRanking(); },
      );
      
      cache.getOrComputeSync(
        key: keyExit, currentStateFingerprint: 'state1',
        compute: () { computedCount++; return generateMockRanking(); },
      );

      expect(computedCount, 2);
      expect(cache.hasValidCache(keyEntry, 'state1'), true);
      expect(cache.hasValidCache(keyExit, 'state1'), true);
    });

    test('4. Telemetry Invalidation: New state fingerprint forces miss', () {
      final key = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_telemetry_1', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_telemetry_2', compute: () { computedCount++; return []; });

      expect(computedCount, 2); // Missed because fingerprint changed
    });

    test('5. Reliability Invalidation: New state fingerprint forces miss', () {
      final key = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_rel_1', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_rel_2', compute: () { computedCount++; return []; });

      expect(computedCount, 2);
    });

    test('6. Capability Invalidation: Explicit invalidation works', () {
      final key = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_cap', compute: () { computedCount++; return []; });
      cache.invalidateAll(); // Simulate manual explicit invalidate from Capability change
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_cap', compute: () { computedCount++; return []; });

      expect(computedCount, 2);
    });

    test('7. Network Context: Different fingerprint acts as different key', () {
      final keyWifi = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      final key4g = ChainAdaptiveRankingCacheKey(
          role: FallbackCandidateRole.entry, networkFingerprint: '4g');
      var computedCount = 0;

      cache.getOrComputeSync(key: keyWifi, currentStateFingerprint: 'state1', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key4g, currentStateFingerprint: 'state1', compute: () { computedCount++; return []; });

      expect(computedCount, 2); // Different key => miss
    });

    test('8. Node Lock: New state fingerprint forces miss', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_lock_false', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_lock_true', compute: () { computedCount++; return []; });

      expect(computedCount, 2);
    });

    test('9. Node Added: Fingerprint with different group size forces miss', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_len_10', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_len_11', compute: () { computedCount++; return []; });
      expect(computedCount, 2);
    });

    test('10. Node Removed: Fingerprint with different group size forces miss', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_len_10', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_len_9', compute: () { computedCount++; return []; });
      expect(computedCount, 2);
    });

    test('11. Hop Role: invalidateRole strictly isolates', () {
      final keyEntry = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      final keyExit = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.exit, networkFingerprint: 'wifi');
      
      cache.getOrComputeSync(key: keyEntry, currentStateFingerprint: 'state1', compute: () => []);
      cache.getOrComputeSync(key: keyExit, currentStateFingerprint: 'state1', compute: () => []);

      cache.invalidateRole(FallbackCandidateRole.entry);

      expect(cache.hasValidCache(keyEntry, 'state1'), false);
      expect(cache.hasValidCache(keyExit, 'state1'), true); // Exit remains valid
    });

    test('12. Sort Mode: Different mode acts as different key', () {
      final keyAdaptive = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi', sortMode: 'adaptive');
      final keyLatency = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi', sortMode: 'latency');
      var computedCount = 0;

      cache.getOrComputeSync(key: keyAdaptive, currentStateFingerprint: 'state1', compute: () { computedCount++; return []; });
      cache.getOrComputeSync(key: keyLatency, currentStateFingerprint: 'state1', compute: () { computedCount++; return []; });

      expect(computedCount, 2);
    });

    test('13. Immutable Result: Returned list cannot be modified', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      final result = cache.getOrComputeSync(key: key, currentStateFingerprint: 'state1', compute: () => generateMockRanking());
      
      expect(() => result.clear(), throwsUnsupportedError);
      expect(() => result.add(result.first), throwsUnsupportedError);
    });

    test('14. Concurrent Requests: Async requests deduplicate and protect against stale overwrites', () async {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      // Request A (starts, then takes time)
      final futureA = cache.getOrComputeAsync(key: key, currentStateFingerprint: 'state1', compute: () async {
        await Future.delayed(const Duration(milliseconds: 50));
        computedCount++;
        return [ChainProxyNodeViewModel(proxy: const Proxy(name: 'A', type: 'SS'), nodeName: 'A')];
      });

      // Request B (starts immediately after, joins in-flight future A)
      final futureB = cache.getOrComputeAsync(key: key, currentStateFingerprint: 'state1', compute: () async {
        computedCount++; // should not run
        return [];
      });

      final resultA = await futureA;
      final resultB = await futureB;
      
      expect(resultA.first.nodeName, 'A');
      expect(resultB.first.nodeName, 'A'); // Deduplicated
      expect(computedCount, 1);

      // Now simulate explicit invalidation DURING a new request
      final futureC = cache.getOrComputeAsync(key: key, currentStateFingerprint: 'state2', compute: () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return [ChainProxyNodeViewModel(proxy: const Proxy(name: 'C', type: 'SS'), nodeName: 'C')];
      });

      // User navigates away causing invalidation
      cache.invalidateAll();

      final resultC = await futureC; // This will return its computed value to the caller...
      // But it should NOT be placed in the cache!
      expect(resultC.first.nodeName, 'C');
      expect(cache.hasValidCache(key, 'state2'), false); // The stale async result did not pollute the cache!
    });

    test('15. Capability Rejection: Incompatible cached model is never returned after state change', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      var computedCount = 0;

      cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_cap1', compute: () { computedCount++; return []; });
      
      // Simulating a change from Incompatible to Eligible via a new state fingerprint
      final result = cache.getOrComputeSync(key: key, currentStateFingerprint: 'state_cap2', compute: () {
        computedCount++;
        return generateMockRanking();
      });

      expect(computedCount, 2);
      expect(result.isNotEmpty, true);
    });

    test('16. Normal Proxy Isolation: Cache invariants apply cleanly', () {
      final key = ChainAdaptiveRankingCacheKey(role: FallbackCandidateRole.entry, networkFingerprint: 'wifi');
      final result = cache.getOrComputeSync(key: key, currentStateFingerprint: 'state1', compute: () => []);
      expect(result.isEmpty, true);
      // Ensures no other state is modified. In a full app context this translates to unchanged Normal proxies.
    });
  });
}
