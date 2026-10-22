import 'package:fluxora/services/residential_ip_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decideVerdict', () {
    test('a matching exit that is not hosted is usable', () {
      expect(
        ResidentialIpCheckService.decideVerdict(
          exitIp: '38.154.185.97',
          expectedIp: '38.154.185.97',
        ),
        ResidentialIpVerdict.usable,
      );
    });

    test('no exit ip means the proxy could not be reached', () {
      expect(
        ResidentialIpCheckService.decideVerdict(exitIp: null),
        ResidentialIpVerdict.unreachable,
      );
      expect(
        ResidentialIpCheckService.decideVerdict(exitIp: ''),
        ResidentialIpVerdict.unreachable,
      );
    });

    test('a different exit ip is reported as a mismatch', () {
      expect(
        ResidentialIpCheckService.decideVerdict(
          exitIp: '1.2.3.4',
          expectedIp: '38.154.185.97',
        ),
        ResidentialIpVerdict.mismatch,
      );
    });

    test('a hosting/proxy flag downgrades the result', () {
      // 出口对了，但 IP 库认为它是机房：不能用"可用"去骗用户。
      expect(
        ResidentialIpCheckService.decideVerdict(
          exitIp: '38.154.185.97',
          expectedIp: '38.154.185.97',
          looksHosted: true,
        ),
        ResidentialIpVerdict.hosted,
      );
    });

    test('a mismatch outranks the hosting flag', () {
      expect(
        ResidentialIpCheckService.decideVerdict(
          exitIp: '1.2.3.4',
          expectedIp: '38.154.185.97',
          looksHosted: true,
        ),
        ResidentialIpVerdict.mismatch,
      );
    });

    test('without an expectation, the hosting flag is the only filter', () {
      expect(
        ResidentialIpCheckService.decideVerdict(exitIp: '1.2.3.4'),
        ResidentialIpVerdict.usable,
      );
      expect(
        ResidentialIpCheckService.decideVerdict(
          exitIp: '1.2.3.4',
          looksHosted: true,
        ),
        ResidentialIpVerdict.hosted,
      );
    });
  });

  group('describeVerdict', () {
    test('every verdict has a message', () {
      for (final verdict in ResidentialIpVerdict.values) {
        expect(
          ResidentialIpCheckService.describeVerdict(verdict),
          isNotEmpty,
          reason: '$verdict',
        );
      }
    });
  });
}
