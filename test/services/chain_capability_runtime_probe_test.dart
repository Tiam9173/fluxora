
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_cache_service.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';

/// P1.2 — Protocol capability: configuration parsing, compatibility semantics
/// and the minimal runtime probe.
///
/// Service-level: exercises the REAL `ChainCapabilityService`,
/// `ChainCompatibilityValidator`, `ChainCapabilityCacheService` and
/// `ChainCapabilityProbeService`. Only the runtime delay primitive is stubbed
/// (`delayProbeOverride`) because it needs a live Mihomo core.
void main() {
  setUp(() {
    ChainCapabilityCacheService.clear();
    ChainCapabilityProbeService.delayProbeOverride = null;
  });

  tearDown(() {
    ChainCapabilityCacheService.clear();
    ChainCapabilityProbeService.delayProbeOverride = null;
  });

  // ── 1–4. Configuration capability ─────────────────────────────────────────
  group('P1.2-A configuration capability', () {
    test('1. udp: true → configDeclared + verifiedSupported', () {
      final profile = ChainCapabilityService.parseFromConfig({
        'type': 'vless',
        'server': 'A',
        'udp': true,
      });
      expect(profile.udp.evidence, CapabilityEvidenceType.configDeclared);
      expect(profile.udp.status, CapabilityStatus.verifiedSupported);
    });

    test('2. udp: false → configDeclared + verifiedUnsupported', () {
      final profile = ChainCapabilityService.parseFromConfig({
        'type': 'vless',
        'server': 'A',
        'udp': false,
      });
      expect(profile.udp.evidence, CapabilityEvidenceType.configDeclared);
      expect(profile.udp.status, CapabilityStatus.verifiedUnsupported);
    });

    test('3. udp missing → unknown (baseline only, no false positive)', () {
      final profile = ChainCapabilityService.parseFromConfig({
        'type': 'vless',
        'server': 'A',
      });
      expect(profile.udp.evidence, CapabilityEvidenceType.unknown);
      expect(profile.udp.status, CapabilityStatus.unknown);
    });

    test('4. cached entry for a different identity → cache miss (unknown)', () {
      const configA = {'type': 'vless', 'server': 'A', 'port': 443};
      const configB = {'type': 'vless', 'server': 'B', 'port': 443};

      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(configA),
        ProtocolCapabilityProfile(
          protocol: 'vless',
          tcp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
          udp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
        ),
      );

      expect(
        ChainCapabilityService.getCapability(configA).udp.evidence,
        CapabilityEvidenceType.runtimeVerified,
      );
      expect(
        ChainCapabilityService.getCapability(configB).udp.evidence,
        CapabilityEvidenceType.unknown,
      );
    });
  });

  // ── 5–9. Compatibility semantics ──────────────────────────────────────────
  group('P1.2-B compatibility semantics', () {
    ProtocolCapabilityProfile profile(
      String protocol,
      CapabilityStatus udp,
      CapabilityEvidenceType evidence,
    ) => ProtocolCapabilityProfile(
      protocol: protocol,
      tcp: CapabilityState(
        status: CapabilityStatus.verifiedSupported,
        evidence: evidence,
      ),
      udp: CapabilityState(status: udp, evidence: evidence),
    );

    test('5. supported → compatible', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('vless', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.configDeclared),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isTrue);
    });

    test('6. unsupported → PROTOCOL_INCOMPATIBLE', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('http', CapabilityStatus.verifiedUnsupported,
            CapabilityEvidenceType.configDeclared),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isFalse);
      expect(res.reason, 'ENTRY_UDP_UNSUPPORTED');
    });

    test('7. unknown → NOT excluded by capability alone', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('vless', CapabilityStatus.unknown,
            CapabilityEvidenceType.unknown),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isTrue);
    });

    test('8. entry UDP unsupported + exit hysteria2 → rejected', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('http', CapabilityStatus.verifiedUnsupported,
            CapabilityEvidenceType.configDeclared),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isFalse);
      expect(res.blockingProtocol, 'http');
    });

    test('9. entry UDP unknown + exit hysteria2 → NOT rejected', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('vless', CapabilityStatus.unknown,
            CapabilityEvidenceType.unknown),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isTrue);
    });

    test('9b. runtimeRejected + unsupported → ENTRY_UDP_RUNTIME_REJECTED', () {
      final res = ChainCompatibilityValidator.validateEdge(
        profile('vless', CapabilityStatus.verifiedUnsupported,
            CapabilityEvidenceType.runtimeRejected),
        profile('hysteria2', CapabilityStatus.verifiedSupported,
            CapabilityEvidenceType.unknown),
      );
      expect(res.compatible, isFalse);
      expect(res.reason, 'ENTRY_UDP_RUNTIME_REJECTED');
    });
  });

  // ── 10–17. Runtime probe ──────────────────────────────────────────────────
  group('P1.2-C runtime probe', () {
    const nodeConfig = {
      'name': 'NodeA',
      'type': 'vless',
      'server': 'A',
      'port': 443,
    };

    test('10. probe success → runtimeVerified (and cached)', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          Delay(name: 'n', url: 'u', value: 42);

      final result = await ChainCapabilityProbeService.probeAndVerify(
        nodeConfig,
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
      expect(result.tcp.status, CapabilityStatus.verifiedSupported);
      expect(
        ChainCapabilityService.getCapability(nodeConfig).tcp.evidence,
        CapabilityEvidenceType.runtimeVerified,
      );
    });

    test('11. definite probe failure → runtimeRejected (and cached)', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          Delay(name: 'n', url: 'u');

      final result = await ChainCapabilityProbeService.probeAndVerify(
        nodeConfig,
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeRejected);
      expect(result.tcp.status, CapabilityStatus.verifiedUnsupported);
    });

    // P1.2-G1: the delay primitive may answer with a **non-positive** sentinel
    // instead of `null` — the native bridge returns `value == -1` on its own 6s
    // timeout, which fires *before* this call's longer timeout. A non-positive
    // round-trip is a failure, never a verification.
    test(
      '11a. timeout sentinel (value: -1) → runtimeRejected, NOT verified',
      () async {
        ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
            Delay(name: 'n', url: 'u', value: -1);

        final result = await ChainCapabilityProbeService.probeAndVerify(
          nodeConfig,
        );
        expect(result.tcp.evidence, CapabilityEvidenceType.runtimeRejected);
        expect(result.tcp.status, CapabilityStatus.verifiedUnsupported);
        // The false positive used to also mark TLS verified on an https URL.
        expect(
          result.tls.evidence,
          isNot(CapabilityEvidenceType.runtimeVerified),
        );
        // The cache may hold the rejection, but never a verification.
        expect(
          ChainCapabilityService.getCapability(nodeConfig).tcp.evidence,
          isNot(CapabilityEvidenceType.runtimeVerified),
        );
      },
    );

    test(
      '11b. zero delay (value: 0) → runtimeRejected, NOT verified',
      () async {
        ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
            Delay(name: 'n', url: 'u', value: 0);

        final result = await ChainCapabilityProbeService.probeAndVerify(
          nodeConfig,
        );
        expect(result.tcp.evidence, CapabilityEvidenceType.runtimeRejected);
        expect(
          ChainCapabilityService.getCapability(nodeConfig).tcp.evidence,
          isNot(CapabilityEvidenceType.runtimeVerified),
        );
      },
    );

    test('11c. boundary: value 1 still verifies (no over-correction)', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          Delay(name: 'n', url: 'u', value: 1);

      final result = await ChainCapabilityProbeService.probeAndVerify(
        nodeConfig,
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
      expect(result.tcp.status, CapabilityStatus.verifiedSupported);
    });

    test('12. probe exception → unknown, cache NOT polluted', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          throw StateError('core unavailable');

      final result = await ChainCapabilityProbeService.probeAndVerify(
        nodeConfig,
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.unknown);
      expect(ChainCapabilityCacheService.get(
        ChainCapabilityCacheService.generateKey(nodeConfig),
      ), isNull);
    });

    test('13. probe timeout → unknown, cache NOT polluted', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return Delay(name: 'n', url: 'u', value: 1);
      };

      final result = await ChainCapabilityProbeService.probeAndVerify(
        nodeConfig,
        timeout: const Duration(milliseconds: 20),
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.unknown);
      expect(ChainCapabilityCacheService.get(
        ChainCapabilityCacheService.generateKey(nodeConfig),
      ), isNull);
    });

    test('15. cache hit → probe not repeated', () async {
      var calls = 0;
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        calls++;
        return Delay(name: 'n', url: 'u', value: 42);
      };

      await ChainCapabilityProbeService.probeAndVerify(nodeConfig);
      await ChainCapabilityProbeService.probeAndVerify(nodeConfig);
      expect(calls, 1, reason: 'second call must hit the cache');
    });

    test('16. 30-minute TTL → expired', () {
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(nodeConfig),
        ProtocolCapabilityProfile(
          protocol: 'vless',
          tcp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
          udp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
        ),
        overrideTimestamp: DateTime.now().subtract(const Duration(minutes: 31)),
      );
      expect(
        ChainCapabilityService.getCapability(nodeConfig).tcp.evidence,
        CapabilityEvidenceType.expired,
      );
    });

    test('17. node identity change → cache miss', () {
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(nodeConfig),
        ProtocolCapabilityProfile(
          protocol: 'vless',
          tcp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
          udp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
        ),
      );
      expect(
        ChainCapabilityService.getCapability({
          'type': 'vless',
          'server': 'A',
          'port': 8443, // port changed
        }).udp.evidence,
        CapabilityEvidenceType.unknown,
      );
    });
  });

  // ── 18–20. Ranking / UI integration semantics ─────────────────────────────
  group('P1.2 ranking / UI integration', () {
    test('18. configDeclared no longer resolves to unknown evidence', () {
      final profile = ChainCapabilityService.getCapability({
        'type': 'hysteria2',
        'server': 'A',
        'udp': true,
      });
      expect(profile.udp.evidence, isNot(CapabilityEvidenceType.unknown));
      expect(profile.udp.evidence, CapabilityEvidenceType.configDeclared);
    });

    test('19. runtimeVerified is a scoring-relevant evidence level', () {
      final verified = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
      );
      expect(
        verified.tcp.evidence.priority,
        greaterThan(CapabilityEvidenceType.unknown.priority),
      );
      expect(
        verified.tcp.evidence.isHigherOrEqual(
          CapabilityEvidenceType.configDeclared,
        ),
        isTrue,
      );
    });

    test('20. runtimeRejected has the highest evidence priority', () {
      expect(
        CapabilityEvidenceType.runtimeRejected.priority,
        greaterThan(CapabilityEvidenceType.runtimeVerified.priority),
      );
    });
  });

  // ── P1.2-F. Evidence independence (regression) ────────────────────────────
  //
  // Before P1.2-F the profile carried ONE evidence shared by TCP / TLS / UDP,
  // so a TCP/TLS probe relabelled the UDP declaration and vice versa. These
  // cases pin the fix.
  group('P1.2-F evidence independence', () {
    const udpNode = {
      'name': 'IndepA',
      'type': 'vless',
      'server': 'A',
      'port': 443,
      'udp': true,
    };

    test('A. TCP failure leaves the UDP dimension untouched', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          Delay(name: name, url: url); // definite failure

      final result = await ChainCapabilityProbeService.probeAndVerify(udpNode);

      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeRejected);
      expect(result.udp.evidence, CapabilityEvidenceType.configDeclared);
      expect(
        result.udp.evidence,
        isNot(CapabilityEvidenceType.runtimeRejected),
        reason: 'a TCP failure must never relabel the UDP declaration',
      );
    });

    test('B. HTTPS success verifies TCP and TLS but not UDP', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async =>
          Delay(name: name, url: url, value: 21);

      final result = await ChainCapabilityProbeService.probeAndVerify(udpNode);

      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
      expect(result.tls.evidence, CapabilityEvidenceType.runtimeVerified);
      expect(
        result.udp.evidence,
        CapabilityEvidenceType.configDeclared,
        reason: 'TLS verification must not upgrade the UDP dimension',
      );
    });

    test('C. only the UDP dimension drives ENTRY_UDP_RUNTIME_REJECTED', () {
      final entry = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.runtimeVerified,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedUnsupported,
          evidence: CapabilityEvidenceType.runtimeRejected,
        ),
      );
      final exit = ChainCapabilityService.getBaselineCapability('hysteria2');

      final res = ChainCompatibilityValidator.validateEdge(entry, exit);

      expect(res.compatible, isFalse);
      expect(res.reason, 'ENTRY_UDP_RUNTIME_REJECTED');
    });

    test('D. TCP rejection must NOT reject the UDP gate', () {
      // requiresUdp == true (exit is hysteria2), TCP is rejected, UDP is fine.
      final entry = ProtocolCapabilityProfile(
        protocol: 'vless',
        tcp: const CapabilityState(
          status: CapabilityStatus.verifiedUnsupported,
          evidence: CapabilityEvidenceType.runtimeRejected,
        ),
        udp: const CapabilityState(
          status: CapabilityStatus.verifiedSupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );
      final exit = ChainCapabilityService.getBaselineCapability('hysteria2');

      final res = ChainCompatibilityValidator.validateEdge(entry, exit);

      expect(
        res.reason,
        isNot('ENTRY_UDP_RUNTIME_REJECTED'),
        reason: 'a TCP/TLS rejection is not a UDP rejection',
      );
      expect(res.compatible, isTrue);
    });

    test('E. strong UDP evidence cannot suppress the TCP probe', () async {
      var calls = 0;
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        calls++;
        return Delay(name: name, url: url, value: 12);
      };

      // A cached profile whose UDP dimension already carries strong evidence.
      ChainCapabilityCacheService.set(
        ChainCapabilityCacheService.generateKey(udpNode),
        ProtocolCapabilityProfile(
          protocol: 'vless',
          udp: const CapabilityState(
            status: CapabilityStatus.verifiedSupported,
            evidence: CapabilityEvidenceType.runtimeVerified,
          ),
        ),
      );

      final result = await ChainCapabilityProbeService.probeAndVerify(udpNode);

      expect(
        calls,
        1,
        reason: 'UDP evidence must not short-circuit the TCP/TLS probe',
      );
      expect(result.tcp.evidence, CapabilityEvidenceType.runtimeVerified);
    });
  });
}
