import 'dart:async';
import 'dart:convert';

import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

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
      return _withFakeIpEnabled(ClashConfig.fromJson(clashConfigMap));
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
  ClashConfig _withFakeIpEnabled(ClashConfig config) {
    final dns = config.dns;
    if (dns.fakeIpFilterMode != FilterMode.blacklist) return config;
    if (!dns.fakeIpFilter.contains('*')) return config;
    return config.copyWith(
      dns: dns.copyWith(
        fakeIpFilter: dns.fakeIpFilter.where((e) => e != '*').toList(),
      ),
    );
  }

  Future<Config?> getConfig() async {    final preferences = await sharedPreferencesCompleter.future;
    final configString = preferences?.getString(configKey);
    if (configString == null) return null;
    try {
      final configMap = json.decode(configString);
      final config = Config.compatibleFromJson(configMap);

      if (preferences?.getBool('autoLaunch') != config.appSetting.autoLaunch) {
        await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
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
