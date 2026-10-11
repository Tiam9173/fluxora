import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_cache_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';

/// P1.4 (G7-B1) — capability-cache **capacity cap + LRU eviction**.
///
/// Scope of what is locked down here:
///   · eviction happens **only** on capacity overflow (never on time);
///   · the victim is the least-recently-**used** entry, not merely the oldest
///     inserted one — `get()` counts as a use, so this must not degrade to FIFO;
///   · the 30-minute TTL and its `expired` evidence are unchanged, including for
///     entries that are still retained.
///
/// The cache is process-wide, so every test clears it on the way in and out.
void main() {
  final cap = ChainCapabilityCacheService.maxEntries;

  setUp(ChainCapabilityCacheService.clear);
  tearDown(ChainCapabilityCacheService.clear);

  ProtocolCapabilityProfile profile({
    CapabilityEvidenceType tcp = CapabilityEvidenceType.runtimeVerified,
  }) {
    return ProtocolCapabilityProfile(
      protocol: 'ss',
      tcp: CapabilityState(
        status: CapabilityStatus.verifiedSupported,
        evidence: tcp,
      ),
    );
  }

  /// Fills the cache with `count` distinct keys, oldest first.
  void fill(int count, {String prefix = 'filler'}) {
    for (var i = 0; i < count; i++) {
      ChainCapabilityCacheService.set('$prefix$i', profile());
    }
  }

  group('P1.4 (G7-B1) — capability cache capacity + LRU', () {
    test('1. capacity cap: inserting cap+1 entries evicts the oldest', () {
      fill(cap + 1);

      expect(
        ChainCapabilityCacheService.get('filler0'),
        isNull,
        reason: 'the oldest entry is the eviction victim',
      );
      expect(
        ChainCapabilityCacheService.get('filler$cap'),
        isNotNull,
        reason: 'the newest entry is retained',
      );
      expect(ChainCapabilityCacheService.get('filler1'), isNotNull);
    });

    test('2. LRU protection: a recently READ entry survives eviction', () {
      fill(cap); // cache is now full, filler0 is the LRU
      expect(ChainCapabilityCacheService.get('filler0'), isNotNull);

      // Reading filler0 makes it the MRU, so the victim must be filler1.
      ChainCapabilityCacheService.set('overflow', profile());

      expect(
        ChainCapabilityCacheService.get('filler0'),
        isNotNull,
        reason: 'get() counts as a use — this is what makes it LRU, not FIFO',
      );
    });

    test('3. eviction really happens: the un-read runner-up is dropped', () {
      fill(cap);
      ChainCapabilityCacheService.get('filler0'); // promote filler0 → MRU
      ChainCapabilityCacheService.set('overflow', profile());

      expect(
        ChainCapabilityCacheService.get('filler1'),
        isNull,
        reason:
            'proves eviction occurred and the victim is the least-recently-used '
            'entry, not a no-op',
      );
    });

    test('4. an evicted entry falls back to config-declared capability', () {
      final config = <dynamic, dynamic>{
        'name': 'Node-A',
        'type': 'ss',
        'server': '1.2.3.4',
        'port': 8388,
        'cipher': 'aes-128-gcm',
      };
      final key = ChainCapabilityCacheService.generateKey(config);

      ChainCapabilityCacheService.set(key, profile());
      expect(
        ChainCapabilityService.getCapability(config).tcp.evidence,
        CapabilityEvidenceType.runtimeVerified,
        reason: 'cache hit wins the priority merge',
      );

      fill(cap); // push `key` out of the cache
      expect(
        ChainCapabilityCacheService.get(key),
        isNull,
        reason: 'the entry was evicted by capacity',
      );

      expect(
        ChainCapabilityService.getCapability(config).tcp.evidence,
        isNot(CapabilityEvidenceType.runtimeVerified),
        reason:
            'expected fallback: with no cache entry, getCapability returns the '
            'config-declared profile (existing semantics, now covered)',
      );
    });

    test('5. the 30-minute TTL is unchanged: stale entries still return '
        '`expired`, never null', () {
      final stale = DateTime.now().subtract(const Duration(minutes: 31));
      ChainCapabilityCacheService.set('stale', profile(), overrideTimestamp: stale);

      final result = ChainCapabilityCacheService.get('stale');

      expect(result, isNotNull, reason: 'expiry is evidence, not eviction');
      expect(result!.tcp.evidence, CapabilityEvidenceType.expired);
      expect(result.tls.evidence, CapabilityEvidenceType.expired);
      expect(result.udp.evidence, CapabilityEvidenceType.expired);
    });

    test('6. reading a retained stale entry repeatedly is stable '
        '(the LRU touch does not change the result)', () {
      final stale = DateTime.now().subtract(const Duration(minutes: 31));
      ChainCapabilityCacheService.set('stale', profile(), overrideTimestamp: stale);

      final first = ChainCapabilityCacheService.get('stale');
      final second = ChainCapabilityCacheService.get('stale');

      expect(first!.tcp.evidence, CapabilityEvidenceType.expired);
      expect(second!.tcp.evidence, CapabilityEvidenceType.expired);
    });
  });
}
