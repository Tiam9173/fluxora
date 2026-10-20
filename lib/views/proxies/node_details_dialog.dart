import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';

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
              child: Text(
                proxyName,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
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
                                    color: colors.outline,
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
