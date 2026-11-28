import 'package:fluxora/common/dns_override.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bootstrap = ['192.0.2.53'];

  test(
    'private DNS endpoint uses bootstrap and bypasses proxy only for DoT',
    () {
      final config = <String, dynamic>{
        'dns': <String, dynamic>{
          'enable': true,
          'default-nameserver': bootstrap,
          'nameserver': ['system'],
          'nameserver-policy': {
            'geosite:private': ['system'],
            '+.internal.example': ['https://office.example/dns-query'],
          },
        },
        'rules': ['DOMAIN,blocked.example,REJECT', 'MATCH,Proxy'],
      };
      applyAndroidPrivateDnsServer(config, 'Dns.Private.Example.');
      applyAndroidPrivateDnsRules(config, 'Dns.Private.Example.');
      applyAndroidPrivateDnsRules(config, 'dns.private.example');
      expect(config['dns']['nameserver-policy'], {
        'geosite:private': ['tls://dns.private.example:853#DIRECT'],
        '+.internal.example': ['https://office.example/dns-query'],
        'dns.private.example': bootstrap,
      });
      expect(
        (config['dns']['nameserver-policy'] as Map).keys.first,
        'dns.private.example',
      );
      expect(config['rules'], [
        'AND,((DOMAIN,dns.private.example),(NETWORK,TCP),(DST-PORT,853)),DIRECT',
        'DOMAIN,blocked.example,REJECT',
        'MATCH,Proxy',
      ]);
    },
  );

  test(
    'private DNS cannot bootstrap through itself or inject routing rules',
    () {
      final config = <String, dynamic>{
        'dns': <String, dynamic>{
          'enable': true,
          'default-nameserver': ['tls://dns.private.example:853#DIRECT'],
        },
        'rules': ['MATCH,Proxy'],
      };
      applyAndroidPrivateDnsServer(config, 'dns.private.example');
      expect(config['dns']['nameserver-policy'], {
        'dns.private.example': ['system'],
      });
      for (final host in ['', '192.0.2.53', 'resolver.example),REJECT']) {
        applyAndroidPrivateDnsRules(config, host);
      }
      expect(config['rules'], ['MATCH,Proxy']);
    },
  );

  test('adds strict private DNS host to a mode-independent bypass list', () {
    final config = <String, dynamic>{
      'dns': <String, dynamic>{'enable': true, 'enhanced-mode': 'fake-ip'},
    };
    applyAndroidPrivateDnsServer(config, 'Dns.Private.Example.');
    applyPrivateDnsBypass(config, 'Dns.Private.Example.');
    applyAndroidPrivateDnsServer(config, 'dns.private.example');
    applyPrivateDnsBypass(config, 'dns.private.example');
    expect(config['dns']['fake-ip-filter-bypass'], ['dns.private.example']);
    expect(config['dns']['nameserver'], [
      'tls://dns.private.example:853#DIRECT',
    ]);
    expect(config['dns']['fallback'], [
      'https://dns.alidns.com/dns-query#DIRECT',
      'https://doh.pub/dns-query#DIRECT',
    ]);
    expect(config['dns']['fallback-lazy-query'], isTrue);
  });

  test('bypasses Android Private DNS hostnames from fake-IP', () {
    final config = <String, dynamic>{
      'dns': {
        'enable': true,
        'enhanced-mode': 'fake-ip',
        'nameserver': bootstrap,
        'fake-ip-filter-bypass': ['existing.example'],
      },
    };

    applyAndroidPrivateDnsServer(config, 'Resolver.Private.Example.');
    applyPrivateDnsBypass(config, 'Resolver.Private.Example.');
    applyPrivateDnsBypass(config, 'resolver.private.example');

    expect(config['dns']['fake-ip-filter-bypass'], [
      'existing.example',
      'resolver.private.example',
    ]);
    expect(config['dns']['nameserver'], [
      'tls://resolver.private.example:853#DIRECT',
    ]);
    expect(config['dns']['fallback'], ['192.0.2.53']);
    expect(config['dns']['fallback-lazy-query'], isTrue);
  });

  test('does not add IP addresses and keeps redir-host on Private DNS', () {
    final fakeIp = <String, dynamic>{
      'dns': <String, dynamic>{'enable': true, 'enhanced-mode': 'fake-ip'},
    };
    final redirHost = <String, dynamic>{
      'dns': <String, dynamic>{'enable': true, 'enhanced-mode': 'redir-host'},
    };

    applyAndroidPrivateDnsServer(fakeIp, '192.0.2.53');
    applyPrivateDnsBypass(fakeIp, '192.0.2.53');
    applyAndroidPrivateDnsServer(redirHost, 'resolver.private.example');
    applyPrivateDnsBypass(redirHost, 'resolver.private.example');

    expect(fakeIp['dns'].containsKey('fake-ip-filter-bypass'), isFalse);
    expect(redirHost['dns']['nameserver'], [
      'tls://resolver.private.example:853#DIRECT',
    ]);
    expect(redirHost['dns'].containsKey('fake-ip-filter-bypass'), isFalse);
  });

  test('uses encrypted fallback when Private DNS is the only resolver', () {
    final config = <String, dynamic>{
      'dns': {
        'enable': true,
        'enhanced-mode': 'redir-host',
        'nameserver': ['tls://resolver.private.example:853'],
      },
    };

    applyAndroidPrivateDnsServer(config, 'resolver.private.example');
    applyPrivateDnsBypass(config, 'resolver.private.example');

    expect(config['dns']['nameserver'], [
      'tls://resolver.private.example:853#DIRECT',
    ]);
    expect(config['dns']['fallback'], [
      'https://dns.alidns.com/dns-query#DIRECT',
      'https://doh.pub/dns-query#DIRECT',
    ]);
  });

  test('replaces system nameserver policies without rewriting hostnames', () {
    final config = <String, dynamic>{
      'dns': <String, dynamic>{
        'enable': true,
        'enhanced-mode': 'fake-ip',
        'nameserver-policy': <String, dynamic>{
          'geosite:private': ['system'],
          'geosite:cn': 'https://resolver.example/dns-query',
          'internal.example': 'dhcp://system',
        },
      },
      'proxies': <dynamic>[
        {'name': 'tls-node', 'server': 'edge.example.test'},
      ],
    };

    applyAndroidPrivateDnsServer(config, 'Resolver.Private.Example.');
    applyPrivateDnsBypass(config, 'Resolver.Private.Example.');

    expect(config['dns']['nameserver-policy'], {
      'resolver.private.example': ['system'],
      'geosite:private': ['tls://resolver.private.example:853#DIRECT'],
      'geosite:cn': 'https://resolver.example/dns-query',
      'internal.example': 'tls://resolver.private.example:853#DIRECT',
    });
    expect(config['proxies'], [
      {'name': 'tls-node', 'server': 'edge.example.test'},
    ]);
  });

  test('drops self-referencing bootstrap DNS from mixed lists and policy', () {
    final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
    applyDnsNodeOverride(
      {
        'dns': dns,
        'proxies': [
          {'server': 'edge.example.test'},
        ],
      },
      originalDns: {
        'listen': '0.0.0.0:1053',
        'proxy-server-nameserver': ['127.0.0.1:1053', '192.0.2.80:53'],
        'proxy-server-nameserver-policy': {
          'edge.example.test': ['tcp://127.0.0.1:1053#DIRECT', '192.0.2.81:53'],
        },
      },
    );
    expect(dns['proxy-server-nameserver'], ['192.0.2.80:53']);
    expect(dns['proxy-server-nameserver-policy'], {
      'edge.example.test': ['192.0.2.81:53'],
    });
  });

  test('preserves private DNS endpoints and keeps their original order', () {
    const privateDoh =
        'https://resolver.office.test/cloudflare?upstream=dns.google';
    final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
    applyDnsNodeOverride(
      {'dns': dns},
      originalDns: {
        'nameserver': [
          '$privateDoh#Subscription',
          'https://dns.google.office.test/dns-query',
          '11.1.1.1:53',
          'https://resolver.office.test/dns-query#direct&h3=true',
          'tailscale://dns.google',
        ],
        'proxy-server-nameserver': [privateDoh],
      },
    );

    expect(dns['proxy-server-nameserver'], [
      privateDoh,
      'https://dns.google.office.test/dns-query',
      '11.1.1.1:53',
      'https://resolver.office.test/dns-query#direct&h3=true',
      'tailscale://dns.google',
    ]);
  });

  test('keeps the configured bootstrap for known public and system DNS', () {
    final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
    applyDnsNodeOverride(
      {'dns': dns},
      originalDns: {
        'nameserver': [
          '1.1.1.1:53',
          'https://DNS.GOOGLE.:8443/dns-query#direct',
          'https://mozilla.cloudflare-dns.com/dns-query',
          'https://dns.alidns.com/dns-query#h3=true',
          'quic://dns.adguard.com:784',
          'https://dns1.nextdns.io/dns-query',
          'system',
          'system://',
          'dhcp://system',
        ],
      },
    );

    expect(dns['proxy-server-nameserver'], bootstrap);
  });

  test('retains proxy hostnames for the matching local DNS listener', () {
    final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
    final config = <String, dynamic>{
      'dns': dns,
      'hosts': {'edge.office.test': '192.0.2.22'},
      'proxies': [
        {'server': 'edge.office.test'},
      ],
    };
    applyDnsNodeOverride(
      config,
      originalDns: {
        'listen': '[::1]:53',
        'proxy-server-nameserver': ['tcp://[::1]#direct'],
        'nameserver': ['0:0:0:0:0:0:0:1', 'https://[::1]:53/dns-query'],
      },
    );

    expect(config['proxies'], [
      {'server': 'edge.office.test'},
    ]);
    expect(dns['proxy-server-nameserver'], ['https://[::1]:53/dns-query']);
  });

  test(
    'keeps the configured bootstrap with a public subscription DoH list',
    () {
      final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
      applyDnsNodeOverride(
        {'dns': dns},
        originalDns: {
          'proxy-server-nameserver': [
            'https://120.53.53.53/dns-query',
            'https://1.12.12.12/dns-query',
            'https://sm2.doh.pub/dns-query',
            'https://doh.360.cn/dns-query',
          ],
        },
      );
      expect(dns['proxy-server-nameserver'], bootstrap);
    },
  );

  test(
    'inherits only explicitly configured public node resolvers on defaults',
    () {
      final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
      applyDnsNodeOverride(
        {'dns': dns},
        originalDns: {
          'nameserver': ['8.8.8.8'],
          'proxy-server-nameserver': [
            'https://dns.google/dns-query#DIRECT',
            'tls://1.1.1.1#Subscription',
            'system://',
          ],
        },
        keepSubscriptionPublicNodeResolvers: true,
      );
      expect(dns['proxy-server-nameserver'], [
        'https://dns.google/dns-query#DIRECT',
        'tls://1.1.1.1',
      ]);
    },
  );

  test('recognizes a loopback resolver for an unspecified listen host', () {
    final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
    applyDnsNodeOverride(
      {'dns': dns},
      originalDns: {
        'listen': ':1053',
        'proxy-server-nameserver': ['tcp://127.0.0.1:1053'],
        'nameserver': ['192.0.2.80:1053'],
      },
    );

    expect(dns['proxy-server-nameserver'], ['192.0.2.80:1053']);
  });

  for (final (listen, resolver) in [
    ('127.0.0.1:1053', 'tcp://127.0.0.1:10530'),
    (
      '127.0.0.1:1053',
      'https://resolver.office.test/dns-query?target=127.0.0.1:1053',
    ),
    (':1053', 'udp://192.0.2.80:1053'),
  ]) {
    test('keeps proxy hosts when the DNS endpoint differs: $resolver', () {
      final dns = <String, dynamic>{'proxy-server-nameserver': bootstrap};
      final config = <String, dynamic>{
        'dns': dns,
        'proxies': [
          {'server': 'edge.office.test'},
        ],
      };
      applyDnsNodeOverride(
        config,
        originalDns: {
          'listen': listen,
          'proxy-server-nameserver': [resolver],
        },
      );

      expect(config['proxies'], [
        {'server': 'edge.office.test'},
      ]);
      expect(dns['proxy-server-nameserver'], [resolver]);
    });
  }
}
