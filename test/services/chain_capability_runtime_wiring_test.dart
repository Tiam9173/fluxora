import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_cache_service.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.3-B — Capability runtime probe wiring (P-1) + baseline semantics (P-2).
///
/// The runtime probes are fire-and-forget by design, so these tests drive them
/// through the REAL `ChainProxyManager.refreshCapabilityProfiles()` entry point
/// (never by calling the service directly), stub only the runtime delay
/// primitive (`ChainCapabilityProbeService.delayProbeOverride`), and then wait
/// for the manager's capability view to converge.
void main() {
  late Directory tmp;
  late ChainProxyManager manager;

  /// Polls [cond] until it holds (or [timeout] elapses) so fire-and-forget
  /// probes can be observed deterministically.
  Future<void> waitFor(
    bool Function() cond, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final sw = Stopwatch()..start();
    while (!cond()) {
      if (sw.elapsed > timeout) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p23b_');
    ChainProxyManager.configFilePathOverride = p.join(
      tmp.path,
      'chain_proxies.json',
    );
    ChainProxyManager.fallbackPoolFilePathOverride = p.join(
      tmp.path,
      'chain_fallback_pool.json',
    );
    ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
      tmp.path,
      'chain_reliability_stats.json',
    );
    ChainProxyManager.capabilityProbeSourceOverride = null;
    ChainCapabilityProbeService.delayProbeOverride = null;
    ChainCapabilityCacheService.clear();
    manager = ChainProxyManager();
  });

  tearDown(() async {
    ChainProxyManager.capabilityProbeSourceOverride = null;
    ChainCapabilityProbeService.delayProbeOverride = null;
    ChainCapabilityCacheService.clear();
    // P2.3-C: flush any pending debounced write before dropping the overrides.
    await chainProxyManager.flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Map<dynamic, dynamic> node(String name, String server) => {
    'name': name,
    'type': 'vless',
    'server': server,
    'port': 443,
  };

  // ── P-2: baseline capability semantics ────────────────────────────────────
  group('P2.3-B (P-2) baseline semantics', () {
    test('1. baseline never pairs verifiedSupported with unknown evidence', () {
      const protocols = [
        'vless',
        'vmess',
        'trojan',
        'socks5',
        'hysteria2',
        'tuic',
        'wireguard',
        'shadowsocks',
        'ss',
        'unknown_proxy',
      ];
      for (final proto in protocols) {
        final profile = ChainCapabilityService.getBaselineCapability(proto);
        expect(
          profile.tcp.evidence,
          CapabilityEvidenceType.unknown,
          reason: '$proto baseline carries no evidence',
        );
        expect(
          profile.tcp.status,
          isNot(CapabilityStatus.verifiedSupported),
          reason: '$proto must not claim verified TCP without evidence',
        );
        expect(
          profile.udp.status,
          isNot(CapabilityStatus.verifiedSupported),
          reason: '$proto must not claim verified UDP without evidence',
        );
      }
    });

    test('2. http/https keep the protocol-level verifiedUnsupported UDP fact '
        'and the gate still blocks them', () {
      for (final proto in ['http', 'https']) {
        expect(
          ChainCapabilityService.getBaselineCapability(proto).udp.status,
          CapabilityStatus.verifiedUnsupported,
        );
      }
      final res = ChainCompatibilityValidator.validateEdge(
        ChainCapabilityService.getBaselineCapability('http'),
        ChainCapabilityService.getBaselineCapability('hysteria2'),
      );
      expect(res.compatible, isFalse);
      expect(res.reason, 'ENTRY_UDP_UNSUPPORTED');
    });

    test(
      '3. config-declared udp:true is still configDeclared+verifiedSupported',
      () {
        final profile = ChainCapabilityService.parseFromConfig({
          'type': 'vless',
          'udp': true,
        });
        expect(profile.udp.status, CapabilityStatus.verifiedSupported);
        expect(profile.udp.evidence, CapabilityEvidenceType.configDeclared);
      },
    );
  });

  // ── P-1: runtime probe production wiring ──────────────────────────────────
  group('P2.3-B (P-1) runtime probe wiring', () {
    test('A/B/F. manager refresh drives a real probe whose result enters '
        'capabilityProfiles and overrides the baseline', () async {
      int probeCalls = 0;
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        probeCalls++;
        return Delay(name: name, url: url, value: 42);
      };
      ChainProxyManager.capabilityProbeSourceOverride = [
        node('A-NODE', 'a.example'),
      ];

      // Entry point under test: the MANAGER, not the service.
      await manager.refreshCapabilityProfiles();

      // The config-level view is published synchronously…
      expect(manager.capabilityProfiles.containsKey('A-NODE'), isTrue);
      // …and the runtime probe (real getDelay path, stubbed primitive) runs.
      await waitFor(
        () =>
            manager.capabilityProfiles['A-NODE']?.tcp.evidence ==
            CapabilityEvidenceType.runtimeVerified,
      );

      expect(probeCalls, 1, reason: 'the real delay primitive must be hit');
      final profile = manager.capabilityProfiles['A-NODE']!;
      expect(profile.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
      expect(profile.tcp.status, CapabilityStatus.verifiedSupported);

      // A later refresh must not downgrade the established runtime evidence.
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        manager.capabilityProfiles['A-NODE']!.tcp.evidence,
        CapabilityEvidenceType.runtimeVerified,
      );
    });

    test(
      'C. a successful delay probe does not overclaim other dimensions',
      () async {
        ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
            Delay(name: name, url: url, value: 7);
        ChainProxyManager.capabilityProbeSourceOverride = [
          node('C-NODE', 'c.example'),
        ];

        await manager.refreshCapabilityProfiles();
        await waitFor(
          () =>
              manager.capabilityProfiles['C-NODE']?.tcp.evidence ==
              CapabilityEvidenceType.runtimeVerified,
        );

        final profile = manager.capabilityProfiles['C-NODE']!;
        expect(profile.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
        expect(profile.tcp.status, CapabilityStatus.verifiedSupported);
        // UDP was never probed → it must stay `unknown`, never fabricated.
        expect(
          profile.udp.status,
          CapabilityStatus.unknown,
          reason: 'a TCP reachability probe must not claim UDP support',
        );
      },
    );

    test('D. probe failure/timeout never throws and never becomes '
        'verifiedUnsupported', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          throw StateError('core unavailable');
      ChainProxyManager.capabilityProbeSourceOverride = [
        node('D-NODE', 'd.example'),
      ];

      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final profile = manager.capabilityProfiles['D-NODE'];
      expect(profile, isNotNull, reason: 'config-level view must survive');
      expect(
        profile!.tcp.evidence,
        isNot(CapabilityEvidenceType.runtimeVerified),
        reason: 'an inconclusive probe must not claim verification',
      );
      expect(
        profile.tcp.status,
        isNot(CapabilityStatus.verifiedUnsupported),
      );
      expect(
        profile.udp.status,
        isNot(CapabilityStatus.verifiedUnsupported),
      );
    });

    test('E. unknown capability is never treated as unsupported', () {
      final entry = ChainCapabilityService.getBaselineCapability('vless');
      final exit = ChainCapabilityService.getBaselineCapability('hysteria2');
      expect(entry.udp.status, CapabilityStatus.unknown);
      final res = ChainCompatibilityValidator.validateEdge(entry, exit);
      expect(res.compatible, isTrue);
    });

    test(
      'G. repeated refresh never starts duplicate concurrent probes',
      () async {
        final gate = Completer<Delay>();
        int probeCalls = 0;
        ChainCapabilityProbeService.delayProbeOverride = (url, name) {
          probeCalls++;
          return gate.future; // held open until released
        };
        ChainProxyManager.capabilityProbeSourceOverride = [
          node('G-NODE', 'g.example'),
        ];

        await manager.refreshCapabilityProfiles();
        await manager.refreshCapabilityProfiles();
        await manager.refreshCapabilityProfiles();

        expect(
          probeCalls,
          1,
          reason:
              'single-flight: one node must never be probed concurrently N×',
        );

        gate.complete(Delay(name: 'G-NODE', url: 'u', value: 9));
        await waitFor(
          () =>
              manager.capabilityProfiles['G-NODE']?.tcp.evidence ==
              CapabilityEvidenceType.runtimeVerified,
        );
      },
    );
  });
}
