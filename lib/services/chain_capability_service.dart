import '../models/protocol_capability.dart';
import 'chain_capability_cache_service.dart';

class ChainCapabilityService {
  /// Resolves the **baseline** (no-evidence) capability profile from the
  /// protocol type alone.
  ///
  /// P2.3-B (P-2): the baseline carries **no** runtime evidence, so it must not
  /// claim `verifiedSupported` — that status means "confirmed by evidence",
  /// and pairing it with `evidence == unknown` is a semantic contradiction
  /// (`verifiedSupported + evidence=unknown`). Without evidence the status is
  /// `unknown`.
  ///
  /// The only protocol-level fact kept is that an HTTP/HTTPS CONNECT proxy
  /// cannot carry UDP at all → `verifiedUnsupported`. This is deliberate: the
  /// P1.2 compatibility gate (`ChainCompatibilityValidator`) blocks a candidate
  /// only on a *confirmed* `verifiedUnsupported` entry capability, so removing
  /// it would make the gate vacuous. `unknown` is still never treated as
  /// unsupported.
  ///
  /// No new enum values are introduced: only the existing
  /// `unknown / verifiedSupported / verifiedUnsupported` are used.
  static ProtocolCapabilityProfile getBaselineCapability(String protocolType) {
    final lower = protocolType.toLowerCase();

    final CapabilityStatus defaultUdp =
        (lower == 'http' || lower == 'https')
        ? CapabilityStatus.verifiedUnsupported
        : CapabilityStatus.unknown;

    return ProtocolCapabilityProfile(
      protocol: protocolType,
      // No evidence for UDP either → `unknown`, never a bare `verifiedSupported`.
      udp: CapabilityState(status: defaultUdp),
      // TCP / TLS default to `unknown` / `unknown`.
    );
  }

  /// Parses capability evidence directly from the node's proxy configuration map.
  static ProtocolCapabilityProfile parseFromConfig(
    Map<dynamic, dynamic> proxyConfig,
  ) {
    final type = proxyConfig['type']?.toString() ?? 'unknown';
    final baseline = getBaselineCapability(type);

    // If config explicitly declares udp: true or false
    if (proxyConfig.containsKey('udp')) {
      final udpValue = proxyConfig['udp'];
      bool isUdpTrue = false;

      if (udpValue is bool) {
        isUdpTrue = udpValue;
      } else if (udpValue is String) {
        isUdpTrue = udpValue.toLowerCase() == 'true';
      }

      return baseline.copyWith(
        udp: baseline.udp.copyWith(
          status: isUdpTrue
              ? CapabilityStatus.verifiedSupported
              : CapabilityStatus.verifiedUnsupported,
          evidence: CapabilityEvidenceType.configDeclared,
        ),
      );
    }

    return baseline;
  }

  /// Gets the highest priority capability evidence for a node config.
  /// Checks memory cache first, then falls back to static config parsing.
  ///
  /// P1.2-F: the merge is **per dimension**. A cached profile may carry runtime
  /// evidence for TCP/TLS while the config still declares UDP; merging the whole
  /// profile would let one dimension's evidence overwrite another's.
  static ProtocolCapabilityProfile getCapability(
    Map<dynamic, dynamic> proxyConfig,
  ) {
    final cacheKey = ChainCapabilityCacheService.generateKey(proxyConfig);
    final cachedProfile = ChainCapabilityCacheService.get(cacheKey);
    final configProfile = parseFromConfig(proxyConfig);

    if (cachedProfile == null) return configProfile;

    return ProtocolCapabilityProfile(
      protocol: configProfile.protocol,
      tcp: _highest(cachedProfile.tcp, configProfile.tcp),
      tls: _highest(cachedProfile.tls, configProfile.tls),
      udp: _highest(cachedProfile.udp, configProfile.udp),
    );
  }

  /// Returns whichever state carries the stronger evidence.
  ///
  /// P1.2-K4 (C1): a **tie** resolves to [b] — the *current* config — not to the
  /// cached [a]. The cache key covers only the node identity
  /// (`type|server|port|uuid|password`), so a declaration that is NOT part of
  /// the key (notably `udp`) could otherwise be masked by a stale cached
  /// declaration for the whole TTL window: `configDeclared` (cached, e.g.
  /// `udp: true`) vs `configDeclared` (config, `udp: false`) is a tie, and
  /// returning the cached side kept the old declaration — which then fed
  /// `ChainCompatibilityValidator`'s UDP gate. Strictly higher evidence still
  /// wins, so runtime evidence continues to override a declaration.
  static CapabilityState _highest(CapabilityState a, CapabilityState b) {
    return a.evidence.priority > b.evidence.priority ? a : b;
  }
}
