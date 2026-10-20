import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:fluxora/models/chain_failover.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_recovery.dart';
import 'package:fluxora/models/chain_support_package.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/services.dart';
import 'package:fluxora/services/chain_support_package_service.dart';
import 'package:fluxora/services/chain_diagnostic_export_service.dart';


import 'package:fluxora/clash/core.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/foundation.dart';

import 'package:fluxora/services/chain_reliability_stats_persistence.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:fluxora/services/core_health_service.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/persistence_schema.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';

import 'package:fluxora/models/protocol_capability.dart';
import 'dart:async';
import 'package:path/path.dart' as p;

@visibleForTesting
class ChainProxyManager extends ChangeNotifier {

  static Duration autoHealthCheckInterval = const Duration(minutes: 1);
  static const capabilityProbeTimeout = Duration(seconds: 10);
  static bool? coreRunningOverride;

  @visibleForTesting
  static Future<ChainProbeReport> Function(ChainProxyConfig)? chainProbeOverride;
  @visibleForTesting
  static IChainFailoverExecutor Function(IChainFailoverExecutor)? failoverExecutorWrapper;

  /// Test-only seam overriding the runtime config reload performed by
  /// [_reloadRuntimeConfig] (the failover executor's apply / rollback path).
  /// Production never sets it; it lets tests drive the reload's success or
  /// failure without a live Mihomo core.
  @visibleForTesting
  static Future<void> Function()? coreConfigReloadOverride;
  
  bool get isAutoHealthCheckRunning => _chainHealthTimer != null && _chainHealthTimer!.isActive;
  int get consecutiveHealthCheckFailures => _consecutiveHealthCheckFailures;

  /// P1.5-A: the auto-failover skip diagnosis currently in effect
  /// (`null` = auto failover is not being skipped).
  ///
  /// The 1-minute health-check loop evaluates the gate on **every** tick, so the
  /// diagnosis is re-logged only when it **changes** — see
  /// [_reportAutoFailoverSkip]. Read-only: tests assert the state here, while
  /// `debugPrint` counting proves how often it was actually emitted.
  @visibleForTesting
  String? get autoFailoverSkipDiagnosis => _lastAutoFailoverSkipDiagnosis;

  
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
    // P0 hardening: `dispose()` can now race an in-flight health check, because
    // the periodic loop actually runs in production for the first time. A tick
    // that is already suspended inside `runChainHealthCheck()` would otherwise
    // notify a disposed ChangeNotifier (which throws) from a fire-and-forget
    // timer callback, i.e. an unhandled async error. Notifying after dispose is
    // meaningless anyway, so drop it.
    if (_disposed) return;
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
    final override = configFilePathOverride;
    if (override != null) return override;
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'chain_proxies.json');
  }

  /// Absolute path of the persisted fallback pool configuration.
  Future<String> _getFallbackPoolFilePath() async {
    final override = fallbackPoolFilePathOverride;
    if (override != null) return override;
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'chain_fallback_pool.json');
  }

  /// Absolute path of the persisted reliability-stats file, or `null` when it
  /// must not be touched (unit tests without an explicit override).
  Future<String?> _getReliabilityStatsFilePath() async {
    final override = reliabilityStatsFilePathOverride;
    if (override != null) return override;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'chain_reliability_stats.json');
  }

  /// Applies restored reliability statistics onto the pool's **existing**
  /// candidates only (role → nodeName must match). Nodes present in the stats
  /// file but absent from the pool are ignored, so a stale entry can never
  /// resurrect a removed candidate.
  ChainFallbackPool _applyRestoredReliabilityStats(
    ChainFallbackPool pool,
    Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>
    byRole,
  ) {
    List<ChainFallbackCandidate> apply(
      List<ChainFallbackCandidate> candidates,
      FallbackCandidateRole role,
    ) {
      final byNode = byRole[role];
      if (byNode == null || byNode.isEmpty) return candidates;
      return <ChainFallbackCandidate>[
        for (final c in candidates)
          byNode.containsKey(c.nodeName)
              ? c.copyWith(statsByContext: byNode[c.nodeName]!)
              : c,
      ];
    }

    return pool.copyWith(
      entryCandidates: apply(pool.entryCandidates, FallbackCandidateRole.entry),
      relayCandidates: apply(pool.relayCandidates, FallbackCandidateRole.relay),
      exitCandidates: apply(pool.exitCandidates, FallbackCandidateRole.exit),
    );
  }

  /// Persists the fallback pool **configuration only**
  /// (`nodeName` / `role` / `enabled` / `priority`).
  ///
  /// Runtime telemetry (`health` / `latencyMs` / `lastChecked` /
  /// `statsByContext` / `cooldownUntil`) is RAM-only and is never written to
  /// disk. Write failures propagate: a failed persist must never be mistaken
  /// for a successful one.
  Future<void> _saveFallbackPool() async {
    final filePath = await _getFallbackPoolFilePath();
    // P2.4-A: crash-safe atomic write (tmp → validate → .bak → rename), and the
    // failure is allowed to propagate — a failed persist must never be mistaken
    // for a successful one (P2.5-E).
    await AtomicConfigStorage(filePath).save(<String, dynamic>{
      ..._fallbackPool.toJson(),
      PersistenceSchema.versionKey: PersistenceSchema.currentVersion,
    });
  }

  void _telemetryListener() => notifyListeners();
  void _flapListener() => notifyListeners();

  @override
  void dispose() {
    // P2.3-B (P-1): stop any in-flight runtime capability probe from writing
    // back into now-invalid state. This only adds a guard — the existing
    // teardown order/semantics are unchanged.
    _disposed = true;
    // F-B2: invalidate the in-flight probe session *before* cancelling, so a
    // probe that ignores the CancelToken and completes after teardown can
    // neither publish `_lastProbeReport` nor hand its report to the failover
    // decision. The token is deliberately NOT nulled: the write-back guard
    // (`_probeCancelToken?.isCancelled == true`) relies on it staying cancelled.
    _probeGeneration++;
    _probeCancelToken?.cancel();
    _failoverCancelToken?.cancel();
    stopChainHealthCheck();
    _consecutiveHealthCheckFailures = 0;
    _reliabilityPersistTimer?.cancel();
    _reliabilityPersistTimer = null;
    // RC.11-C1: a pending freshness transition must not fire after teardown.
    _freshnessTickTimer?.cancel();
    _freshnessTickTimer = null;
    chainTelemetryService.removeListener(_telemetryListener);
    chainFlapDampenerService.removeListener(_flapListener);
    // RC.11-A (F-AR4): drop the transport hook together with the rest of the
    // teardown, so a disposed manager is never notified.
    networkFingerprintProvider.onChanged = null;
    super.dispose();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Phase 5.x integration: register listeners unconditionally once per instance.
    chainTelemetryService.addListener(_telemetryListener);
    chainFlapDampenerService.addListener(_flapListener);
    // RC.11-A (F-AR4): a transport change must invalidate the ranking cache.
    // `NetworkFingerprintProvider` has no notifier of its own and the ranking
    // provider reads the fingerprint imperatively, so without this a
    // wifi ↔ cellular switch left the node picker on the previous network's
    // ranking until some unrelated notification arrived. `notifyListeners()`
    // bumps `stateVersion`, which is part of the ranking `stateFingerprint`.
    networkFingerprintProvider.onChanged = (_) {
      notifyListeners();
      // RC.11-C1: a transport change re-scopes every observation, so a pending
      // freshness transition (computed against the OLD fingerprint) is now
      // stale and must be recomputed.
      _scheduleFreshnessTick();
    };

    try {
      final filePath = await _getConfigFilePath();
      // P2.5-A: read through the shared atomic storage so a missing / corrupt
      // primary recovers from `.bak` / orphan `.tmp`. P2.5-C: the schema
      // predicate rejects an unsupported primary without clobbering it.
      final jsonMap = await AtomicConfigStorage(filePath).load(
        accept: PersistenceSchema.accepts,
      );
      if (jsonMap != null) {
        _config = ChainProxyConfig.fromJson(jsonMap);
      }
    } catch (e) {
      commonPrint.log(
        'ChainProxyManager: Failed to load chain_proxies.json: $e',
      );
    } finally {
      notifyListeners();
    }

    // RC.10-A.4.2 — normalise a legacy three-hop configuration once the
    // persisted config has been decoded. RC.10-A removed the hop-count
    // selector, so a stored `threeHop` would otherwise keep the topology card
    // rendering a relay node the UI can no longer manage.
    //
    // Reuses `setHopMode`, which migrates the exit from `hop3Node` back into
    // `hop2Node` and clears `hop3Node`. A former relay stored in `hop2Node` is
    // therefore overwritten: two-hop has no relay slot to carry it across, and
    // that is the existing, documented migration rule.
    //
    // Only an actual `threeHop` config is touched — an already-two-hop config
    // takes neither the reload nor the write path (`setHopMode` also has its
    // own idempotence guard).
    //
    // `setHopMode` reaches `_reloadRuntimeConfig`, which rethrows a real core
    // reload failure. `init()` is awaited on the service path, so an unguarded
    // failure there would abort startup; the migration is therefore contained:
    // the config is already persisted at this point, and the next start simply
    // retries from the migrated state.
    if (_config.hopMode == ChainHopMode.threeHop) {
      try {
        await setHopMode(ChainHopMode.twoHop);
      } catch (e) {
        commonPrint.log(
          'ChainProxyManager: three-hop normalisation failed: $e',
        );
      }
    }

    // RC.10-A.4.5 — surface, but do NOT destroy, a stale two-hop exit
    // reference.
    //
    // After the migration above (or from any older config) `hop2Node` can name
    // a landing proxy that no longer exists — the legacy `hop3Node` value is
    // exactly such a case. Deleting it here would be unsafe: `init()` cannot
    // enumerate the runtime proxy set (that needs a live core), so a name
    // missing from the *landing* list cannot be proven dead — it might be a
    // subscription node the user picked deliberately.
    //
    // The read path handles it instead: `ChainProxyConfig.effectiveExitNode`
    // falls back to the active landing proxy whenever `hop2Node` does not
    // resolve. Nothing has to be rewritten, the user's stored value survives,
    // and `hop1Node` / `defaultDialerProxy` / `enable` plus the DIRECT and
    // empty-string semantics are untouched.
    if (_config.hopMode == ChainHopMode.twoHop) {
      final String exit = _config.hop2Node.trim();
      if (exit.isNotEmpty &&
          !_config.landingProxies.any((p) => p.name == exit)) {
        commonPrint.log(
          'ChainProxyManager: hop2Node "$exit" is not in the landing list; '
          'effectiveExitNode falls back to the active landing proxy',
        );
      }
    }

    // Restore the persisted fallback pool configuration so a curated pool
    // survives a restart. Runtime telemetry is never restored from disk.
    try {
      final poolPath = await _getFallbackPoolFilePath();
      final poolJson = await AtomicConfigStorage(poolPath).load(
        accept: PersistenceSchema.accepts,
      );
      if (poolJson != null) {
        _fallbackPool = ChainFallbackPool.fromJson(poolJson);
      }
    } catch (e) {
      commonPrint.log(
        'ChainProxyManager: Failed to load chain_fallback_pool.json: $e',
      );
    }

    // Restore the durable reliability statistics (P2.1 / P2.5-A) and apply them
    // **only** to candidates that already exist in the pool: a stats entry for a
    // node that is no longer a candidate must never materialise a ghost node.
    try {
      final statsPath = await _getReliabilityStatsFilePath();
      if (statsPath != null) {
        final byRole = await const ChainReliabilityStatsPersistence().load(
          statsPath,
        );
        if (byRole.isNotEmpty) {
          _fallbackPool = _applyRestoredReliabilityStats(_fallbackPool, byRole);
          notifyListeners();
        }
      }
    } catch (e) {
      commonPrint.log(
        'ChainProxyManager: Failed to load chain_reliability_stats.json: $e',
      );
    }

    // Build the initial per-node capability view from the active profile so
    // adaptive ranking has real capability state from startup. Fire-and-forget:
    // this reads the profile through the core, and must therefore never block
    // or fail `init()`. The runtime probes are started by
    // `refreshCapabilityProfiles` itself.
    unawaited(refreshCapabilityProfiles());

    // RC.11-C1: the restored pool may already hold gated latency observations,
    // so arm the first freshness transition from startup.
    _scheduleFreshnessTick();

    // P0: a persisted `autoFailover: true` must actually resume the loop after a
    // restart. Before this, nothing in production ever started the loop, so the
    // automatic failover path was unreachable even though the flag was stored.
    _syncChainHealthCheck();
  }

  Future<void> _saveConfig() async {
    final filePath = await _getConfigFilePath();
    // P2.4-A: crash-safe atomic write (tmp → validate → .bak → rename).
    // P2.5-E: the failure propagates — a config that never landed must not be
    // reported as a successful save (no false success).
    await AtomicConfigStorage(filePath).save(<String, dynamic>{
      ..._config.toJson(),
      PersistenceSchema.versionKey: PersistenceSchema.currentVersion,
    });
  }

  /// Applies the current [_config] to the running core.
  ///
  /// A reload failure must reach the caller instead of being swallowed —
  /// otherwise a candidate that never actually applied would be treated as
  /// applied (and could then be committed): a "false success". When no app has
  /// booted (`globalState.appController` throws — unit tests and very early
  /// startup) there is no runtime to reload, so this is a no-op rather than a
  /// failure; once the app IS booted, any failure is logged **and rethrown**.
  Future<void> _reloadRuntimeConfig() async {
    try {
      final override = coreConfigReloadOverride;
      if (override != null) {
        await override();
        return;
      }

      dynamic appController;
      try {
        appController = globalState.appController;
      } catch (_) {
        return; // app not booted -> nothing to reload (not a failure)
      }

      await appController.setupClashConfig();
      await appController.updateGroups();
      // The core config was just (re)loaded — rebuild the capability view.
      // `refreshCapabilityProfiles` is itself best-effort (it catches and logs
      // internally), so it never turns into a reload failure.
      await refreshCapabilityProfiles();
    } catch (e, stackTrace) {
      commonPrint.log(
        'ChainProxyManager: core config reload failed: $e\n$stackTrace',
      );
      rethrow;
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
      // P2.4-C: a reload failure must reach the caller instead of being
      // swallowed — otherwise a config that never actually applied would be
      // treated as applied (a "false success"). `_reloadRuntimeConfig` is a
      // no-op when the app has not booted, and rethrows real failures.
      await _reloadRuntimeConfig();
      notifyListeners();
    }
  }

  Future<void> setEnable(bool enable) async {
    await updateConfig((c) => c.copyWith(enable: enable));
    if (enable) {
      await _autoSelectChainGroup();
    }
    // P0: `enable` is one of the two inputs that decide whether the automatic
    // failover loop runs, so every toggle must reconcile the loop.
    _syncChainHealthCheck();
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

  Future<void> setPreventDnsLeak(bool prevent) async {
    await updateConfig((c) => c.copyWith(preventDnsLeak: prevent));
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

  /// Adds landing proxies, skipping names that already exist.
  ///
  /// Returns how many were actually added. Names must be unique: they are
  /// written into the generated config as proxy names, and mihomo rejects a
  /// whole config that contains a duplicate — one repeated import would take
  /// down every node, not just the duplicated one.
  Future<int> addLandingProxies(List<LandingProxy> proxies) async {
    if (proxies.isEmpty) return 0;
    var added = 0;
    await updateConfig((c) {
      final names = c.landingProxies.map((p) => p.name.trim()).toSet();
      final accepted = <LandingProxy>[];
      for (final proxy in proxies) {
        final name = proxy.name.trim();
        if (name.isEmpty) continue;
        // No commonPrint here: it routes through AppController.addLog,
        // which touches a Riverpod ref and throws when the widget is
        // already disposed (it broke a test that way). The return value
        // and the UI snackbar carry the same information.
        if (!names.add(name)) continue;
        accepted.add(proxy);
      }
      added = accepted.length;
      if (accepted.isEmpty) return c;
      return c.copyWith(
        landingProxies: List<LandingProxy>.from(c.landingProxies)
          ..addAll(accepted),
      );
    });
    return added;
  }

  /// Updates one landing proxy in place. Returns false when nothing changed —
  /// an unknown id, or a rename onto a name another entry already uses.
  Future<bool> updateLandingProxy(LandingProxy proxy) async {
    var updated = false;
    await updateConfig((c) {
      final index = c.landingProxies.indexWhere((p) => p.id == proxy.id);
      if (index == -1) return c;
      final name = proxy.name.trim();
      final duplicate = c.landingProxies.any(
        (p) => p.id != proxy.id && p.name.trim() == name,
      );
      if (duplicate) return c;
      final list = List<LandingProxy>.from(c.landingProxies);
      list[index] = proxy;
      updated = true;
      return c.copyWith(landingProxies: list);
    });
    return updated;
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
  void applyToClashConfig(
    Map<String, dynamic> rawConfig, {
    Map<String, Map<String, dynamic>> extraProxyConfigs = const {},
  }) {
    _config.applyToClashConfig(
      rawConfig,
      extraProxyConfigs: extraProxyConfigs,
    );
  }

  // ─── Phase 5.x Runtime State ─────────────────────────────────────────────

  ChainRetryProgress? _retryProgress;
  ChainProbeReport? _lastProbeReport;
  bool _isProbingChain = false;
  ChainFailoverProgress? _failoverProgress;
  CancelToken? _probeCancelToken;
  CancelToken? _failoverCancelToken;

  /// RC.10-C.1 — id of the probe session that currently owns the shared probe
  /// state ([_isProbingChain] / [_probeCancelToken] / [_lastProbeReport]).
  ///
  /// [probeCurrentChain] takes the next id synchronously, so a superseded probe
  /// can never publish a stale report, reset the busy flag under its successor,
  /// or drive automatic failover on behalf of the newer probe.
  int _probeGeneration = 0;

  /// In-memory fallback pool.
  ChainFallbackPool _fallbackPool = const ChainFallbackPool();

  int _consecutiveHealthCheckFailures = 0;

  /// P1.5-A: the last auto-failover skip diagnosis written to the log, so a
  /// persistent condition (e.g. an exhausted candidate pool) is reported **once**
  /// rather than on every 1-minute health-check tick.
  String? _lastAutoFailoverSkipDiagnosis;
  Timer? _chainHealthTimer;
  Timer? _reliabilityPersistTimer;

  /// RC.11-C1 (F-AR5) — the single-shot timer that advances `stateVersion` when
  /// the **next real latency-freshness transition** becomes due.
  ///
  /// Time itself is not a Riverpod dependency: `adaptiveRankingProvider` watches
  /// only `groupsProvider` / `selectedMapProvider` / `capabilityRevision` /
  /// `stateVersion` / the network fingerprint, and `rankingStateFingerprint`
  /// carries no time component. So when an observation crosses
  /// `LatencyFreshness.trustedMaxAge` / `degradedMaxAge` with no other change,
  /// nothing would re-rank. This timer closes that gap by doing exactly one
  /// thing at the boundary: `notifyListeners()`. That bumps `stateVersion`,
  /// which is already a fingerprint input, so the existing cache-miss path
  /// (NOT a bypass) recomputes the ranking.
  ///
  /// It never probes the network and never writes candidate business data.
  Timer? _freshnessTickTimer;

  /// The delay until the next transition, or `null` when no observation is
  /// currently in a gated (`trusted` / `degraded`) state.
  ///
  /// Exposed for tests so the schedule can be asserted without waiting on a
  /// real timer. Production callers use [_scheduleFreshnessTick].
  @visibleForTesting
  Duration? nextFreshnessTransitionDelay() =>
      _computeNextFreshnessTransition(_now());

  /// Cancels any armed freshness tick. Exposed for tests so a case can drop the
  /// timer it caused to be re-armed, without disposing the shared singleton.
  @visibleForTesting
  void cancelFreshnessTick() {
    _freshnessTickTimer?.cancel();
    _freshnessTickTimer = null;
  }

  /// Test seam: overrides the clock used by the freshness tick. `null` in
  /// production, where [now] falls back to `DateTime.now()` — the same optional
  /// injection pattern `ChainFallbackPolicy.clock` already uses
  /// (`chain_fallback_service.dart:49/67`).
  @visibleForTesting
  static DateTime Function()? freshnessClockOverride;

  /// The clock this tick schedules against. Production default is the wall
  /// clock; tests inject a controllable one.
  ///
  /// Private on purpose: it is only ever called from within this class, so
  /// marking it `@visibleForTesting` would wrongly flag production use.
  DateTime _now() =>
      freshnessClockOverride != null ? freshnessClockOverride!() : DateTime.now();

  /// The delay from [from] until the earliest applicable freshness transition
  /// among the current candidates, or `null` if none is due.
  ///
  /// Only the **gated** states are considered (`evaluate` returning `trusted`
  /// or `degraded`), because `unknown` is terminal — it can never transition
  /// again. Thresholds are read from [LatencyFreshness] rather than duplicated;
  /// the `<=` boundary and the fingerprint / scope checks are exactly those of
  /// [LatencyFreshness.evaluate], so this schedule can never disagree with the
  /// gate that produced the value the UI shows.
  ///
  /// A 1-second guard is added so a timer that fires slightly early (or a
  /// still-equal age due to clock granularity) cannot reschedule itself into a
  /// busy loop.
  Duration? _computeNextFreshnessTransition(DateTime from) {
    final String currentFingerprint =
        networkFingerprintProvider.getCurrentFingerprint();
    Duration? earliest;

    void consider(LatencyState? state) {
      if (state == null) return;
      if (state.scope != LatencyScope.node) return;
      if (state.fingerprint != currentFingerprint) return;

      final LatencyFreshness freshness = LatencyFreshness.evaluate(
        state: state,
        now: from,
        currentFingerprint: currentFingerprint,
        expectedScope: LatencyScope.node,
      );

      // `unknown` is terminal: nothing to schedule. `trusted` → the age at
      // which it becomes `degraded`; `degraded` → the age at which it becomes
      // `unknown`.
      final Duration? boundary;
      switch (freshness) {
        case LatencyFreshness.trusted:
          boundary = LatencyFreshness.trustedMaxAge;
        case LatencyFreshness.degraded:
          boundary = LatencyFreshness.degradedMaxAge;
        case LatencyFreshness.unknown:
          return;
      }

      final Duration age = from.difference(state.testedAt);
      // A negative age is `trusted` by contract but has no well-defined
      // transition instant off the stored timestamp; skip it rather than
      // schedule an arbitrary delay.
      if (age.isNegative) return;

      final Duration delay =
          (boundary - age) + const Duration(seconds: 1);
      if (earliest == null || delay < earliest!) earliest = delay;
    }

    for (final c in _fallbackPool.entryCandidates) {
      consider(c.nodeLatency);
    }
    for (final c in _fallbackPool.relayCandidates) {
      consider(c.nodeLatency);
    }
    for (final c in _fallbackPool.exitCandidates) {
      consider(c.nodeLatency);
    }
    return earliest;
  }

  /// (Re)arms [_freshnessTickTimer] from the current pool.
  ///
  /// Always cancels first, so a repeated call never leaves two live timers;
  /// when no transition is pending the timer is simply left cancelled (no空转
  /// polling).
  void _scheduleFreshnessTick() {
    _freshnessTickTimer?.cancel();
    _freshnessTickTimer = null;

    final Duration? delay = _computeNextFreshnessTransition(_now());
    if (delay == null) return;

    _freshnessTickTimer = Timer(delay, () {
      // A timer that outlives `dispose()` must do no work. `notifyListeners()`
      // has its own `_disposed` guard, but skipping here avoids even the
      // reschedule.
      if (_disposed) return;
      // The only effect: advance `stateVersion` through the normal path.
      notifyListeners();
      // Re-arm for the following boundary — a single-shot timer would
      // otherwise stop permanently after one transition.
      _scheduleFreshnessTick();
    });
  }

  /// Authoritative "un-persisted reliability samples exist" marker.
  ///
  /// It is set the moment a persist becomes pending — *before* the
  /// `_initialized` guard in [_scheduleReliabilityPersist] — and cleared by
  /// [flushReliabilityStats]. The debounce `Timer` alone cannot express this
  /// state: it is only armed once the manager is initialized.
  bool _reliabilityPersistDirty = false;
  bool _disposed = false;
  static List<dynamic>? capabilityProbeSourceOverride;
  final Map<String, ProtocolCapabilityProfile> _capabilityProfiles = {};
  int _capabilityRevision = 0;
  final Set<String> _capabilityProbesInFlight = {};

  /// P1.2-K3 (S1): bumped by [refreshCapabilityProfiles] every time the
  /// capability view is rebuilt. A probe captures it on start and discards its
  /// result if the view has been rebuilt since — otherwise a stale probe (born
  /// from the previous config, carrying the previous `udp` declaration) would
  /// overwrite the new baseline by node name and feed a wrong declaration into
  /// the failover compatibility gate.
  int _capabilityViewGeneration = 0;

  // Phase 5.x state fields (mutable, set by recovery/failover logic)
  ChainRecoveryPlan? pendingRecoveryPlan;
  ChainSupportPackage? lastGeneratedPackage;

  /// Absolute path of the real ZIP written by [createSupportPackage]. `null`
  /// until a package has actually been produced.
  String? lastGeneratedPackagePath;

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

  /// Switches the hop count, **migrating the exit node** between the two modes.
  ///
  /// Two-hop keeps the exit in `hop2Node`; three-hop keeps the relay in
  /// `hop2Node` and the exit in `hop3Node`. A bare `hopMode` write would
  /// silently reinterpret the previous exit as the relay and leave the chain
  /// with no exit at all — and the UI used to clear both fields, destroying the
  /// user's exit configuration outright.
  ///
  /// Only the exit is migrated: two-hop has no relay, so there is no field to
  /// carry one across a round trip.
  Future<void> setHopMode(ChainHopMode mode) async {
    if (mode == _config.hopMode) return;

    await updateConfig((c) {
      if (mode == ChainHopMode.twoHop) {
        // Three-hop keeps the exit in `hop3Node`; restore it into `hop2Node`.
        // Nothing to restore → leave `hop2Node` untouched rather than wiping it.
        final String exit = c.hop3Node.trim();
        return c.copyWith(
          hopMode: ChainHopMode.twoHop,
          hop2Node: exit.isNotEmpty ? exit : c.hop2Node,
          hop3Node: '',
        );
      }

      // Entering three hops: move the two-hop exit into `hop3Node` and clear the
      // relay slot for the user to pick. An empty `hop2Node` means there is
      // nothing to migrate, so both fields are left exactly as they are.
      final String previousExit = c.hop2Node.trim();
      return c.copyWith(
        hopMode: ChainHopMode.threeHop,
        hop2Node: previousExit.isEmpty ? c.hop2Node : '',
        hop3Node: previousExit.isEmpty ? c.hop3Node : previousExit,
      );
    });
  }

  Future<void> setHop1Node(String name) async {
    await updateConfig((c) => c.copyWith(
          hop1Node: name,
          defaultDialerProxy: name,
        ));
  }

  /// Replaces the front-hop chain wholesale.
  ///
  /// The chain is stored as a list so adding or removing a hop cannot leave the
  /// old single-hop fields disagreeing with it; `hop1Node` is kept in sync
  /// because the probe and the topology labels still read it.
  Future<void> setFrontHops(List<String> hops) async {
    final cleaned = hops
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await updateConfig((c) => c.copyWith(
          frontHops: cleaned,
          hop1Node: cleaned.isNotEmpty ? cleaned.first : '',
          defaultDialerProxy: cleaned.isNotEmpty ? cleaned.first : '',
        ));
  }

  Future<void> addFrontHop(String name) async {
    final current = List<String>.from(_config.effectiveFrontHops);
    current.add(name);
    await setFrontHops(current);
  }

  Future<void> removeFrontHopAt(int index) async {
    final current = List<String>.from(_config.effectiveFrontHops);
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    await setFrontHops(current);
  }

  Future<void> setFrontHopAt(int index, String name) async {
    final current = List<String>.from(_config.effectiveFrontHops);
    if (index < 0 || index >= current.length) return;
    current[index] = name;
    await setFrontHops(current);
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

  /// Stores the fallback pool **in memory only** — it does not persist.
  ///
  /// F-E3: this is the runtime/test path, not a production write. Production
  /// writes the pool through [updateFallbackPool], which also saves to disk and
  /// schedules the reliability write; calling this one from production would
  /// silently drop the change on the next restart. It is public purely so tests
  /// can seed the pool directly, hence [visibleForTesting]. Full integration
  /// with ChainFallbackService is performed by the AutoFailover coordinator at
  /// runtime.
  @visibleForTesting
  Future<void> setFallbackPool(ChainFallbackPool pool) async {
    _fallbackPool = pool;
    notifyListeners();
    // RC.11-C1: candidate set changed ⇒ the pending freshness transition may
    // differ (a new observation shortens it, a removed one drops it).
    _scheduleFreshnessTick();
  }

  // ─── Phase 5.x Failover Lifecycle ────────────────────────────────────────

  /// Applies [cfg] to the running core **without persisting it**.
  ///
  /// This is the failover executor's `onApply` / `onRollback` path: a candidate
  /// is only committed to disk (see [_commitConfig]) once it has been proven
  /// healthy.
  Future<void> _applyConfigRuntime(ChainProxyConfig cfg) async {
    _config = cfg;
    notifyListeners();
    // A runtime reload failure must be observed here, otherwise a candidate
    // that never actually applied would be treated as applied (and could then
    // be committed).
    await _reloadRuntimeConfig();
    notifyListeners();
  }

  /// Commits [cfg]: updates memory **and** persists it to `chain_proxies.json`.
  Future<void> _commitConfig(ChainProxyConfig cfg) async {
    _config = cfg;
    notifyListeners();
    await _saveConfig();
  }

  /// Builds the real production executor (the existing
  /// [DelegateChainFailoverExecutor], wired to this manager's runtime
  /// apply / probe / rollback / commit paths).
  IChainFailoverExecutor _buildFailoverExecutor(ChainFailoverPolicy policy) {
    final real = DelegateChainFailoverExecutor(
      onApply: (cfg, _) => _applyConfigRuntime(cfg),
      onProbe: (cfg, token) => chainProbeService.probeChain(
        config: cfg,
        timeout: policy.probeTimeout,
        cancelToken: token,
      ),
      onRollback: (cfg, _) => _applyConfigRuntime(cfg),
      onCommit: (cfg) => _commitConfig(cfg),
    );
    final wrapper = failoverExecutorWrapper;
    return wrapper != null ? wrapper(real) : real;
  }

  /// Triggers auto-failover. Full implementation delegates to ChainFailoverService.
  /// This thin coordinator updates progress state and notifies listeners.
  Future<ChainFailoverResult> triggerAutoFailover({
    String? triggerReason,
    ChainProbeReport? initialFailureReport,
    Duration? timeout,
    dynamic retryPolicy,
    bool bypassDampening = false,
  }) async {
    // P1.1-F single-flight: while a failover session is already active, a
    // second trigger is rejected outright — it must NOT cancel, take over, or
    // supersede the running session. The rejection reason is carried in the
    // returned result's `rootCause`.
    if (isFailingOver) {
      return ChainFailoverResult.cancelled(
        originalConfig: _config,
        reason: '已有故障转移正在执行，已拒绝重复触发',
      );
    }

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
        availableProxyNames: _availableProxyNames(),
        availableProxyProfiles: _capabilityProfiles.isEmpty
            ? null
            : Map<String, ProtocolCapabilityProfile>.of(_capabilityProfiles),
        cancelToken: _failoverCancelToken,
        executor: _buildFailoverExecutor(policy),
        flapDampener: chainFlapDampenerService,
        // Forward the report the health check already produced: without it,
        // `executeFailover` would fall back to a real network retry/probe.
        initialFailureReport: initialFailureReport,
        onProgress: (progress) {
          _failoverProgress = progress;
          notifyListeners();
        },
        onPoolUpdated: (pool) {
          _fallbackPool = pool;
          notifyListeners();
          // Failover records reliability samples too — persist (debounced).
          _scheduleReliabilityPersist();
          // RC.11-C1: the failover writer is the ONLY producer of
          // `nodeLatency`, so this is where a fresh observation actually
          // appears — re-arm the freshness transition from the new pool.
          _scheduleFreshnessTick();
        },
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

  // ─── Phase 5.x Probe Lifecycle ─────────────────────────────────────────────
  void cancelCurrentProbe() {
    _probeCancelToken?.cancel();
    _probeCancelToken = null;
    // RC.10-C.2: invalidate the cancelled session's generation right away.
    // Without this the publish guard below (`generation == _probeGeneration`)
    // still passes, so a probe that ignores the CancelToken and completes
    // normally would publish its report; and because `_probeCancelToken` was
    // just nulled, the cancel check in `_writeBackProbeResultsToCandidates`
    // (`_probeCancelToken?.isCancelled == true`) no longer fires either, so that
    // report could also record reliability samples. Bumping the generation
    // makes the publish guard fail first, regardless of what the probe does.
    _probeGeneration++;
    _isProbingChain = false;
    notifyListeners();
  }

  Future<ChainProbeReport> probeCurrentChain({
    String? testUrl,
    Duration? timeout,
    CancelToken? cancelToken,
    ChainRetryPolicy? retryPolicy,
  }) async {
    // RC.10-C.1 — a new probe supersedes the previous one. The old token is
    // cancelled *before* the field is replaced: silently overwriting it would
    // orphan the token, and `cancelCurrentProbe()` could never reach it again.
    _probeCancelToken?.cancel();
    final int generation = ++_probeGeneration;
    final CancelToken token = cancelToken ?? CancelToken();
    _probeCancelToken = token;
    _isProbingChain = true;
    notifyListeners();

    // item 3-A — the chain probe must honour the user-configured test URL
    // (`appSetting.testUrl`, the same one the delay tests use) instead of
    // silently falling back to the hard-coded gstatic default. Callers that
    // pass an explicit URL still win. `globalState.config` always resolves to a
    // default config (state.dart:46), so this is safe before the app boots.
    final String configuredTestUrl = globalState.config.appSetting.testUrl
        .trim();
    final String? effectiveTestUrl = (testUrl == null || testUrl.isEmpty)
        ? (configuredTestUrl.isEmpty ? null : configuredTestUrl)
        : testUrl;
    try {
      final override = chainProbeOverride;
      final report = override != null
          ? await override(_config)
          : await chainProbeService.probeChain(
              config: _config,
              testUrl: effectiveTestUrl,
              cancelToken: token,
            );
      // RC.10-C.1 — only the owning probe may publish. A superseded probe's
      // report is stale evidence: it must not overwrite the newer report, write
      // back to the candidate pool, or be handed to the failover decision.
      if (generation == _probeGeneration) {
        _lastProbeReport = report;
        _writeBackProbeResultsToCandidates(report);
      }
      return report;
    } finally {
      // RC.10-C.1 — only the owning probe may clear the busy flag; otherwise a
      // slow predecessor finishing first would report "not probing" while its
      // successor is still running.
      if (generation == _probeGeneration) {
        _isProbingChain = false;
        notifyListeners();
      }
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
  /// P2.5-D: delegates to the REAL [ChainDiagnosticExportService] — the report
  /// is built from this manager's REAL telemetry ([telemetrySnapshot]) and REAL
  /// chain config, and a real Markdown file is written to disk.
  Future<File?> exportChainDiagnosticReport() {
    return chainDiagnosticExportService.exportReport(this);
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

  /// Generates a support package (a real ZIP) through the existing real
  /// service.
  ///
  /// On success the produced package and its real file path are published on
  /// [lastGeneratedPackage] / [lastGeneratedPackagePath]. On failure nothing is
  /// fabricated and the error propagates to the caller (the UI surfaces it).
  Future<void> createSupportPackage() async {
    final package = await chainSupportPackageService.createPackage(this);
    final file = await chainSupportPackageService.exportPackage(package);
    lastGeneratedPackage = package;
    lastGeneratedPackagePath = file.path;
    notifyListeners();
  }

  int get capabilityRevision => _capabilityRevision;

  /// Per-node capability view (nodeName -> profile), built from the REAL profile
  /// config. Empty until [refreshCapabilityProfiles] succeeds.
  Map<String, ProtocolCapabilityProfile> get capabilityProfiles =>
      Map.unmodifiable(_capabilityProfiles);
  void stopChainHealthCheck() {
    _chainHealthTimer?.cancel();
    _chainHealthTimer = null;
    _consecutiveHealthCheckFailures = 0;
    // P1.5-A: a stopped loop has no skip state to report — reset silently (no
    // log line; this is a lifecycle reset, not a diagnosis transition).
    _lastAutoFailoverSkipDiagnosis = null;
  }
  
  /// Test seam: redirects `chain_proxies.json` away from the real
  /// application data directory. `null` in production.
  @visibleForTesting
  static String? configFilePathOverride;

  /// Test seam: redirects `chain_fallback_pool.json` away from the real
  /// application data directory. `null` in production.
  @visibleForTesting
  static String? fallbackPoolFilePathOverride;
  @visibleForTesting
  static String? reliabilityStatsFilePathOverride;

  /// Runs the real chain probe for the node that currently occupies [role].
  ///
  /// The runtime only supports probing the **configured chain**, so that is the
  /// probe this entry performs — the node card offers the button only for the
  /// node that currently occupies [role], and the chain probe is what produces
  /// that node's hop result. Results flow through the existing write-back
  /// ([_writeBackProbeResultsToCandidates]), which attributes each hop to the
  /// matching pool candidate by name; nothing is fabricated and no other node is
  /// credited.
  ///
  /// A probe already in flight is never restarted, so a repeated trigger cannot
  /// record the same probe twice.
  Future<void> testSingleProxy({
    required String nodeName,
    required FallbackCandidateRole role,
  }) async {
    final current = switch (role) {
      FallbackCandidateRole.entry => _config.effectiveHop1,
      FallbackCandidateRole.relay => _config.hop2Node,
      FallbackCandidateRole.exit => _config.effectiveExitNode,
    };
    // The caller's node no longer occupies this hop: there is nothing to probe,
    // and probing the chain would attribute another node's result to it.
    if (current.trim() != nodeName.trim()) return;
    if (_isProbingChain) return;
    await probeCurrentChain();
  }


  List<String>? _availableProxyNames() {
    // `null` means "do not filter by available names" (see
    // ChainFallbackService.selectCandidates). When the app is not booted
    // (unit tests), there is no AppController to read groups from.
    if (!globalState.hasAppController) return null;
    try {
      final groups = globalState.appController.ref.read(groupsProvider);
      return groups.expand((g) => g.all.map((p) => p.name)).toList();
    } catch (_) {
      // The group view is not readable (e.g. a torn-down ProviderScope).
      // `null` degrades to "do not filter" rather than aborting the caller —
      // a synchronous throw here would otherwise unwind `triggerAutoFailover`
      // before it has even started, leaving a misleading "not failing over"
      // state.
      return null;
    }
  }

  /// Read-only view of the node names currently available for chain hops.
  ///
  /// Exposes the same source the failover path already trusts
  /// ([_availableProxyNames]): the names of every proxy in the live group view,
  /// which is also what the node picker offers. B3's hop-configuration UI needs
  /// it to run [ChainTopologyValidator.validate] against the real node set
  /// before a hop is written.
  ///
  /// `null` means the set could not be read (app not booted, or the group view
  /// is not readable). Callers must treat that as "availability unknown" — not
  /// as "every node is available" — and refuse to report success.
  List<String>? get availableProxyNames => _availableProxyNames();

  /// Starts the periodic health-check loop if it is not already running.
  ///
  /// F-C1: this is **not** a production entry point. Production turns the loop
  /// on only through [_syncChainHealthCheck], which gates on the desired config
  /// state; it is public purely so tests can drive the loop directly, hence
  /// [visibleForTesting] (a production caller in another library would get an
  /// `invalid_use_of_visible_for_testing_member` warning).
  ///
  /// It is also **self-guarding**: a call while the loop is already live is a
  /// no-op. Without this, a stray caller could cancel-and-restart a running
  /// loop and thereby reset [_consecutiveHealthCheckFailures] — which delays
  /// automatic-failover detection by up to one full failure window. Use
  /// [stopChainHealthCheck] to end the loop; a later start resets the counter as
  /// expected.
  @visibleForTesting
  void startChainHealthCheck() {
    if (isAutoHealthCheckRunning) return;
    _chainHealthTimer?.cancel();
    _consecutiveHealthCheckFailures = 0;
    _chainHealthTimer = Timer.periodic(autoHealthCheckInterval, (_) {
      runChainHealthCheck();
    });
  }

  /// P0: the single reconciliation point for the automatic failover loop.
  ///
  /// The periodic health check is the **only** production driver of automatic
  /// failover ([runChainHealthCheck] → [_maybeAutoFailover] →
  /// [triggerAutoFailover]). It must therefore be (re)started from every
  /// lifecycle entry that can turn it on:
  ///
  ///   * [init]              — restoring a persisted `autoFailover: true`
  ///   * [setEnable]         — enabling/disabling the chain itself
  ///   * [setAutoFailover]   — the explicit user toggle
  ///
  /// It is deliberately **not** called from [updateConfig]: that runs on every
  /// config write (hop edits, failover commits) and restarting the timer there
  /// would reset `_consecutiveHealthCheckFailures`, delaying detection.
  ///
  /// An already-running loop is left untouched, so repeated calls are
  /// idempotent and never reset the consecutive-failure counter.
  void _syncChainHealthCheck() {
    final bool shouldRun = _config.autoFailover && _config.enable;
    if (shouldRun) {
      if (!isAutoHealthCheckRunning) {
        startChainHealthCheck();
      }
    } else if (isAutoHealthCheckRunning) {
      stopChainHealthCheck();
    }
  }


  Future<void> runChainHealthCheck() async {
    // P0 hardening: a tick that fired just before `dispose()` must do no work.
    if (_disposed) return;
    if (!_config.autoFailover || !_config.enable || _isProbingChain || isFailingOver) return;

    final bool coreRunning = await _isCoreReady();
    if (!coreRunning) return;

    // RC.10-C.1 — `_isCoreReady()` awaits a real core-API call, so the guard
    // above is stale once we resume: a manual probe (or another tick) may have
    // started in the meantime. Re-check before starting our own probe.
    //
    // F-B2: teardown may also have run during the await. A probe started now
    // would take a fresh, un-cancelled token and write back into a disposed
    // manager, so `_disposed` must be part of the re-check too.
    if (_disposed || _isProbingChain || isFailingOver) return;

    // `probeCurrentChain` takes the next id synchronously, so this is exactly
    // the id our own probe will own.
    final int probeGeneration = _probeGeneration + 1;
    final report = await probeCurrentChain();
    // A newer probe superseded ours: its report is stale evidence and must not
    // drive automatic failover.
    if (_probeGeneration != probeGeneration) return;
    await _maybeAutoFailover(report);
  }

  /// P2.4-E (CF-5): the core is "ready" only when its API actually answers —
  /// `appState.runTime != null` is *local* bookkeeping and cannot tell a healthy
  /// core from a killed one.
  ///
  /// * an explicit `coreRunningOverride` (test seam) wins outright;
  /// * `running` → ready; `stopped` / `starting` / `unreachable` → not ready;
  /// * `unknown` (a platform with no desktop core service, e.g. Android) →
  ///   falls back to the local start flag and **never** optimistically assumes
  ///   ready.
  Future<bool> _isCoreReady() async {
    final override = coreRunningOverride;
    if (override != null) return override;

    final result = await CoreHealthService.instance.check();
    if (result.state == CoreHealthState.running) return true;
    if (result.state == CoreHealthState.unknown) {
      try {
        return globalState.isStart;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// P1.5-A: reports **why** automatic failover was skipped.
  ///
  /// The three reasons are mutually exclusive within one pass — decided by
  /// nesting depth inside [_maybeAutoFailover], so only the outermost failing
  /// gate is reported:
  ///   1. `failureHop 未提供` — role is indeterminate, nothing can be replaced
  ///   2. `无可用候选`        — the enabled candidate pool for that role is empty
  ///   3. `抖动抑制中`        — the flap dampener suppressed this pass
  ///
  /// A diagnosis is written only when it **differs** from the previous pass, so a
  /// persistent condition (an exhausted pool re-evaluated every minute) logs
  /// once instead of once per tick.
  void _reportAutoFailoverSkip(String reason) {
    if (_lastAutoFailoverSkipDiagnosis == reason) return;
    _lastAutoFailoverSkipDiagnosis = reason;
    commonPrint.log('ChainProxyManager: auto failover skipped — $reason');
  }

  /// P1.5-A: clears the skip diagnosis after a genuine recovery, logging once.
  ///
  /// Only reached for `healthy` — see the caller. `degraded` / `cancelled` /
  /// `unknown` / `checking` deliberately keep the existing diagnosis, since a
  /// still-impaired (or undetermined) chain does not prove the skip reason has
  /// gone away.
  void _clearAutoFailoverSkipDiagnosis() {
    if (_lastAutoFailoverSkipDiagnosis == null) return;
    _lastAutoFailoverSkipDiagnosis = null;
    commonPrint.log('ChainProxyManager: auto failover skip cleared');
  }

  Future<void> _maybeAutoFailover(ChainProbeReport report) async {
    if (report.status == ChainHealthStatus.failed || report.status == ChainHealthStatus.unavailable) {
      _consecutiveHealthCheckFailures++;
      if (_consecutiveHealthCheckFailures >= 2) {
        // The failing hop index is the authoritative signal for *which* role to
        // replace. Without it (null) the role is indeterminate, so the
        // automatic trigger must not fire.
        final int? failureHopIndex = report.failureHop;
        if (failureHopIndex != null) {
          final role = ChainFailoverService.deduceRoleFromFailureHop(
            _config.hopMode,
            failureHopIndex,
          );
          final candidates = _fallbackPool
              .getCandidatesByRole(role)
              .where((c) => c.enabled)
              .toList();
          if (candidates.isNotEmpty) {
            final dampening = chainFlapDampenerService.evaluate();
            if (!dampening.isDampened) {
              // Await the session so a single health-check pass is a complete,
              // observable unit (apply → probe → commit/rollback). The
              // `isFailingOver` guard already makes re-entrancy impossible, and
              // the periodic timer simply runs one tick longer.
              try {
                await triggerAutoFailover(
                  triggerReason: 'Auto failover triggered',
                  initialFailureReport: report,
                  bypassDampening: false,
                );
              } catch (e) {
                commonPrint.log('ChainProxyManager: auto failover failed: $e');
              }
            } else {
              _reportAutoFailoverSkip('抖动抑制中 (dampened)');
            }
          } else {
            _reportAutoFailoverSkip('无可用候选 (role=${role.name})');
          }
        } else {
          _reportAutoFailoverSkip(
            'failureHop 未提供，无法判定需替换的角色 '
            '(hopMode=${_config.hopMode.name}, status=${report.status.name})',
          );
        }
      }
    } else {
      _consecutiveHealthCheckFailures = 0;
      // P1.5-A: only a genuinely healthy report clears the diagnosis. This else
      // branch is "not failed/unavailable" — it also covers `degraded`,
      // `cancelled`, `unknown` and `checking`, none of which proves the original
      // skip reason has gone away.
      if (report.status == ChainHealthStatus.healthy) {
        _clearAutoFailoverSkipDiagnosis();
      }
    }
  }

  void _scheduleReliabilityPersist() {
    _reliabilityPersistDirty = true;
    if (!_initialized) return;
    _reliabilityPersistTimer?.cancel();
    _reliabilityPersistTimer = Timer(const Duration(seconds: 2), () {
      _reliabilityPersistTimer = null;
      unawaited(flushReliabilityStats());
    });
  }

  Future<bool> flushReliabilityStats() async {
    _reliabilityPersistTimer?.cancel();
    _reliabilityPersistTimer = null;
    _reliabilityPersistDirty = false;
    try {
      final overridePath = reliabilityStatsFilePathOverride;
      String filePath;
      if (overridePath != null) {
        filePath = overridePath;
      } else {
        final resolved = await _getReliabilityStatsFilePath();
        if (resolved == null) return true;
        filePath = resolved;
      }
      
      final mapToSave = <FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>{};
      mapToSave[FallbackCandidateRole.entry] = { for (var c in _fallbackPool.entryCandidates) c.nodeName: c.statsByContext };
      mapToSave[FallbackCandidateRole.relay] = { for (var c in _fallbackPool.relayCandidates) c.nodeName: c.statsByContext };
      mapToSave[FallbackCandidateRole.exit] = { for (var c in _fallbackPool.exitCandidates) c.nodeName: c.statsByContext };
      
      const service = ChainReliabilityStatsPersistence();
      return await service.save(filePath, mapToSave);
    } catch (e) {
      commonPrint.log('ChainProxyManager: Failed to flush reliability stats: $e');
      return false;
    }
  }

  Future<void> refreshCapabilityProfiles() async {
    if (_disposed) return;
    // P1.2-K3 (S1): a new capability view version begins here. Probes started
    // against the previous view must not write back into this one.
    _capabilityViewGeneration++;
    try {
    
      final targets = <dynamic>[];
    
      if (capabilityProbeSourceOverride != null) {
        targets.addAll(capabilityProbeSourceOverride!);
      } else {
        final currentProfileId = globalState.config.currentProfileId;
        if (currentProfileId == null || currentProfileId.isEmpty) return;
      
        final configMap = await globalState.getProfileConfig(currentProfileId);
        final proxies = configMap['proxies'];
        if (proxies is! List) return;
        targets.addAll(proxies);
      }
    
      final currentNames = <String>{};
      for (final proxy in targets) {
        if (proxy is! Map) continue;
        final nodeName = proxy['name']?.toString() ?? '';
        if (nodeName.isEmpty) continue;
        currentNames.add(nodeName);
      
        final capability = ChainCapabilityService.getCapability(proxy);
        _capabilityProfiles[nodeName] = capability;
      }

      // P1.2-G7 (H2): the capability view means "the current config is the
      // truth". Entries for nodes that no longer exist must not linger: they are
      // never consumed today (a ghost is not read by any consumer), but they are
      // unbounded retention, and they make `availableProxyProfiles` — which is
      // handed to failover — carry names the config no longer has. Pruning here
      // is therefore behaviour-neutral by construction.
      _capabilityProfiles.removeWhere((name, _) => !currentNames.contains(name));
    
      _capabilityRevision++;
      notifyListeners();
    
      unawaited(_startRuntimeCapabilityProbes(targets));
    } catch (e) {
      // Best-effort by contract: a core/read failure here must never break the
      // caller (`_reloadRuntimeConfig`), nor surface as an unhandled async error
      // from the fire-and-forget call in `init()`. The previous capability view
      // is deliberately left untouched.
      commonPrint.log(
        'ChainProxyManager: refreshCapabilityProfiles failed: $e',
      );
    }
  }
  
  Future<void> _startRuntimeCapabilityProbes(List<dynamic> targets) async {
    // P1.2-G3 (K1): bound the fan-out. The previous `for` + `unawaited` fired
    // one probe per node at once, so the in-flight count grew linearly with the
    // subscription size (hundreds of simultaneous native `getDelay` calls on
    // startup). Reuse the governor the UI delay test already honours
    // (`ProxiesStyle.concurrencyLimit`) and the existing `Iterable.batch`
    // helper — no new concurrency primitive is introduced.
    //
    // Per-node single-flight is unchanged: a node already in flight is filtered
    // out *before* the batches are formed.
    //
    // P1.2-K3 (S1): every probe in this batch belongs to the capability view
    // that is current *now*; a later `refreshCapabilityProfiles` invalidates it.
    final generation = _capabilityViewGeneration;
    final pending = <Map<dynamic, dynamic>>[];
    for (final proxy in targets) {
      if (proxy is! Map) continue;
      final nodeName = proxy['name']?.toString() ?? '';
      if (nodeName.isEmpty) continue;
      if (_capabilityProbesInFlight.contains(nodeName)) continue;
      _capabilityProbesInFlight.add(nodeName);
      pending.add(proxy);
    }

    final configuredLimit = globalState.config.proxiesStyle.concurrencyLimit;
    final limit = configuredLimit > 0 ? configuredLimit : 250;

    // Still fire-and-forget for the caller (`unawaited` at the call site):
    // awaiting batch-by-batch does not delay `refreshCapabilityProfiles`.
    for (final batch in pending.batch(limit)) {
      // P1.2-K3 (S2): a disposed manager must not start further batches. This
      // cannot cancel the probes already in flight (a native `getDelay` call is
      // not cancellable) — it only stops *new* ones from being issued.
      if (_disposed) break;
      await Future.wait(batch.map((proxy) async {
        final nodeName = proxy['name']?.toString() ?? '';
        try {
          final profile = await ChainCapabilityProbeService.probeAndVerify(
            proxy,
            timeout: capabilityProbeTimeout,
          );
          if (_disposed) return;
          // P1.2-K3 (S1): the capability view was rebuilt while this probe was
          // in flight. The result describes the *previous* config (including its
          // declared `udp`), so writing it back by node name would overwrite the
          // new baseline — discard it instead.
          if (generation != _capabilityViewGeneration) return;
          // Only a probe that actually changed the capability view may bump
          // the revision. An inconclusive probe (e.g. a failed/timeout probe
          // that returns the unchanged `unknown` baseline) must not churn the
          // ranking with a phantom state change.
          final current = _capabilityProfiles[nodeName];
          final changed = current == null ||
              current.tcp.evidence != profile.tcp.evidence ||
              current.tls.evidence != profile.tls.evidence ||
              current.udp.evidence != profile.udp.evidence;
          if (!changed) return;
          _capabilityProfiles[nodeName] = profile;
          _capabilityRevision++;
          notifyListeners();
        } catch (_) {
        } finally {
          _capabilityProbesInFlight.remove(nodeName);
        }
      }));
    }
  }

  Future<void> updateFallbackPool(ChainFallbackPool Function(ChainFallbackPool) updater) async {
    _fallbackPool = updater(_fallbackPool);
    notifyListeners();
    await _saveFallbackPool();
    _scheduleReliabilityPersist();
    // RC.11-C1: this is the other pool write path (`:1117` is the failover
    // callback), so a freshness transition may have changed with it.
    _scheduleFreshnessTick();
  }

  /// Records one observation of [nodeName] from outside the chain probe.
  ///
  /// A delay test that succeeded is evidence the node answers, which is the same
  /// thing the chain probe records when a hop reports healthy - not a guess. It
  /// is only applied to nodes already in the fallback pool: adding the node
  /// would change what failover may pick, and measuring a node is not a reason
  /// to promote it to a candidate.
  ///
  /// Returns true when a candidate was found and updated.
  Future<bool> recordNodeObservation(
    String nodeName, {
    required bool success,
  }) async {
    final name = nodeName.trim();
    if (name.isEmpty) return false;

    var updated = false;
    await updateFallbackPool((pool) {
      List<ChainFallbackCandidate> apply(List<ChainFallbackCandidate> list) {
        return [
          for (final c in list)
            if (c.nodeName == name)
              (() {
                updated = true;
                final context =
                    networkFingerprintProvider.getCurrentFingerprint();
                final stats = (c.statsByContext[context] ??
                        ChainReliabilityStats.initial(
                          networkFingerprint: context,
                        ))
                    .recordEvent(
                  isSuccess: success,
                  now: DateTime.now(),
                  lambda: ChainReliabilityStats.decayLambda,
                );
                final map = Map<String, ChainReliabilityStats>.from(
                  c.statsByContext,
                );
                map[context] = stats;
                return c.copyWith(statsByContext: map);
              })()
            else
              c,
        ];
      }

      return pool.copyWith(
        entryCandidates: apply(pool.entryCandidates),
        relayCandidates: apply(pool.relayCandidates),
        exitCandidates: apply(pool.exitCandidates),
      );
    });
    return updated;
  }

  Future<void> setAutoFailover(bool enable) async {
    await updateConfig((c) => c.copyWith(autoFailover: enable));
    // P0: route through the single reconciliation point instead of starting the
    // timer unconditionally. The loop only makes sense while the chain itself is
    // enabled, and `setEnable(true)` will start it as soon as that happens.
    _syncChainHealthCheck();
  }


  /// 把一次链路探测的结果**按节点名**归属到 fallback pool 的候选上。
  ///
  /// **P1.3-C1 — 写入边界（重要，勿误解为「候选状态的统一回写」）**：
  ///  * 本函数**只**累积 `statsByContext`（reliability 样本，按当前 network
  ///    fingerprint 分桶）；
  ///  * **不写** `candidate.health` / `candidate.latencyMs` /
  ///    `candidate.lastChecked` —— 这三个字段目前**只**由 failover 路径写入
  ///    （`ChainFailoverService._updateCandidateStats`）；
  ///  * **覆盖范围**：`report.hops` 只包含**当前生效链路**的跳（最多 3 跳），
  ///    因此一次回写最多命中 ≤3 个候选；pool 内其余候选**不会**因健康检查而更新。
  ///
  /// 完整的 latency / health 统一状态（**谁拥有**该值、覆盖哪些候选、粒度是
  /// 单跳还是链总、以及 timestamp / fingerprint 生命周期）在当前生产路径中
  /// **未覆盖**，需要在 **P1.3-C Score Model Evolution** 中统一设计，
  /// 而不是在本函数内补写字段。
  void _writeBackProbeResultsToCandidates(ChainProbeReport report, {FallbackCandidateRole? role}) {
    if (_probeCancelToken?.isCancelled == true) return;
    // A cancelled probe carries no evidence about the chain, so it must not
    // move the reliability counters. The cancel may be carried by the report
    // itself (the probe observed the token) rather than by our token.
    if (report.isCancelled ||
        report.healthStatus == ChainHealthStatus.cancelled) {
      return;
    }
    
    final now = DateTime.now();

    List<ChainFallbackCandidate> processCandidates(List<ChainFallbackCandidate> candidates, FallbackCandidateRole currentRole) {
      if (role != null && currentRole != role) return candidates;
      
      return candidates.map((c) {
        HopProbeState? matchedHop;
        for (final h in report.hops) {
           if (h.nodeName == c.nodeName) {
             matchedHop = h;
             break;
           }
        }
        if (matchedHop == null) return c;
        
        // P2.2: reliability samples are keyed by the CURRENT network
        // fingerprint, so a transport change routes later samples into a new
        // context instead of merging every network into one bucket.
        final context = networkFingerprintProvider.getCurrentFingerprint();
        
        // Same classification and decay semantics as the failover writer
        // (`ChainFailoverService._updateCandidateStats`), so one node has one
        // history regardless of which path observed it.
        final bool? isSuccess = switch (matchedHop.healthStatus) {
          ChainHealthStatus.healthy || ChainHealthStatus.degraded => true,
          ChainHealthStatus.failed || ChainHealthStatus.unavailable => false,
          // unknown / checking / cancelled carry no evidence — recording either
          // outcome would fabricate a sample.
          _ => null,
        };
        if (isSuccess == null) return c;

        final newStats = (c.statsByContext[context] ??
                ChainReliabilityStats.initial(networkFingerprint: context))
            .recordEvent(
              isSuccess: isSuccess,
              now: now,
              lambda: ChainReliabilityStats.decayLambda,
            );
        final newMap = Map<String, ChainReliabilityStats>.from(c.statsByContext);
        newMap[context] = newStats;

        // The manual chain probe used to record reliability only, and the
        // failover writer was the sole producer of `nodeLatency` — so a probed
        // node still rendered as 「暂无延迟」 in the picker and the card. Its own
        // hop latency is exactly the number those views want, so publish it
        // here, tagged with the network context it was measured on.
        final int? hopLatency = matchedHop.latencyMs;
        final LatencyState? nodeLatency = (hopLatency == null || hopLatency <= 0)
            ? null
            : LatencyState(
                latencyMs: hopLatency,
                scope: LatencyScope.node,
                source: LatencySource.probe,
                testedAt: matchedHop.testedAt ?? now,
                fingerprint: context,
              );

        return c.copyWith(
          statsByContext: newMap,
          nodeLatency: nodeLatency ?? c.nodeLatency,
        );
      }).toList();
    }

    _fallbackPool = _fallbackPool.copyWith(
      entryCandidates: processCandidates(_fallbackPool.entryCandidates, FallbackCandidateRole.entry),
      relayCandidates: processCandidates(_fallbackPool.relayCandidates, FallbackCandidateRole.relay),
      exitCandidates: processCandidates(_fallbackPool.exitCandidates, FallbackCandidateRole.exit),
    );
    
    notifyListeners();
    _scheduleReliabilityPersist();
  }

  /// Whether a reliability sample is awaiting persistence.
  ///
  /// Reflects the real internal state (see [_reliabilityPersistDirty]); it is
  /// never a constant.
  bool get hasPendingReliabilityPersist => _reliabilityPersistDirty;

  /// Adds a candidate to the fallback pool by node name + role.
  ///
  /// Idempotent: adding the same [nodeName] under the same [role] twice leaves
  /// a single entry. A blank / whitespace-only node name is ignored.
  Future<void> addFallbackCandidate({
    required String nodeName,
    required FallbackCandidateRole role,
  }) async {
    final name = nodeName.trim();
    if (name.isEmpty) return;
    await updateFallbackPool((pool) {
      final candidates = _candidatesForRole(pool, role);
      if (candidates.any((c) => c.nodeName == name)) return pool;
      candidates.add(ChainFallbackCandidate(nodeName: name, role: role));
      return _withReplacedRoleCandidates(pool, role, candidates);
    });
  }

  List<ChainFallbackCandidate> _candidatesForRole(ChainFallbackPool pool, FallbackCandidateRole role) {
    if (role == FallbackCandidateRole.entry) return List.from(pool.entryCandidates);
    if (role == FallbackCandidateRole.relay) return List.from(pool.relayCandidates);
    if (role == FallbackCandidateRole.exit) return List.from(pool.exitCandidates);
    return [];
  }

  ChainFallbackPool _withReplacedRoleCandidates(ChainFallbackPool pool, FallbackCandidateRole role, List<ChainFallbackCandidate> candidates) {
    if (role == FallbackCandidateRole.entry) return pool.copyWith(entryCandidates: candidates);
    if (role == FallbackCandidateRole.relay) return pool.copyWith(relayCandidates: candidates);
    if (role == FallbackCandidateRole.exit) return pool.copyWith(exitCandidates: candidates);
    return pool;
  }

  /// Removes a candidate. Only the matching role bucket is touched — the same
  /// node name may legitimately exist under another role.
  Future<void> removeFallbackCandidate({
    required String nodeName,
    required FallbackCandidateRole role,
  }) async {
    await updateFallbackPool((pool) {
      final candidates = _candidatesForRole(pool, role);
      candidates.removeWhere((c) => c.nodeName == nodeName);
      return _withReplacedRoleCandidates(pool, role, candidates);
    });
  }

  /// Toggles `enabled` on the matching candidate.
  Future<void> setFallbackCandidateEnabled({
    required String nodeName,
    required FallbackCandidateRole role,
    required bool enabled,
  }) async {
    await updateFallbackPool((pool) {
      final candidates = _candidatesForRole(pool, role);
      final index = candidates.indexWhere((c) => c.nodeName == nodeName);
      if (index != -1) {
        candidates[index] = candidates[index].copyWith(enabled: enabled);
        return _withReplacedRoleCandidates(pool, role, candidates);
      }
      return pool;
    });
  }

  /// Moves a candidate between role buckets and re-tags its `role` field.
  Future<void> setFallbackCandidateRole({
    required String nodeName,
    required FallbackCandidateRole fromRole,
    required FallbackCandidateRole toRole,
  }) async {
    if (fromRole == toRole) return;
    await updateFallbackPool((pool) {
      final fromCandidates = _candidatesForRole(pool, fromRole);
      final index = fromCandidates.indexWhere((c) => c.nodeName == nodeName);
      if (index != -1) {
        final candidate = fromCandidates.removeAt(index);
        final toCandidates = _candidatesForRole(pool, toRole);
        if (!toCandidates.any((c) => c.nodeName == nodeName)) {
          toCandidates.add(candidate.copyWith(role: toRole));
        }
        return _withReplacedRoleCandidates(
          _withReplacedRoleCandidates(pool, fromRole, fromCandidates),
          toRole,
          toCandidates,
        );
      }
      return pool;
    });
  }

  @visibleForTesting
  void applyRestoredReliabilityStatsForTest(
      Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>> loaded) {
    _fallbackPool = _fallbackPool.copyWith(
      entryCandidates: _injectStats(_fallbackPool.entryCandidates, loaded[FallbackCandidateRole.entry]),
      relayCandidates: _injectStats(_fallbackPool.relayCandidates, loaded[FallbackCandidateRole.relay]),
      exitCandidates: _injectStats(_fallbackPool.exitCandidates, loaded[FallbackCandidateRole.exit]),
    );
  }

  List<ChainFallbackCandidate> _injectStats(
      List<ChainFallbackCandidate> candidates, Map<String, Map<String, ChainReliabilityStats>>? stats) {
    if (stats == null) return candidates;
    return candidates.map((c) {
      final nodeStats = stats[c.nodeName];
      if (nodeStats != null) {
        return c.copyWith(statsByContext: nodeStats);
      }
      return c;
    }).toList();
  }
}

final chainProxyManager = ChainProxyManager();

