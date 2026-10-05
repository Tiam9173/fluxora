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
    test('1. unknown node blocked (vless -> hy2)', () {
      final entryConfig = {'type': 'vless', 'server': 'A'};
      final exitConfig = {'type': 'hysteria2', 'server': 'B'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      expect(result.compatible, isFalse);
      expect(result.reason, equals('ENTRY_UDP_CAPABILITY_UNKNOWN'));
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
      expect(entryProfile.evidence, equals(CapabilityEvidenceType.unknown));

      // Simulate runtime verification success
      final verifiedProfile = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeVerified,
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, verifiedProfile);

      entryProfile = ChainCapabilityService.getCapability(entryConfig);
      expect(
        entryProfile.evidence,
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
      final rejectedProfile = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedUnsupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeRejected,
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, rejectedProfile);

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      // Priority: runtimeRejected > configDeclared
      expect(
        entryProfile.evidence,
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

      final verifiedProfile = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeVerified,
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
      expect(entryProfile.evidence, equals(CapabilityEvidenceType.expired));

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

      final verifiedProfile = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeVerified,
      );

      final cacheKey = ChainCapabilityCacheService.generateKey(entryConfig);
      ChainCapabilityCacheService.set(cacheKey, verifiedProfile);

      // Node mutated (port changed)
      final mutatedConfig = {'type': 'vless', 'server': 'A', 'port': 8443};
      final mutatedProfile = ChainCapabilityService.getCapability(
        mutatedConfig,
      );

      // Cache miss -> fallback to baseline (unknown)
      expect(mutatedProfile.evidence, equals(CapabilityEvidenceType.unknown));
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

      // Edge 2: Relay -> Exit (HY2 requires UDP, Socks5 baseline is verifiedSupported)
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
        }, // configDeclared (PASS)
        {'name': 'C2', 'type': 'vless', 'server': 'B'}, // unknown (BLOCK)
        {
          'name': 'C3',
          'type': 'vless',
          'server': 'C',
        }, // runtimeVerified (PASS)
      ];

      // Simulate C3 runtime verified
      final c3Profile = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeVerified,
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
      };
      final exitConfig = {'type': 'hysteria2'};

      final entryProfile = ChainCapabilityService.getCapability(entryConfig);
      final exitProfile = ChainCapabilityService.getCapability(exitConfig);

      final result = ChainCompatibilityValidator.validateEdge(
        entryProfile,
        exitProfile,
      );

      // Error message should just say ENTRY_UDP_CAPABILITY_UNKNOWN and blocking protocol
      expect(result.reason, equals('ENTRY_UDP_CAPABILITY_UNKNOWN'));
      expect(result.blockingProtocol, equals('vless'));

      // Ensure no password leakage in the profile string
      expect(entryProfile.toString(), isNot(contains('SECRET_PASSWORD')));
    });
  });
}
