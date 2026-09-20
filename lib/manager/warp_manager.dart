import 'dart:convert';
import 'dart:io';

import 'package:bett_box/clash/core.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/common/curve25519.dart';
import 'package:bett_box/models/warp_config.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class WarpManager extends ChangeNotifier {
  static WarpManager? _instance;
  WarpConfig _config = const WarpConfig();
  bool _initialized = false;
  WarpStatusReport? _latestReport;
  bool _isTesting = false;
  bool _isRegistering = false;

  WarpManager._internal();

  factory WarpManager() {
    _instance ??= WarpManager._internal();
    return _instance!;
  }

  WarpConfig get config => _config;
  bool get isInitialized => _initialized;
  WarpStatusReport? get latestReport => _latestReport;
  bool get isTesting => _isTesting;
  bool get isRegistering => _isRegistering;

  Future<String> _getConfigFilePath() async {
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'warp_config.json');
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final filePath = await _getConfigFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final jsonMap = jsonDecode(content);
          if (jsonMap is Map<String, dynamic>) {
            _config = WarpConfig.fromJson(jsonMap);
          }
        }
      } else {
        // First-time setup: automatically pre-generate keys
        _config = WarpConfig.generateNew();
        await _saveConfig();
      }
    } catch (e) {
      commonPrint.log('WarpManager: Failed to load warp_config.json: $e');
      if (_config.privateKey.isEmpty) {
        _config = WarpConfig.generateNew();
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveConfig() async {
    try {
      final filePath = await _getConfigFilePath();
      final file = File(filePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(_config.toJson());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      commonPrint.log('WarpManager: Failed to save config: $e');
    }
  }

  Future<void> updateConfig(
    WarpConfig Function(WarpConfig current) updater, {
    bool reloadCore = true,
  }) async {
    _config = updater(_config);
    notifyListeners();
    await _saveConfig();
    if (reloadCore) {
      try {
        await globalState.appController.setupClashConfig();
        await globalState.appController.updateGroups();
      } catch (e) {
        commonPrint.log('WarpManager: Core reload: $e');
      }
      notifyListeners();
    }
  }

  Future<void> setEnable(bool enable) async {
    await updateConfig((c) => c.copyWith(enable: enable));
  }

  Future<void> setMode(WarpMode mode) async {
    await updateConfig((c) => c.copyWith(mode: mode));
  }

  Future<void> setDefaultDialer(String dialer) async {
    await updateConfig((c) => c.copyWith(defaultDialerProxy: dialer));
  }

  Future<void> setEndpoint(String server, int port) async {
    await updateConfig((c) => c.copyWith(server: server.trim(), port: port));
  }

  Future<void> setMtu(int mtu) async {
    await updateConfig((c) => c.copyWith(mtu: mtu));
  }

  Future<void> setLicenseKey(String licenseKey) async {
    await updateConfig((c) => c.copyWith(licenseKey: licenseKey.trim()));
  }

  Future<void> generateNewKeys() async {
    final keyPair = Curve25519.generateKeyPair();
    await updateConfig((c) => c.copyWith(
          privateKey: keyPair.privateKey,
          publicKey: keyPair.publicKey,
        ));
  }

  HttpClient _createHttpClient([int proxyPort = 0]) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    client.badCertificateCallback = (cert, host, port) => true;

    if (proxyPort > 0) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$proxyPort';
    }

    return client;
  }

  Future<int> _getEffectiveProxyPort() async {
    try {
      final isCoreRunning = await clashCore.isInit;
      if (isCoreRunning) {
        return globalState.config.patchClashConfig.mixedPort;
      }
    } catch (_) {}
    return 0;
  }

  /// Registers a free Cloudflare WARP account via Cloudflare REST API.
  /// Also binds user's license key if specified.
  Future<bool> registerCloudflareAccount({String? license}) async {
    _isRegistering = true;
    notifyListeners();

    try {
      // 1. Ensure valid key pair
      String priv = _config.privateKey;
      String pub = _config.publicKey;
      if (priv.isEmpty || pub.isEmpty) {
        final pair = Curve25519.generateKeyPair();
        priv = pair.privateKey;
        pub = pair.publicKey;
      }

      final proxyPort = await _getEffectiveProxyPort();
      final client = _createHttpClient(proxyPort);

      final regUri = Uri.parse('https://api.cloudflareclient.com/v0a2158/reg');
      final request = await client.postUrl(regUri);
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.headers.set('User-Agent', 'okhttp/3.12.1');

      final body = {
        'key': pub,
        'install_id': '',
        'fcm_token': '',
        'tos': DateTime.now().toUtc().toIso8601String(),
        'model': 'PC',
        'serial_number': '',
        'locale': 'en_US',
      };
      request.write(jsonEncode(body));

      final response = await request.close();
      final respStr = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resJson = jsonDecode(respStr) as Map<String, dynamic>;
        final result = resJson['result'] as Map<String, dynamic>? ?? {};

        final accountId = result['id']?.toString() ?? '';
        final token = result['token']?.toString() ?? '';
        final account = result['account'] as Map<String, dynamic>? ?? {};
        final accountType = account['account_type']?.toString() ?? 'free';

        final configObj = result['config'] as Map<String, dynamic>? ?? {};
        final clientIdB64 = configObj['client_id']?.toString() ?? '';
        List<int> reserved = [0, 0, 0];
        if (clientIdB64.isNotEmpty) {
          try {
            final decoded = base64Decode(clientIdB64);
            if (decoded.length >= 3) {
              reserved = [decoded[0], decoded[1], decoded[2]];
            }
          } catch (_) {}
        }

        final interfaceObj =
            configObj['interface'] as Map<String, dynamic>? ?? {};
        final addresses =
            interfaceObj['addresses'] as Map<String, dynamic>? ?? {};
        final v4 = addresses['v4']?.toString() ?? WarpConfig.defaultV4;
        final v6 = addresses['v6']?.toString() ?? WarpConfig.defaultV6;

        String server = _config.server;
        int port = _config.port;
        final peers = configObj['peers'] as List<dynamic>? ?? [];
        if (peers.isNotEmpty) {
          final peer = peers.first as Map<String, dynamic>? ?? {};
          final endpoint = peer['endpoint'] as Map<String, dynamic>? ?? {};
          final v4Host = endpoint['v4']?.toString() ?? '';
          if (v4Host.isNotEmpty && server.isEmpty) {
            final parts = v4Host.split(':');
            server = parts[0];
            if (parts.length > 1) {
              port = int.tryParse(parts[1]) ?? port;
            }
          }
        }

        // Check if user has license key to bind
        final lic = (license ?? _config.licenseKey).trim();
        String finalAccountType = accountType;
        if (lic.isNotEmpty && accountId.isNotEmpty && token.isNotEmpty) {
          try {
            final licUri = Uri.parse(
                'https://api.cloudflareclient.com/v0a2158/reg/$accountId/account');
            final licReq = await client.putUrl(licUri);
            licReq.headers.set(
                'Content-Type', 'application/json; charset=UTF-8');
            licReq.headers.set('Authorization', 'Bearer $token');
            licReq.write(jsonEncode({'license': lic}));
            final licResp = await licReq.close();
            if (licResp.statusCode >= 200 && licResp.statusCode < 300) {
              finalAccountType = 'plus';
            }
          } catch (_) {}
        }

        await updateConfig((c) => c.copyWith(
              privateKey: priv,
              publicKey: pub,
              accountId: accountId,
              accountToken: token,
              accountType: finalAccountType,
              reserved: reserved,
              ip: v4,
              ipv6: v6,
              server: server.isNotEmpty ? server : WarpConfig.defaultEndpoint,
              port: port,
              licenseKey: lic,
            ));
        return true;
      } else {
        commonPrint.log('WarpManager: CF API error: ${response.statusCode} $respStr');
        return false;
      }
    } catch (e) {
      commonPrint.log('WarpManager: Registration failed: $e');
      return false;
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  /// Diagnostic testing: requests Cloudflare trace and Google to inspect WARP status and anti-redirection
  Future<WarpStatusReport> checkWarpStatus() async {
    _isTesting = true;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    try {
      final proxyPort = await _getEffectiveProxyPort();
      final client = _createHttpClient(proxyPort);

      // 1. Cloudflare CDN-CGI Trace check
      final traceUri = Uri.parse('https://www.cloudflare.com/cdn-cgi/trace');
      final request = await client.getUrl(traceUri);
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      final traceContent = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      // 2. Google Anti-Redirect & Anti-Captcha check
      bool googleOk = false;
      String googleDetail = '未测试';
      try {
        final gClient = _createHttpClient(proxyPort);
        final gUri = Uri.parse('https://www.google.com/generate_204');
        final gReq = await gClient.getUrl(gUri);
        gReq.followRedirects = false;
        final gResp = await gReq.close();
        if (gResp.statusCode == 204) {
          googleOk = true;
          googleDetail = '原生访问正常，无送中与验证码拦截';
        } else if (gResp.isRedirect) {
          final location = gResp.headers.value('location') ?? '';
          if (location.contains('.hk') || location.contains('.cn')) {
            googleOk = false;
            googleDetail = '存在送中风险 (重定向至 $location)';
          } else {
            googleOk = true;
            googleDetail = '重定向至正常区域: $location';
          }
        } else {
          googleOk = false;
          googleDetail = 'Google 响应状态码: ${gResp.statusCode}';
        }
      } catch (ge) {
        googleOk = false;
        googleDetail = 'Google 连接超时或受阻: $ge';
      }

      final report = WarpStatusReport.fromTrace(
        traceText: traceContent,
        latencyMs: stopwatch.elapsedMilliseconds,
        googleOk: googleOk,
        googleDetail: googleDetail,
      );

      _latestReport = report;
      return report;
    } catch (e) {
      final report = WarpStatusReport.failure('诊断请求超时或连接失败: $e');
      _latestReport = report;
      return report;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  /// Injects WARP configuration into runtime Clash config.
  /// Called in `state.dart` within `patchRawConfig`.
  void applyToClashConfig(Map<String, dynamic> rawConfig) {
    _config.applyToClashConfig(rawConfig);
  }
}

final warpManager = WarpManager();
