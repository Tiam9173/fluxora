import 'dart:async';
import '../models/protocol_capability.dart';
import 'chain_capability_service.dart';
import 'chain_capability_cache_service.dart';

class ChainCapabilityProbeService {
  /// Probes the node capability asynchronously in the background.
  /// Strictly for evidence collection.
  /// Does NOT trigger Failover, modify node health, or touch Telemetry.
  static Future<void> probeAndVerify(Map<dynamic, dynamic> proxyConfig) async {
    // Skip if already definitively verified or rejected
    final current = ChainCapabilityService.getCapability(proxyConfig);
    if (current.evidence == CapabilityEvidenceType.runtimeVerified ||
        current.evidence == CapabilityEvidenceType.runtimeRejected) {
      return;
    }

    try {
      // Hypothetical background probe:
      // e.g. Create single-hop shadow node and send DNS over UDP.
      // For now, we simulate the network behavior.
      await Future.delayed(const Duration(milliseconds: 50));

      // Because this is a scaffold, we don't randomly verify or reject.
      // We expose a public method for tests or actual future implementation to record the result.
    } catch (e) {
      // Silent catch, no telemetry.
    }
  }

  /// Records the result of a capability probe directly into the cache.
  static void recordProbeResult(
    Map<dynamic, dynamic> proxyConfig,
    ProtocolCapabilityProfile profile,
  ) {
    final key = ChainCapabilityCacheService.generateKey(proxyConfig);
    ChainCapabilityCacheService.set(key, profile);
  }
}
