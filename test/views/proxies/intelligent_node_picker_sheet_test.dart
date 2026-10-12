import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/providers/providers.dart';

/// B4 — unified node classification & probe filtering.
///
/// This file previously held 24 `expect(true, true)` placeholders and asserted
/// nothing. It now covers:
///
///   1. the shared predicate `ChainProxyConfig.isSelectableProxy` (§4 of the
///      B4 contract) — the single rule every node list / delay test uses;
///   2. that `adaptiveRankingProvider` (the picker's real data source) actually
///      consumes that rule;
///   3. a structural guard proving the four production call sites delegate to
///      the shared predicate instead of carrying their own condition lists.
///
/// The subscription "information" nodes (剩余流量 / 套餐到期 / …) are asserted to
/// be **kept** — see `B4_SUBSCRIPTION_PSEUDO_NODE_AUDIT.md` §5/§12: P1.1-D2
/// classifies them from real behavioural samples, so a name blacklist would
/// contradict the P1.1-C proof and starve the classifier.
void main() {
  // ── 1. the shared predicate ───────────────────────────────────────────────
  group('B4 — ChainProxyConfig.isSelectableProxy', () {
    bool selectable(String name, String type) =>
        ChainProxyConfig.isSelectableProxy(name: name, type: type);

    group('built-in policies are not ordinary proxies', () {
      test('DIRECT is excluded (by name and by type)', () {
        expect(selectable('DIRECT', 'Direct'), isFalse);
        expect(selectable('DIRECT', ''), isFalse);
      });

      test('case variants of DIRECT are excluded consistently', () {
        expect(selectable('direct', 'direct'), isFalse);
        expect(selectable('Direct', 'Direct'), isFalse);
        expect(selectable('dIrEcT', 'dIrEcT'), isFalse);
      });

      test('REJECT / REJECT-DROP / PASS are excluded', () {
        expect(selectable('REJECT', 'Reject'), isFalse);
        expect(selectable('REJECT-DROP', 'RejectDrop'), isFalse);
        expect(selectable('PASS', ''), isFalse);
      });

      test('case variants of REJECT / PASS are excluded', () {
        expect(selectable('reject', 'reject'), isFalse);
        expect(selectable('reject-drop', ''), isFalse);
        expect(selectable('pass', ''), isFalse);
      });

      test('COMPATIBLE is excluded (the project protects this name)', () {
        expect(selectable('COMPATIBLE', 'Compatible'), isFalse);
        expect(selectable('compatible', ''), isFalse);
      });
    });

    group('proxy groups and their nested members are excluded', () {
      test('Selector / URLTest / Fallback / LoadBalance types are excluded', () {
        for (final type in const [
          'Selector',
          'URLTest',
          'Fallback',
          'LoadBalance',
        ]) {
          expect(
            selectable('SomeGroup', type),
            isFalse,
            reason: 'group type $type must not be an ordinary node',
          );
          // lowercase variant — the rule is case-insensitive by design.
          expect(selectable('SomeGroup', type.toLowerCase()), isFalse);
        }
      });

      test('a nested member whose type is a group type is excluded', () {
        expect(selectable('InnerGroup', 'Selector'), isFalse);
      });

      test('the REMATCH pseudo type is excluded', () {
        expect(selectable('Rule', 'REMATCH'), isFalse);
        expect(selectable('Rule', 'rematch'), isFalse);
      });
    });

    group('chain shadow nodes are excluded', () {
      test('transit shadow names are excluded', () {
        expect(
          selectable(ChainProxyConfig.transitShadowName('NodeA'), 'hysteria2'),
          isFalse,
        );
      });

      test('exit shadow names are excluded', () {
        expect(
          selectable(ChainProxyConfig.exitShadowName('NodeA'), 'hysteria2'),
          isFalse,
        );
      });
    });

    group('ordinary proxies are kept', () {
      test('common protocols are selectable', () {
        for (final type in const [
          'VLESS',
          'VMess',
          'Shadowsocks',
          'Trojan',
          'Hysteria2',
          'ss',
          'vless',
        ]) {
          expect(
            selectable('Tokyo-01', type),
            isTrue,
            reason: 'protocol $type is an ordinary proxy',
          );
        }
      });

      test('subscription "information" nodes MUST stay selectable', () {
        // These carry a fully valid hysteria2 config and are structurally
        // identical to a real node (P1.1-C). They must NOT be name-filtered —
        // the behavioural classifier needs their real samples.
        for (final name in const [
          '剩余流量：103.23 GB',
          '套餐到期：2026-12-31',
          '节点超时请手动更新订阅',
          '更新订阅以获得最新节点',
        ]) {
          expect(
            selectable(name, 'hysteria2'),
            isTrue,
            reason: 'pseudo-node "$name" must reach the behavioural classifier',
          );
        }
      });

      test('a structurally valid but unreachable node is still selectable', () {
        expect(selectable('Dead-Node', 'vmess'), isTrue);
      });

      test('a node with no telemetry yet is still selectable', () {
        expect(selectable('Brand-New', 'trojan'), isTrue);
      });

      test('an unknown, non-built-in type is kept (conservative)', () {
        expect(selectable('Future-Proto', 'some-new-protocol'), isTrue);
        expect(selectable('Future-Proto', ''), isTrue);
      });

      test('whitespace around name/type does not change the verdict', () {
        expect(selectable('  DIRECT  ', '  Direct  '), isFalse);
        expect(selectable('  Tokyo-01  ', '  vless  '), isTrue);
      });
    });
  });

  // ── 2. the picker's real data source consumes the rule ────────────────────
  group('B4 — adaptiveRankingProvider consumes the shared rule', () {
    // `chainProxyConfigProvider` is a ChangeNotifierProvider over the
    // process-wide `chainProxyManager` singleton and riverpod disposes the
    // notifier when the container is disposed — so exactly ONE container may be
    // created/disposed for this file.
    late ProviderContainer container;

    const params = (role: FallbackCandidateRole.entry, sortMode: 'name');

    setUpAll(() {
      container = ProviderContainer(
        overrides: [
          groupsProvider.overrideWithValue([
            Group(
              name: 'Proxy',
              type: GroupType.Selector,
              all: const [
                // ordinary — must survive
                Proxy(name: 'Tokyo-01', type: 'vless'),
                Proxy(name: 'Osaka-02', type: 'hysteria2'),
                // subscription pseudo-node — must survive (behavioural, not name)
                Proxy(name: '剩余流量：103.23 GB', type: 'hysteria2'),
                // built-in policies — must be dropped
                Proxy(name: 'DIRECT', type: 'Direct'),
                Proxy(name: 'REJECT', type: 'Reject'),
                // a nested group member — must be dropped
                Proxy(name: 'InnerAuto', type: 'URLTest'),
                // chain shadow node — must be dropped
                Proxy(name: '🔗中转·Tokyo-01', type: 'vless'),
              ],
              now: '',
            ),
          ]),
        ],
      );
    });

    tearDownAll(() {
      container.dispose();
    });

    test('group members, built-ins and shadow nodes are not offered', () {
      final names = container
          .read(adaptiveRankingProvider(params))
          .map((vm) => vm.nodeName)
          .toSet();

      expect(names, contains('Tokyo-01'));
      expect(names, contains('Osaka-02'));
      expect(names, contains('剩余流量：103.23 GB'));

      expect(names, isNot(contains('DIRECT')));
      expect(names, isNot(contains('REJECT')));
      expect(names, isNot(contains('InnerAuto')));
      expect(names, isNot(contains('🔗中转·Tokyo-01')));
    });

    test('exactly the three ordinary members are offered', () {
      final names = container
          .read(adaptiveRankingProvider(params))
          .map((vm) => vm.nodeName)
          .toList();

      expect(names.toSet(), {'Tokyo-01', 'Osaka-02', '剩余流量：103.23 GB'});
      // `sortMode: 'name'` ⇒ deterministic order.
      expect(names, ['Osaka-02', 'Tokyo-01', '剩余流量：103.23 GB']);
    });

    test('the GLOBAL group itself is never a node', () {
      final names = container
          .read(adaptiveRankingProvider(params))
          .map((vm) => vm.nodeName)
          .toSet();
      expect(names, isNot(contains('GLOBAL')));
    });

    // ── P2 (option 3): the 「延迟」 mode must not pretend it has data ─────────
    test('P2 — latency mode with nothing measured keeps the name-order fallback',
        () {
      const latencyParams = (
        role: FallbackCandidateRole.entry,
        sortMode: 'latency',
      );
      final latencyViewModels = container.read(
        adaptiveRankingProvider(latencyParams),
      );

      // No `nodeLatency` has ever been recorded for these nodes, so every card
      // reports "unknown" instead of a fabricated number.
      expect(
        latencyViewModels.every((vm) => vm.latencyMs == null),
        isTrue,
        reason: 'a missing measurement must stay null, never be back-filled',
      );

      // …and the order is the documented stable fallback: exactly the name order
      // the 「名称」 mode produces — NOT the Smart order, and not a silent
      // re-sort by a value that does not exist.
      expect(
        latencyViewModels.map((vm) => vm.nodeName).toList(),
        container
            .read(adaptiveRankingProvider(params))
            .map((vm) => vm.nodeName)
            .toList(),
      );
    });
  });

  // ── 3. structural guard: the four call sites share one rule ───────────────
  group('B4 — the four production call sites use the shared predicate', () {
    String read(String path) => File(path).readAsStringSync();

    const callSites = [
      'lib/providers/adaptive_ranking_provider.dart',
      'lib/views/proxies/common.dart',
      'lib/views/proxies/card.dart',
      'lib/common/tray.dart',
    ];

    test('every call site references isSelectableProxy', () {
      for (final path in callSites) {
        expect(
          read(path),
          contains('isSelectableProxy'),
          reason: '$path must delegate to the shared predicate',
        );
      }
    });

    test('the old divergent literals are gone from the call sites', () {
      // The pre-B4 rule-sets carried these ad-hoc condition lists. Their
      // removal is what makes the four sites consistent.
      expect(
        read('lib/views/proxies/common.dart'),
        isNot(contains("name == 'REJECT'")),
      );
      expect(
        read('lib/views/proxies/card.dart'),
        isNot(contains("name == 'REJECT'")),
      );
      expect(
        read('lib/common/tray.dart'),
        isNot(contains("name != 'REJECT'")),
      );
      expect(
        read('lib/providers/adaptive_ranking_provider.dart'),
        isNot(contains("p.type != 'URLTest'")),
      );
    });

    test('no subscription-metadata name blacklist was introduced', () {
      // Guards the P1.1-C proof: the fix must not filter by subscription text.
      for (final path in callSites) {
        final source = read(path);
        for (final forbidden in const ['剩余流量', '套餐到期', '手动更新订阅']) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason: '$path must not name-filter subscription metadata',
          );
        }
      }
    });
  });
}
