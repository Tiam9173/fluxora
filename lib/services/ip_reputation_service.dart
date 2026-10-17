import 'package:dio/dio.dart';
import 'package:fluxora/models/ip_reputation.dart';

/// P4 — reads the IPure report for one IP.
///
/// Contract (see `ip_reputation.dart` for the E-4/E-5 decisions):
///
/// * **Never throws.** Every failure becomes [IpReputation.unavailable] with a
///   reason, because a failed lookup must never be presented as "clean" (E-5).
/// * **Score only with its reasons.** E-4 originally dropped `risk` entirely.
///   The user has since relaxed that: the source's `purity` / `level` /
///   `verdict` are now mapped **together with `risk.factors`**, and the UI must
///   always render the number and the reasons as one unit, attributed to the
///   source. A score without its reasons would still be the black box E-4
///   rejected.
/// * **No new dependency.** Uses the `dio` client the project already ships.
/// * Does not touch `networkDetectionUrl`, the IP query order, or `IpInfo`.
class IpReputationService {
  IpReputationService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Keyless public endpoint — no API key, no secret compiled into the client.
  static const String endpoint = 'https://ipure.dev/api/lookup';

  /// Vendor-documented status codes that carry a machine-readable `code`.
  static const String _codeVerificationRequired = 'verification_required';
  static const String _codeOpenRateLimited = 'open_rate_limited';

  /// Marker `id` → the key the source uses inside `flags`.
  static const Map<String, String> markerFlagKeys = {
    'vpn': 'isVpn',
    'proxy': 'isProxy',
    'tor': 'isTor',
    'hosting': 'isHosting',
    'relay': 'isRelay',
    'mobile': 'isMobile',
    'bogon': 'isBogon',
    'searchEngineBot': 'isSearchEngineBot',
  };

  /// E-4 marker ids, in display order. Every one is always present in the
  /// result — a field the source omits becomes [IpRiskMarkerState.unknown]
  /// rather than being dropped.
  static List<String> get markerIds => markerFlagKeys.keys.toList();

  Future<IpReputation> lookup(
    String ip, {
    Duration timeout = const Duration(seconds: 8),
    CancelToken? cancelToken,
  }) async {
    if (ip.trim().isEmpty) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }
    try {
      final res = await _dio
          .get<dynamic>(
            endpoint,
            queryParameters: {'ip': ip},
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.json,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              validateStatus: (status) => true,
            ),
          )
          .timeout(timeout);
      final body = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : null;
      return parse(ip, res.statusCode ?? 0, body);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return IpReputation.unavailable(ip, IpReputationFailure.network);
      }
      final mapped = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout
          ? IpReputationFailure.timeout
          : IpReputationFailure.network;
      return IpReputation.unavailable(ip, mapped);
    } catch (_) {
      return IpReputation.unavailable(ip, IpReputationFailure.network);
    }
  }

  /// Pure mapping from an HTTP status + decoded body to a report. Kept public so
  /// the failure taxonomy and the marker tri-state can be unit-tested offline.
  IpReputation parse(String ip, int statusCode, Map<String, dynamic>? body) {
    if (statusCode == 403) {
      final code = body?['code']?.toString();
      return IpReputation.unavailable(
        ip,
        code == _codeVerificationRequired
            ? IpReputationFailure.quotaExhausted
            : IpReputationFailure.httpError,
      );
    }
    if (statusCode == 429) {
      final code = body?['code']?.toString();
      return IpReputation.unavailable(
        ip,
        code == _codeOpenRateLimited
            ? IpReputationFailure.rateLimited
            : IpReputationFailure.httpError,
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      return IpReputation.unavailable(ip, IpReputationFailure.httpError);
    }
    if (body == null || body['ip'] == null) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }

    try {
      return IpReputation(
        status: IpReputationStatus.ok,
        ip: body['ip'].toString(),
        queriedAt: DateTime.tryParse(body['queriedAt']?.toString() ?? ''),
        source: body['source']?.toString(),
        stale: body['stale'] == true,
        markers: _markers(body['flags']),
        asn: _asnNumber(body['asn']),
        asnOrg: _asnOrg(body['asn']),
        usageType: _nonEmpty(body['usageType']),
        nativeType: _nonEmpty(body['nativeType']),
        abuseScore: _abuseScore(body['abuse']),
        abuseReports: _abuseReports(body['abuse']),
        blocklistsHit: _blocklistsHit(body['blocklists']),
        risk: _risk(body['risk']),
        scenarios: _scenarios(body['scenarios']),
        unknownNotes: _unknownNotes(body['unknowns']),
        reportUrl: _nonEmpty(body['reportUrl']),
      );
    } catch (_) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }
  }

  /// Map the source's composite score, keeping its reasons attached.
  ///
  /// Returns null when the source sent nothing usable — the UI then shows "no
  /// score", which is not the same as a good score.
  static IpRiskScore? _risk(Object? raw) {
    if (raw is! Map) return null;
    final purity = _asInt(raw['purity']);
    final factorsRaw = raw['factors'];
    final factors = <IpRiskFactor>[];
    if (factorsRaw is List) {
      for (final item in factorsRaw) {
        if (item is! Map) continue;
        final id = _nonEmpty(item['id']);
        final label = _nonEmpty(item['label']);
        if (id == null || label == null) continue;
        factors.add(
          IpRiskFactor(
            id: id,
            label: label,
            // A factor without points cannot be ranked; treat it as neutral
            // rather than inventing a weight.
            points: _asInt(item['points']) ?? 0,
            category: _nonEmpty(item['category']),
            detail: _nonEmpty(item['detail']),
          ),
        );
      }
    }
    if (purity == null && factors.isEmpty) return null;
    return IpRiskScore(
      purity: purity,
      riskPoints: _asInt(raw['riskPoints']),
      level: _nonEmpty(raw['level']),
      label: _nonEmpty(raw['label']),
      verdict: _nonEmpty(raw['verdict']),
      factors: factors,
    );
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  /// Stable, non-localised scenario ids. The UI owns the translation, exactly
  /// as it does for marker ids.
  static const List<String> scenarioIds = [
    'ai',
    'social',
    'streaming',
    'gaming',
    'ecommerce',
    'email',
  ];

  /// Map per-use-case scores, dropping anything the source did not actually
  /// score — an unscored use is "nothing to say", not a low score.
  static List<IpScenarioScore> _scenarios(Object? raw) {
    if (raw is! List) return const [];
    final out = <IpScenarioScore>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = _nonEmpty(item['id']);
      if (id == null || !scenarioIds.contains(id)) continue;
      final score = _asInt(item['score']);
      // Without a number the entry says nothing usable.
      if (score == null) continue;
      out.add(
        IpScenarioScore(
          id: id,
          score: score,
          levelLabel: _nonEmpty(item['levelLabel']),
          reason: _nonEmpty(item['reason']),
        ),
      );
    }
    return out;
  }

  static String? _nonEmpty(Object? v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// `flags` is a required object of required booleans, so a `false` is the
  /// source **affirmatively** reporting absence ⇒ `clear`. A missing key or a
  /// missing `flags` object ⇒ `unknown` (never `clear`).
  static List<IpRiskMarker> _markers(Object? rawFlags) {
    final flags = rawFlags is Map ? rawFlags : null;
    return [
      for (final entry in markerFlagKeys.entries)
        IpRiskMarker(
          id: entry.key,
          state: flags == null || !flags.containsKey(entry.value)
              ? IpRiskMarkerState.unknown
              : (flags[entry.value] == true
                    ? IpRiskMarkerState.flagged
                    : IpRiskMarkerState.clear),
        ),
    ];
  }

  static String? _asnNumber(Object? rawAsn) {
    if (rawAsn is! Map) return null;
    final n = rawAsn['asn'];
    if (n == null) return null;
    final s = n.toString();
    return s.isEmpty ? null : 'AS$s';
  }

  static String? _asnOrg(Object? rawAsn) {
    if (rawAsn is! Map) return null;
    return _nonEmpty(rawAsn['org']) ?? _nonEmpty(rawAsn['name']);
  }

  /// `abuse[]` is a list; the first entry that carries a score wins. Null means
  /// the source reported nothing — **not** a zero score.
  static int? _abuseScore(Object? rawAbuse) {
    if (rawAbuse is! List) return null;
    for (final entry in rawAbuse) {
      if (entry is Map && entry['score'] is num) {
        return (entry['score'] as num).toInt();
      }
    }
    return null;
  }

  static int? _abuseReports(Object? rawAbuse) {
    if (rawAbuse is! List) return null;
    var total = 0;
    var seen = false;
    for (final entry in rawAbuse) {
      if (entry is Map && entry['reports'] is num) {
        total += (entry['reports'] as num).toInt();
        seen = true;
      }
    }
    return seen ? total : null;
  }

  /// Only genuine hits count: `listed == true` and **not** `benign`, and the
  /// list must have been reachable (`unavailable == false`). An unavailable
  /// list is "unknown", not "not listed".
  static List<String> _blocklistsHit(Object? rawBlocklists) {
    if (rawBlocklists is! List) return const [];
    final hits = <String>[];
    for (final entry in rawBlocklists) {
      if (entry is! Map) continue;
      if (entry['listed'] != true) continue;
      if (entry['benign'] == true) continue;
      if (entry['unavailable'] == true) continue;
      final name = _nonEmpty(entry['label']) ?? _nonEmpty(entry['zone']);
      if (name != null) hits.add(name);
    }
    return hits;
  }

  static List<String> _unknownNotes(Object? rawUnknowns) {
    if (rawUnknowns is! List) return const [];
    final notes = <String>[];
    for (final entry in rawUnknowns) {
      if (entry is! Map) continue;
      final label = _nonEmpty(entry['label']) ?? _nonEmpty(entry['detail']);
      if (label != null) notes.add(label);
    }
    return notes;
  }
}
