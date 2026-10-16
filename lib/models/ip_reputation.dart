/// P4 — IP reputation ("IP 风险情报") data contract.
///
/// Decisions this file encodes (from the user's E-1..E-6 baseline):
///
/// * **E-4** — independent markers only. There is deliberately **no composite
///   0–100 score** and no overall verdict: the vendor exposes `risk.purity`
///   and a six-level `verdict`, but surfacing those would invent a single
///   number the project explicitly rejected.
/// * **E-4** — a marker that the source does not provide is [IpRiskMarkerState
///   .unknown], **never** `clear`. "No data" is not "low risk".
/// * **E-5** — this model is **separate from `IpInfo`** and never feeds it.
/// * **E-5** — failure is modelled as [IpReputationStatus.unavailable] with a
///   reason, never as a clean result.
library;

/// Tri-state for a single risk marker.
enum IpRiskMarkerState {
  /// The source affirmatively reports this property.
  flagged,

  /// The source affirmatively reports its absence.
  clear,

  /// The source said nothing about it — the UI must show "unknown", not "clear".
  unknown,
}

/// One independent marker (E-4 list). `id` is a stable, non-localised key so
/// the UI owns the translation.
class IpRiskMarker {
  final String id;
  final IpRiskMarkerState state;

  /// Optional extra fact supplied by the source (e.g. a known VPN operator name).
  final String? detail;

  const IpRiskMarker({
    required this.id,
    required this.state,
    this.detail,
  });
}

enum IpReputationStatus { ok, unavailable }

/// Why a lookup produced no report. Kept as a stable key (not a message) so the
/// UI decides the wording and the caller can distinguish "quota" from "timeout".
class IpReputationFailure {
  static const quotaExhausted = 'quota_exhausted';
  static const rateLimited = 'rate_limited';
  static const timeout = 'timeout';
  static const network = 'network';
  static const parseError = 'parse_error';
  static const httpError = 'http_error';
}

/// One report. `status == unavailable` means **nothing is known** — the UI must
/// not render it as a clean bill of health (E-5: failure ≠ safe).
class IpReputation {
  final IpReputationStatus status;

  /// One of [IpReputationFailure]; null when [status] is ok.
  final String? failureReason;

  final String ip;

  /// When the *source* produced the report (`queriedAt`). Null when unavailable.
  final DateTime? queriedAt;

  /// `fresh` (live query) · `cache` (process cache) · `store` (historical).
  final String? source;

  /// True when the source itself marks the report as past its freshness
  /// threshold — the UI must not present a stale report as real-time (E-5).
  final bool stale;

  final List<IpRiskMarker> markers;

  final String? asn;
  final String? asnOrg;

  /// `residential` · `mobile` · `business` · `hosting` · `education` ·
  /// `government` · `unknown`.
  final String? usageType;

  /// `native` · `broadcast` · `unknown`.
  final String? nativeType;

  /// Abuse reputation. Null means the source did not report it — which is
  /// **not** the same as a zero score.
  final int? abuseScore;
  final int? abuseReports;

  /// Names of public blocklists that listed this IP (benign listings excluded).
  final List<String> blocklistsHit;

  /// The source's own "what this data cannot tell you" list — surfaced verbatim
  /// so the UI can show the limits alongside the markers.
  final List<String> unknownNotes;

  /// Canonical web report for this IP; cited alongside any conclusion.
  final String? reportUrl;

  const IpReputation({
    required this.status,
    required this.ip,
    this.failureReason,
    this.queriedAt,
    this.source,
    this.stale = false,
    this.markers = const [],
    this.asn,
    this.asnOrg,
    this.usageType,
    this.nativeType,
    this.abuseScore,
    this.abuseReports,
    this.blocklistsHit = const [],
    this.unknownNotes = const [],
    this.reportUrl,
  });

  factory IpReputation.unavailable(String ip, String reason) =>
      IpReputation(
        status: IpReputationStatus.unavailable,
        ip: ip,
        failureReason: reason,
      );

  bool get isOk => status == IpReputationStatus.ok;

  /// True when at least one marker is affirmatively flagged.
  bool get hasFlaggedMarker =>
      markers.any((m) => m.state == IpRiskMarkerState.flagged);

  /// Markers the source did not speak to. The UI must render these explicitly
  /// rather than silently dropping them (E-4).
  List<IpRiskMarker> get unknownMarkers =>
      markers.where((m) => m.state == IpRiskMarkerState.unknown).toList();
}
