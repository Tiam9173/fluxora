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

/// P1.2-F: the state of a **single** capability dimension.
///
/// Before P1.2-F the profile carried one profile-level `evidence` shared by TCP,
/// TLS and UDP. That made a TCP/TLS probe relabel the UDP declaration (and vice
/// versa) — see `P1.2-E_CAPABILITY_EVIDENCE_PASSIVE_UDP_AUDIT.md`. Evidence is
/// now owned by the dimension it actually describes.
class CapabilityState {
  /// Whether the capability is confirmed / rejected / still unknown.
  final CapabilityStatus status;

  /// What the [status] is based on. `unknown` evidence never claims support.
  final CapabilityEvidenceType evidence;

  const CapabilityState({
    this.status = CapabilityStatus.unknown,
    this.evidence = CapabilityEvidenceType.unknown,
  });

  CapabilityState copyWith({
    CapabilityStatus? status,
    CapabilityEvidenceType? evidence,
  }) {
    return CapabilityState(
      status: status ?? this.status,
      evidence: evidence ?? this.evidence,
    );
  }

  @override
  String toString() => 'CapabilityState(status: $status, evidence: $evidence)';
}

/// Per-node capability profile.
///
/// Every dimension defaults to `unknown` / `unknown` — a capability is never
/// assumed supported without evidence.
class ProtocolCapabilityProfile {
  final String protocol;

  /// TCP reachability, verified by the real delay probe (`clashCore.getDelay`).
  final CapabilityState tcp;

  /// TLS capability.
  ///
  /// Only ever `verifiedSupported`, and only from a **runtime** probe whose test
  /// URL was `https://` — a completed HTTPS round-trip proves the TLS handshake
  /// succeeded through the node (the core performs a real HTTP HEAD with a TLS
  /// transport). A probe *failure* never marks TLS `verifiedUnsupported`: it may
  /// have failed at the TCP / DNS / timeout layer instead.
  final CapabilityState tls;

  /// UDP forwarding capability. Currently only ever `configDeclared` (the
  /// `udp` key of the node config); no runtime UDP probe exists yet.
  final CapabilityState udp;

  const ProtocolCapabilityProfile({
    required this.protocol,
    this.tcp = const CapabilityState(),
    this.tls = const CapabilityState(),
    this.udp = const CapabilityState(),
  });

  factory ProtocolCapabilityProfile.unknown(String protocol) {
    return ProtocolCapabilityProfile(protocol: protocol);
  }

  ProtocolCapabilityProfile copyWith({
    String? protocol,
    CapabilityState? tcp,
    CapabilityState? tls,
    CapabilityState? udp,
  }) {
    return ProtocolCapabilityProfile(
      protocol: protocol ?? this.protocol,
      tcp: tcp ?? this.tcp,
      tls: tls ?? this.tls,
      udp: udp ?? this.udp,
    );
  }

  @override
  String toString() {
    return 'ProtocolCapabilityProfile(protocol: $protocol, tcp: $tcp, tls: $tls, udp: $udp)';
  }
}
