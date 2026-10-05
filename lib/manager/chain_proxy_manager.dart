import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_failover.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_recovery.dart';
import 'package:fluxora/models/chain_support_package.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/services.dart';


import 'package:fluxora/clash/core.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
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
  int _stateVersion = 0;

  ChainProxyManager._internal();

  factory ChainProxyManager() {
    _instance ??= ChainProxyManager._internal();
    return _instance!;
  }

  int get stateVersion => _stateVersion;
  ChainProxyConfig get config => _config;
  bool get isInitialized => _initialized;
  Map<String, int?> get delays => Map.unmodifiable(_delays);
  Map<String, ProxyHealthReport> get healthReports =>
      Map.unmodifiable(_healthReports);
  bool get isBatchHealthChecking => _isBatchHealthChecking;
  int get batchCheckCompleted => _batchCheckCompleted;
  int get batchCheckTotal => _batchCheckTotal;

  @override
  void notifyListeners() {
    _stateVersion++;
    super.notifyListeners();
  }

  int? getDelayForProxy(String proxyId) => _delays[proxyId];
  ProxyHealthReport? getHealthReport(String proxyId) => _healthReports[proxyId];

  bool isLandingProxy(String name) {
    return _config.landingProxies.any((p) => p.name == name);
  }

  String? getPrimaryLandingProxyName() {
    final active = _config.landingProxies.where((p) => p.enable).toList();
    if (active.isNotEmpty) return active.first.name;
    if (_config.landingProxies.isNotEmpty) {
      return _config.landingProxies.first.name;
    }
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

  void _telemetryListener() => notifyListeners();
  void _flapListener() => notifyListeners();

  @override
  void dispose() {
    _probeCancelToken?.cancel();
    _failoverCancelToken?.cancel();
    chainTelemetryService.removeListener(_telemetryListener);
    chainFlapDampenerService.removeListener(_flapListener);
    super.dispose();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Phase 5.x integration: register listeners unconditionally once per instance.
    chainTelemetryService.addListener(_telemetryListener);
    chainFlapDampenerService.addListener(_flapListener);

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
      commonPrint.log(
        'ChainProxyManager: Failed to load chain_proxies.json: $e',
      );
    } finally {
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
      final jsonStr = const JsonEncoder.withIndent(
        '  ',
      ).convert(_config.toJson());
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
      try {
        await globalState.appController.setupClashConfig();
        await globalState.appController.updateGroups();
      } catch (_) {
        // Tolerate failures in test / non-running core contexts
      }
      notifyListeners();
    }
  }

  Future<void> setEnable(bool enable) async {
    await updateConfig((c) => c.copyWith(enable: enable));
    if (enable) {
      await _autoSelectChainGroup();
    }
  }

  Future<void> _autoSelectChainGroup() async {
    try {
      final appController = globalState.appController;
      final mode = appController.ref.read(patchClashConfigProvider).mode;

      final dedicatedGroupName = _config.dedicatedGroupName.isNotEmpty
          ? _config.dedicatedGroupName
          : '🔗 链式代理';
      final activeLanding = getPrimaryLandingProxyName();
      final targetProxy = _config.createDedicatedGroup
          ? dedicatedGroupName
          : (activeLanding ?? '');

      if (targetProxy.isEmpty) return;

      final batchMap = <String, String>{};

      if (mode == Mode.global) {
        batchMap['GLOBAL'] = targetProxy;
      } else if (mode == Mode.rule) {
        final groups = appController.ref.read(groupsProvider);
        final selectedMap = appController.ref.read(selectedMapProvider);

        bool isValidSelector(String? name) {
          if (name == null || name.isEmpty) return false;
          for (final g in groups) {
            if (g.name == name && g.type == GroupType.Selector) {
              return g.all.any((p) => p.name == targetProxy);
            }
          }
          return false;
        }

        // Priority 1: active outbound selector
        String? activeOutbound;
        for (final g in groups) {
          if (g.name != 'GLOBAL' &&
              g.name != dedicatedGroupName &&
              g.name != '✈️ 链式跳板' &&
              g.type == GroupType.Selector) {
            activeOutbound = g.name;
            break;
          }
        }

        // Priority 2: GLOBAL 下游 selector
        String? globalDownstream = selectedMap['GLOBAL'];

        // Priority 3: getCurrentGroupName()
        String? currentView = appController.getCurrentGroupName();

        String? targetSelector;
        if (isValidSelector(activeOutbound)) {
          targetSelector = activeOutbound;
        } else if (isValidSelector(globalDownstream)) {
          targetSelector = globalDownstream;
        } else if (isValidSelector(currentView)) {
          targetSelector = currentView;
        }

        if (targetSelector != null) {
          batchMap[targetSelector] = targetProxy;
        }
      }

      if (batchMap.isNotEmpty) {
        await appController.changeProxiesBatch(batchMap);

        bool verifySelection() {
          final sm = appController.ref.read(selectedMapProvider);
          for (final entry in batchMap.entries) {
            if (sm[entry.key] != entry.value) {
              return false;
            }
          }
          return true;
        }

        if (!verifySelection()) {
          await Future.delayed(const Duration(milliseconds: 500));
          await appController.changeProxiesBatch(batchMap);

          if (!verifySelection()) {
            commonPrint.log('Chain proxy auto-select retry failed.');
          }
        }
      }
    } catch (e, stack) {
      commonPrint.log('Failed to auto select chain group: $e\n$stack');
    }
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
      final updated = List<LandingProxy>.from(c.landingProxies)
        ..addAll(proxies);
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
    setDelayForProxy(proxy.id, 0); // 0 means testing in Fluxora
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
            final delayRes = await clashCore.getDelay(
              target.testUrl,
              proxy.name,
            );
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
        final delays = successful
            .where((r) => r.delay != null)
            .map((r) => r.delay!)
            .toList();
        final minDelay = delays.isNotEmpty ? delays.reduce(min) : null;
        final avgDelay = delays.isNotEmpty
            ? (delays.reduce((a, b) => a + b) / delays.length).round()
            : null;

        HealthStatus status;
        String diagnosticTips;

        if (successCount >= 5) {
          status = HealthStatus.healthy;
          diagnosticTips =
              '全项服务连接顺畅，支持 OpenAI/ChatGPT、TikTok 与跨境电商访问，原生住宅 IP 状态优异。';
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
            final hopName =
                (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
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

        final status = direct.isSuccess
            ? HealthStatus.healthy
            : HealthStatus.error;
        final diagnosticTips = direct.isSuccess
            ? '直接握手成功（响应时间 ${direct.delay}ms）。建议启动 Fluxora 核心通过跳板节点进行多目标业务体检。'
            : (direct.isAuthError
                  ? '住宅 IP 账号或密码错误（鉴权失败），请核对凭据。'
                  : '${direct.message}。提示：在国内网络直接测试海外住宅IP可能受阻，建议启动 Fluxora 核心通过跳板节点体检。');

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
      final remaining = c.landingProxies
          .where((p) => !invalidIds.contains(p.id))
          .toList();
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

  // ─── Phase 5.x Runtime State ─────────────────────────────────────────────

  ChainRetryProgress? _retryProgress;
  ChainProbeReport? _lastProbeReport;
  bool _isProbingChain = false;
  ChainFailoverProgress? _failoverProgress;
  CancelToken? _probeCancelToken;
  CancelToken? _failoverCancelToken;

  /// In-memory fallback pool.
  ChainFallbackPool _fallbackPool = const ChainFallbackPool();

  // Phase 5.x state fields (mutable, set by recovery/failover logic)
  ChainRecoveryPlan? pendingRecoveryPlan;
  ChainSupportPackage? lastGeneratedPackage;

  // ─── Phase 5.x Getters ────────────────────────────────────────────────────

  ChainRetryProgress? get retryProgress => _retryProgress;
  ChainProbeReport? get lastProbeReport => _lastProbeReport;
  bool get isProbingChain => _isProbingChain;
  ChainFailoverProgress? get failoverProgress => _failoverProgress;

  ChainFallbackPool get fallbackPool => _fallbackPool;

  bool get isFailingOver =>
      failoverProgress != null &&
      !failoverProgress!.state.isIdle &&
      !failoverProgress!.state.isTerminal;

  /// Delegates to the real ChainFlapDampenerService singleton.
  ChainFlapDampenerStatus get flapDampenerStatus =>
      chainFlapDampenerService.getStatus();

  /// Delegates to the real ChainTelemetryService singleton.
  ChainTelemetrySnapshot get telemetrySnapshot =>
      chainTelemetryService.getSnapshot();

  IChainTelemetryService get telemetryService => chainTelemetryService;

  // ─── Phase 5.x Topology ───────────────────────────────────────────────────

  ValidationResult validateCurrentTopology({
    List<String>? availableProxyNames,
  }) {
    return ChainTopologyValidator.validate(
      mode: _config.hopMode,
      hop1: _config.effectiveHop1,
      hop2: _config.hop2Node,
      hop3: _config.hopMode == ChainHopMode.threeHop ? _config.hop3Node : null,
      availableProxyNames: availableProxyNames,
      dedicatedGroupName: _config.dedicatedGroupName,
    );
  }

  // ─── Phase 5.x Hop Configuration ─────────────────────────────────────────

  Future<void> setHopMode(ChainHopMode mode) async {
    await updateConfig((c) => c.copyWith(hopMode: mode));
  }

  Future<void> setHop1Node(String name) async {
    await updateConfig((c) => c.copyWith(
          hop1Node: name,
          defaultDialerProxy: name,
        ));
  }

  Future<void> setHop2Node(String name) async {
    await updateConfig((c) => c.copyWith(hop2Node: name));
  }

  Future<void> setHop3Node(String name) async {
    await updateConfig((c) => c.copyWith(hop3Node: name));
  }

  Future<void> setHops({
    required ChainHopMode mode,
    required String hop1,
    required String hop2,
    String? hop3,
  }) async {
    await updateConfig((c) => c.copyWith(
          hopMode: mode,
          hop1Node: hop1,
          defaultDialerProxy: hop1,
          hop2Node: hop2,
          hop3Node: hop3 ?? '',
        ));
  }

  // ─── Phase 5.x Fallback Pool ──────────────────────────────────────────────

  /// Stores the fallback pool. Full integration with ChainFallbackService
  /// is performed by the AutoFailover coordinator at runtime.
  Future<void> setFallbackPool(ChainFallbackPool pool) async {
    _fallbackPool = pool;
    notifyListeners();
  }

  // ─── Phase 5.x Failover Lifecycle ────────────────────────────────────────

  /// Triggers auto-failover. Full implementation delegates to ChainFailoverService.
  /// This thin coordinator updates progress state and notifies listeners.
  Future<ChainFailoverResult> triggerAutoFailover({
    String? triggerReason,
    ChainProbeReport? initialFailureReport,
    Duration? timeout,
    dynamic retryPolicy,
    bool bypassDampening = false,
  }) async {
    cancelFailover();
    
    _failoverCancelToken = CancelToken();
    _failoverProgress = ChainFailoverProgress(
      state: ChainFailoverState.selectingCandidate,
      message: triggerReason ?? 'Initializing failover',
      timestamp: DateTime.now(),
    );
    notifyListeners();

    try {
      final policy = ChainFailoverPolicy(
        bypassDampening: bypassDampening,
      );
      
      final result = await chainFailoverService.executeFailover(
        currentConfig: _config,
        fallbackPool: _fallbackPool,
        targetRole: null,
        policy: policy,
        cancelToken: _failoverCancelToken,
        flapDampener: chainFlapDampenerService,
        onProgress: (progress) {
          _failoverProgress = progress;
          notifyListeners();
        },
        onPoolUpdated: (pool) {
          _fallbackPool = pool;
          notifyListeners();
        }
      );
      
      if (result.isSuccess) {
        await updateConfig((_) => result.finalConfig);
      }
      return result;
    } finally {
      if (_failoverProgress != null && !_failoverProgress!.state.isTerminal) {
        _failoverProgress = ChainFailoverProgress(
          state: _failoverCancelToken?.isCancelled == true 
                 ? ChainFailoverState.cancelled 
                 : ChainFailoverState.idle,
          candidateNodeName: _failoverProgress!.candidateNodeName,
          message: 'Finished',
          timestamp: DateTime.now(),
        );
      }
      _failoverCancelToken = null;
      notifyListeners();
    }
  }

  void cancelFailover() {
    _failoverCancelToken?.cancel();
    _failoverCancelToken = null;
    if (_failoverProgress != null) {
      _failoverProgress = ChainFailoverProgress(
        state: ChainFailoverState.cancelled,
        candidateNodeName: _failoverProgress!.candidateNodeName,
        message: 'Cancelled by user',
        timestamp: DateTime.now(),
      );
    }
    notifyListeners();
  }

  // ─── Phase 5.x Probe Lifecycle ────────────────────────────────────────────

  void cancelCurrentProbe() {
    _probeCancelToken?.cancel();
    _probeCancelToken = null;
    _isProbingChain = false;
    notifyListeners();
  }

  Future<ChainProbeReport> probeCurrentChain({
    String? testUrl,
    Duration? timeout,
    CancelToken? cancelToken,
    ChainRetryPolicy? retryPolicy,
  }) async {
    _isProbingChain = true;
    _probeCancelToken = cancelToken ?? CancelToken();
    notifyListeners();
    try {
      final report = await chainProbeService.probeChain(
        config: _config,
        testUrl: testUrl,
        cancelToken: _probeCancelToken,
      );
      _lastProbeReport = report;
      return report;
    } finally {
      _isProbingChain = false;
      notifyListeners();
    }
  }

  // ─── Phase 5.x Flap Dampening ────────────────────────────────────────────

  void resetFlapDampener() {
    chainFlapDampenerService.reset();
  }

  // ─── Phase 5.x Telemetry ──────────────────────────────────────────────────

  void clearTelemetry() {
    chainTelemetryService.clear();
  }

  // ─── Phase 5.x Diagnostics & Support ─────────────────────────────────────

  /// Exports a chain diagnostic report. Full implementation in Phase 5.9-E.1.2+.
  Future<dynamic> exportChainDiagnosticReport() async {
    // ChainDiagnosticExportService integration pending Phase 5.9-E.1.2.
    return null;
  }

  // ─── Phase 5.x Recovery Plan ──────────────────────────────────────────────

  Future<void> rejectRecoveryPlan() async {
    pendingRecoveryPlan = null;
    notifyListeners();
  }

  Future<void> approveRecoveryPlan() async {
    if (pendingRecoveryPlan?.action == ChainRecoveryAction.pauseChainProxy) {
      await setHopMode(ChainHopMode.twoHop);
    }
    pendingRecoveryPlan = null;
    notifyListeners();
  }

  // ─── Phase 5.x Support Package ────────────────────────────────────────────

  /// Generates a support package. Full implementation in Phase 5.9-E.1.2+.
  Future<void> createSupportPackage() async {
    // ChainSupportPackageService integration pending Phase 5.9-E.1.2.
    notifyListeners();
  }
}

final chainProxyManager = ChainProxyManager();
