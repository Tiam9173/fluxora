import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDnsOutput', () {
    test('reads the servers of the requested link', () {
      const output = 'Global: 8.8.8.8\n'
          'Link 2 (wlan0): 192.168.1.1 223.5.5.5\n';
      expect(LinuxSystemDns.parseDnsOutput(output, 'wlan0'), [
        '192.168.1.1',
        '223.5.5.5',
      ]);
    });

    test('a link without servers yields an empty list, not null', () {
      // 空列表和 null 是两件事：前者表示"这条链路本来就没配 DNS"，
      // 后者表示"没找到这条链路"。恢复时前者走 revert。
      const output = 'Global: 8.8.8.8\nLink 2 (eth0):\n';
      expect(LinuxSystemDns.parseDnsOutput(output, 'eth0'), isEmpty);
    });

    test('an unknown link yields null', () {
      const output = 'Global: 8.8.8.8\nLink 2 (eth0): 1.1.1.1\n';
      expect(LinuxSystemDns.parseDnsOutput(output, 'wlan0'), isNull);
    });

    test('does not confuse a link name that contains another', () {
      // (eth0) 不能匹配到 (eth0.100)
      const output = 'Link 3 (eth0.100): 9.9.9.9\nLink 2 (eth0): 1.1.1.1\n';
      expect(LinuxSystemDns.parseDnsOutput(output, 'eth0'), ['1.1.1.1']);
    });
  });
}
