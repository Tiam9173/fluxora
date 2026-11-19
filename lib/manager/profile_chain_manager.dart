import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/warp_config.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ProfileChainConfig {
  static const warpEntry = 'fluxora:warp:entry';
  static const warpExit = 'fluxora:warp:exit';
  final String profileId;
  final bool enable;
  final String? preProxy; // 前置代理节点名称 (Pre-Proxy)
  final String? landingProxy; // 落地代理节点名称 (Landing Proxy)

  const ProfileChainConfig({
    required this.profileId,
    this.enable = true,
    this.preProxy,
    this.landingProxy,
  });

  bool get hasPreProxy => preProxy != null && preProxy!.trim().isNotEmpty;
  bool get hasLandingProxy =>
      landingProxy != null && landingProxy!.trim().isNotEmpty;
  bool get hasActiveChains => enable && (hasPreProxy || hasLandingProxy);

  ProfileChainConfig copyWith({
    String? profileId,
    bool? enable,
    String? preProxy,
    String? landingProxy,
    bool clearPreProxy = false,
    bool clearLandingProxy = false,
  }) {
    return ProfileChainConfig(
      profileId: profileId ?? this.profileId,
      enable: enable ?? this.enable,
      preProxy: clearPreProxy ? null : (preProxy ?? this.preProxy),
      landingProxy: clearLandingProxy
          ? null
          : (landingProxy ?? this.landingProxy),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'enable': enable,
      if (preProxy != null) 'preProxy': preProxy,
      if (landingProxy != null) 'landingProxy': landingProxy,
    };
  }

  factory ProfileChainConfig.fromJson(Map<String, dynamic> json) {
    return ProfileChainConfig(
      profileId: json['profileId']?.toString() ?? '',
      enable: json['enable'] != false,
      preProxy: json['preProxy']?.toString(),
      landingProxy: json['landingProxy']?.toString(),
    );
  }
}

class ProfileChainManager extends ChangeNotifier {
  static ProfileChainManager? _instance;
  Map<String, ProfileChainConfig> _chains = {};
  bool _initialized = false;

  ProfileChainManager._internal();

  factory ProfileChainManager() {
    _instance ??= ProfileChainManager._internal();
    return _instance!;
  }

  bool get isInitialized => _initialized;

  ProfileChainConfig getChain(String profileId) {
    return _chains[profileId] ?? ProfileChainConfig(profileId: profileId);
  }

  Map<String, dynamic> backupConfig() =>
      _chains.map((id, chain) => MapEntry(id, chain.toJson()));

  Future<void> restoreBackupConfig(
    Map<String, ProfileChainConfig> chains, {
    required bool merge,
  }) async {
    final next = merge ? {..._chains, ...chains} : chains;
    await _saveConfig(next);
    _chains = next;
    notifyListeners();
  }

  /// P2.8-B: test-only seam so persistence tests never touch the real
  /// application data directory. Production never sets it.
  ///
  /// It overrides only the **path** — production always persists through the
  /// shared [AtomicConfigStorage]; there is no test-only save implementation.
  @visibleForTesting
  static String? configFilePathOverride;

  Future<String> _getConfigFilePath() async {
    final override = configFilePathOverride;
    if (override != null && override.isNotEmpty) return override;
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'profile_chains.json');
  }

  /// P2.8-B: persists [chains] through the shared [AtomicConfigStorage]
  /// (tmp → validate → `.bak` → atomic rename), then **rethrows** on failure.
  ///
  /// Before P2.8-B this was a bare `File.writeAsString` inside a
  /// `catch → log` block, so a failed write still returned normally and the
  /// caller believed the change had landed. The failure is now logged **and**
  /// propagated, and the user is told the change did not take effect.
  Future<void> _saveConfig(Map<String, ProfileChainConfig> chains) async {
    try {
      final filePath = await _getConfigFilePath();
      await AtomicConfigStorage(
        filePath,
      ).save(chains.map((k, v) => MapEntry(k, v.toJson())));
    } catch (e) {
      commonPrint.log('ProfileChainManager: Failed to save config: $e');
      // Best-effort user notice — it must NEVER mask the real failure.
      // `globalState.showNotifier` goes through `GlobalKey.currentContext`,
      // which itself throws when no widget binding is initialized (unit tests,
      // headless startup), so it is contained here rather than left to replace
      // the save error with a binding error.
      try {
        globalState.showNotifier('链路配置保存失败，更改未生效');
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final filePath = await _getConfigFilePath();
      // P2.8-B: read through the shared `AtomicConfigStorage`, so a crash
      // during a previous save recovers from `.bak` / an orphan `.tmp` instead
      // of silently starting from an empty map.
      final jsonMap = await AtomicConfigStorage(filePath).load();
      if (jsonMap != null) {
        _chains = jsonMap.map(
          (k, v) => MapEntry(
            k,
            ProfileChainConfig.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      }
    } catch (e) {
      commonPrint.log(
        'ProfileChainManager: Failed to load profile_chains.json: $e',
      );
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> updateChain(
    String profileId,
    ProfileChainConfig Function(ProfileChainConfig current) updater, {
    bool reloadCore = true,
    bool save = true,
  }) async {
    final current = getChain(profileId);
    final updated = updater(current);
    // P2.8-B: persist BEFORE committing to memory. The old order mutated
    // `_chains` first and swallowed the write failure, so a failed save left
    // memory/UI showing a change the disk never received ("false success").
    // Saving first means a failure leaves the in-memory state untouched, so
    // there is nothing to roll back.
    final next = {..._chains, profileId: updated};
    if (save) {
      await _saveConfig(next);
    }
    _chains = next;
    notifyListeners();

    if (reloadCore) {
      try {
        final currentProfileId = globalState.config.currentProfileId;
        if (currentProfileId == profileId) {
          globalState.appController.applyProfileDebounce(silence: true);
        }
      } catch (e) {
        commonPrint.log('ProfileChainManager: Error applying core config: $e');
      }
    }
  }

  /// Injects pre-proxy and landing-proxy chain topology into the Clash configuration map at runtime.
  /// Called in `state.dart` within `patchRawConfig`.
  void applyToClashConfig(
    Map<String, dynamic> rawConfig,
    String profileId, {
    WarpConfig? warp,
    Map<String, String> selectedMap = const {},
    ChainPolicyAliases? policyAliases,
  }) {
    final chain = getChain(profileId);
    if (!chain.hasActiveChains) return;

    final rawProxies = rawConfig['proxies'];
    if (rawProxies is! List || rawProxies.isEmpty) return;

    final List<dynamic> proxiesList = List<dynamic>.from(rawProxies);
    rawConfig['proxies'] = proxiesList;
    var preProxy = chain.preProxy?.trim();
    var landingProxy = chain.landingProxy?.trim();
    for (final slot in [
      ProfileChainConfig.warpEntry,
      ProfileChainConfig.warpExit,
    ]) {
      if (preProxy != slot && landingProxy != slot) continue;
      if (warp == null || warp.privateKey.trim().isEmpty) {
        throw const FormatException('请先配置 WARP 密钥');
      }
      final name = slot == ProfileChainConfig.warpEntry
          ? '🛡️ WARP 入口'
          : '🛡️ WARP 落地';
      if (proxiesList.any((p) => p is Map && p['name'] == name)) {
        throw FormatException('代理名称冲突：$name');
      }
      proxiesList.add(warp.toMihomoProxyMap('')..['name'] = name);
      if (preProxy == slot) preProxy = name;
      if (landingProxy == slot) landingProxy = name;
    }

    // 1. Apply Pre-Proxy (前置代理)
    // All original proxies in this subscription dial through preProxy
    if (chain.hasPreProxy && preProxy != null && preProxy.isNotEmpty) {
      // The saved name is a snapshot of a subscription the user may have
      // replaced since. Writing a `dialer-proxy` that names a node this
      // profile does not contain makes mihomo fail every connection through
      // it — the symptom is a wall of
      // `proxyName[🇺🇸 美国05 |公益|1倍] not found` and a WARP that only times
      // out. Skip the hop instead of poisoning the whole config; the chain is
      // re-picked from the UI when the user notices.
      final preProxyExists =
          proxiesList.any(
            (p) => p is Map && p['name']?.toString() == preProxy,
          ) ||
          ((rawConfig['proxy-groups'] as List?) ?? const []).any(
            (g) => g is Map && g['name'] == preProxy,
          );
      if (preProxyExists) {
        final upstream = proxyDependencyClosure(
          [preProxy],
          (rawConfig['proxy-groups'] as List?) ?? const [],
          proxiesList,
          (rawConfig['proxy-providers'] as Map?) ?? const {},
        );
        final preIsGroup = ((rawConfig['proxy-groups'] as List?) ?? const [])
            .any((g) => g is Map && g['name'] == preProxy);
        if (preIsGroup &&
            !proxiesList.whereType<Map>().any(
              (p) => !upstream.contains(p['name']),
            )) {
          throw const FormatException('前置策略组覆盖所有节点，请选择独立入口组或使用链式代理入口');
        }
        for (final item in proxiesList) {
          if (item is Map) {
            final pName = item['name']?.toString() ?? '';
            if (pName.isNotEmpty && !upstream.contains(pName)) {
              item['dialer-proxy'] = preProxy;
            }
          }
        }
      } else {
        commonPrint.log(
          'ProfileChainManager: preProxy "$preProxy" is not in this profile, '
          'skipping the hop instead of emitting a dangling dialer-proxy',
        );
      }
    }

    // 2. Apply Landing Proxy (落地代理)
    // Connect original proxies to landing proxy: Local -> Node -> LandingProxy -> Target
    if (chain.hasLandingProxy &&
        landingProxy != null &&
        landingProxy.isNotEmpty) {
      Map<String, dynamic>? landingTemplate;
      for (final item in proxiesList) {
        if (item is Map && item['name'] == landingProxy) {
          landingTemplate = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (landingTemplate == null &&
          ((rawConfig['proxy-groups'] as List?) ?? const []).any(
            (g) => g is Map && g['name'] == landingProxy,
          )) {
        final originals = proxiesList
            .whereType<Map>()
            .map((p) => p['name'])
            .whereType<String>()
            .toList();
        final sourceGroups = List<dynamic>.from(
          (rawConfig['proxy-groups'] as List?) ?? const [],
        );
        final dependencies = proxyDependencyClosure(
          [landingProxy],
          sourceGroups,
          proxiesList,
          (rawConfig['proxy-providers'] as Map?) ?? const {},
        );
        final outputs = <String>[];
        final candidates = originals
            .where((name) => !dependencies.contains(name))
            .toList();
        var landingCount = originals.where(dependencies.contains).length;
        final providers = (rawConfig['proxy-providers'] as Map?) ?? const {};
        for (final group in sourceGroups.whereType<Map>().where(
          (g) => dependencies.contains(g['name']),
        )) {
          for (final name in (group['use'] as List?) ?? const []) {
            final provider = providers[name];
            if (provider is! Map || provider['payload'] is! List) {
              throw const FormatException('动态节点集合暂不能批量作为后置，请选择具体节点');
            }
            landingCount += (provider['payload'] as List).length;
          }
        }
        if (candidates.isEmpty) {
          throw const FormatException('后置策略组与入口节点重合，请选择独立后置组或单个节点');
        }
        if (candidates.length * landingCount > 10000) {
          throw const FormatException('后置策略组会生成过多链路，请缩小策略组或选择单个节点');
        }
        for (final node in candidates) {
          outputs.add(
            chainProxyWithDialer(
              rawConfig,
              name: landingProxy,
              dialer: node,
              outputName: '$node ➜ $landingProxy',
              selectedMap: selectedMap,
              policyAliases: policyAliases,
            ),
          );
        }
        for (final group in sourceGroups.whereType<Map>()) {
          if (!dependencies.contains(group['name']) &&
              group['proxies'] is List) {
            group['proxies'] = [...outputs, ...group['proxies'] as List];
          }
        }
      }
      // If landing proxy exists as a node in the list
      if (landingTemplate != null) {
        final originalNodes = List<Map<String, dynamic>>.from(
          proxiesList
              .where((p) => p is Map && p['name'] != landingProxy)
              .map((p) => Map<String, dynamic>.from(p as Map)),
        );

        final List<String> chainedNodeNames = [];
        for (final node in originalNodes) {
          final nodeName = node['name']?.toString() ?? '';
          if (nodeName.isEmpty) continue;

          final chainedName = '$nodeName ➜ $landingProxy';
          chainedNodeNames.add(chainedName);

          final chainedProxy = Map<String, dynamic>.from(landingTemplate);
          chainedProxy['name'] = chainedName;
          chainedProxy['dialer-proxy'] = nodeName;

          // Replace or add chained proxy
          proxiesList.removeWhere((p) => p is Map && p['name'] == chainedName);
          proxiesList.add(chainedProxy);
        }

        // Update proxy-groups to include or replace with chained nodes
        if (rawConfig['proxy-groups'] is List) {
          final groups = rawConfig['proxy-groups'] as List;
          for (final group in groups) {
            if (group is Map && group['proxies'] is List) {
              final pList = List<dynamic>.from(group['proxies'] as List);
              for (final chainedName in chainedNodeNames) {
                if (!pList.contains(chainedName)) {
                  pList.insert(0, chainedName);
                }
              }
              group['proxies'] = pList;
            }
          }
        }
      }
    }
  }
}

final profileChainManager = ProfileChainManager();
