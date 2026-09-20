import 'dart:convert';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// FlClash 数据库提取工具
class FlClashDatabaseExtractor {
  /// 从 FlClash 数据库文件提取 Profiles
  static Future<List<Profile>> extractProfiles(String dbPath) async {
    Database? db;
    try {
      if (system.isDesktop) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      db = await openDatabase(dbPath, readOnly: true, singleInstance: false);
      final List<Map<String, dynamic>> results = await db.query('profiles');

      final profiles = <Profile>[];
      for (final row in results) {
        try {
          profiles.add(_convertRowToProfile(row));
        } catch (e) {
          commonPrint.log('Failed to convert profile row: $e, row=$row');
        }
      }
      return profiles;
    } catch (e) {
      commonPrint.log('Failed to extract profiles from database: $e');
      rethrow;
    } finally {
      await db?.close();
    }
  }

  /// 将数据库行转换为 Profile 对象
  static Profile _convertRowToProfile(Map<String, dynamic> row) {
    final id = row['id'].toString();
    final label = (row['label'] as String?) ?? 'Subscription $id';
    final url = (row['url'] as String?) ?? '';
    final currentGroupName = row['current_group_name'] as String?;

    // 解析更新时间 (Drift 默认存储为秒)
    final lastUpdateDateSecs = row['last_update_date'];
    DateTime? lastUpdateDate;
    if (lastUpdateDateSecs != null) {
      final secs = lastUpdateDateSecs is int
          ? lastUpdateDateSecs
          : int.tryParse(lastUpdateDateSecs.toString());
      if (secs != null) {
        lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
      }
    }

    final autoUpdateRaw = row['auto_update'];
    final autoUpdate = autoUpdateRaw == 1 || autoUpdateRaw == true;
    final autoUpdateDurationMillis = (row['auto_update_duration_millis'] as int?) ?? 0;
    final autoUpdateDuration = Duration(milliseconds: autoUpdateDurationMillis);

    final subscriptionInfo = _parseSubscriptionInfo(row['subscription_info']);
    final selectedMap = _parseSelectedMap(row['selected_map']);
    final unfoldSet = _parseUnfoldSet(row['unfold_set']);

    final overwriteTypeStr = row['overwrite_type'] as String?;
    final overwriteType = _parseOverwriteType(overwriteTypeStr);

    commonPrint.log('Converted profile: id=$id, label=$label');

    return Profile(
      id: id,
      label: label,
      url: url,
      currentGroupName: currentGroupName,
      lastUpdateDate: lastUpdateDate,
      autoUpdate: autoUpdate,
      autoUpdateDuration: autoUpdateDuration,
      subscriptionInfo: subscriptionInfo,
      selectedMap: selectedMap,
      unfoldSet: unfoldSet,
      overrideData: OverrideData(
        enable: false,
        rule: OverrideRule(type: overwriteType),
      ),
    );
  }

  static SubscriptionInfo? _parseSubscriptionInfo(dynamic jsonStr) {
    if (jsonStr == null || jsonStr is! String || jsonStr.isEmpty) return null;
    try {
      return SubscriptionInfo.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      commonPrint.log('Failed to parse subscription_info: $e');
      return null;
    }
  }

  static Map<String, String> _parseSelectedMap(dynamic jsonStr) {
    if (jsonStr == null || jsonStr is! String || jsonStr.isEmpty) return {};
    try {
      return Map<String, String>.from(json.decode(jsonStr) as Map);
    } catch (e) {
      commonPrint.log('Failed to parse selected_map: $e');
      return {};
    }
  }

  static Set<String> _parseUnfoldSet(dynamic jsonStr) {
    if (jsonStr == null || jsonStr is! String || jsonStr.isEmpty) return {};
    try {
      return Set<String>.from(json.decode(jsonStr) as List);
    } catch (e) {
      commonPrint.log('Failed to parse unfold_set: $e');
      return {};
    }
  }

  static OverrideRuleType _parseOverwriteType(String? typeStr) {
    return typeStr == 'script' ? OverrideRuleType.override : OverrideRuleType.added;
  }
}
