import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/views/proxies/chain_proxy_view.dart';

/// B3 — three-hop UI recovery: the pre-write gate.
///
/// `ChainProxyConfig.applyToClashConfig` silently injects no shadow nodes when
/// a hop node is missing from the proxy map, and it is never handed an
/// `availableProxyNames` list, so it cannot report the problem itself. The
/// production UI therefore validates a prospective hop configuration through
/// [hopChainValidationError] before writing it.
///
/// These tests pin that decision, the same way
/// `chain_proxy_stale_detection_test.dart` pins `isFallbackCandidateStale`:
///
///   * a two-hop landing-proxy chain (no `hop2Node`) is NOT validated — the
///     topology validator requires `hop2` to be non-empty and would report
///     `EMPTY_HOP` for the working production configuration;
///   * a half-built three-hop chain is allowed to be written (blocking it would
///     deadlock the two hop pickers) and is flagged by [isThreeHopIncomplete]
///     so the topology card reports it as unfinished;
///   * duplicate, reserved and unavailable nodes are refused.
void main() {
  const available = ['HK-01', 'SG-01', 'US-01'];

  group('B3 — usesHopFieldChain', () {
    test(
      '1. two-hop landing-proxy chain (no hop2Node) → not hop-field driven',
      () {
        const config = ChainProxyConfig(
          hopMode: ChainHopMode.twoHop,
          defaultDialerProxy: 'HK-01',
        );
        expect(usesHopFieldChain(config), isFalse);
        // …and so it is not validated at all: no false EMPTY_HOP for the
        // production two-hop chain.
        expect(hopChainValidationError(config, available), isNull);
      },
    );

    test('2. two-hop with an explicit hop2Node → hop-field driven', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
      );
      expect(usesHopFieldChain(config), isTrue);
    });

    test('3. three-hop → hop-field driven even before nodes are picked', () {
      const config = ChainProxyConfig(hopMode: ChainHopMode.threeHop);
      expect(usesHopFieldChain(config), isTrue);
    });
  });

  group('B3 — a half-built three-hop chain is marked, not blocked', () {
    // The two hop rows are filled one at a time, so the first pick always
    // leaves the other hop empty. Blocking that would deadlock the pickers —
    // neither hop could ever be chosen. The write is therefore allowed and the
    // chain is surfaced as incomplete instead, so it is never read as finished.
    test('4. relay picked first → allowed, and flagged incomplete', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
      );
      expect(hopChainValidationError(config, available), isNull);
      expect(isThreeHopIncomplete(config), isTrue);
    });

    test('5. exit picked first → allowed, and flagged incomplete', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop3Node: 'US-01',
      );
      expect(hopChainValidationError(config, available), isNull);
      expect(isThreeHopIncomplete(config), isTrue);
    });

    test('6. entry slot unset → allowed, not flagged as incomplete', () {
      // The relay and exit ARE chosen here; only the entry slot is empty, which
      // means "follow the main selector" — `applyToClashConfig` resolves that to
      // the dedicated hop group, so it is a valid intent, not a missing node.
      // The incompleteness signal covers the two three-hop slots only.
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop2Node: 'SG-01',
        hop3Node: 'US-01',
      );
      expect(hopChainValidationError(config, available), isNull);
      expect(isThreeHopIncomplete(config), isFalse);
    });

    test('7. complete three-hop chain → allowed and not flagged', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'US-01',
      );
      expect(hopChainValidationError(config, available), isNull);
      expect(isThreeHopIncomplete(config), isFalse);
    });

    test('8. two-hop is never flagged as an incomplete three-hop', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.twoHop,
        defaultDialerProxy: 'HK-01',
      );
      expect(isThreeHopIncomplete(config), isFalse);
    });
  });

  group('B3 — nodes that would break generation are refused', () {
    test('9. relay == exit → refused', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'SG-01',
      );
      final error = hopChainValidationError(config, available);
      expect(error, isNotNull);
      expect(error, contains('不能使用同一个节点'));
    });

    test('10. entry == exit → refused', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'HK-01',
      );
      final error = hopChainValidationError(config, available);
      expect(error, isNotNull);
      expect(error, contains('不能使用同一个节点'));
    });

    test('11. exit node no longer exists → refused (the stale-node case)', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'GONE-99',
      );
      final error = hopChainValidationError(config, available);
      expect(error, isNotNull);
      expect(error, contains('不存在'));
    });

    test('12. DIRECT is a reserved name for the relay slot → refused', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'DIRECT',
        hop3Node: 'US-01',
      );
      expect(hopChainValidationError(config, available), isNotNull);
    });
  });

  group('B3 — unreadable node list', () {
    test('13. structural checks still run when the node set is unknown', () {
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'SG-01',
      );
      final error = hopChainValidationError(config, null);
      expect(error, isNotNull);
      expect(error, contains('不能使用同一个节点'));
    });

    test('14. availability is skipped (not faked) when the set is unknown', () {
      // The validator cannot check availability with no list, so it returns
      // valid — the caller is responsible for refusing to report success
      // (`_hopConfigError` maps this to `chainHopUnavailable`).
      const config = ChainProxyConfig(
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'US-01',
      );
      expect(hopChainValidationError(config, null), isNull);
    });
  });
}
