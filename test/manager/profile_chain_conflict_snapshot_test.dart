import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/profile_chain_manager.dart';

/// RC.8 — configuration-combination snapshot (global chain + per-profile chain).
///
/// **This file pins the CURRENT behaviour. It does not assert that the
/// behaviour is desirable, and it does not choose a priority.**
///
/// `State.patchRawConfig` applies three passes in a fixed order
/// (`state.dart:1084` → `:1087` → `:1090`):
///
/// ```text
/// chainProxyManager.applyToClashConfig(rawConfig)                  // global chain
/// warpManager.applyToClashConfig(rawConfig)                        // WARP
/// profileChainManager.applyToClashConfig(rawConfig, profileId)     // per-profile, LAST
/// ```
///
/// `ProfileChainManager.applyToClashConfig` (`profile_chain_manager.dart:178`)
/// rewrites `dialer-proxy` on **every** proxy whose name differs from
/// `preProxy` — it does not filter by `type` the way the WARP pass does
/// (`warp_config.dart:367-375`). Because it runs last, it also rewrites the
/// `dialer-proxy` that the global chain had already wired on its generated
/// shadow nodes (`chain_proxy.dart:903/913/949`).
///
/// The input below therefore represents the state **after** the global pass:
/// the two shadow nodes already carry the global chain's own wiring.
///
/// Runtime consequences (does Mihomo accept the result, where does traffic
/// actually exit, does the global three-hop still work) are **not** covered —
/// that needs a real core.
void main() {
  late ProfileChainManager manager;

  setUp(() {
    manager = ProfileChainManager();
  });

  Map<String, dynamic> rawConfigAfterGlobalPass() => <String, dynamic>{
    'proxies': <dynamic>[
      {'name': 'EntryNode', 'type': 'ss', 'server': '10.0.0.1'},
      {'name': 'AirportA', 'type': 'vmess', 'server': '10.0.0.2'},
      // Global chain shadow nodes, wired by `ChainProxyConfig.applyToClashConfig`.
      {'name': '🔗中转·AirportA', 'type': 'vmess', 'dialer-proxy': 'AirportA'},
      {
        'name': '🔗出口·AirportA',
        'type': 'socks5',
        'dialer-proxy': '🔗中转·AirportA',
      },
      {'name': 'LandingNode', 'type': 'socks5', 'server': '10.0.0.9'},
    ],
    'proxy-groups': <dynamic>[
      {
        'name': 'PROXY',
        'type': 'select',
        'proxies': <dynamic>['AirportA', '🔗出口·AirportA'],
      },
    ],
  };

  Map<String, dynamic> byName(Map<String, dynamic> raw, String name) =>
      (raw['proxies'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == name);

  List<String> proxyNames(Map<String, dynamic> raw) => (raw['proxies'] as List)
      .cast<Map<String, dynamic>>()
      .map((p) => p['name'] as String)
      .toList();

  void enableBoth(String profileId) {
    manager.updateChain(profileId, (c) {
      return c.copyWith(
        enable: true,
        preProxy: 'EntryNode',
        landingProxy: 'LandingNode',
      );
    }, reloadCore: false, save: false);
  }

  test('SNAPSHOT: pre-proxy rewrites the global chain shadow wiring', () {
    final raw = rawConfigAfterGlobalPass();
    // The global pass had wired a real two-hop chain:
    //   AirportA -> 🔗中转·AirportA -> 🔗出口·AirportA
    expect(byName(raw, '🔗中转·AirportA')['dialer-proxy'], 'AirportA');
    expect(byName(raw, '🔗出口·AirportA')['dialer-proxy'], '🔗中转·AirportA');

    enableBoth('rc8-combo-a');
    manager.applyToClashConfig(raw, 'rc8-combo-a');

    // Current behaviour: the per-profile pass overwrites BOTH, flattening the
    // global chain to a single hop through `EntryNode`.
    expect(
      byName(raw, '🔗中转·AirportA')['dialer-proxy'],
      'EntryNode',
      reason: 'global shadow transit wiring is overwritten by the pre-proxy pass',
    );
    expect(
      byName(raw, '🔗出口·AirportA')['dialer-proxy'],
      'EntryNode',
      reason: 'global shadow exit wiring is overwritten by the pre-proxy pass',
    );

    // Unfiltered by `type`: even the landing node dials through the pre-proxy.
    expect(byName(raw, 'LandingNode')['dialer-proxy'], 'EntryNode');
    // The pre-proxy itself is excluded.
    expect(byName(raw, 'EntryNode').containsKey('dialer-proxy'), isFalse);
  });

  test('SNAPSHOT: the landing pass also clones the global shadow nodes', () {
    final raw = rawConfigAfterGlobalPass();
    enableBoth('rc8-combo-b');
    manager.applyToClashConfig(raw, 'rc8-combo-b');

    final names = proxyNames(raw);
    // One clone per original node, including the global chain's own shadows.
    for (final expected in <String>[
      'EntryNode ➜ LandingNode',
      'AirportA ➜ LandingNode',
      '🔗中转·AirportA ➜ LandingNode',
      '🔗出口·AirportA ➜ LandingNode',
    ]) {
      expect(
        names,
        contains(expected),
        reason: 'the landing pass clones every non-landing proxy, shadows included',
      );
    }

    // The clones are wired back to their source node.
    expect(byName(raw, '🔗出口·AirportA ➜ LandingNode')['dialer-proxy'], '🔗出口·AirportA');

    // 5 originals + 4 clones.
    expect(names.length, 9);

    // No node was renamed: the global names survive as names.
    expect(names, containsAll(<String>['🔗中转·AirportA', '🔗出口·AirportA']));
  });

  test('SNAPSHOT: the clones are inserted at the head of every group', () {
    final raw = rawConfigAfterGlobalPass();
    enableBoth('rc8-combo-c');
    manager.applyToClashConfig(raw, 'rc8-combo-c');

    final group = (raw['proxy-groups'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((g) => g['name'] == 'PROXY');
    final groupProxies = (group['proxies'] as List).cast<String>();

    // NOTE: the clones come out in REVERSE node order, because the pass does
    // `pList.insert(0, chainedName)` while walking the nodes forwards. The
    // snapshot pins that; it is not a claim that the order is intended.
    expect(groupProxies.take(4), <String>[
      '🔗出口·AirportA ➜ LandingNode',
      '🔗中转·AirportA ➜ LandingNode',
      'AirportA ➜ LandingNode',
      'EntryNode ➜ LandingNode',
    ]);
    // The pre-existing members are preserved, just pushed down.
    expect(groupProxies, containsAll(<String>['AirportA', '🔗出口·AirportA']));
    expect(groupProxies.length, 6);
  });

  test('SNAPSHOT: a pre-proxy equal to the landing node still chains', () {
    // Guards the degenerate case where both pickers name the same node, so a
    // later change to the passes cannot silently start producing a self-loop.
    final raw = rawConfigAfterGlobalPass();
    manager.updateChain('rc8-combo-d', (c) {
      return c.copyWith(
        enable: true,
        preProxy: 'LandingNode',
        landingProxy: 'LandingNode',
      );
    }, reloadCore: false, save: false);
    manager.applyToClashConfig(raw, 'rc8-combo-d');

    final names = proxyNames(raw);
    // The landing node is skipped by its own clone pass, and the pre-proxy pass
    // also skips it (`pName != preProxy`), so it keeps no dialer-proxy.
    expect(byName(raw, 'LandingNode').containsKey('dialer-proxy'), isFalse);
    expect(names.contains('LandingNode ➜ LandingNode'), isFalse);
  });
}
