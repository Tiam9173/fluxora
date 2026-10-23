import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_service.dart';
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

    // ── T-2 ────────────────────────────────────────────────────────────────

    // ── T-3 ────────────────────────────────────────────────────────────────

    // ── T-4 ────────────────────────────────────────────────────────────────

    // ── T-5 ────────────────────────────────────────────────────────────────
  });
}
