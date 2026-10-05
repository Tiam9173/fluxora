enum CapabilityStatus { unknown, verifiedSupported, verifiedUnsupported }

enum CapabilityEvidenceType {
  unknown,
  expired,
  configDeclared,
  userConfirmed,
  runtimeVerified,
  runtimeRejected,
}

extension CapabilityEvidenceTypeExtension on CapabilityEvidenceType {
  int get priority {
    switch (this) {
      case CapabilityEvidenceType.unknown:
        return 0;
      case CapabilityEvidenceType.expired:
        return 1;
      case CapabilityEvidenceType.configDeclared:
        return 2;
      case CapabilityEvidenceType.userConfirmed:
        return 3;
      case CapabilityEvidenceType.runtimeVerified:
        return 4;
      case CapabilityEvidenceType.runtimeRejected:
        return 5;
    }
  }

  bool isHigherOrEqual(CapabilityEvidenceType other) {
    return priority >= other.priority;
  }
}

class ProtocolCapabilityProfile {
  final String protocol;
  final CapabilityStatus udpCapability;
  final CapabilityStatus tcpCapability;
  final CapabilityEvidenceType evidence;

  const ProtocolCapabilityProfile({
    required this.protocol,
    required this.udpCapability,
    required this.tcpCapability,
    required this.evidence,
  });

  factory ProtocolCapabilityProfile.unknown(String protocol) {
    return ProtocolCapabilityProfile(
      protocol: protocol,
      udpCapability: CapabilityStatus.unknown,
      tcpCapability: CapabilityStatus.unknown,
      evidence: CapabilityEvidenceType.unknown,
    );
  }

  factory ProtocolCapabilityProfile.withEvidence({
    required String protocol,
    required CapabilityStatus udpCapability,
    required CapabilityStatus tcpCapability,
    required CapabilityEvidenceType evidence,
  }) {
    return ProtocolCapabilityProfile(
      protocol: protocol,
      udpCapability: udpCapability,
      tcpCapability: tcpCapability,
      evidence: evidence,
    );
  }

  ProtocolCapabilityProfile copyWith({
    String? protocol,
    CapabilityStatus? udpCapability,
    CapabilityStatus? tcpCapability,
    CapabilityEvidenceType? evidence,
  }) {
    return ProtocolCapabilityProfile(
      protocol: protocol ?? this.protocol,
      udpCapability: udpCapability ?? this.udpCapability,
      tcpCapability: tcpCapability ?? this.tcpCapability,
      evidence: evidence ?? this.evidence,
    );
  }

  @override
  String toString() {
    return 'ProtocolCapabilityProfile(protocol: $protocol, udp: $udpCapability, tcp: $tcpCapability, evidence: $evidence)';
  }
}
