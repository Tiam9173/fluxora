import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:intl/intl.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/cupertino.dart';

class _DecompressedResponseLimitExceeded extends FormatException {
  const _DecompressedResponseLimitExceeded()
    : super('Decompressed response exceeds 64 MiB');
}

class _ResponseBodyLimitExceeded extends FormatException {
  const _ResponseBodyLimitExceeded()
    : super('HTTP response body exceeds 64 MiB');
}

class _LimitedByteSink extends ByteConversionSinkBase {
  _LimitedByteSink(this.maxBytes, this.limitExceeded);

  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List takeBytes() => _builder.takeBytes();
  final FormatException limitExceeded;

  @override
  void add(List<int> chunk) {
    if (_builder.length + chunk.length > maxBytes) {
      throw limitExceeded;
    }
    _builder.add(chunk);
  }

  @override
  void close() {}
}

/// IP 检测失败的原因。
///
/// 之前所有失败都显示同一句「请尝试手动刷新」，用户分不清是节点不通、内核
/// 没起来，还是探测地址本身挂了。
enum IpFailureReason {
  /// 探测地址连上了但超时（多半是节点不通或链路很慢）。
  timeout,

  /// 连 127.0.0.1 的代理端口就被拒了（内核没起来 / 端口不对）。
  coreNotReady,
}

class Request {
  static const _maxDecompressedBytes = 64 * 1024 * 1024;
  static const _maxResponseBodyBytes = 64 * 1024 * 1024;

  /// 最近一次 IP 检测失败的原因；成功时为 null。
  IpFailureReason? lastIpFailureReason;
  late final Dio _dio;
  late final Dio _clashDio;
  String? userAgent;

  Request() {
    _dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        return client;
      },
    );
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return FluxoraHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
  }

  Uint8List _decompressIfNeeded(Uint8List bytes, Headers headers) {
    final encodings =
        headers['content-encoding']?.map((e) => e.toLowerCase()).toList() ?? [];
    final encodingStr = encodings.join(', ');
    var wantGzip = encodingStr.contains('gzip');
    var wantDeflate = encodingStr.contains('deflate');

    var current = bytes;
    for (var i = 0; i < 4; i++) {
      final isGzipMagic =
          current.length >= 2 && current[0] == 0x1f && current[1] == 0x8b;
      if (wantGzip || isGzipMagic) {
        if (!isGzipMagic) {
          if (wantGzip) throw const FormatException('Invalid gzip response');
          break;
        }
        if (current.length < 20) {
          throw const FormatException('Truncated gzip response');
        }
        try {
          current = _decodeWithLimit(gzip.decoder, current);
          wantGzip = false;
          continue;
        } on _DecompressedResponseLimitExceeded {
          rethrow;
        } catch (error) {
          throw FormatException('Invalid gzip response: $error');
        }
      }
      if (wantDeflate) {
        try {
          current = _decodeWithLimit(zlib.decoder, current);
          wantDeflate = false;
          continue;
        } on _DecompressedResponseLimitExceeded {
          rethrow;
        } catch (zlibError) {
          try {
            current = _decodeWithLimit(ZLibDecoder(raw: true), current);
            wantDeflate = false;
            continue;
          } on _DecompressedResponseLimitExceeded {
            rethrow;
          } catch (rawError) {
            throw FormatException(
              'Invalid deflate response: $zlibError; $rawError',
            );
          }
        }
      }
      break;
    }
    return current;
  }

  Uint8List _bytesFromResponse(Response response) {
    final data = response.data;
    if (data is Uint8List) return data;
    return Uint8List.fromList((data as List).cast<int>());
  }

  Uint8List _decodeWithLimit(
    Converter<List<int>, List<int>> decoder,
    Uint8List input,
  ) {
    final sink = _LimitedByteSink(
      _maxDecompressedBytes,
      const _DecompressedResponseLimitExceeded(),
    );
    final inputSink = decoder.startChunkedConversion(sink);
    inputSink.add(input);
    inputSink.close();
    return sink.takeBytes();
  }

  Future<Uint8List> _readResponseBody(ResponseBody responseBody) async {
    final sink = _LimitedByteSink(
      _maxResponseBodyBytes,
      const _ResponseBodyLimitExceeded(),
    );
    try {
      await for (final chunk in responseBody.stream) {
        sink.add(chunk);
      }
      return sink.takeBytes();
    } finally {
      // Close the adapter response when a size-limit error ends the stream early.
      // ignore: invalid_use_of_internal_member
      responseBody.close();
    }
  }

  Future<Response> _getResponseForUrl(
    String url,
    ResponseType responseType, {
    CancelToken? cancelToken,
  }) async {
    String? userInfo;
    String requestUrl = url;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final schemeEnd = url.indexOf('://') + 3;
      final slashIndex = url.indexOf('/', schemeEnd);
      final questionIndex = url.indexOf('?', schemeEnd);
      final hashIndex = url.indexOf('#', schemeEnd);
      var authorityEnd = url.length;
      if (slashIndex != -1) authorityEnd = slashIndex;
      if (questionIndex != -1 && questionIndex < authorityEnd) {
        authorityEnd = questionIndex;
      }
      if (hashIndex != -1 && hashIndex < authorityEnd) {
        authorityEnd = hashIndex;
      }
      final atIndex = url.lastIndexOf('@', authorityEnd - 1);
      if (atIndex >= schemeEnd) {
        userInfo = url.substring(schemeEnd, atIndex);
        requestUrl = url.substring(0, schemeEnd) + url.substring(atIndex + 1);
      }
    }

    final headers = <String, dynamic>{'Connection': 'close'};
    if (userInfo != null && userInfo.isNotEmpty) {
      final auth = base64Encode(utf8.encode(userInfo));
      headers['Authorization'] = 'Basic $auth';
    }

    final response = await _clashDio.get<ResponseBody>(
      requestUrl,
      options: Options(responseType: ResponseType.stream, headers: headers),
      cancelToken: cancelToken,
    );

    final body = response.data;
    if (body == null) throw const FormatException('Empty HTTP response body');
    final rawBytes = await _readResponseBody(body);
    final decompressedBytes = _decompressIfNeeded(rawBytes, response.headers);

    if (responseType == ResponseType.plain) {
      final text = utf8.decode(decompressedBytes, allowMalformed: true);
      return Response(
        requestOptions: response.requestOptions,
        data: text,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
        headers: response.headers,
      );
    } else {
      return Response(
        requestOptions: response.requestOptions,
        data: decompressedBytes,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
        headers: response.headers,
      );
    }
  }

  Future<Response> getFileResponseForUrl(
    String url, {
    CancelToken? cancelToken,
  }) async {
    return _getResponseForUrl(
      url,
      ResponseType.bytes,
      cancelToken: cancelToken,
    );
  }

  Future<Response> getTextResponseForUrl(
    String url, {
    CancelToken? cancelToken,
  }) async {
    return _getResponseForUrl(
      url,
      ResponseType.plain,
      cancelToken: cancelToken,
    );
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );
    final body = response.data;
    if (body == null) return null;
    final rawBytes = await _readResponseBody(body);
    final bytes = _decompressIfNeeded(rawBytes, response.headers);
    return MemoryImage(bytes);
  }

  /// Newest release in the requested channel.
  ///
  /// Both channels read the same Atom feed: it lists every release
  /// (pre-releases included), needs no token — the REST API is rate-limited per
  /// IP — and **carries the release notes**, which is exactly what the update
  /// dialog renders. The stable channel simply skips entries whose tag looks
  /// like a pre-release.
  Future<Map<String, dynamic>?> checkForUpdate({
    bool includePrerelease = false,
  }) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.get(
        'https://github.com/$repository/releases.atom?t=$t',
      );
      final xml = response.data.toString();
      final current = globalState.packageInfo.version;
      for (final match in RegExp(
        r'<entry>([\s\S]*?)</entry>',
      ).allMatches(xml)) {
        final entry = match.group(1) ?? '';
        final title = RegExp(
          r'<title>([^<]*)</title>',
        ).firstMatch(entry)?.group(1)?.trim();
        if (title == null || title.isEmpty) continue;
        final isPrerelease = RegExp(
          r'-(rc|beta|alpha|pre|dev)',
          caseSensitive: false,
        ).hasMatch(title);
        if (!includePrerelease && isPrerelease) continue;
        if (utils.compareVersions(title.replaceAll('v', ''), current) <= 0) {
          continue;
        }
        final link = RegExp(
          r'<link[^>]*href="([^"]+)"',
        ).firstMatch(entry)?.group(1);
        final content =
            RegExp(
              r'<content[^>]*>([\s\S]*?)</content>',
            ).firstMatch(entry)?.group(1) ??
            '';
        return {
          'tag_name': title,
          'html_url': link ?? 'https://github.com/$repository/releases',
          'body': _releaseNotesFromHtml(content),
        };
      }
    } catch (e) {
      commonPrint.log('Check update failed: ${e.formatErrorLog}');
    }
    return null;
  }

  /// Turns the Atom entry's HTML into the `- ` bullet lines that
  /// `utils.parseReleaseBody` reads, so the dialog shows the real notes instead
  /// of a placeholder sentence.
  static String _releaseNotesFromHtml(String html) {
    // GitHub escapes the release body inside <content>, so the markup arrives
    // as entities (&lt;li&gt;). Decoding has to happen *first*: stripping tags
    // before that finds no <li> at all, every bullet is lost, and the dialog
    // shows a version number with no notes under it.
    //
    // It is escaped twice (a body containing "&" arrives as "&amp;amp;"), so
    // one pass leaves a literal "&amp;" in the middle of a sentence.
    String decode(String input) => input
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        // Last, so an escaped entity (&amp;lt;) is not decoded twice.
        .replaceAll('&amp;', '&');

    final decoded = decode(decode(html));
    final text = decoded
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Release bodies are mostly boilerplate: community links, download tables,
    // feedback and the licence credits. Only the changelog belongs in an update
    // prompt, so stop at the first section that is clearly not one.
    const stopMarkers = [
      'telegram',
      'download',
      '下载',
      'feedback',
      '反馈',
      '致谢',
      '鸣谢',
      'acknowledg',
      '开源协议',
      'license',
      'licence',
      'notice',
      'lineage',
    ];
    final notes = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (stopMarkers.any(lower.contains)) break;
      notes.add(line);
    }
    return notes.join('\n');
  }

  // Returns the current *built-in* primary IP source for the given locale.
  // Kept as the fallback when the user has not overridden the URL.
  String _builtinPrimaryIpSource() {
    return defaultNetworkDetectionUrl;
  }

  // Reads the user-configured network detection URL (primary source).
  // Falls back to the locale-aware built-in source when unset/empty/invalid,
  // so default behavior is unchanged for existing users.
  String _configuredPrimaryIpSource() {
    try {
      final url = globalState.config.appSetting.networkDetectionUrl;
      if (url.isNotEmpty && url.isUrl) return url;
    } catch (_) {}
    return _builtinPrimaryIpSource();
  }

  List<String> _getPrimaryIpSources() {
    final primary = _configuredPrimaryIpSource();
    return [
      primary,
      'https://get.geojs.io/v1/ip/geo.json',
    ].where((e) => e.isNotEmpty).toSet().toList();
  }

  final List<String> _domesticIpSources = ['https://myip.ipip.net/json'];

  final List<String> _cloudflareIpInfoSources = [
    'https://ip.sb/cdn-cgi/trace',
    'https://api.ip.sb/cdn-cgi/trace',
  ];

  final List<String> _cloudflareDomesticIpSources = [
    'https://www.qualcomm.cn/cdn-cgi/trace',
    'https://www.teamviewer.cn/cdn-cgi/trace',
  ];

  Future<Result<IpInfo?>> _checkIpFromSources(
    List<String> sources,
    CancelToken? cancelToken,
    Duration? timeout, {
    void Function(IpInfo info)? onUpdate,
    bool preferIpv6 = false,
    bool direct = false,
  }) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);

    final dio = Dio(
      BaseOptions(
        receiveTimeout: effectiveTimeout,
        connectTimeout: effectiveTimeout,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        if (direct) client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );

    final Completer<Result<IpInfo?>> firstCompleter = Completer();
    IpInfo? primaryInfo;
    IpInfo? fallbackInfo;
    IpInfo? publishedInfo;
    int completedCount = 0;
    Timer? cleanupTimer;
    var sawTimeout = false;
    var sawConnectionError = false;
    lastIpFailureReason = null;

    IpInfo? preferredInfo() {
      final primary = primaryInfo;
      final fallback = fallbackInfo;
      if (preferIpv6 &&
          fallback != null &&
          InternetAddress.tryParse(fallback.ip)?.type ==
              InternetAddressType.IPv6 &&
          (primary == null ||
              InternetAddress.tryParse(primary.ip)?.type !=
                  InternetAddressType.IPv6)) {
        return fallback;
      }
      return primary?.withCountryCodeFrom(fallback) ?? fallback;
    }

    void cleanup() {
      cleanupTimer?.cancel();
      cleanupTimer = null;
      dio.close(force: true);
    }

    cleanupTimer = Timer(effectiveTimeout, cleanup);
    cancelToken?.whenCancel.then((_) => cleanup());

    void checkAllFinished() {
      completedCount++;
      if (completedCount == sources.length) {
        if (!firstCompleter.isCompleted) {
          final res = preferredInfo();
          if (res != null) {
            onUpdate?.call(res);
          } else {
            // 全部源都失败：记下原因，UI 据此选提示文案。
            lastIpFailureReason = sawConnectionError
                ? IpFailureReason.coreNotReady
                : (sawTimeout ? IpFailureReason.timeout : null);
            commonPrint.log(
              '[ip] all ${sources.length} sources failed '
              '(connectionError=$sawConnectionError, timeout=$sawTimeout)',
            );
          }
          firstCompleter.complete(Result.success(res));
        }
        cleanup();
      }
    }

    for (int i = 0; i < sources.length; i++) {
      final url = sources[i];
      final isPrimary = i == 0;
      final startedAt = DateTime.now();
      dio
          .get<Uint8List>(
            url,
            cancelToken: cancelToken,
            options: Options(responseType: ResponseType.bytes),
          )
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              try {
                final text = utf8
                    .decode(
                      _decompressIfNeeded(_bytesFromResponse(res), res.headers),
                      allowMalformed: true,
                    )
                    .trim();
                IpInfo? ipInfo;
                if (text.startsWith('{')) {
                  final jsonMap = json.decode(text);
                  if (jsonMap is Map<String, dynamic>) {
                    if (url.contains('ip-api.com') &&
                        jsonMap['status'] != 'success') {
                      ipInfo = null;
                    } else {
                      ipInfo = IpInfo.fromJson(jsonMap);
                    }
                  }
                } else {
                  ipInfo = IpInfo.fromCloudflareTrace(text);
                }

                if (ipInfo != null &&
                    InternetAddress.tryParse(ipInfo.ip) != null) {
                  if (isPrimary) {
                    primaryInfo = ipInfo;
                  } else {
                    fallbackInfo = ipInfo;
                  }
                  final info = preferredInfo()!;
                  if (!identical(info, publishedInfo)) {
                    publishedInfo = info;
                    onUpdate?.call(info);
                  }
                  if (!firstCompleter.isCompleted) {
                    firstCompleter.complete(Result.success(info));
                  }
                }
              } catch (_) {}
            }
            checkAllFinished();
          })
          .catchError((e) {
            final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
            commonPrint.log('[ip] $url -> ${e.runtimeType}: $e (${elapsed}ms)');
            if (e is DioException) {
              switch (e.type) {
                case DioExceptionType.connectionTimeout:
                case DioExceptionType.receiveTimeout:
                case DioExceptionType.sendTimeout:
                  sawTimeout = true;
                case DioExceptionType.connectionError:
                  sawConnectionError = true;
                case DioExceptionType.cancel:
                  if (!firstCompleter.isCompleted) {
                    firstCompleter.complete(Result.error('cancelled'));
                  }
                default:
                  break;
              }
            }
            checkAllFinished();
          });
    }

    return await firstCompleter.future.timeout(
      effectiveTimeout,
      onTimeout: () {
        final res = preferredInfo();
        if (res == null) {
          lastIpFailureReason = IpFailureReason.timeout;
          commonPrint.log(
            '[ip] overall timeout after ${effectiveTimeout.inSeconds}s',
          );
        }
        return Result.success(res);
      },
    );
  }

  /// Retries a few times before giving up.
  ///
  /// The IP lookup sites (ip-api, geojs) regularly time out for a few seconds
  /// under load. One failure used to leave the card showing "请手动刷新" until
  /// the user tapped it, even though the tunnel was fine and the next attempt
  /// would have worked.
  Future<Result<IpInfo?>> _withRetries(
    Future<Result<IpInfo?>> Function() attempt, {
    int retries = 2,
    CancelToken? cancelToken,
  }) async {
    var result = await attempt();
    for (var i = 1; i <= retries; i++) {
      if (result.data != null) return result;
      if (cancelToken?.isCancelled ?? false) return result;
      await Future.delayed(Duration(milliseconds: 600 * i));
      if (cancelToken?.isCancelled ?? false) return result;
      result = await attempt();
    }
    return result;
  }

  Future<Result<IpInfo?>> checkIp({
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(IpInfo info)? onUpdate,
    int retries = 2,
    bool direct = false,
  }) async {
    final sources = _getPrimaryIpSources();
    final primary = sources.first;
    final preferIpv6 =
        globalState.config.patchClashConfig.ipv6 &&
        (primary == defaultNetworkDetectionUrl ||
            primary == _builtinPrimaryIpSource());
    return _withRetries(
      () => _checkIpFromSources(
        sources,
        cancelToken,
        timeout,
        onUpdate: onUpdate,
        preferIpv6: preferIpv6,
        direct: direct,
      ),
      retries: retries,
      cancelToken: cancelToken,
    );
  }

  Future<Result<IpInfo?>> checkIpDomestic({
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(IpInfo info)? onUpdate,
    bool direct = false,
  }) async {
    return _checkIpFromSources(
      _domesticIpSources,
      cancelToken,
      timeout,
      onUpdate: onUpdate,
      direct: direct,
    );
  }

  Future<Result<IpInfo?>> checkIpCloudflare({
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _checkIpFromSources(_cloudflareIpInfoSources, cancelToken, timeout);
  }

  Future<Result<IpInfo?>> checkIpDomesticCloudflare({
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _checkIpFromSources(
      _cloudflareDomesticIpSources,
      cancelToken,
      timeout,
    );
  }

  static const _ipCacheKey = 'ip_detail_cache';
  static const _cacheDuration = Duration(days: 14);

  Future<IpInfo?> _getValidCachedIp(String cacheKey) async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      final cacheStr = prefs?.getString(_ipCacheKey);
      if (cacheStr == null || cacheStr.isEmpty) return null;

      final dynamic decoded = json.decode(cacheStr);
      if (decoded is! Map) return null;

      final rawMap = Map<String, dynamic>.from(decoded);
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = _cacheDuration.inMilliseconds;

      bool hasExpired = false;
      final validEntries = <String, dynamic>{};
      IpInfo? matchedIpInfo;

      // 仅在用户查询时，主动检查并清理所有过期的缓存
      for (final entry in rawMap.entries) {
        final val = entry.value;
        if (val is Map) {
          final valMap = Map<String, dynamic>.from(val);
          final timestamp = valMap['timestamp'] as num?;
          if (timestamp != null && (now - timestamp) < maxAgeMs) {
            validEntries[entry.key] = valMap;
            if (entry.key == cacheKey && valMap['data'] is Map) {
              try {
                matchedIpInfo = IpInfo.fromJson(
                  Map<String, dynamic>.from(valMap['data'] as Map),
                );
              } catch (_) {}
            }
          } else {
            hasExpired = true;
          }
        }
      }

      // 如果有过期的数据被剔除，保存清理后的缓存
      if (hasExpired) {
        await prefs?.setString(_ipCacheKey, json.encode(validEntries));
      }

      return matchedIpInfo;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedIp(String cacheKey, IpInfo ipInfo) async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      final cacheStr = prefs?.getString(_ipCacheKey);
      final rawMap = (cacheStr != null && cacheStr.isNotEmpty)
          ? Map<String, dynamic>.from(json.decode(cacheStr) as Map)
          : <String, dynamic>{};

      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = _cacheDuration.inMilliseconds;

      // 清理已过期数据，并插入新数据
      final validEntries = <String, dynamic>{};
      for (final entry in rawMap.entries) {
        final val = entry.value;
        if (val is Map) {
          final valMap = Map<String, dynamic>.from(val);
          final timestamp = valMap['timestamp'] as num?;
          if (timestamp != null && (now - timestamp) < maxAgeMs) {
            validEntries[entry.key] = valMap;
          }
        }
      }

      validEntries[cacheKey] = {'timestamp': now, 'data': ipInfo.toJson()};

      await prefs?.setString(_ipCacheKey, json.encode(validEntries));
    } catch (_) {}
  }

  Future<Result<IpInfo?>> queryIpDetail(
    String ip, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final isZh = Intl.getCurrentLocale().toLowerCase().startsWith('zh');
    final cacheKey = '${ip}_${isZh ? 'zh' : 'en'}';

    // 1. 检查本地缓存并执行过期清理（有效时长7天）
    final cached = await _getValidCachedIp(cacheKey);
    if (cached != null) {
      return Result.success(cached);
    }

    final effectiveTimeout = timeout ?? const Duration(seconds: 5);
    final url = isZh
        ? 'http://ip-api.com/json/$ip?lang=zh-CN'
        : 'http://ip-api.com/json/$ip';

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: effectiveTimeout,
          sendTimeout: effectiveTimeout,
        ),
      );

      if (res.statusCode == HttpStatus.ok && res.data != null) {
        final data = res.data!;
        final status = data['status']?.toString();
        if (status == 'fail') {
          final message = data['message']?.toString() ?? 'query failed';
          return Result.error(message);
        }
        final ipInfo = IpInfo.fromJson(data);
        // 2. 写入 7 天有效期的本地缓存
        await _saveCachedIp(cacheKey, ipInfo);
        return Result.success(ipInfo);
      }
      return Result.error('query failed');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return Result.error('cancelled');
      }
      return Result.error(e.toString());
    }
  }
}

final request = Request();
