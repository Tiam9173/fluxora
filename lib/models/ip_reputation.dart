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

/// One reason behind the source's score — a deduction or a bonus.
///
/// item 6 — the score is only shown alongside these, never on its own: a number
/// without its reasons is the black box E-4 rejected.
class IpRiskFactor {
  final String id;
  final String? category;
  final String label;

  /// Negative means the source *added* points for this (a good signal);
  /// positive means it deducted. Sign is the source's, not ours.
  final int points;
  final String? detail;

  const IpRiskFactor({
    required this.id,
    required this.label,
    required this.points,
    this.category,
    this.detail,
  });
}

/// The source's own composite assessment.
///
/// item 6 (user decision, relaxing E-4) — E-4 originally kept this out entirely
/// because a 0–100 score hides how it was reached. It is allowed back **only
/// because** the source also sends [factors], and the UI always renders the two
/// together, labelled as the source's judgement rather than a verdict of ours.
class IpRiskScore {
  /// 0–100, higher is cleaner.
  final int? purity;
  final int? riskPoints;
  final String? level;
  final String? label;
  final String? verdict;
  final List<IpRiskFactor> factors;

  const IpRiskScore({
    this.purity,
    this.riskPoints,
    this.level,
    this.label,
    this.verdict,
    this.factors = const [],
  });

  /// True when there is a number worth showing.
  bool get hasScore => purity != null;
}

/// How suitable the IP is for one concrete use.
///
/// item 6 — the source scores each use case separately because "is this IP any
/// good" has no single answer: an address can be fine for streaming and hopeless
/// for email. [id] is stable and non-localised, so the UI owns the translation
/// and the source's own Chinese label is deliberately not shown.
class IpScenarioScore {
  /// One of [IpReputationService.scenarioIds].
  final String id;
  final int? score;

  /// The source's verdict for this use, e.g. "very suitable".
  final String? levelLabel;
  final String? reason;

  const IpScenarioScore({
    required this.id,
    this.score,
    this.levelLabel,
    this.reason,
  });
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

  /// The source's composite score, shown together with its reasons.
  ///
  /// Null when the source did not send one — which the UI must render as "no
  /// score", never as a good score.
  final IpRiskScore? risk;

  /// Per-use-case suitability. Empty when the source sent none — which is
  /// "nothing to say", never "fine for everything".
  final List<IpScenarioScore> scenarios;

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
    this.risk,
    this.scenarios = const [],
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
