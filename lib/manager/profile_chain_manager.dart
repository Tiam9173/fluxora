import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ProfileChainConfig {
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
  bool get hasLandingProxy => landingProxy != null && landingProxy!.trim().isNotEmpty;
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
      landingProxy: clearLandingProxy ? null : (landingProxy ?? this.landingProxy),
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

  Future<String> _getConfigFilePath() async {
    final homeDir = await appPath.homeDirPath;
    return p.join(homeDir, 'profile_chains.json');
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
            _chains = jsonMap.map(
              (k, v) => MapEntry(
                k,
                ProfileChainConfig.fromJson(Map<String, dynamic>.from(v as Map)),
              ),
            );
          }
        }
      }
    } catch (e) {
      commonPrint.log('ProfileChainManager: Failed to load profile_chains.json: $e');
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
      final jsonMap = _chains.map((k, v) => MapEntry(k, v.toJson()));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      commonPrint.log('ProfileChainManager: Failed to save config: $e');
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
    _chains[profileId] = updated;
    if (save) {
      await _saveConfig();
    }
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
  void applyToClashConfig(Map<String, dynamic> rawConfig, String profileId) {
    final chain = getChain(profileId);
    if (!chain.hasActiveChains) return;

    final rawProxies = rawConfig['proxies'];
    if (rawProxies is! List || rawProxies.isEmpty) return;

    final List<dynamic> proxiesList = List<dynamic>.from(rawProxies);
    rawConfig['proxies'] = proxiesList;
    final preProxy = chain.preProxy?.trim();
    final landingProxy = chain.landingProxy?.trim();

    // 1. Apply Pre-Proxy (前置代理)
    // All original proxies in this subscription dial through preProxy
    if (chain.hasPreProxy && preProxy != null && preProxy.isNotEmpty) {
      for (final item in proxiesList) {
        if (item is Map) {
          final pName = item['name']?.toString() ?? '';
          if (pName.isNotEmpty && pName != preProxy) {
            item['dialer-proxy'] = preProxy;
          }
        }
      }
    }

    // 2. Apply Landing Proxy (落地代理)
    // Connect original proxies to landing proxy: Local -> Node -> LandingProxy -> Target
    if (chain.hasLandingProxy && landingProxy != null && landingProxy.isNotEmpty) {
      Map<String, dynamic>? landingTemplate;
      for (final item in proxiesList) {
        if (item is Map && item['name'] == landingProxy) {
          landingTemplate = Map<String, dynamic>.from(item);
          break;
        }
      }

      // If landing proxy exists as a node in the list
      if (landingTemplate != null) {
        final originalNodes = List<Map<String, dynamic>>.from(
          proxiesList.where((p) => p is Map && p['name'] != landingProxy).map((p) => Map<String, dynamic>.from(p as Map)),
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
