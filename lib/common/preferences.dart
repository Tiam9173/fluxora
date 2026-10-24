import 'dart:async';
import 'dart:convert';

import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';
import 'system.dart';

import 'print.dart';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async => await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final clashConfigString = preferences?.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    try {
      final clashConfigMap = json.decode(clashConfigString);
      return _normalizeLegacyDefaults(ClashConfig.fromJson(clashConfigMap));
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse clash config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  /// 老版本的默认值把 `*` 放进了 fake-ip 黑名单。
  ///
  /// 配合 `fake-ip-filter-mode: blacklist`，那条通配符会把**所有**域名排除在
  /// fake-ip 之外，fake-ip 等于没开：每个域名都要先做一次真实 DNS 才建连。
  /// 访问境外站点时，这一步既慢又容易被污染。
  ///
  /// 读取时摘掉它，其余例外（局域网、国内站点、NTP）保持原样——那几条是
  /// fake-ip 真正会出问题的地方，必须留着。
  /// 修正老版本的默认值。
  ///
  /// 两处都是"配了就等于没配"的坑：
  ///
  /// 1. `fake-ip-filter` 首项曾是 `*`。配合 `blacklist` 模式，它把**所有**域名
  ///    排除在 fake-ip 之外，fake-ip 等于没开——每个域名都要先做一次真实 DNS
  ///    才建连，访问境外站点时既慢又容易被污染。
  /// 2. `nameserver` 曾是 `1.1.1.1`（明文 UDP）。国内访问它常被绕远或污染，
  ///    一次解析可能 200ms 以上。换成国内解析，通常 20–50ms。
  ///
  /// 只改"正好等于旧默认值"的配置，用户自己改过的一律不动。
  ClashConfig _normalizeLegacyDefaults(ClashConfig config) {
    var result = config;
    final dns = result.dns;

    if (dns.fakeIpFilterMode == FilterMode.blacklist &&
        dns.fakeIpFilter.contains('*')) {
      result = result.copyWith(
        dns: result.dns.copyWith(
          fakeIpFilter:
              result.dns.fakeIpFilter.where((e) => e != '*').toList(),
        ),
      );
    }

    final isLegacyNameserver =
        result.dns.nameserver.length == 1 &&
        result.dns.nameserver.first == '1.1.1.1';
    if (isLegacyNameserver) {
      result = result.copyWith(
        dns: result.dns.copyWith(
          nameserver: const ['223.5.5.5', '119.29.29.29'],
        ),
      );
    }

    return result;
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final configString = preferences?.getString(configKey);
    if (configString == null) return null;
    try {
      final configMap = json.decode(configString);
      var config = Config.compatibleFromJson(configMap);

      if (preferences?.getBool('autoLaunch') != config.appSetting.autoLaunch) {
        await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
      }

      // 静默启动一次性迁移：这个开关在 Android 上从未生效过（旧实现只管
      // 桌面窗口显隐），所以存量值没有任何用户意图可言。磁贴启动改成走
      // 透明中转 Activity 后它才真正起作用，按用户要求默认打开——只做
      // 一次，之后用户自己关掉就保持关闭。
      if (system.isAndroid &&
          preferences?.getBool('silentLaunchAndroidMigrated') != true) {
        await preferences?.setBool('silentLaunchAndroidMigrated', true);
        if (!config.appSetting.silentLaunch) {
          config = config.copyWith(
            appSetting: config.appSetting.copyWith(silentLaunch: true),
          );
          await saveConfig(config);
        }
      }

      return config;
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    
    await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
    
    return await preferences?.setString(configKey, json.encode(config)) ??
        false;
  }

  @visibleForTesting
  static const pendingAutoDelayTestAtKey = 'pendingAutoDelayTestAt';

  /// Arms the auto-delay test for a headless service start. The UI isolate
  /// consumes it when it next becomes visible, where the result is observable.
  Future<void> markPendingAutoDelayTest() async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt(
      pendingAutoDelayTestAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> hasPendingAutoDelayTest() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt(pendingAutoDelayTestAtKey) != null;
  }

  /// Consumes the pending marker exactly once. A stale marker is discarded so
  /// opening the app long after a tile start does not trigger a surprise test.
  Future<bool> consumePendingAutoDelayTest({
    Duration maxAge = const Duration(minutes: 10),
    DateTime? now,
  }) async {
    final preferences = await sharedPreferencesCompleter.future;
    final at = preferences?.getInt(pendingAutoDelayTestAtKey);
    await preferences?.remove(pendingAutoDelayTestAtKey);
    if (at == null) return false;

    final age = (now ?? DateTime.now()).difference(
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    return !age.isNegative && age <= maxAge;
  }

  Future<void> clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    preferences?.remove(clashConfigKey);
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
