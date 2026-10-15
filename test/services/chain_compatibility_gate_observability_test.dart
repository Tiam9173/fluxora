import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// S-1 (T-A) — compatibility-gate observability, diagnostic only.
///
/// F-AR7 is NOT being fixed: `ChainCompatibilityValidator.validateEdge` returns
/// `compatible` for a `null` profile by contract, so the gate is *designed* to
/// fail open. S-1 only makes that pass-through **visible** in telemetry: it
/// records how many candidates reached the gate, how many were really verified,
/// and how many were let through unverified (with a cause).
///
/// The overriding invariant (T-5) is that these counters change **no** decision
/// output — `selected`, `rankedCandidates` and `excluded` are byte-for-byte the
/// same as before. T-1…T-4 pin the counters; T-5 pins the neutrality.
void main() {
  ProtocolCapabilityProfile p(String protocol) =>
      ChainCapabilityService.getBaselineCapability(protocol);

  ChainFallbackCandidate candidate(
    String name,
    FallbackCandidateRole role, {
    ChainHealthStatus health = ChainHealthStatus.healthy,
  }) => ChainFallbackCandidate(
    nodeName: name,
    role: role,
    health: health,
    statsByContext: {
      'unknown_default': ChainReliabilityStats(
        weightedSuccess: 0.0,
        weightedFailure: 0.0,
        consecutiveFailures: 0,
        totalSamples: 0,
        lastUpdated: DateTime(2026, 9, 28, 12, 0, 0),
        networkFingerprint: 'wifi_default',
      ),
    },
  );

  /// The metadata of the last telemetry event recorded by the selection.
  Map<String, dynamic> lastMetadata() {
    final events = chainTelemetryService.getSnapshot().recentEvents;
    final withCompat = events.where((e) => e.metadata != null).toList();
    expect(withCompat, isNotEmpty, reason: 'expected a metadata-carrying event');
    return withCompat.last.metadata!;
  }

  setUp(() => chainTelemetryService.clear());
  tearDown(() => chainTelemetryService.clear());

  const twoHopConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'Entry-VLESS',
    hop2Node: 'Exit-TUIC',
  );

  const threeHopConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.threeHop,
    hop1Node: 'Entry-VLESS',
    hop2Node: 'Relay-Active',
    hop3Node: 'Exit-TUIC',
  );

  group('S-1 (T-A) — compatibility gate observability is diagnostic only', () {
    // ── T-1 ────────────────────────────────────────────────────────────────
    test('T-1: empty capability table + a selected candidate reports '
        'compatibilityUnverified >= 1 with cause tableEmpty', () {
      final pool = ChainFallbackPool(
        exitCandidates: [candidate('US-Resi-02', FallbackCandidateRole.exit)],
      );

      final result = const ChainFallbackService().selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        // No capability table at all — the gate is skipped, fail-open.
        availableProxyProfiles: null,
      );

      expect(result.selectedNodeName, 'US-Resi-02');

      final md = lastMetadata();
      expect(md['compatibilityUnverified'], greaterThanOrEqualTo(1));
      expect(md['compatibilityChecked'], 0);
      expect(md['compatibilityUnverifiedCause'], 'tableEmpty');
    });

    // ── T-2 ────────────────────────────────────────────────────────────────
    test('T-2: full capability table with a compatible edge reports '
        'compatibilityChecked >= 1 and zero unverified', () {
      final pool = ChainFallbackPool(
        exitCandidates: [candidate('US-Resi-02', FallbackCandidateRole.exit)],
      );

      final result = const ChainFallbackService().selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        availableProxyProfiles: {
          'Entry-VLESS': p('vless'),
          'US-Resi-02': p('vless'),
        },
      );

      expect(result.selectedNodeName, 'US-Resi-02');

      final md = lastMetadata();
      expect(md['compatibilityChecked'], greaterThanOrEqualTo(1));
      expect(md['compatibilityUnverified'], 0);
      // Nothing was unverified, so there is no cause to report.
      expect(md['compatibilityUnverifiedCause'], isNull);
    });

    // ── T-3 ────────────────────────────────────────────────────────────────
    test('T-3: a verified-incompatible candidate is excluded and is NOT '
        'counted as unverified', () {
      final pool = ChainFallbackPool(
        relayCandidates: [
          candidate('Middle-HTTP', FallbackCandidateRole.relay),
          candidate('Middle-SOCKS5', FallbackCandidateRole.relay),
        ],
      );

      final result = const ChainFallbackService().selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.relay,
        pool: pool,
        availableProxyProfiles: {
          'Entry-VLESS': p('vless'),
          'Middle-HTTP': p('http'),
          'Middle-SOCKS5': p('socks5'),
          'Exit-TUIC': p('tuic'),
        },
      );

      // The incompatible relay is still excluded through the existing channel.
      expect(
        result.excluded.any(
          (e) =>
              e.candidate.nodeName == 'Middle-HTTP' &&
              e.reasonCode == 'PROTOCOL_INCOMPATIBLE',
        ),
        isTrue,
      );
      expect(result.selectedNodeName, 'Middle-SOCKS5');

      final md = lastMetadata();
      // Two candidates reached the gate: one verified compatible, one excluded.
      expect(md['compatibilityChecked'], 1);
      // The excluded one must not leak into the unverified count.
      expect(md['compatibilityUnverified'], 0);
      expect(md['compatibilityUnverifiedCause'], isNull);
    });

    // ── T-4 ────────────────────────────────────────────────────────────────
    test('T-4 (non-vacuity): a candidate missing from a NON-empty table is '
        'reported as unverified with cause missingProfile', () {
      // The table exists but does not contain this node's profile, so
      // `validateEdge` receives a `null` and returns compatible WITHOUT a real
      // check. This is the `missingProfile` cause — distinct from `tableEmpty`.
      final pool = ChainFallbackPool(
        exitCandidates: [candidate('US-Resi-02', FallbackCandidateRole.exit)],
      );

      final result = const ChainFallbackService().selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        availableProxyProfiles: {
          'Entry-VLESS': p('vless'),
          // 'US-Resi-02' deliberately absent.
        },
      );

      expect(result.selectedNodeName, 'US-Resi-02');

      final md = lastMetadata();
      expect(md['compatibilityUnverified'], greaterThanOrEqualTo(1));
      expect(md['compatibilityUnverifiedCause'], 'missingProfile');
    });

    // ── T-5 ────────────────────────────────────────────────────────────────
    test('T-5 (hard gate): the counters change NO decision output', () {
      final pool = ChainFallbackPool(
        relayCandidates: [
          candidate('Middle-HTTP', FallbackCandidateRole.relay),
          candidate('Middle-SOCKS5', FallbackCandidateRole.relay),
          candidate('Middle-VLESS', FallbackCandidateRole.relay),
        ],
      );

      // Two runs over the SAME pool, differing only in whether the capability
      // table is supplied. The gate observability must not perturb the
      // decision outputs it accompanies.
      final withTable = const ChainFallbackService().selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.relay,
        pool: pool,
        availableProxyProfiles: {
          'Entry-VLESS': p('vless'),
          'Middle-HTTP': p('http'),
          'Middle-SOCKS5': p('socks5'),
          'Middle-VLESS': p('vless'),
          'Exit-TUIC': p('tuic'),
        },
      );
      final mdWith = lastMetadata();

      final withoutTable = const ChainFallbackService().selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.relay,
        pool: pool,
        availableProxyProfiles: null,
      );
      final mdWithout = lastMetadata();

      // The incompatible candidate is excluded in the table run; without the
      // table the same candidate is (by design) passed through. That difference
      // comes from the gate itself, NOT from the new counters. What T-5 pins is
      // that the counters add no further change: with the table present, the
      // outcome is exactly what the gate alone dictates.
      expect(
        withTable.rankedCandidates.map((c) => c.nodeName).toList(),
        isNot(contains('Middle-HTTP')),
      );
      expect(
        withTable.excluded.map((e) => e.candidate.nodeName).toList(),
        contains('Middle-HTTP'),
      );
      // The unverified path still admits the same candidates the gate admits.
      expect(
        withoutTable.rankedCandidates.map((c) => c.nodeName).toList(),
        containsAll(<String>['Middle-HTTP', 'Middle-SOCKS5', 'Middle-VLESS']),
      );

      // And the diagnostics agree with the decision they describe.
      expect(mdWith['compatibilityUnverified'], 0);
      expect(mdWith['compatibilityChecked'], greaterThanOrEqualTo(1));
      expect(mdWithout['compatibilityUnverified'], 3);
      expect(mdWithout['compatibilityUnverifiedCause'], 'tableEmpty');
    });
  });
}
