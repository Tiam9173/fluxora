import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/common/node_overrides.dart';

/// 节点详情。
///
/// `Proxy` 只带 name/type/now，真正的配置（服务器、端口、加密方式…）在订阅
/// 的原始配置里，所以这里按名字回查 `proxies` 里的那一条。
///
/// 敏感字段做遮挡：详情是给"看一眼配置"用的，不是密码查看器。
Future<void> showNodeDetailsDialog(
  BuildContext context, {
  required String proxyName,
  String? profileId,
}) async {
  Map<String, dynamic>? raw;
  try {
    if (profileId == null) throw StateError('no active profile');
    final configMap = await globalState.getProfileConfig(profileId);
    final proxies = configMap['proxies'];
    if (proxies is List) {
      for (final item in proxies) {
        if (item is Map && item['name']?.toString() == proxyName) {
          raw = Map<String, dynamic>.from(item);
          break;
        }
      }
    }
  } catch (e) {
    commonPrint.log('showNodeDetailsDialog: $e');
  }

  if (!context.mounted) return;

  // 覆盖状态在打开时取一次：这个面板显示的是**叠加之后**的配置，不看一眼
  // 覆盖层，用户没法知道自己看到的是订阅原样还是自己改过的。
  await NodeOverrideStore.instance.ensureLoaded();
  final hasOverride = profileId != null &&
      NodeOverrideStore.instance.hasOverride(profileId, proxyName);
  final overriddenFields = profileId == null
      ? const <String>{}
      : (NodeOverrideStore.instance.overridesFor(profileId, proxyName)?.keys
              .toSet() ??
          const <String>{});

  await showDialog(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      final entries = <MapEntry<String, String>>[];
      if (raw != null) {
        for (final e in raw.entries) {
          if (e.key == 'name') continue;
          final value = e.value;
          if (value == null) continue;
          final text = value is Map || value is List
              ? value.toString()
              : value.toString();
          entries.add(MapEntry(
            e.key,
            _isSecret(e.key) ? _mask(text) : text,
          ));
        }
      }

      return AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      proxyName,
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasOverride) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已修改',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (raw != null && profileId != null)
              IconButton(
                tooltip: '编辑',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () async {
                  // 闭包里不会保留 null 提升，取一份非空引用。
                  final data = raw;
                  if (data == null) return;
                  final changed = await showNodeEditDialog(
                    ctx,
                    proxyName: proxyName,
                    profileId: profileId,
                    raw: data,
                  );
                  if (changed && ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已保存本地修改，重启内核后生效'),
                      ),
                    );
                  }
                },
              ),
            IconButton(
              tooltip: '复制配置',
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              onPressed: () {
                final text = raw == null
                    ? ''
                    : raw.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: raw == null
                ? Text(
                    '找不到这个节点的原始配置（可能来自策略组或已被订阅更新替换）',
                    style: TextStyle(fontSize: 13, color: colors.outline),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: overriddenFields.contains(e.key)
                                        ? colors.tertiary
                                        : colors.outline,
                                    fontWeight: overriddenFields.contains(e.key)
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  e.value,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        actions: [
          if (hasOverride)
            TextButton(
              onPressed: () async {
                await NodeOverrideStore.instance.clear(profileId, proxyName);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复订阅原始配置，重启内核后生效')),
                );
              },
              child: const Text('恢复原始配置'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

bool _isSecret(String key) {
  final k = key.toLowerCase();
  return k.contains('password') ||
      k.contains('passwd') ||
      k.contains('uuid') ||
      k.contains('token') ||
      k.contains('secret') ||
      k.contains('psk') ||
      k.contains('private-key') ||
      k == 'auth' ||
      k == 'auth-str';
}

/// 只露头尾各两位，中间用点：能认出"是哪个密码"，又不会把整串摆在屏幕上。
String _mask(String value) {
  if (value.length <= 4) return '••••';
  return '${value.substring(0, 2)}••••${value.substring(value.length - 2)}';
}

/// 编辑节点参数。
///
/// 只允许改**标量**字段（字符串 / 数字 / 布尔）：`name` 是配置里所有引用它的
/// 地方（策略组、规则、链路）的锚点，`type` 改了整段参数都得跟着换，两者都不
/// 是"顺手改一下"能承担的。改完写进覆盖层，订阅更新不会冲掉。
Future<bool> showNodeEditDialog(
  BuildContext context, {
  required String proxyName,
  required String profileId,
  required Map<String, dynamic> raw,
}) async {
  final controllers = <String, TextEditingController>{};
  for (final e in raw.entries) {
    if (e.key == 'name' || e.key == 'type') continue;
    final value = e.value;
    if (value is Map || value is List || value == null) continue;
    controllers[e.key] = TextEditingController(text: value.toString());
  }
  if (controllers.isEmpty) return false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('编辑 $proxyName', style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final entry in controllers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: entry.key,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (saved != true) return false;

  final fields = <String, dynamic>{};
  for (final entry in controllers.entries) {
    final original = raw[entry.key];
    final text = entry.value.text;
    if (text == original?.toString()) continue;
    // 端口这类字段在配置里是数字，写成字符串内核会拒绝。
    final asInt = int.tryParse(text);
    fields[entry.key] = (original is int && asInt != null) ? asInt : text;
  }

  if (fields.isEmpty) return false;
  await NodeOverrideStore.instance.setOverride(profileId, proxyName, fields);
  return true;
}
