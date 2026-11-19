import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/clash_config.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  test(
    'DNS override defaults have independent bootstrap and no system wildcard',
    () {
      const dns = Dns();
      expect(dns.nameserver, [
        'https://dns.alidns.com/dns-query',
        'https://doh.pub/dns-query',
      ]);
      expect(dns.nameserverPolicy, isEmpty);
      expect(dns.proxyServerNameserver.length, 2);
      expect(dns.defaultNameserver, ['223.5.5.5', '119.29.29.29']);
      expect(dns.fakeIpFilter.any((v) => v.startsWith('geosite:')), isFalse);
      if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        File(
          'build/feedback_fixes/dns-defaults.json',
        ).writeAsStringSync(jsonEncode(dns.toJson()));
      }
    },
  );
  test('exact legacy DNS defaults migrate while customized values survive', () {
    final dns = Dns.safeDnsFromJson({
      'proxy-server-nameserver': ['https://120.53.53.53/dns-query#DIRECT'],
      'nameserver-policy': {
        '+.internal.corp.com': '10.0.0.1',
        'geosite:cn': '119.29.29.29',
        'geosite:private': 'system',
        '*': 'system',
      },
    });
    expect(dns.proxyServerNameserver, const Dns().proxyServerNameserver);
    expect(dns.nameserverPolicy, isEmpty);
    final custom = Dns.safeDnsFromJson({
      'proxy-server-nameserver': ['https://office.example/dns-query'],
      'nameserver-policy': {'*.corp': '10.0.0.53'},
    });
    expect(custom.proxyServerNameserver, ['https://office.example/dns-query']);
    expect(custom.nameserverPolicy, {'*.corp': '10.0.0.53'});
  });
}
