import 'package:fluxora/common/dns_override.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bootstrap = ['192.0.2.53'];

  test('adds strict private DNS host to a mode-independent bypass list', () {
    final config = <String, dynamic>{
      'dns': <String, dynamic>{'enhanced-mode': 'fake-ip'},
    };
    applyPrivateDnsBypass(config, 'Dns.Private.Example.');
    applyPrivateDnsBypass(config, 'dns.private.example');
    expect(config['dns']['fake-ip-filter-bypass'], ['dns.private.example']);
  });

  test('bypasses Android Private DNS hostnames from fake-IP', () {
    final config = <String, dynamic>{
      'dns': {
        'enhanced-mode': 'fake-ip',
        'fake-ip-filter-bypass': ['existing.example'],
      },
    };

    applyPrivateDnsBypass(config, 'Resolver.Private.Example.');
    applyPrivateDnsBypass(config, 'resolver.private.example');

    expect(config['dns']['fake-ip-filter-bypass'], [
      'existing.example',
      'resolver.private.example',
    ]);
  });

  test('does not add IP addresses or alter redir-host DNS', () {
    final fakeIp = <String, dynamic>{
      'dns': {'enhanced-mode': 'fake-ip'},
    };
    final redirHost = <String, dynamic>{
      'dns': {'enhanced-mode': 'redir-host'},
    };

    applyPrivateDnsBypass(fakeIp, '192.0.2.53');
    applyPrivateDnsBypass(redirHost, 'resolver.private.example');

    expect(fakeIp['dns'].containsKey('fake-ip-filter-bypass'), isFalse);
    expect(redirHost['dns'].containsKey('fake-ip-filter-bypass'), isFalse);
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
