import '../models/protocol_capability.dart';

class CompatibilityResult {
  final bool compatible;
  final String reason;
  final String? requiredTransport;
  final String? blockingProtocol;

  const CompatibilityResult.compatible()
    : compatible = true,
      reason = 'OK',
      requiredTransport = null,
      blockingProtocol = null;

  const CompatibilityResult.incompatible({
    required this.reason,
    this.requiredTransport,
    this.blockingProtocol,
  }) : compatible = false;
}

class ChainCompatibilityValidator {
  static bool _requiresUdp(String type) {
    switch (type.toLowerCase()) {
      case 'hysteria2':
      case 'tuic':
      case 'wireguard':
        return true;
      default:
        return false;
    }
  }

  static CompatibilityResult validateEdge(
    ProtocolCapabilityProfile? entryProfile,
    ProtocolCapabilityProfile? exitProfile,
  ) {
    if (entryProfile == null || exitProfile == null) {
      return const CompatibilityResult.compatible(); // Ignore if unknown or DIRECT
    }

    final requiresUdp = _requiresUdp(exitProfile.protocol);

    if (requiresUdp) {
      if (entryProfile.udpCapability == CapabilityStatus.verifiedUnsupported) {
        if (entryProfile.evidence == CapabilityEvidenceType.runtimeRejected) {
          return CompatibilityResult.incompatible(
            reason: 'ENTRY_UDP_RUNTIME_REJECTED',
            requiredTransport: 'UDP',
            blockingProtocol: entryProfile.protocol,
          );
        }
        return CompatibilityResult.incompatible(
          reason: 'ENTRY_UDP_UNSUPPORTED',
          requiredTransport: 'UDP',
          blockingProtocol: entryProfile.protocol,
        );
      } else if (entryProfile.udpCapability !=
              CapabilityStatus.verifiedSupported ||
          entryProfile.evidence == CapabilityEvidenceType.expired) {
        if (entryProfile.evidence == CapabilityEvidenceType.expired) {
          return CompatibilityResult.incompatible(
            reason: 'ENTRY_UDP_CAPABILITY_EXPIRED',
            requiredTransport: 'UDP',
            blockingProtocol: entryProfile.protocol,
          );
        }
        return CompatibilityResult.incompatible(
          reason: 'ENTRY_UDP_CAPABILITY_UNKNOWN',
          requiredTransport: 'UDP',
          blockingProtocol: entryProfile.protocol,
        );
      }
    }

    return const CompatibilityResult.compatible();
  }
}
