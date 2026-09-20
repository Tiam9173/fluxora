import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bett_box/clash/core.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/chain_proxy.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ChainProxyManager extends ChangeNotifier {
  static ChainProxyManager? _instance;
  ChainProxyConfig _config = const ChainProxyConfig();
  bool _initialized = false;
  final Map<String, int?> _delays = {};
  final Map<String, ProxyHealthReport> _healthReports = {};
  bool _isBatchHealthChecking = false;
  int _batchCheckCompleted = 0;
  int _batchCheckTotal = 0;

  ChainProxyManager._internal();

  factory ChainProxyManager() {
    _instance ??= ChainProxyManager._internal();
    return _instance!;
  }

  ChainProxyConfig get config => _config;
  bool get isInitialized => _initialized;
  Map<String, int?> get delays => Map.unmodifiable(_delays);
  Map<String, ProxyHealthReport> get healthReports => Map.unmodifiable(_healthReports);
  bool get isBatchHealthChecking => _isBatchHealthChecking;
  int get batchCheckCompleted => _batchCheckCompleted;
  int get batchCheckTotal => _batchCheckTotal;

  int? getDelayForProxy(String proxyId) => _delays[proxyId];
  ProxyHealthReport? getHealthReport(String proxyId) => _healthReports[proxyId];

  bool isLandingProxy(String name) {
    return _config.landingProxies.any((p) => p.name == name);
  }

  String? getPrimaryLandingProxyName() {
    final active = _config.landingProxies.where((p) => p.enable).toList();
    if (active.isNotEmpty) return active.first.name;
    if (_config.landingProxies.isNotEmpty) return _config.landingProxies.first.name;
    return null;
  }

  void setDelayForProxy(String proxyId, int? delay) {
    _delays[proxyId] = delay;
    notifyListeners();
  }

  Future<String> _getConfigFilePath() async {
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'chain_proxies.json');
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
            _config = ChainProxyConfig.fromJson(jsonMap);
          }
        }
      }
    } catch (e) {
      commonPrint.log('ChainProxyManager: Failed to load chain_proxies.json: $e');
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
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_config.toJson());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      commonPrint.log('ChainProxyManager: Failed to save config: $e');
    }
  }

  Future<void> updateConfig(
    ChainProxyConfig Function(ChainProxyConfig current) updater, {
    bool reloadCore = true,
  }) async {
    _config = updater(_config);
    notifyListeners();
    await _saveConfig();
    if (reloadCore) {
      await globalState.appController.setupClashConfig();
      await globalState.appController.updateGroups();
      notifyListeners();
    }
  }

  Future<void> setEnable(bool enable) async {
    await updateConfig((c) => c.copyWith(enable: enable));
  }

  Future<void> setDefaultDialer(String dialer) async {
    await updateConfig((c) => c.copyWith(defaultDialerProxy: dialer));
  }

  Future<void> setAutoInjectGroups(bool autoInject) async {
    await updateConfig((c) => c.copyWith(autoInjectGroups: autoInject));
  }

  Future<void> setCreateDedicatedGroup(bool createGroup) async {
    await updateConfig((c) => c.copyWith(createDedicatedGroup: createGroup));
  }

  Future<void> setPreventWebRtcLeak(bool prevent) async {
    await updateConfig((c) => c.copyWith(preventWebRtcLeak: prevent));
  }

  Future<void> addLandingProxies(List<LandingProxy> proxies) async {
    if (proxies.isEmpty) return;
    await updateConfig((c) {
      final updated = List<LandingProxy>.from(c.landingProxies)..addAll(proxies);
      return c.copyWith(landingProxies: updated);
    });
  }

  Future<void> updateLandingProxy(LandingProxy proxy) async {
    await updateConfig((c) {
      final index = c.landingProxies.indexWhere((p) => p.id == proxy.id);
      if (index == -1) return c;
      final updated = List<LandingProxy>.from(c.landingProxies);
      updated[index] = proxy;
      return c.copyWith(landingProxies: updated);
    });
  }

  Future<void> toggleLandingProxy(String id, bool enable) async {
    await updateConfig((c) {
      final index = c.landingProxies.indexWhere((p) => p.id == id);
      if (index == -1) return c;
      final updated = List<LandingProxy>.from(c.landingProxies);
      updated[index] = updated[index].copyWith(enable: enable);
      return c.copyWith(landingProxies: updated);
    });
  }

  Future<void> deleteLandingProxy(String id) async {
    _delays.remove(id);
    await updateConfig((c) {
      final updated = c.landingProxies.where((p) => p.id != id).toList();
      return c.copyWith(landingProxies: updated);
    });
  }

  Future<void> testProxyDelay(LandingProxy proxy, String testUrl) async {
    setDelayForProxy(proxy.id, 0); // 0 means testing in Bettbox
    try {
      final res = await clashCore.getDelay(testUrl, proxy.name);
      setDelayForProxy(proxy.id, res.value);
    } catch (_) {
      setDelayForProxy(proxy.id, -1);
    }
  }

  Future<void> testAllDelays(String testUrl) async {
    final targets = _config.landingProxies.where((p) => p.enable).toList();
    for (final p in targets) {
      setDelayForProxy(p.id, 0);
    }

    await Future.wait(
      targets.map((proxy) async {
        try {
          final res = await clashCore.getDelay(testUrl, proxy.name);
          setDelayForProxy(proxy.id, res.value);
        } catch (_) {
          setDelayForProxy(proxy.id, -1);
        }
      }),
    );
  }

  Future<ProxyHealthReport> checkProxyHealth(LandingProxy proxy) async {
    _healthReports[proxy.id] = ProxyHealthReport(
      proxyId: proxy.id,
      proxyName: proxy.name,
      status: HealthStatus.testing,
      testedAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final isCoreRunning = await clashCore.isInit;
      if (isCoreRunning) {
        final targetFutures = TargetService.values.map((target) async {
          try {
            final delayRes = await clashCore.getDelay(target.testUrl, proxy.name);
            final val = delayRes.value;
            if (val != null && val > 0) {
              return TargetHealthResult(
                service: target,
                delay: val,
                isSuccess: true,
              );
            } else {
              return TargetHealthResult(
                service: target,
                isSuccess: false,
                error: '请求超时或无响应',
              );
            }
          } catch (e) {
            return TargetHealthResult(
              service: target,
              isSuccess: false,
              error: '连通失败: $e',
            );
          }
        });

        final results = await Future.wait(targetFutures);
        final successful = results.where((r) => r.isSuccess).toList();
        final successCount = successful.length;
        final delays = successful.where((r) => r.delay != null).map((r) => r.delay!).toList();
        final minDelay = delays.isNotEmpty ? delays.reduce(min) : null;
        final avgDelay = delays.isNotEmpty
            ? (delays.reduce((a, b) => a + b) / delays.length).round()
            : null;

        HealthStatus status;
        String diagnosticTips;

        if (successCount >= 5) {
          status = HealthStatus.healthy;
          diagnosticTips = '全项服务连接顺畅，支持 OpenAI/ChatGPT、TikTok 与跨境电商访问，原生住宅 IP 状态优异。';
          setDelayForProxy(proxy.id, minDelay);
        } else if (successCount > 0) {
          status = HealthStatus.warning;
          final failedNames = results
              .where((r) => !r.isSuccess)
              .map((r) => r.service.label)
              .join('、');
          diagnosticTips = '部分目标平台访问受限（$failedNames），基础连通正常，请根据需要选择性使用。';
          setDelayForProxy(proxy.id, minDelay);
        } else {
          final direct = await DirectSocketVerifier.verify(
            server: proxy.server,
            port: proxy.port,
            protocol: proxy.protocol,
            username: proxy.username,
            password: proxy.password,
          );

          status = HealthStatus.error;
          if (direct.isAuthError) {
            diagnosticTips = '住宅 IP 账号或密码错误（鉴权失败），请核对供应商密码或白名单设置。';
          } else {
            final hopName = (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
                ? proxy.dialerProxy!
                : (_config.defaultDialerProxy.isNotEmpty
                    ? _config.defaultDialerProxy
                    : '全局主选择');
            diagnosticTips =
                '所有目标服务均超时不可达。请确认前置跳板 [$hopName] 是否畅通，或住宅 IP 是否已过期下线。';
          }
          setDelayForProxy(proxy.id, -1);
        }

        final report = ProxyHealthReport(
          proxyId: proxy.id,
          proxyName: proxy.name,
          status: status,
          targets: results,
          diagnosticTips: diagnosticTips,
          testedAt: DateTime.now(),
          minDelay: minDelay,
          avgDelay: avgDelay,
        );
        _healthReports[proxy.id] = report;
        notifyListeners();
        return report;
      } else {
        final direct = await DirectSocketVerifier.verify(
          server: proxy.server,
          port: proxy.port,
          protocol: proxy.protocol,
          username: proxy.username,
          password: proxy.password,
        );

        final status = direct.isSuccess ? HealthStatus.healthy : HealthStatus.error;
        final diagnosticTips = direct.isSuccess
            ? '直接握手成功（响应时间 ${direct.delay}ms）。建议启动 Bettbox 核心通过跳板节点进行多目标业务体检。'
            : (direct.isAuthError
                ? '住宅 IP 账号或密码错误（鉴权失败），请核对凭据。'
                : '${direct.message}。提示：在国内网络直接测试海外住宅IP可能受阻，建议启动 Bettbox 核心通过跳板节点体检。');

        final results = [
          TargetHealthResult(
            service: TargetService.cloudflare,
            delay: direct.delay,
            isSuccess: direct.isSuccess,
            error: direct.isSuccess ? null : direct.message,
          ),
        ];

        setDelayForProxy(proxy.id, direct.isSuccess ? direct.delay : -1);

        final report = ProxyHealthReport(
          proxyId: proxy.id,
          proxyName: proxy.name,
          status: status,
          targets: results,
          diagnosticTips: diagnosticTips,
          testedAt: DateTime.now(),
          minDelay: direct.delay,
          avgDelay: direct.delay,
        );
        _healthReports[proxy.id] = report;
        notifyListeners();
        return report;
      }
    } catch (e) {
      final report = ProxyHealthReport(
        proxyId: proxy.id,
        proxyName: proxy.name,
        status: HealthStatus.error,
        diagnosticTips: '体检执行异常: $e',
        testedAt: DateTime.now(),
      );
      _healthReports[proxy.id] = report;
      setDelayForProxy(proxy.id, -1);
      notifyListeners();
      return report;
    }
  }

  Future<void> checkAllProxiesHealth() async {
    final targets = _config.landingProxies.where((p) => p.enable).toList();
    if (targets.isEmpty) return;

    _isBatchHealthChecking = true;
    _batchCheckTotal = targets.length;
    _batchCheckCompleted = 0;
    notifyListeners();

    try {
      for (int i = 0; i < targets.length; i += 3) {
        final chunk = targets.sublist(i, min(i + 3, targets.length));
        await Future.wait(chunk.map((p) => checkProxyHealth(p)));
        _batchCheckCompleted = min(i + chunk.length, targets.length);
        notifyListeners();
      }
    } finally {
      _isBatchHealthChecking = false;
      notifyListeners();
    }
  }

  Future<int> clearInvalidProxies() async {
    final invalidIds = _healthReports.entries
        .where((e) => e.value.status == HealthStatus.error)
        .map((e) => e.key)
        .toSet();

    if (invalidIds.isEmpty) return 0;

    for (final id in invalidIds) {
      _delays.remove(id);
      _healthReports.remove(id);
    }

    await updateConfig((c) {
      final remaining = c.landingProxies.where((p) => !invalidIds.contains(p.id)).toList();
      return c.copyWith(landingProxies: remaining);
    });

    return invalidIds.length;
  }

  Future<DirectCheckResult> directCheckProxy({
    required String server,
    required int port,
    ChainProxyProtocol protocol = ChainProxyProtocol.socks5,
    String username = '',
    String password = '',
  }) {
    return DirectSocketVerifier.verify(
      server: server,
      port: port,
      protocol: protocol,
      username: username,
      password: password,
    );
  }

  /// Injects chain proxies and groups into the Clash config map at runtime.
  /// This is called in `patchRawConfig` before writing config.yaml.
  void applyToClashConfig(Map<String, dynamic> rawConfig) {
    _config.applyToClashConfig(rawConfig);
  }
}

final chainProxyManager = ChainProxyManager();
