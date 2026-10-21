import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

/// item 6 — map one Go-side `logEntry` to a Fluxora [Log].
///
/// The Go bridge stamps every history entry with `Time` (ms since epoch),
/// because mihomo's own `log.Event` carries no timestamp. `Log.fromJson` cannot
/// be used here: its `dateTime` converter ignores the input and returns
/// "now" (`_logDateTime` in models/common.dart), which would make the whole
/// history look like it just happened. Top-level so `Isolate.run` can capture
/// it.
Log _logFromHistoryEntry(Map<String, Object?> entry) {
  final timeMs = entry['Time'];
  final dateTime = timeMs is int
      ? DateTime.fromMillisecondsSinceEpoch(timeMs).showFull
      : DateTime.now().showFull;
  return Log(
    logLevel: _logLevelFromName(entry['LogLevel']),
    payload: entry['Payload']?.toString() ?? '',
    dateTime: dateTime,
  );
}

LogLevel _logLevelFromName(Object? raw) => switch (raw) {
  'debug' || 'DEBUG' => LogLevel.debug,
  'info' || 'INFO' => LogLevel.info,
  'warning' || 'WARNING' => LogLevel.warning,
  'error' || 'ERROR' => LogLevel.error,
  'silent' || 'SILENT' => LogLevel.silent,
  _ => LogLevel.error,
};

/// item 6 ⑤ — fire-and-forget wrapper for core calls whose result nobody
/// awaits (ported from upstream v1.19.4 "Improve core stability").
///
/// The core answers FFI calls with a rejected future when it is stopped, torn
/// down, or not up yet — which is exactly when the UI fires these ("clear
/// logs" right after stopping the VPN, a connection closing during a core
/// restart). An un-awaited rejection surfaces as an uncaught async error, so
/// the failure is logged and swallowed here instead: the caller asked for a
/// best-effort action, not a result.
void clashCoreForget(FutureOr<Object?> request, String name) {
  Future.value(request).then<void>(
    (_) {},
    onError: (Object e) => commonPrint.log('$name ignored: $e'),
  );
}

class ClashCore {
  static ClashCore? _instance;
  late ClashHandlerInterface clashInterface;

  ClashCore._internal() {
    if (system.isAndroid) {
      clashInterface = clashLib!;
    } else {
      clashInterface = clashService!;
    }
  }

  factory ClashCore() {
    _instance ??= ClashCore._internal();
    return _instance!;
  }

  Future<bool> preload() {
    return clashInterface.preload();
  }

  static Future<void> initGeo() async {
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    if (!await homeDir.exists()) {
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [mmdbFileName, geoSiteFileName, asnFileName, bundleMRSFileName];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(join(homePath, geoFileName));
        if (await geoFile.exists()) continue;
        final data = await rootBundle.load('assets/data/$geoFileName');
        await geoFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
    } catch (e) {
      exit(0);
    }
  }

  Future<bool> init() async {
    await initGeo();
    if (globalState.config.appSetting.openLogs) {
      clashCore.startLog();
    } else {
      clashCore.stopLog();
    }
    final homeDirPath = await appPath.homeDirPath;
    return await clashInterface.init(
      InitParams(homeDir: homeDirPath, version: globalState.appState.version),
    );
  }

  Future<bool> setState(CoreState state) async {
    return await clashInterface.setState(state);
  }

  Future<void> shutdown() async {
    await clashInterface.shutdown();
  }

  FutureOr<bool> get isInit => clashInterface.isInit;

  bool get hasLiveProcess => clashInterface.hasLiveProcess;

  FutureOr<String> validateConfig(String data, {String? ageSecretKey}) {
    return clashInterface.validateConfig(data, ageSecretKey: ageSecretKey);
  }

  FutureOr<String> decryptAgeConfig(String data, String ageSecretKey) {
    return clashInterface.decryptAgeConfig(data, ageSecretKey);
  }

  Future<String> updateConfig(UpdateParams updateParams) async {
    return await clashInterface.updateConfig(updateParams);
  }

  Future<String> setupConfig(SetupParams setupParams) async {
    return await clashInterface.setupConfig(setupParams);
  }

  Future<List<Group>> getProxiesGroups({
    List<ExternalProvider>? preloadedProviders,
  }) async {
    final proxies = await clashInterface.getProxies();
    if (proxies.isEmpty) return [];

    final providers = preloadedProviders ?? await getExternalProviders();

    return Isolate.run<List<Group>>(() {
      final allProxies = Map<String, dynamic>.from(proxies);
      for (final provider in providers) {
        if (provider.proxies != null) {
          for (final proxy in provider.proxies!) {
            if (proxy is Map) {
              final proxyMap = Map<String, dynamic>.from(proxy);
              final name = proxyMap['name'];
              if (name != null) {
                allProxies[name] = proxyMap;
                final suffix = '[${provider.name}]';
                if (!name.endsWith(suffix)) {
                  allProxies['$name$suffix'] = proxyMap;
                }
              }
            }
          }
        }
      }

      final globalProxy = allProxies[UsedProxy.GLOBAL.name];
      if (globalProxy == null) return [];

      final allList = globalProxy['all'] as List?;
      if (allList == null) return [];

      final groupNames = [
        UsedProxy.GLOBAL.name,
        ...allList.where((e) {
          final proxy = allProxies[e];
          if (proxy is Map) {
            return GroupTypeExtension.valueList.contains(proxy['type']);
          }
          return false;
        }),
      ];
      final groupsRaw = groupNames.map((groupName) {
        final proxyData = allProxies[groupName] as Map?;
        if (proxyData == null) return null;
        final group = Map<String, dynamic>.from(
          proxyData.cast<String, dynamic>(),
        );
        group['all'] = ((group['all'] ?? []) as List)
            .map((name) {
              final p = allProxies[name];
              return p is Map ? Map<String, dynamic>.from(p) : null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
        return group;
      }).whereType<Map<String, dynamic>>().toList();
      return groupsRaw.map((e) => Group.fromJson(e)).toList();
    });
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    return await clashInterface.changeProxy(changeProxyParams);
  }

  Future<Mode> getMode() async {
    final modeStr = await clashInterface.getMode();
    return Mode.values.firstWhere(
      (m) => m.name == modeStr.toLowerCase(),
      orElse: () => Mode.rule,
    );
  }

  Future<List<TrackerInfo>> getConnections() async {
    final res = await clashInterface.getConnections();
    if (res.isEmpty) {
      return [];
    }
    try {
      final connectionsData = json.decode(res) as Map;
      final connectionsRaw = connectionsData['connections'] as List? ?? [];
      return connectionsRaw.map((e) => TrackerInfo.fromJson(e)).toList();
    } catch (e) {
      commonPrint.log('Failed to parse connections: $e');
      return [];
    }
  }

  void closeConnection(String id) {
    clashCoreForget(clashInterface.closeConnection(id), 'closeConnection');
  }

  Future<void> closeConnections() async {
    await clashInterface.closeConnections();
  }

  void resetConnections() {
    clashCoreForget(clashInterface.resetConnections(), 'resetConnections');
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString = await clashInterface
        .getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    try {
      return await Isolate.run<List<ExternalProvider>>(() {
        final externalProviders =
            (json.decode(externalProvidersRawString) as List<dynamic>)
                .map((item) => ExternalProvider.fromJson(item))
                .toList();
        return externalProviders;
      });
    } catch (e) {
      commonPrint.log('Failed to parse external providers: $e');
      return [];
    }
  }

  Future<ExternalProvider?> getExternalProvider(
    String externalProviderName,
  ) async {
    final externalProvidersRawString = await clashInterface.getExternalProvider(
      externalProviderName,
    );
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    try {
      return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
    } catch (e) {
      commonPrint.log('Failed to parse external provider: $e');
      return null;
    }
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) {
    return clashInterface.updateGeoData(params);
  }

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    return clashInterface.sideLoadExternalProvider(
      providerName: providerName,
      data: data,
    );
  }

  Future<String> updateExternalProvider({required String providerName}) async {
    return clashInterface.updateExternalProvider(providerName);
  }

  Future<String> parseExternalProviderContent(String providerName) {
    return clashInterface.parseExternalProviderContent(providerName);
  }

  Future<void> startListener() async {
    await clashInterface.startListener();
  }

  Future<void> stopListener() async {
    await clashInterface.stopListener();
  }

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await clashInterface.asyncTestDelay(url, proxyName);
    if (data.isEmpty) {
      throw Exception('Empty delay response');
    }
    try {
      return Delay.fromJson(json.decode(data));
    } catch (e) {
      commonPrint.log('Failed to parse delay: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getConfig(String id, {String? ageSecretKey}) async {
    final profilePath = await appPath.getProfilePath(id);
    final res = await clashInterface.getConfig(profilePath, ageSecretKey: ageSecretKey);
    if (res.isSuccess) {
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{};
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic() async {
    final trafficString = await clashInterface.getTraffic();
    if (trafficString.isEmpty) {
      return Traffic();
    }
    try {
      return Traffic.fromMap(json.decode(trafficString));
    } catch (e) {
      commonPrint.log('Failed to parse traffic: $e');
      return Traffic();
    }
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await clashInterface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(ip: ip, countryCode: countryCode);
  }

  /// Consecutive empty reads, used to log the failure once instead of every
  /// second. A traffic counter that never moves is otherwise indistinguishable
  /// from a UI bug: the panel just shows 0.00 forever.
  static int _emptyTrafficReads = 0;
  static bool _loggedNonZeroTraffic = false;

  Future<Traffic> getTotalTraffic() async {
    final totalTrafficString = await clashInterface.getTotalTraffic();
    if (totalTrafficString.isEmpty) {
      _emptyTrafficReads++;
      if (_emptyTrafficReads == 1 || _emptyTrafficReads % 60 == 0) {
        commonPrint.log(
          'getTotalTraffic: core returned an empty string '
          '($_emptyTrafficReads consecutive reads) — the counter is not '
          'reaching the UI',
        );
      }
      return Traffic();
    }
    _emptyTrafficReads = 0;
    try {
      final traffic = Traffic.fromMap(json.decode(totalTrafficString));
      if (!_loggedNonZeroTraffic &&
          (traffic.up.value > 0 || traffic.down.value > 0)) {
        _loggedNonZeroTraffic = true;
        commonPrint.log(
          'getTotalTraffic: first non-zero reading $totalTrafficString',
        );
      }
      return traffic;
    } catch (e) {
      commonPrint.log('Failed to parse total traffic: $e');
      return Traffic();
    }
  }

  Future<int> getMemory() async {
    final value = await clashInterface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  Future<CoreStatus?> getCoreStatus() async {
    final value = await clashInterface.getCoreStatus();
    if (value.isEmpty) {
      return null;
    }
    final decoded = json.decode(value);
    if (decoded is! Map) {
      return null;
    }
    return CoreStatus.fromJson(Map<String, dynamic>.from(decoded));
  }

  void resetTraffic() {
    clashInterface.resetTraffic();
  }

  void startLog() {
    clashInterface.startLog();
  }

  void stopLog() {
    clashInterface.stopLog();
  }

  /// item 6 — the buffered log history, so a page opened after the fact can
  /// catch up on what the core already said.
  ///
  /// Decoded inside `Isolate.run` because a long history turns into a large
  /// JSON blob and this runs on the UI isolate's caller. Any failure degrades to
  /// an empty list rather than throwing — the log page must keep working.
  Future<List<Log>> getLogs() async {
    final res = await clashInterface.getLogs();
    if (res.isEmpty) {
      return [];
    }
    try {
      return await Isolate.run<List<Log>>(() {
        final logsRaw = json.decode(res) as List? ?? [];
        return logsRaw
            .map((e) => _logFromHistoryEntry(e as Map<String, Object?>))
            .toList();
      });
    } catch (e) {
      commonPrint.log('Failed to parse logs: $e');
      return [];
    }
  }

  void clearLogs() {
    clashCoreForget(clashInterface.clearLogs(), 'clearLogs');
  }

  Future<void> requestGc({bool forceFreeOSMemory = false}) async {
    await clashInterface.forceGc(forceFreeOSMemory: forceFreeOSMemory);
  }

  Future<void> flushFakeIP() async {
    await clashInterface.flushFakeIP();
  }

  Future<void> flushDnsCache() async {
    await clashInterface.flushDnsCache();
  }

  Future<Map<String, String>> generateAgeKeyPair() {
    return clashInterface.generateAgeKeyPair();
  }

  Future<Result<String>> convertAgeSecretKeyToPublicKey(String secretKey) {
    return clashInterface.convertAgeSecretKeyToPublicKey(secretKey);
  }

  Future<void> destroy() async {
    await clashInterface.destroy();
  }
}

final clashCore = ClashCore();