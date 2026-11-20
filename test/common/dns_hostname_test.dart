import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/dns_override.dart';

void main() {
  test(
    'DNS override retains the hostname used for TLS certificate verification',
    () async {
      final config = <String, dynamic>{
        'dns': {
          'enable': true,
          'listen': '',
          'nameserver': ['127.0.0.1:9'],
          'default-nameserver': ['127.0.0.1'],
          'proxy-server-nameserver': ['127.0.0.1:9'],
          'use-hosts': true,
          'enhanced-mode': 'redir-host',
        },
        'hosts': {
          'node.fixture.test': ['127.0.0.1'],
        },
        'proxies': [
          {
            'name': 'fixture',
            'type': 'http',
            'server': 'node.fixture.test',
            'port': 443,
            'tls': true,
            'skip-cert-verify': false,
          },
        ],
      };
      applyDnsNodeOverride(
        config,
        originalDns: {
          'listen': '0.0.0.0:1053',
          'proxy-server-nameserver': ['127.0.0.1:1053'],
        },
      );
      if (const bool.fromEnvironment('DNS_HOSTS_FIXTURE')) {
        final file = File('build/dns-diagnostics/hosts-output.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode(config));
      }
      expect((config['proxies'] as List).single['server'], 'node.fixture.test');
      expect(config['hosts'], {
        'node.fixture.test': ['127.0.0.1'],
      });
      expect((config['proxies'] as List).single['skip-cert-verify'], false);
    },
  );
}
