import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fluxora/models/ip_reputation.dart';

/// Reads public IP risk reports without credentials. Missing data stays unknown.
class IpReputationService {
  IpReputationService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final _cache = <String, ({IpReputation report, DateTime expiresAt})>{};

  /// Only reports already stored by IPure are available anonymously.
  static const String endpoint = 'https://ipure.dev/api/v1/ip';
  static const String publicEndpoint = 'https://api.ipquery.io';

  /// Vendor-documented status codes that carry a machine-readable `code`.
  static const String _codeVerificationRequired = 'verification_required';

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
    Duration timeout = const Duration(seconds: 12),
    CancelToken? cancelToken,
  }) async {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }
    if (cancelToken?.isCancelled == true) {
      return IpReputation.unavailable(ip, IpReputationFailure.network);
    }
    if (timeout <= Duration.zero) {
      return IpReputation.unavailable(ip, IpReputationFailure.timeout);
    }
    final key = address.address;
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.report;
    }
    final timer = Stopwatch()..start();
    final firstBudget = Duration(microseconds: timeout.inMicroseconds ~/ 3);
    var report = await _request(
      key,
      '$endpoint/${Uri.encodeComponent(key)}',
      firstBudget,
      cancelToken,
      parse,
    );
    if (!report.isOk && cancelToken?.isCancelled != true) {
      final remaining = timeout - timer.elapsed;
      if (remaining > Duration.zero) {
        report = await _request(
          key,
          '$publicEndpoint/${Uri.encodeComponent(key)}',
          remaining,
          cancelToken,
          parsePublicReport,
        );
      }
    }
    if (report.isOk && cancelToken?.isCancelled != true) {
      _cache.remove(key);
      if (_cache.length >= 32) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = (
        report: report,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
    }
    return report;
  }

  Future<IpReputation> _request(
    String ip,
    String url,
    Duration timeout,
    CancelToken? parent,
    IpReputation Function(String, int, Map<String, dynamic>?) decode,
  ) async {
    final token = CancelToken();
    var finished = false;
    parent?.whenCancel.then((_) {
      if (!finished) token.cancel();
    });
    if (parent?.isCancelled == true) token.cancel();
    try {
      final res = await _dio
          .get<dynamic>(
            url,
            cancelToken: token,
            options: Options(
              responseType: ResponseType.json,
              followRedirects: false,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              validateStatus: (_) => true,
            ),
          )
          .timeout(
            timeout,
            onTimeout: () {
              token.cancel();
              throw TimeoutException('IP reputation lookup timed out');
            },
          );
      return decode(
        ip,
        res.statusCode ?? 0,
        res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null,
      );
    } on TimeoutException {
      return IpReputation.unavailable(ip, IpReputationFailure.timeout);
    } on DioException catch (e) {
      return IpReputation.unavailable(
        ip,
        e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout
            ? IpReputationFailure.timeout
            : IpReputationFailure.network,
      );
    } catch (_) {
      return IpReputation.unavailable(ip, IpReputationFailure.network);
    } finally {
      finished = true;
    }
  }

  /// IPQuery 公开接口仅提供独立标记；不将其风险值换算成 IPure 纯净度。
  IpReputation parsePublicReport(
    String ip,
    int status,
    Map<String, dynamic>? body,
  ) {
    if (status == 429) {
      return IpReputation.unavailable(ip, IpReputationFailure.rateLimited);
    }
    if (status < 200 || status >= 300) {
      return IpReputation.unavailable(ip, IpReputationFailure.httpError);
    }
    final risk = body?['risk'];
    final address = InternetAddress.tryParse(ip);
    if (body == null ||
        address == null ||
        risk is! Map ||
        InternetAddress.tryParse(body['ip']?.toString() ?? '') != address ||
        !const [
          'is_vpn',
          'is_proxy',
          'is_tor',
          'is_datacenter',
          'is_mobile',
        ].any((key) => risk[key] is bool)) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }
    final isp = body['isp'];
    return IpReputation(
      status: IpReputationStatus.ok,
      ip: address.address,
      source: 'IPQuery',
      markers: _markers({
        'isVpn': risk['is_vpn'],
        'isProxy': risk['is_proxy'],
        'isTor': risk['is_tor'],
        'isHosting': risk['is_datacenter'],
        'isMobile': risk['is_mobile'],
      }),
      asn: isp is Map ? _nonEmpty(isp['asn']) : null,
      asnOrg: isp is Map ? _nonEmpty(isp['org']) : null,
      reportUrl:
          'https://ipquery.io/ip/${Uri.encodeComponent(address.address)}',
    );
  }

  /// Pure mapping from an HTTP status + decoded body to a report. Kept public so
  /// the failure taxonomy and the marker tri-state can be unit-tested offline.
  IpReputation parse(String ip, int statusCode, Map<String, dynamic>? body) {
    final error = body?['error'];
    final code = error is Map ? error['code'] : body?['code'];
    if (statusCode == 401) {
      return IpReputation.unavailable(ip, IpReputationFailure.noPublicReport);
    }
    if (statusCode == 403) {
      return IpReputation.unavailable(
        ip,
        code == _codeVerificationRequired
            ? IpReputationFailure.quotaExhausted
            : IpReputationFailure.httpError,
      );
    }
    if (statusCode == 429) {
      return IpReputation.unavailable(ip, IpReputationFailure.rateLimited);
    }
    if (statusCode < 200 || statusCode >= 300) {
      return IpReputation.unavailable(ip, IpReputationFailure.httpError);
    }
    final data = body?['data'];
    if (data is Map) body = Map<String, dynamic>.from(data);
    final requested = InternetAddress.tryParse(ip.trim());
    if (body == null ||
        requested == null ||
        InternetAddress.tryParse(body['ip']?.toString() ?? '') != requested) {
      return IpReputation.unavailable(ip, IpReputationFailure.parseError);
    }

    try {
      return IpReputation(
        status: IpReputationStatus.ok,
        ip: body['ip'].toString(),
        queriedAt: DateTime.tryParse(body['queriedAt']?.toString() ?? ''),
        source: 'IPure',
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
          state: switch (flags?[entry.value]) {
            true => IpRiskMarkerState.flagged,
            false => IpRiskMarkerState.clear,
            _ => IpRiskMarkerState.unknown,
          },
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
