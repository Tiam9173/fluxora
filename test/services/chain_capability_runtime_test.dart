import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_cache_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';

void main() {
  setUp(() {
    ChainCapabilityCacheService.clear();
  });

  group('Phase 5.5-C — Capability Intelligence Runtime Verification', () {
    test('1. unknown node NOT blocked (vless -> hy2)', () {
      final entryConfig = {'type': 'vless', 'server': 'A'};
      final exitConfig = {'type': 'hysteria2', 'server': 'B'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      // P1.2: `unknown` = insufficient evidence, not `unsupported`. It must not
      // be a hard reject — only explicit negative evidence (unsupported /
      // runtimeRejected) blocks a candidate.
      expect(result.compatible, isTrue);
      expect(result.reason, isNot('ENTRY_UDP_CAPABILITY_UNKNOWN'));
    });

    test('2. configDeclared udp=true allowed', () {
      final entryConfig = {'type': 'vless', 'server': 'A', 'udp': true};
      final exitConfig = {'type': 'hysteria2', 'server': 'B'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      expect(result.compatible, isTrue);
    });

    test('3. runtimeVerified overrides unknown', () {
      final entryConfig = {'type': 'vless', 'server': 'A'};
      final exitConfig = {'type': 'hysteria2', 'server': 'B'};

      // Initially unknown
      var entryProfile = ChainCapabilityService.getCapability(entryConfig);
      expect(entryProfile.udp.evidence, equals(CapabilityEvidenceType.unknown));

      // Simulate runtime verification success
      final verifiedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, verifiedProfile);

      entryProfile = ChainCapabilityService.getCapability(entryConfig);
      expect(
        entryProfile.udp.evidence,
        equals(CapabilityEvidenceType.runtimeVerified),
      );

      final exitProfile = ChainCapabilityService.getCapability(exitConfig);
      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      expect(result.compatible, isTrue);
    });

    test('4. runtimeRejected blocks healthy configDeclared node', () {
      // User sets udp: true in config
      final entryConfig = {'type': 'vless', 'server': 'A', 'udp': true};
      final exitConfig = {'type': 'hysteria2', 'server': 'B'};

      // Simulate runtime verification failure (node lies about UDP)
      final rejectedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeRejected,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedUnsupported,
          evidence: CapabilityEvidenceType.runtimeRejected,
        ),
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, rejectedProfile);

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      // Priority: runtimeRejected > configDeclared
      expect(
        entryProfile.udp.evidence,
        equals(CapabilityEvidenceType.runtimeRejected),
      );

      final exitProfile = ChainCapabilityService.getCapability(exitConfig);
      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      expect(result.compatible, isFalse);
      expect(result.reason, equals('ENTRY_UDP_RUNTIME_REJECTED'));
    });

    test('5. expired evidence returns unknown', () {
      final entryConfig = {'type': 'vless', 'server': 'A'};

      final verifiedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      // Mock timestamp to 31 mins ago (expired)
      final expiredTime = DateTime.now().subtract(const Duration(minutes: 31));
      ChainCapabilityCacheService.set(
        cacheKey,
        verifiedProfile,
        overrideTimestamp: expiredTime,
      );

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      expect(entryProfile.udp.evidence, equals(CapabilityEvidenceType.expired));

      final exitProfile = ChainCapabilityService.getCapability({
        'type': 'hysteria2',
        'server': 'B',
      });
      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      expect(result.compatible, isFalse);
      expect(result.reason, equals('ENTRY_UDP_CAPABILITY_EXPIRED'));
    });

    test('6. cache invalidates after node mutation', () {
      final entryConfig = {'type': 'vless', 'server': 'A', 'port': 443};

      final verifiedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, verifiedProfile);

      // Node mutated (port changed)
      final mutatedConfig = {'type': 'vless', 'server': 'A', 'port': 8443};
      final mutatedProfile = ChainCapabilityService.getCapability(
        mutatedConfig,
      );

      // Cache miss -> fallback to baseline (unknown)
      expect(mutatedProfile.udp.evidence, equals(CapabilityEvidenceType.unknown));
    });

    test('7. cache fingerprint collision protection', () {
      final entryConfig1 = {'type': 'vless', 'server': 'A', 'uuid': '111'};
      final entryConfig2 = {'type': 'vless', 'server': 'A', 'uuid': '222'};

      final key1 = ChainCapabilityCacheService.generateKey(entryConfig1);
      final key2 = ChainCapabilityCacheService.generateKey(entryConfig2);

      expect(key1, isNot(equals(key2)));
    });

    test('8. 3-Hop edge validation', () {
      // Entry -> Relay -> Exit
      // vless(unknown) -> socks5(supported) -> hysteria2(requires udp)
      final entryConfig = {'type': 'vless', 'server': 'A'};
      final relayConfig = {'type': 'socks5', 'server': 'B'};
      final exitConfig = {'type': 'hysteria2', 'server': 'C'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final relayProfile = ChainCapabilityService.getCapability(relayConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      // Edge 1: Entry -> Relay (Socks5 does not *require* UDP from entry, just supports it)
      final edge1 = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        relayProfile,
      );
      expect(edge1.compatible, isTrue);

      // Edge 2: Relay -> Exit (HY2 requires UDP; Socks5 baseline is `unknown`,
      // which is insufficient evidence, not a hard reject)
      final edge2 = ChainCompatibilityValidator.validateEdge(
        relayProfile,
        exitProfile,
      );
      expect(edge2.compatible, isTrue);
    });

    test('9. Failover does not bypass gate', () async {
      // Failover filter logic relies on ChainCompatibilityValidator in 5.4.
      // We will ensure a node rejected by the validator is excluded from the fallback pool logic
      // or we just assert that Validator blocks it, as we can't test full UI failover easily here.
      // We simulate fallback filtering.

      final candidates = [
        {
          'name': 'C1',
          'type': 'vless',
          'server': 'A',
          'udp': true,
        }, // configDeclared supported (PASS)
        {
          'name': 'C2',
          'type': 'vless',
          'server': 'B',
          'udp': false,
        }, // explicitly unsupported (BLOCK)
        {
          'name': 'C3',
          'type': 'vless',
          'server': 'C',
        }, // runtimeVerified (PASS)
      ];

      // Simulate C3 runtime verified
      final c3Profile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(candidates[2]),
        c3Profile,
      );

      final exitProfile = ChainCapabilityService.getCapability({
        'type': 'hysteria2',
      });

      final validCandidates = candidates.where((c) {
        final profile = ChainCapabilityService.getCapability(c);
        final result = ChainCompatibilityValidator.validateEdge(
          profile,
          exitProfile,
        );
        return result.compatible;
      }).toList();

      expect(validCandidates.length, equals(2));
      expect(validCandidates[0]['name'], equals('C1'));
      expect(validCandidates[1]['name'], equals('C3'));
    });

    test('10. Telemetry unchanged', () {
      // Just assert that standard error strings used by telemetry are strictly ENUM-based
      // and do not leak user secrets.
      final entryConfig = {
        'type': 'vless',
        'server': 'A',
        'password': 'SECRET_PASSWORD',
        'udp': false,
      };
      final exitConfig = {'type': 'hysteria2'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      // Explicitly-unsupported UDP still yields an ENUM-based reason and
      // blocking protocol (P1.2: `unknown` no longer blocks, so this case uses
      // a genuine negative-evidence config).
      expect(result.reason, equals('ENTRY_UDP_UNSUPPORTED'));
      expect(result.blockingProtocol, equals('vless'));

      // Ensure no password leakage in the profile string
      expect(entryProfile.toString(), isNot(contains('SECRET_PASSWORD')));
    });

    // ── K4-C1: `_highest` tie-break ─────────────────────────────────────────
    test('11. K4-C1: a tie resolves to the current config, not the cache', () {
      // Same node identity (cache key unchanged) ⇒ the cache is hit. The cache
      // carries `udp: true` (configDeclared/verifiedSupported) while the
      // *current* config declares `udp: false`
      // (configDeclared/verifiedUnsupported). Same evidence priority ⇒ tie.
      final entryConfig = {'type': 'vless', 'server': 'A', 'udp': false};

      final cachedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(entryConfig),
        cachedProfile,
      );

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);

      // Before P1.2-K4-C1 the cached `verifiedSupported` won the tie and the new
      // `udp: false` declaration stayed masked for the whole TTL window.
      expect(
        entryProfile.udp.evidence,
        equals(CapabilityEvidenceType.configDeclared),
      );
      expect(
        entryProfile.udp.status,
        equals(CapabilityStatus.verifiedUnsupported),
        reason: 'the current config declaration must win the tie',
      );

      // ...and the failover gate now sees the real declaration.
      final exitProfile = ChainCapabilityService.getCapability({
        'type': 'hysteria2',
        'server': 'B',
      });
      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );
      expect(result.compatible, isFalse);
      expect(result.reason, equals('ENTRY_UDP_UNSUPPORTED'));
    });

    test('12. K4-C1: higher cached evidence still wins (no over-correction)', () {
      final entryConfig = {'type': 'vless', 'server': 'A', 'udp': false};

      final verifiedProfile = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(entryConfig),
        verifiedProfile,
      );

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);

      // runtimeVerified (4) > configDeclared (2): runtime evidence must still
      // override the config declaration — the tie fix must not break this.
      expect(
        entryProfile.udp.evidence,
        equals(CapabilityEvidenceType.runtimeVerified),
      );
      expect(
        entryProfile.udp.status,
        equals(CapabilityStatus.verifiedSupported),
      );
      expect(
        entryProfile.tcp.evidence,
        equals(CapabilityEvidenceType.runtimeVerified),
      );
    });

    // ── P1.3-B (K4-C2): canonical cache identity ────────────────────────────
    test('13. K4-C2: distinct credentials produce distinct cache keys', () {
      // The key is a canonical fingerprint of the whole config, so two nodes
      // that differ only by `username` must NOT share a capability entry.
      // Before P1.3-B both hashed to `sha256('socks5|x|443||pw')`.
      final a = {
        'type': 'socks5',
        'server': 'x',
        'port': 443,
        'username': 'userA',
        'password': 'pw',
      };
      final b = {
        'type': 'socks5',
        'server': 'x',
        'port': 443,
        'username': 'userB',
        'password': 'pw',
      };

      expect(
        ChainCapabilityCacheService.generateKey(a),
        isNot(ChainCapabilityCacheService.generateKey(b)),
      );

      // Same for a transport-level difference (`flow`) on identical credentials.
      final flowVision = {
        'type': 'vless',
        'server': 'x',
        'port': 443,
        'uuid': 'U',
        'flow': 'xtls-rprx-vision',
      };
      final flowNone = {...flowVision, 'flow': 'none'};
      expect(
        ChainCapabilityCacheService.generateKey(flowVision),
        isNot(ChainCapabilityCacheService.generateKey(flowNone)),
      );
    });

    test('14. K4-C2: key is insertion-order stable and ignores non-identity keys',
        () {
      final ordered = {
        'type': 'vless',
        'server': 'x',
        'port': 443,
        'uuid': 'U',
        'flow': 'xtls-rprx-vision',
      };
      final shuffled = {
        'flow': 'xtls-rprx-vision',
        'uuid': 'U',
        'port': 443,
        'server': 'x',
        'type': 'vless',
      };

      // Canonical key sorting ⇒ logically equal configs hash identically.
      expect(
        ChainCapabilityCacheService.generateKey(ordered),
        ChainCapabilityCacheService.generateKey(shuffled),
      );

      // `name` is not identity: a rename must keep the same entry.
      expect(
        ChainCapabilityCacheService.generateKey({...ordered, 'name': 'whatever'}),
        ChainCapabilityCacheService.generateKey(ordered),
      );

      // `dialer-proxy` is routing topology, not identity.
      expect(
        ChainCapabilityCacheService.generateKey({
          ...ordered,
          'dialer-proxy': '🔗 链式代理',
        }),
        ChainCapabilityCacheService.generateKey(ordered),
      );

      // ...but a different server MUST change the key.
      expect(
        ChainCapabilityCacheService.generateKey({...ordered, 'server': 'y'}),
        isNot(ChainCapabilityCacheService.generateKey(ordered)),
      );
    });
  });
}
