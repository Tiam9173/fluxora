import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/public_ip_info.dart';

typedef RawHttpFetcher =
    Future<String> Function(
      String url, {
      Duration? timeout,
      CancelToken? cancelToken,
      int proxyPort,
    });

class _CacheEntry {
  final PublicIpInfo data;
  final DateTime expiresAt;

  const _CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class PublicIpService {
  static PublicIpService? _instance;
  final Duration defaultTimeout;
  final Duration cacheTtl;
  final RawHttpFetcher? _customFetcher;

  final Map<String, _CacheEntry> _cache = {};

  PublicIpService({
    this.defaultTimeout = const Duration(seconds: 5),
    this.cacheTtl = const Duration(minutes: 5),
    RawHttpFetcher? customFetcher,
  }) : _customFetcher = customFetcher;

  factory PublicIpService.getInstance() {
    _instance ??= PublicIpService();
    return _instance!;
  }

  void clearCache() {
    _cache.clear();
  }

  void invalidateCacheForPort(int proxyPort) {
    _cache.removeWhere((key, _) => key.startsWith('${proxyPort}_'));
  }

  Future<String> _defaultFetch(
    String url, {
    Duration? timeout,
    CancelToken? cancelToken,
    int proxyPort = 0,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;
    final dio = Dio(
      BaseOptions(
        connectTimeout: effectiveTimeout,
        receiveTimeout: effectiveTimeout,
        sendTimeout: effectiveTimeout,
        headers: {
          'User-Agent': 'Fluxora/1.1.0 (PublicIpService)',
          'Accept': 'application/json, text/plain, */*',
        },
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = effectiveTimeout;
        client.badCertificateCallback = (_, _, _) => true;
        if (proxyPort > 0) {
          client.findProxy = (uri) => 'PROXY 127.0.0.1:$proxyPort';
        }
        return client;
      },
    );

    try {
      final response = await dio.get<String>(
        url,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> _fetch(
    String url, {
    Duration? timeout,
    CancelToken? cancelToken,
    int proxyPort = 0,
  }) async {
    if (_customFetcher != null) {
      return _customFetcher(
        url,
        timeout: timeout,
        cancelToken: cancelToken,
        proxyPort: proxyPort,
      );
    }
    return _defaultFetch(
      url,
      timeout: timeout,
      cancelToken: cancelToken,
      proxyPort: proxyPort,
    );
  }

  List<String> _getSourcesForVersion(IpVersion targetVersion) {
    if (targetVersion == IpVersion.v6) {
      return const [
        'https://v6.ident.me',
        'https://api64.ipify.org?format=json',
        'https://api.ip.sb/cdn-cgi/trace',
      ];
    }
    return const [
      'http://ip-api.com/json/?lang=zh-CN',
      'https://get.geojs.io/v1/ip/geo.json',
      'https://api.ip.sb/cdn-cgi/trace',
    ];
  }

  PublicIpInfo? parseResponse(String rawText, String sourceUrl) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    final now = DateTime.now();

    // 1. JSON response parser
    if (text.startsWith('{')) {
      try {
        final dynamic decoded = json.decode(text);
        if (decoded is Map<String, dynamic>) {
          if (decoded['status'] != null && decoded['status'] != 'success') {
            return null;
          }

          final rawIp =
              (decoded['query'] ?? decoded['ip'])?.toString().trim() ?? '';
          if (rawIp.isEmpty) return null;

          final version = IpVersion.detect(rawIp);
          String? country = decoded['country']?.toString();
          String? countryCode =
              (decoded['countryCode'] ?? decoded['country_code'])?.toString();
          String? region = (decoded['regionName'] ?? decoded['region'])
              ?.toString();
          String? city = decoded['city']?.toString();
          String? isp = (decoded['isp'] ?? decoded['organization_name'])
              ?.toString();
          String? asn = (decoded['as'] ?? decoded['asn'])?.toString();

          return PublicIpInfo(
            ip: rawIp,
            version: version,
            country: country?.isNotEmpty == true ? country : null,
            countryCode: countryCode?.isNotEmpty == true ? countryCode : null,
            region: region?.isNotEmpty == true ? region : null,
            city: city?.isNotEmpty == true ? city : null,
            isp: isp?.isNotEmpty == true ? isp : null,
            asn: asn?.isNotEmpty == true ? asn : null,
            timestamp: now,
            source: sourceUrl,
          );
        }
      } catch (_) {
        // Fall through to plain text
      }
    }

    // 2. Cloudflare Trace (key=value lines)
    if (text.contains('ip=') || text.contains('loc=')) {
      final lines = text.split('\n');
      String? ip;
      String? loc;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('ip=')) {
          ip = trimmed.substring(3).trim();
        } else if (trimmed.startsWith('loc=')) {
          loc = trimmed.substring(4).trim();
        }
      }

      if (ip != null && ip.isNotEmpty) {
        return PublicIpInfo(
          ip: ip,
          version: IpVersion.detect(ip),
          countryCode: loc?.isNotEmpty == true ? loc : null,
          timestamp: now,
          source: sourceUrl,
        );
      }
    }

    // 3. Plain IP string fallback (e.g. ident.me)
    final candidateIp = text.split(RegExp(r'\s+')).first;
    final detectedVer = IpVersion.detect(candidateIp);
    if (detectedVer != IpVersion.unknown) {
      return PublicIpInfo(
        ip: candidateIp,
        version: detectedVer,
        timestamp: now,
        source: sourceUrl,
      );
    }

    return null;
  }

  Future<Result<PublicIpInfo>> fetchPublicIp({
    int proxyPort = 0,
    IpVersion targetVersion = IpVersion.unknown,
    Duration? timeout,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;
    final cacheKey = '${proxyPort}_${targetVersion.name}';

    // 1. Check memory cache
    if (!forceRefresh) {
      final entry = _cache[cacheKey];
      if (entry != null && !entry.isExpired) {
        return Result.success(entry.data);
      }
    }

    final sources = _getSourcesForVersion(targetVersion);
    String? lastErrorMessage;

    for (final sourceUrl in sources) {
      if (cancelToken?.isCancelled == true) {
        return Result.error('cancelled');
      }

      try {
        final body = await _fetch(
          sourceUrl,
          timeout: effectiveTimeout,
          cancelToken: cancelToken,
          proxyPort: proxyPort,
        );

        final parsed = parseResponse(body, sourceUrl);
        if (parsed != null && parsed.ip.isNotEmpty) {
          // If a specific version was requested and mismatch, ignore and try next
          if (targetVersion != IpVersion.unknown &&
              parsed.version != targetVersion) {
            continue;
          }

          // Cache the valid result
          _cache[cacheKey] = _CacheEntry(
            data: parsed,
            expiresAt: DateTime.now().add(cacheTtl),
          );

          return Result.success(parsed);
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          return Result.error('cancelled');
        }
        lastErrorMessage = e.toString();
      }
    }

    return Result.error(lastErrorMessage ?? '所有公网 IP 查询源均未响应有效数据');
  }
}

final publicIpService = PublicIpService.getInstance();
