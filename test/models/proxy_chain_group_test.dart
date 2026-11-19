import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/warp_config.dart';
import 'package:fluxora/manager/profile_chain_manager.dart';
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> fixture() => {
  'proxies': [
    {'name': 'Entry', 'type': 'socks5', 'server': '127.0.0.1', 'port': 31001},
    {'name': 'Relay', 'type': 'socks5', 'server': '127.0.0.1', 'port': 31002},
    {'name': 'Exit', 'type': 'socks5', 'server': '127.0.0.1', 'port': 31003},
  ],
  'proxy-groups': [
    {
      'name': 'GLOBAL',
      'type': 'select',
      'proxies': ['Entry', 'Relay', 'Exit', 'Policy'],
    },
    {
      'name': 'Policy',
      'type': 'select',
      'proxies': ['Relay', 'DIRECT'],
    },
  ],
};

void main() {
  test(
    'unsupported recursive pre group and unknown-size post providers fail explicitly',
    () {
      final manager = ProfileChainManager();
      manager.updateChain(
        'all-pre',
        (c) => c.copyWith(preProxy: 'Policy'),
        reloadCore: false,
        save: false,
      );
      final pre = fixture();
      (pre['proxy-groups'] as List).last['proxies'] = [
        'Entry',
        'Relay',
        'Exit',
      ];
      expect(
        () => manager.applyToClashConfig(pre, 'all-pre'),
        throwsFormatException,
      );
      manager.updateChain(
        'remote-post',
        (c) => c.copyWith(landingProxy: 'Remote'),
        reloadCore: false,
        save: false,
      );
      final post = fixture();
      (post['proxy-groups'] as List).add({
        'name': 'Remote',
        'type': 'select',
        'use': ['pool'],
      });
      post['proxy-providers'] = {
        'pool': {'type': 'http', 'url': 'https://example.invalid/proxies.yaml'},
      };
      expect(
        () => manager.applyToClashConfig(post, 'remote-post'),
        throwsFormatException,
      );
    },
  );
  test(
    'post policy creates dialer-backed groups and rejects overlapping-only groups',
    () {
      final manager = ProfileChainManager();
      manager.updateChain(
        'policy-post',
        (c) => c.copyWith(landingProxy: 'Policy'),
        reloadCore: false,
        save: false,
      );
      final raw = fixture();
      manager.applyToClashConfig(raw, 'policy-post');
      final proxies = {for (final p in raw['proxies'] as List) p['name']: p};
      expect(proxies['Entry ➜ Policy › Relay']['dialer-proxy'], 'Entry');
      expect(proxies['Exit ➜ Policy › Relay']['dialer-proxy'], 'Exit');
      final overlap = fixture();
      (overlap['proxy-groups'] as List).last['proxies'] = [
        'Entry',
        'Relay',
        'Exit',
      ];
      expect(
        () => manager.applyToClashConfig(overlap, 'policy-post'),
        throwsFormatException,
      );
    },
  );

  test('oversized post policy is rejected before expanding the graph', () {
    final manager = ProfileChainManager();
    manager.updateChain(
      'large-post',
      (c) => c.copyWith(landingProxy: 'Policy'),
      reloadCore: false,
      save: false,
    );
    final raw = <String, dynamic>{
      'proxies': [
        for (var i = 0; i < 222; i++)
          {
            'name': 'node-$i',
            'type': 'socks5',
            'server': '127.0.0.1',
            'port': 1080,
          },
      ],
      'proxy-groups': [
        {
          'name': 'Policy',
          'type': 'select',
          'proxies': [for (var i = 0; i < 111; i++) 'node-$i'],
        },
      ],
    };
    expect(
      () => manager.applyToClashConfig(raw, 'large-post'),
      throwsFormatException,
    );
    expect((raw['proxies'] as List).length, 222);
  });
  test('include-all entry is frozen before new exits are injected', () {
    final raw = fixture();
    (raw['proxy-groups'] as List).add({
      'name': 'EntryAll',
      'type': 'select',
      'include-all-proxies': true,
      'filter': r'^Entry$',
    });
    const ChainProxyConfig(
      enable: true,
      frontHops: ['EntryAll', 'Policy'],
      hop1Node: 'EntryAll',
      hop2Node: 'Exit',
      preventDnsLeak: false,
      preventWebRtcLeak: false,
    ).applyToClashConfig(raw);
    final entry = (raw['proxy-groups'] as List).singleWhere(
      (g) => g['name'] == 'EntryAll',
    );
    expect(entry.containsKey('include-all-proxies'), isFalse);
    final provider = raw['proxy-providers'][(entry['use'] as List).single];
    expect((provider['payload'] as List).map((p) => p['name']), [
      'Entry',
      'Relay',
      'Exit',
    ]);
    expect(entry['filter'], r'^Entry$');
    if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
      File(
        'build/feedback_fixes/entry-all-policy.json',
      ).writeAsStringSync(jsonEncode(raw));
    }
  });
  test(
    'relay policy is wired between entry and exit without altering originals',
    () {
      final raw = fixture();
      const config = ChainProxyConfig(
        enable: true,
        frontHops: ['Entry', 'Policy'],
        hop1Node: 'Entry',
        hop2Node: 'Exit',
        preventDnsLeak: false,
        preventWebRtcLeak: false,
      );
      final aliases =
          <String, ({String source, Map<String, String> members})>{};
      config.applyToClashConfig(
        raw,
        selectedMap: {'Policy': 'Relay'},
        policyAliases: aliases,
      );
      final proxies = {for (final p in raw['proxies'] as List) p['name']: p};
      final groups = {
        for (final g in raw['proxy-groups'] as List) g['name']: g,
      };
      final shadow = ChainProxyConfig.frontHopShadowName(1, 'Policy');
      expect(proxies['🔗出口·Exit']['dialer-proxy'], shadow);
      expect(groups[shadow]['default-selected'], '$shadow › Relay');
      expect(aliases[shadow]?.source, 'Policy');
      expect(aliases[shadow]?.members['Relay'], '$shadow › Relay');
      expect(proxies['$shadow › Relay']['dialer-proxy'], 'Entry');
      expect(groups[shadow]['proxies'], ['$shadow › Relay', 'Entry']);
      expect(groups['Policy']['proxies'], ['Relay', 'DIRECT']);
      expect(proxies['Relay'].containsKey('dialer-proxy'), isFalse);
      if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        File(
          'build/feedback_fixes/relay-policy.json',
        ).writeAsStringSync(jsonEncode(raw));
      }
    },
  );

  test('provider policy retains its type, filter and provider overrides', () {
    final raw = fixture();
    raw['proxy-providers'] = {
      'pool': {
        'type': 'inline',
        'payload': [
          {
            'name': 'HK-1',
            'type': 'socks5',
            'server': '127.0.0.1',
            'port': 31002,
          },
        ],
        'override': {'udp': true},
      },
    };
    (raw['proxy-groups'] as List).add({
      'name': 'Auto',
      'type': 'url-test',
      'url': 'http://127.0.0.1:31004',
      'use': ['pool'],
      'filter': '^HK-',
      'interval': 300,
    });
    chainProxyWithDialer(
      raw,
      name: 'Auto',
      dialer: 'Entry',
      outputName: 'ChainAuto',
    );
    final group = (raw['proxy-groups'] as List).last;
    expect(group['type'], 'url-test');
    expect(group['filter'], '^HK-');
    expect(group['use'], ['ChainAuto › pool']);
    expect(raw['proxy-providers']['ChainAuto › pool']['override'], {
      'udp': true,
      'dialer-proxy': 'Entry',
    });
    expect(raw['proxy-providers']['pool']['override'], {'udp': true});
    if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
      File(
        'build/feedback_fixes/provider-policy.json',
      ).writeAsStringSync(jsonEncode(raw));
    }
  });

  test('cyclic groups are rejected without partially adding proxies', () {
    final raw = fixture();
    (raw['proxy-groups'] as List).add({
      'name': 'Loop',
      'type': 'select',
      'proxies': ['Relay', 'Loop'],
    });
    expect(
      () => chainProxyWithDialer(
        raw,
        name: 'Loop',
        dialer: 'Entry',
        outputName: 'Invalid',
      ),
      throwsFormatException,
    );
    expect((raw['proxies'] as List).length, 3);
    expect((raw['proxy-groups'] as List).length, 3);
  });

  test(
    'include-all policy filters original provider names before chaining',
    () {
      final raw = fixture();
      (raw['proxy-groups'] as List).add({
        'name': 'All relays',
        'type': 'select',
        'include-all-proxies': true,
        'filter': '^Relay\$',
      });
      chainProxyWithDialer(
        raw,
        name: 'All relays',
        dialer: 'Entry',
        outputName: 'FilteredChain',
      );
      final group = (raw['proxy-groups'] as List).last;
      expect(group.containsKey('include-all-proxies'), isFalse);
      expect(group['filter'], '^Relay\$');
      expect(group['use'], ['FilteredChain › 全部节点']);
      expect(
        raw['proxy-providers']['FilteredChain › 全部节点']['payload'],
        hasLength(3),
      );
      if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        File(
          'build/feedback_fixes/include-all-policy.json',
        ).writeAsStringSync(jsonEncode(raw));
      }
    },
  );

  for (final entry in [true, false]) {
    test(
      'profile WARP ${entry ? 'entry' : 'exit'} is explicit and has no self dependency',
      () {
        final manager = ProfileChainManager();
        manager.updateChain(
          'fixture',
          (c) => c.copyWith(
            preProxy: entry ? ProfileChainConfig.warpEntry : null,
            landingProxy: entry ? null : ProfileChainConfig.warpExit,
          ),
          reloadCore: false,
          save: false,
        );
        final raw = fixture();
        manager.applyToClashConfig(
          raw,
          'fixture',
          warp: const WarpConfig(privateKey: 'test-key'),
        );
        final proxies = {for (final p in raw['proxies'] as List) p['name']: p};
        if (entry) {
          expect(proxies['Entry']['dialer-proxy'], '🛡️ WARP 入口');
          expect(proxies['🛡️ WARP 入口'].containsKey('dialer-proxy'), isFalse);
        } else {
          expect(proxies['Entry ➜ 🛡️ WARP 落地']['dialer-proxy'], 'Entry');
          expect(proxies['Entry ➜ 🛡️ WARP 落地']['type'], 'wireguard');
        }
      },
    );
  }
}
