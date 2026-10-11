import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';

void main() {
  group('Protocol Capability Intelligence Layer', () {
    test('Parses udp:true as VERIFIED_SUPPORTED', () {
      final meta = {'udp': true, 'type': 'vless'};
      final profile = ChainCapabilityService.parseFromConfig(meta);
      expect(profile.udp.status, CapabilityStatus.verifiedSupported);
      expect(profile.udp.evidence, CapabilityEvidenceType.configDeclared);
    });

    test('Parses missing udp as UNKNOWN', () {
      final meta = {'type': 'vless'};
      final profile = ChainCapabilityService.parseFromConfig(meta);
      expect(profile.udp.status, CapabilityStatus.unknown);
      expect(profile.udp.evidence, CapabilityEvidenceType.unknown);
    });

    test('Compatibility Gate does NOT hard-reject UNKNOWN VLESS -> HY2', () {
      final p1 = const ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.unknown,
        ),
      );
      final p2 = const ProtocolCapabilityProfile(
        protocol: 'hysteria2',
        tcp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
        udp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );

      final res = ChainCompatibilityValidator.validateEdge(p1, p2);
      // P1.2: `unknown` = insufficient evidence, not `unsupported`.
      expect(res.compatible, isTrue);
      expect(res.reason, isNot('ENTRY_UDP_CAPABILITY_UNKNOWN'));
    });

    test('Compatibility Gate allows VERIFIED_SUPPORTED VLESS -> HY2', () {
      final p1 = const ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
        udp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );
      final p2 = const ProtocolCapabilityProfile(
        protocol: 'hysteria2',
        tcp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
        udp: CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );

      final res = ChainCompatibilityValidator.validateEdge(p1, p2);
      expect(res.compatible, isTrue);
    });
  });
}
