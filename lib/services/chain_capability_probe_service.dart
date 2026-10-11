import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/models/core.dart';

import '../models/protocol_capability.dart';
import 'chain_capability_cache_service.dart';
import 'chain_capability_service.dart';

class ChainCapabilityProbeService {
  /// Test-only seam overriding the runtime delay primitive. Production never
  /// sets it — it exists so the probe's verified/rejected/inconclusive branches
  /// can be exercised without a live Mihomo core.
  @visibleForTesting
  static Future<Delay> Function(String url, String proxyName)?
  delayProbeOverride;

  /// P1.2-C: real (minimal) runtime capability probe.
  ///
  /// Verifies **reachability** through the runtime primitive already used by
  /// P1.1-D1 (`clashCore.getDelay`). A **strictly positive** round-trip
  /// (`value > 0`) is recorded as [CapabilityEvidenceType.runtimeVerified]; a
  /// definite failure — `null`, `0` or a negative value, including the native
  /// bridge's own `-1` timeout sentinel — as
  /// [CapabilityEvidenceType.runtimeRejected] (P1.2-G1).
  ///
  /// Everything else — timeout / core unavailable / cancelled / unexpected
  /// exception / insufficient evidence — returns the previous profile with
  /// `unknown` evidence and NEVER writes to the cache: an inconclusive probe
  /// must not poison capability evidence.
  ///
  /// Scope (first version): TCP / reachability only. UDP, TLS, WebSocket,
  /// gRPC, HTTP/2, QUIC, Reality, IPv4/IPv6 and DNS probing are explicitly out
  /// of scope.
  ///
  /// This does NOT touch health, semantic classification, reliability or the
  /// fallback pool.
  static Future<ProtocolCapabilityProfile> probeAndVerify(
    Map<dynamic, dynamic> proxyConfig, {
    String? testUrl,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final baseline = ChainCapabilityService.getCapability(proxyConfig);

    // Already definitively verified or rejected → nothing to do.
    //
    // P1.2-F: this probe verifies **TCP** (and TLS), so the early-return must
    // read the TCP dimension. Reading a profile-level evidence here used to let
    // an unrelated UDP declaration suppress TCP/TLS probing.
    if (baseline.tcp.evidence == CapabilityEvidenceType.runtimeVerified ||
        baseline.tcp.evidence == CapabilityEvidenceType.runtimeRejected) {
      return baseline;
    }

    final name = proxyConfig['name']?.toString() ?? '';
    if (name.isEmpty) {
      // Insufficient evidence → stay unknown, do not cache.
      return baseline;
    }

    final url = testUrl ?? 'https://www.gstatic.com/generate_204';
    final key = ChainCapabilityCacheService.generateKey(proxyConfig);

    try {
      final probe = delayProbeOverride;
      final res = await (probe != null
              ? probe(url, name)
              : clashCore.getDelay(url, name))
          .timeout(timeout);
      final delay = res.value;
      // P1.2-G1: a delay primitive can answer with a **non-positive** sentinel
      // instead of `null`. The native bridge returns `value == -1` on its own
      // 6s timeout (`clash/interface.dart` `asyncTestDelay`'s `onTimeout`),
      // which fires *before* this call's own (longer) timeout — so `-1` used to
      // be read as a completed round-trip and recorded as `runtimeVerified`.
      // Only a strictly positive round-trip counts as verified; `null` **or**
      // `<= 0` is a definite failure. This mirrors the existing convention at
      // `chain_proxy_manager.dart` (`val != null && val > 0`).
      final verified = delay != null && delay > 0;
      final probed = verified
          ? baseline.copyWith(
              tcp: baseline.tcp.copyWith(
                status: CapabilityStatus.verifiedSupported,
                evidence: CapabilityEvidenceType.runtimeVerified,
              ),
              // P1.2-B: the delay primitive performs a real HTTP HEAD through
              // the node with a TLS-capable transport, so a completed round-trip
              // against an `https://` URL also proves the TLS handshake. A
              // non-https test URL leaves TLS untouched (`copyWith(null)` keeps
              // the previous value).
              tls: url.toLowerCase().startsWith('https://')
                  ? baseline.tls.copyWith(
                      status: CapabilityStatus.verifiedSupported,
                      evidence: CapabilityEvidenceType.runtimeVerified,
                    )
                  : null,
            )
          : baseline.copyWith(
              tcp: baseline.tcp.copyWith(
                status: CapabilityStatus.verifiedUnsupported,
                evidence: CapabilityEvidenceType.runtimeRejected,
              ),
            );
      ChainCapabilityCacheService.set(key, probed);
      return probed;
    } on TimeoutException {
      return baseline; // inconclusive → unknown, no cache write
    } catch (_) {
      return baseline; // inconclusive → unknown, no cache write
    }
  }
}
