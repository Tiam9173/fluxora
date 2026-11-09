import 'package:fluxora/widgets/dialog.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
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
  String? protocol,
  int? delay,
}) async {
  final config = _readNodeDetails(proxyName, profileId);
  await showDialog(
    context: context,
    builder: (ctx) => FutureBuilder(
      future: config,
      builder: (ctx, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final overriddenFields = profileId == null || !loaded
            ? const <String>{}
            : NodeOverrideStore.instance
                      .overridesFor(profileId, proxyName)
                      ?.keys
                      .toSet() ??
                  const <String>{};
        final hasOverride = overriddenFields.isNotEmpty;
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final data = snapshot.data;
        final type = protocol ?? data?['type']?.toString();
        final endpoint = [
          if (data?['server'] case final Object server)
            MapEntry('server', server),
          if (data?['port'] case final Object port) MapEntry('port', port),
        ];
        final parameters = [
          if (data != null)
            for (final entry in data.entries)
              if (!const {
                    'name',
                    'type',
                    'server',
                    'port',
                  }.contains(entry.key) &&
                  entry.value != null)
                MapEntry(entry.key, entry.value as Object),
        ];

        Widget field(MapEntry<String, Object> entry, [String? label]) {
          final modified = overriddenFields.contains(entry.key);
          final caption = Text(
            label ?? entry.key,
            style: theme.textTheme.bodySmall?.copyWith(
              color: modified ? colors.tertiary : colors.onSurfaceVariant,
              fontWeight: modified ? FontWeight.w600 : null,
            ),
          );
          final value = SelectableText(
            _displayField(entry.key, entry.value).toString(),
            style: theme.textTheme.bodyMedium,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: FluxoraSpacing.xs),
            child: entry.key == 'server'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      caption,
                      const SizedBox(height: FluxoraSpacing.xs),
                      value,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: caption),
                      const SizedBox(width: FluxoraSpacing.sm),
                      Expanded(flex: 3, child: value),
                    ],
                  ),
          );
        }

        return GlassAlertDialog(
          scrollable: true,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(FluxoraRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FluxoraSpacing.sm),
                  child: Icon(
                    Icons.hub_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: FluxoraSpacing.sm),
              Expanded(
                child: Tooltip(
                  message: proxyName,
                  child: Text(
                    proxyName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type != null || delay != null || hasOverride) ...[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: FluxoraSpacing.sm,
                    runSpacing: FluxoraSpacing.xs,
                    children: [
                      if (type != null)
                        Text(
                          type,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      if (delay != null)
                        Semantics(
                          label: appLocalizations.delay,
                          child: FluxoraLatencyBadge(
                            delay: delay,
                            timeoutLabel: appLocalizations.timeoutLabel,
                          ),
                        ),
                      if (hasOverride)
                        Text(
                          appLocalizations.nodeDetailModified,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.tertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: FluxoraSpacing.sm),
                ],
                if (!loaded)
                  const LinearProgressIndicator()
                else if (data == null)
                  Text(
                    appLocalizations.nodeDetailMissing,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (endpoint.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FluxoraSpacing.sm,
                      vertical: FluxoraSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(FluxoraRadius.card),
                    ),
                    child: Column(
                      children: [
                        for (final entry in endpoint)
                          field(
                            entry,
                            entry.key == 'server'
                                ? appLocalizations.serverAddress
                                : appLocalizations.port,
                          ),
                      ],
                    ),
                  ),
                if (parameters.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(appLocalizations.advancedSettings),
                    children: [for (final entry in parameters) field(entry)],
                  ),
              ],
            ),
          ),
          actions: [
            if (data != null)
              IconButton(
                tooltip: appLocalizations.nodeDetailCopyConfig,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: data.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(appLocalizations.nodeDetailCopied)),
                  );
                },
              ),
            if (hasOverride && profileId != null)
              TextButton(
                onPressed: () async {
                  await NodeOverrideStore.instance.clear(profileId, proxyName);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.nodeDetailRestored),
                    ),
                  );
                },
                child: Text(appLocalizations.nodeDetailRestore),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.nodeDetailClose),
            ),
            if (data != null && profileId != null)
              FilledButton(
                onPressed: () async {
                  final changed = await showNodeEditDialog(
                    ctx,
                    proxyName: proxyName,
                    profileId: profileId,
                    raw: data,
                  );
                  if (!changed || !ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(appLocalizations.nodeDetailSaved)),
                  );
                },
                child: Text(appLocalizations.nodeDetailEdit),
              ),
          ],
        );
      },
    ),
  );
}

Future<Map<String, dynamic>?> _readNodeDetails(
  String proxyName,
  String? profileId,
) async {
  if (profileId == null) return null;
  Map<String, dynamic>? raw;
  try {
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
    // 聚合节点不在当前订阅里：它们带 `[别名] ` 前缀，属于另一个订阅。
    if (raw == null) {
      for (final profile in globalState.config.profiles) {
        if (!profile.joinAggregate) continue;
        final alias = profile.aggregateAlias.isNotEmpty
            ? profile.aggregateAlias
            : (profile.label ?? profile.id);
        final prefix = '[$alias] ';
        if (!proxyName.startsWith(prefix)) continue;
        final original = proxyName.substring(prefix.length);
        final otherConfig = await globalState.getProfileConfig(profile.id);
        final others = otherConfig['proxies'];
        if (others is! List) continue;
        for (final item in others) {
          if (item is Map && item['name']?.toString() == original) {
            raw = Map<String, dynamic>.from(item);
            break;
          }
        }
        if (raw != null) break;
      }
    }
  } catch (e) {
    commonPrint.log('showNodeDetailsDialog: $e');
  }
  await NodeOverrideStore.instance.ensureLoaded();
  return raw;
}

Object? _displayField(String key, Object? value) {
  if (_isSecret(key)) return _mask(value.toString());
  return switch (value) {
    Map() => value.map(
      (key, value) => MapEntry(key, _displayField('$key', value)),
    ),
    List() => [for (final item in value) _displayField('', item)],
    _ => value,
  };
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

/// 只露头尾各两位，中间用星号：能认出"是哪个密码"，又不会把整串摆在屏幕上。
String _mask(String value) {
  if (value.length <= 4) return '****';
  return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
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
    // name 现在允许改：改名会连带更新策略组和规则里的引用，见 NodeOverrideStore。
    if (e.key == 'type') continue;
    final value = e.value;
    if (value is Map || value is List || value == null) continue;
    controllers[e.key] = TextEditingController(text: value.toString());
  }
  if (controllers.isEmpty) return false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => GlassAlertDialog(
      title: Text(appLocalizations.nodeDetailEditTitle(proxyName), style: const TextStyle(fontSize: 15)),
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
          child: Text(appLocalizations.nodeDetailCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(appLocalizations.nodeDetailSave),
        ),
      ],
    ),
  );
  if (saved != true) return false;

  final fields = <String, dynamic>{};
  String? newName;
  for (final entry in controllers.entries) {
    final original = raw[entry.key];
    final text = entry.value.text;
    if (text == original?.toString()) continue;
    if (entry.key == 'name') {
      final trimmed = text.trim();
      if (trimmed.isEmpty || trimmed == proxyName) continue;
      newName = trimmed;
      continue;
    }
    // 端口这类字段在配置里是数字，写成字符串内核会拒绝。
    final asInt = int.tryParse(text);
    fields[entry.key] = (original is int && asInt != null) ? asInt : text;
  }

  if (fields.isEmpty && newName == null) return false;
  if (fields.isNotEmpty) {
    await NodeOverrideStore.instance.setOverride(profileId, proxyName, fields);
  }
  if (newName != null) {
    await NodeOverrideStore.instance.setRename(profileId, proxyName, newName);
  }
  return true;
}
