import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';

void main() {
  group('Protocol Capability Intelligence Layer', () {
    test('Parses udp:true as VERIFIED_SUPPORTED', () {
      final meta = {'udp': true, 'type': 'vless'};
      final profile = ChainCapabilityService.parseFromConfig(meta);
      expect(profile.udpCapability, CapabilityStatus.verifiedSupported);
      expect(profile.evidence, CapabilityEvidenceType.configDeclared);
    });

    test('Parses missing udp as UNKNOWN', () {
      final meta = {'type': 'vless'};
      final profile = ChainCapabilityService.parseFromConfig(meta);
      expect(profile.udpCapability, CapabilityStatus.unknown);
      expect(profile.evidence, CapabilityEvidenceType.unknown);
    });

    test('Compatibility Gate blocks UNKNOWN VLESS -> HY2', () {
      final p1 = const ProtocolCapabilityProfile(
        protocol: 'vless',
        udpCapability: CapabilityStatus.unknown,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.unknown,
      );
      final p2 = const ProtocolCapabilityProfile(
        protocol: 'hysteria2',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.configDeclared,
      );

      final res = ChainCompatibilityValidator.validateEdge(p1, p2);
      expect(res.compatible, isFalse);
      expect(res.reason, contains('UNKNOWN'));
    });

    test('Compatibility Gate allows VERIFIED_SUPPORTED VLESS -> HY2', () {
      final p1 = const ProtocolCapabilityProfile(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.configDeclared,
      );
      final p2 = const ProtocolCapabilityProfile(
        protocol: 'hysteria2',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.configDeclared,
      );

      final res = ChainCompatibilityValidator.validateEdge(p1, p2);
      expect(res.compatible, isTrue);
    });
  });
}
