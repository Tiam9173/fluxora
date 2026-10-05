import '../models/protocol_capability.dart';
import 'chain_capability_cache_service.dart';

class ChainCapabilityService {
  /// Resolves baseline tcp/udp capabilities simply based on the protocol type.
  static ProtocolCapabilityProfile getBaselineCapability(String protocolType) {
    final lower = protocolType.toLowerCase();

    CapabilityStatus defaultUdp = CapabilityStatus.unknown;
    CapabilityStatus defaultTcp =
        CapabilityStatus.verifiedSupported; // almost all support TCP

    switch (lower) {
      case 'socks5':
      case 'hysteria2':
      case 'tuic':
      case 'wireguard':
      case 'shadowsocks':
      case 'ss':
        defaultUdp = CapabilityStatus.verifiedSupported;
        break;
      case 'vless':
      case 'vmess':
      case 'trojan':
        defaultUdp = CapabilityStatus.unknown;
        break;
      case 'http':
      case 'https':
        defaultUdp = CapabilityStatus.verifiedUnsupported;
        break;
      default:
        defaultUdp = CapabilityStatus.unknown;
        break;
    }

    return ProtocolCapabilityProfile(
      protocol: protocolType,
      udpCapability: defaultUdp,
      tcpCapability: defaultTcp,
      evidence: CapabilityEvidenceType.unknown,
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
        udpCapability: isUdpTrue
            ? CapabilityStatus.verifiedSupported
            : CapabilityStatus.verifiedUnsupported,
        evidence: CapabilityEvidenceType.configDeclared,
      );
    }

    return baseline;
  }

  /// Gets the highest priority capability evidence for a node config.
  /// Checks memory cache first, then falls back to static config parsing.
  static ProtocolCapabilityProfile getCapability(
    Map<dynamic, dynamic> proxyConfig,
  ) {
    final cacheKey = ChainCapabilityCacheService.generateKey(proxyConfig);
    final cachedProfile = ChainCapabilityCacheService.get(cacheKey);
    final configProfile = parseFromConfig(proxyConfig);

    if (cachedProfile != null) {
      // If the cached profile has higher or equal priority evidence, use it.
      if (cachedProfile.evidence.isHigherOrEqual(configProfile.evidence)) {
        return cachedProfile;
      }
    }

    return configProfile;
  }
}
