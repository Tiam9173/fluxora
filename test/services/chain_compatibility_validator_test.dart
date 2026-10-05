import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';
import 'package:fluxora/models/protocol_capability.dart';

import 'package:fluxora/services/chain_capability_service.dart';

ProtocolCapabilityProfile p(String protocol) {
  return ChainCapabilityService.getBaselineCapability(protocol);
}

void main() {
  group('ChainCompatibilityValidator', () {
    test('1. TCP compatible (VLESS -> VLESS)', () {
      final res = ChainCompatibilityValidator.validateEdge(
        p('vless'),
        p('vless'),
      );
      expect(res.compatible, isTrue);
    });

    test('2. TCP compatible (Trojan -> VMess)', () {
      final res = ChainCompatibilityValidator.validateEdge(
        p('trojan'),
        p('vmess'),
      );
      expect(res.compatible, isTrue);
    });

    test('3. UDP native -> UDP required (Hysteria2 -> TUIC)', () {
      final res = ChainCompatibilityValidator.validateEdge(
        p('hysteria2'),
        p('tuic'),
      );
      expect(res.compatible, isTrue);
    });

    test('4. UDP native -> UDP required (SOCKS5 -> WireGuard)', () {
      final res = ChainCompatibilityValidator.validateEdge(
        p('socks5'),
        p('wireguard'),
      );
      expect(res.compatible, isTrue);
    });

    test('5. TCP only -> UDP required (HTTP -> Hysteria2) -> Incompatible', () {
      final res = ChainCompatibilityValidator.validateEdge(
        p('http'),
        p('hysteria2'),
      );
      expect(res.compatible, isFalse);
      expect(res.reason, 'ENTRY_UDP_UNSUPPORTED');
      expect(res.blockingProtocol, 'http');
    });

    test(
      '6. UDP conditional -> UDP required (VLESS -> Hysteria2) -> Incompatible',
      () {
        final res = ChainCompatibilityValidator.validateEdge(
          p('vless'),
          p('hysteria2'),
        );
        expect(res.compatible, isFalse);
        expect(res.reason, 'ENTRY_UDP_CAPABILITY_UNKNOWN');
        expect(res.blockingProtocol, 'vless');
      },
    );

    test(
      '7. UDP conditional -> UDP required (VMess -> TUIC) -> Incompatible',
      () {
        final res = ChainCompatibilityValidator.validateEdge(
          p('vmess'),
          p('tuic'),
        );
        expect(res.compatible, isFalse);
        expect(res.reason, 'ENTRY_UDP_CAPABILITY_UNKNOWN');
        expect(res.blockingProtocol, 'vmess');
      },
    );

    test(
      '8. Unknown -> UDP required (unknown_proxy -> WireGuard) -> Incompatible',
      () {
        final res = ChainCompatibilityValidator.validateEdge(
          p('unknown_proxy'),
          p('wireguard'),
        );
        expect(res.compatible, isFalse);
        expect(res.reason, 'ENTRY_UDP_CAPABILITY_UNKNOWN');
        expect(res.blockingProtocol, 'unknown_proxy');
      },
    );

    test('9. Missing proxy type -> Should ignore and pass', () {
      final res = ChainCompatibilityValidator.validateEdge(
        null,
        p('hysteria2'),
      );
      expect(res.compatible, isTrue);
    });

    test('10. Missing exit type -> Should ignore and pass', () {
      final res = ChainCompatibilityValidator.validateEdge(p('vless'), p(''));
      expect(res.compatible, isTrue);
    });
  });
}
