import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:path/path.dart' as p;

/// P1 — hop-mode switching must MIGRATE the exit node, never reinterpret or
/// drop it.
///
/// Two-hop keeps the exit in `hop2Node`; three-hop keeps the relay in `hop2Node`
/// and the exit in `hop3Node`. Before P1 a switch did a bare `hopMode` write
/// (silently re-reading the old exit as the relay) and the UI cleared both
/// fields, so the user's exit configuration was destroyed by a mode toggle.
///
/// The migration lives in `ChainProxyManager.setHopMode`, so these tests drive
/// the real manager entry point — not a copy of its logic.
///
/// NOTE: `ChainProxyManager` is a process-wide singleton. Every test arranges
/// its own config through `updateConfig`, so no test depends on another's
/// leftover state.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p1_hopmode_');
    ChainProxyManager.configFilePathOverride =
        p.join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride =
        p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
  });

  tearDown(() {
    ChainProxyManager().stopChainHealthCheck();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Replaces the whole config through the production write path.
  Future<ChainProxyManager> arrange(ChainProxyConfig config) async {
    final manager = ChainProxyManager();
    await manager.updateConfig((_) => config);
    manager.stopChainHealthCheck();
    return manager;
  }

  ChainProxyConfig twoHop({String exit = 'US-01'}) => ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'HK-01',
    hop2Node: exit,
    defaultDialerProxy: 'HK-01',
  );

  ChainProxyConfig threeHop({String relay = 'SG-01', String exit = 'US-01'}) =>
      ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: relay,
        hop3Node: exit,
        defaultDialerProxy: 'HK-01',
      );

  // ── A. field migration ────────────────────────────────────────────────────
  group('P1 — two-hop → three-hop migrates the exit', () {
    test('the exit moves from hop2Node into hop3Node; the relay slot is freed',
        () async {
      final manager = await arrange(twoHop(exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.threeHop);

      expect(manager.config.hopMode, ChainHopMode.threeHop);
      expect(manager.config.hop3Node, 'US-01', reason: 'exit migrated');
      expect(manager.config.hop2Node, '', reason: 'relay slot freed');
      expect(
        manager.config.effectiveExitNode,
        'US-01',
        reason: 'the effective exit must not change across the switch',
      );
    });

    test('a round trip preserves the exit', () async {
      final manager = await arrange(twoHop(exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.threeHop);
      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hopMode, ChainHopMode.twoHop);
      expect(manager.config.hop2Node, 'US-01');
      expect(manager.config.hop3Node, '');
      expect(manager.config.effectiveExitNode, 'US-01');
    });

    test('an empty hop2Node is not treated as an exit to migrate', () async {
      final manager = await arrange(
        const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'HK-01',
          hop2Node: '',
          hop3Node: 'US-01',
          defaultDialerProxy: 'HK-01',
        ),
      );

      await manager.setHopMode(ChainHopMode.threeHop);

      expect(manager.config.hop2Node, '');
      expect(
        manager.config.hop3Node,
        'US-01',
        reason: 'an existing hop3Node must not be wiped by the switch',
      );
    });
  });

  group('P1 — three-hop → two-hop restores the exit', () {
    test('the exit moves from hop3Node back into hop2Node', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hopMode, ChainHopMode.twoHop);
      expect(manager.config.hop2Node, 'US-01', reason: 'exit restored');
      expect(manager.config.hop3Node, '');
      expect(manager.config.effectiveExitNode, 'US-01');
    });

    test('a round trip preserves the exit', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);
      await manager.setHopMode(ChainHopMode.threeHop);

      expect(manager.config.hop3Node, 'US-01');
      expect(manager.config.hop2Node, '');
    });

    test('an empty hop3Node does not wipe the existing hop2Node', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: ''));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(
        manager.config.hop2Node,
        'SG-01',
        reason: 'nothing to restore → keep the field, never blank it',
      );
      expect(manager.config.hop3Node, '');
    });
  });

  group('P1 — switching is a no-op when the mode is unchanged', () {
    test('two-hop → two-hop leaves every field untouched', () async {
      final manager = await arrange(twoHop(exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hop2Node, 'US-01');
      expect(manager.config.hop3Node, '');
    });

    test('three-hop → three-hop leaves every field untouched', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.threeHop);

      expect(manager.config.hop2Node, 'SG-01');
      expect(manager.config.hop3Node, 'US-01');
    });
  });

  // ── C. entry fields and special values survive the migration ─────────────
  group('P1 — three-hop → two-hop leaves the entry fields untouched', () {
    test('hop1Node and defaultDialerProxy are not rewritten', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hop1Node, 'HK-01');
      expect(manager.config.defaultDialerProxy, 'HK-01');
      expect(manager.config.effectiveHop1, 'HK-01');
    });

    test('a DIRECT entry survives the migration', () async {
      final manager = await arrange(
        const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.threeHop,
          hop1Node: 'DIRECT',
          defaultDialerProxy: 'DIRECT',
          hop2Node: 'SG-01',
          hop3Node: 'US-01',
        ),
      );

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hop1Node, 'DIRECT');
      expect(manager.config.defaultDialerProxy, 'DIRECT');
      expect(manager.config.effectiveHop1, 'DIRECT');
    });

    test('an empty entry (follow main) survives the migration', () async {
      final manager = await arrange(
        const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.threeHop,
          hop2Node: 'SG-01',
          hop3Node: 'US-01',
        ),
      );

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hop1Node, isEmpty);
      expect(manager.config.defaultDialerProxy, isEmpty);
      expect(manager.config.effectiveHop1, isEmpty);
    });

    test('the former relay stored in hop2Node is overwritten by the exit',
        () async {
      // Documents the one lossy part of the migration: two-hop has no relay
      // slot, so a stored relay cannot be carried across a round trip.
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hopMode, ChainHopMode.twoHop);
      expect(manager.config.hop2Node, 'US-01');
      expect(manager.config.hop3Node, isEmpty);
    });
  });

  // ── B. generated Mihomo config ────────────────────────────────────────────
  group('P1 — the generated Mihomo config follows the migration', () {
    Map<String, dynamic> sampleConfig() => <String, dynamic>{
      'proxies': <dynamic>[
        <String, dynamic>{
          'name': 'HK-01',
          'type': 'ss',
          'server': '1.1.1.1',
          'port': 8388,
          'cipher': 'aes-256-gcm',
          'password': 'pass',
        },
        <String, dynamic>{
          'name': 'SG-01',
          'type': 'trojan',
          'server': '2.2.2.2',
          'port': 443,
          'password': 'pass',
          'sni': 'sg.example.com',
        },
        <String, dynamic>{
          'name': 'US-01',
          'type': 'vmess',
          'server': '3.3.3.3',
          'port': 443,
          'uuid': 'uuid-us',
          'alterId': 0,
          'cipher': 'auto',
        },
      ],
      'proxy-groups': <dynamic>[
        <String, dynamic>{
          'name': 'GLOBAL',
          'type': 'select',
          'proxies': <String>['HK-01', 'SG-01', 'US-01', 'DIRECT'],
        },
        <String, dynamic>{
          'name': 'PROXY',
          'type': 'select',
          'proxies': <String>['HK-01', 'SG-01', 'US-01'],
        },
      ],
      'rules': <String>['MATCH,PROXY'],
    };

    List<Map<String, dynamic>> proxiesOf(Map<String, dynamic> raw) =>
        (raw['proxies'] as List).cast<Map<String, dynamic>>();

    test('after two-hop → three-hop the migrated exit is chained behind the relay',
        () async {
      final manager = await arrange(twoHop(exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.threeHop);
      // The relay slot is empty after migration; the user picks a relay.
      await manager.setHop2Node('SG-01');

      final raw = sampleConfig();
      manager.config.applyToClashConfig(raw);
      final proxies = proxiesOf(raw);

      final transit = proxies.firstWhere(
        (p) => p['name'] == ChainProxyConfig.transitShadowName('SG-01'),
      );
      expect(transit['dialer-proxy'], 'HK-01');

      final exit = proxies.firstWhere(
        (p) => p['name'] == ChainProxyConfig.exitShadowName('US-01'),
      );
      expect(exit['type'], 'vmess');
      expect(exit['server'], '3.3.3.3');
      expect(
        exit['dialer-proxy'],
        ChainProxyConfig.transitShadowName('SG-01'),
        reason: 'the migrated exit must be chained behind the relay',
      );
    });

    test('a migrated exit that no longer exists is never injected', () async {
      final manager = await arrange(twoHop(exit: 'GONE-99'));

      await manager.setHopMode(ChainHopMode.threeHop);
      await manager.setHop2Node('SG-01');
      expect(manager.config.hop3Node, 'GONE-99', reason: 'migrated as-is');

      final raw = sampleConfig();
      manager.config.applyToClashConfig(raw);
      final proxies = proxiesOf(raw);

      // Fail safe: the stale node is not in the config, so no shadow node is
      // generated at all — a broken chain referencing a missing node would be
      // worse than no chain.
      expect(
        proxies.any(
          (p) => p['name'] == ChainProxyConfig.exitShadowName('GONE-99'),
        ),
        isFalse,
      );
      expect(
        proxies.any(
          (p) => p['name'] == ChainProxyConfig.transitShadowName('SG-01'),
        ),
        isFalse,
      );
    });
  });

  // ── D. RC.10-A.4.5 — a stale exit reference must not stay a probe target ──

  LandingProxy landing(String name, {bool enable = true}) => LandingProxy(
    id: 'landing-$name',
    name: name,
    server: '127.0.0.1',
    port: 1080,
    enable: enable,
  );

  group('RC.10-A.4.5 — a stale two-hop exit falls back to a landing proxy', () {
    test('the migration keeps the legacy exit name but stops using it',
        () async {
      // The legacy exit is kept in `hop2Node` — the migration rule must not
      // destroy it — but once the config declares landing proxies and the name
      // is not one of them, it can no longer be the effective exit.
      final manager = await arrange(
        threeHop(relay: 'SG-01', exit: 'US-01').copyWith(
          landingProxies: [landing('us8 -1')],
        ),
      );

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hopMode, ChainHopMode.twoHop);
      expect(manager.config.hop2Node, 'US-01');
      expect(manager.config.effectiveExitNode, 'us8 -1');
    });

    test('an active landing proxy becomes the fallback candidate', () async {
      final manager = await arrange(
        ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'HK-01',
          defaultDialerProxy: 'HK-01',
          hop2Node: 'residential_exit_us',
          landingProxies: [landing('us8 -1')],
        ),
      );

      expect(manager.config.effectiveExitNode, 'us8 -1');
    });

    test('a valid landing exit still wins over the fallback', () async {
      final manager = await arrange(
        ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'HK-01',
          defaultDialerProxy: 'HK-01',
          hop2Node: 'us9',
          landingProxies: [landing('us8 -1'), landing('us9')],
        ),
      );

      expect(manager.config.effectiveExitNode, 'us9');
    });

    test('no usable candidate yields no exit rather than a fabricated one',
        () async {
      final manager = await arrange(
        ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'HK-01',
          defaultDialerProxy: 'HK-01',
          hop2Node: 'residential_exit_us',
          landingProxies: [landing('us8 -1', enable: false)],
        ),
      );

      expect(manager.config.effectiveExitNode, isEmpty);
    });

    test('the RC.10-A.3 entry-field invariant is not regressed', () async {
      final manager = await arrange(threeHop(relay: 'SG-01', exit: 'US-01'));

      await manager.setHopMode(ChainHopMode.twoHop);

      expect(manager.config.hop1Node, 'HK-01');
      expect(manager.config.defaultDialerProxy, 'HK-01');
      expect(manager.config.effectiveHop1, 'HK-01');
    });
  });
}
