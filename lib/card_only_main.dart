import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知栏「切换」卡片专用的 Dart 入口。
///
/// 跑在**独立引擎**里（`CardActivity` 用 `DartEntrypoint("cardMain")` 启动），
/// 不经过主 App 的 `main()`：卡片只显示一屏内容，没必要把 controller、内核
/// 初始化、主界面路由全部跑一遍。
///
/// 也不能复用主引擎 —— 一个 `FlutterEngine` 同时只能服务一个 Activity，共用会
/// 让主界面回来时黑屏；而且渲染表面的透明性在第一个窗口创建时就定死了，共用
/// 必然不透明。
///
/// 数据不依赖 `globalState`：直接按配置里的 `external-controller` 问内核要。
/// 内核跑在常驻 service 里，和哪个 Flutter 引擎在跑无关。
@pragma('vm:entry-point')
void cardMain() {
  runApp(const CardOnlyApp());
}

class CardOnlyApp extends StatelessWidget {
  const CardOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // MaterialApp 自己会画背景，不设透明的话卡片四周永远是黑的。
      color: Colors.transparent,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const CardOnlyScaffold(),
    );
  }
}

class _Node {
  const _Node(this.group, this.name, this.selected);

  final String group;
  final String name;
  final bool selected;
}

class CardOnlyScaffold extends StatefulWidget {
  const CardOnlyScaffold({super.key});

  @override
  State<CardOnlyScaffold> createState() => _CardOnlyScaffoldState();
}

class _CardOnlyScaffoldState extends State<CardOnlyScaffold> {
  final List<_Node> _nodes = [];
  bool _loading = true;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _close() async {
    try {
      await const MethodChannel('card').invokeMethod('close');
    } catch (_) {
      SystemNavigator.pop();
    }
  }

  /// 从配置里拿内核的 external-controller 地址和密钥。
  Future<(String, String)?> _endpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('config');
    if (raw == null || raw.isEmpty) return null;
    final map = json.decode(raw);
    if (map is! Map) return null;
    final controller = map['external-controller']?.toString();
    if (controller == null || controller.isEmpty) return null;
    final host = controller.contains(':') ? controller : '$controller:9090';
    return (host, map['secret']?.toString() ?? '');
  }

  Dio _dio(String host, String secret) => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          headers: secret.isEmpty ? null : {'Authorization': 'Bearer $secret'},
        ),
      );

  Future<void> _load() async {
    try {
      final endpoint = await _endpoint();
      if (endpoint == null) {
        setState(() {
          _error = '找不到内核地址';
          _loading = false;
        });
        return;
      }
      final (host, secret) = endpoint;
      final res =
          await _dio(host, secret).get<Map<String, dynamic>>('http://$host/proxies');
      final proxies = res.data?['proxies'];
      if (proxies is! Map) throw '内核返回格式不对';

      final collected = <_Node>[];
      for (final entry in proxies.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        if (value['type'] != 'Selector') continue;
        final all = value['all'];
        if (all is! List) continue;
        final now = value['now']?.toString();
        for (final name in all) {
          collected.add(
            _Node(entry.key, name.toString(), name.toString() == now),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _nodes
          ..clear()
          ..addAll(collected);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '读取节点失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _select(_Node node) async {
    if (_busy != null) return;
    setState(() => _busy = node.name);
    try {
      final endpoint = await _endpoint();
      if (endpoint == null) return;
      final (host, secret) = endpoint;
      await _dio(host, secret).put(
        'http://$host/proxies/${Uri.encodeComponent(node.group)}',
        data: {'name': node.name},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = null;
          _error = '切换失败：$e';
        });
      }
      return;
    }
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 340,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '切换节点',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _close,
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _error!,
                          style: TextStyle(fontSize: 12, color: colors.error),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _nodes.length,
                          itemBuilder: (_, i) {
                            final node = _nodes[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                node.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: _busy == node.name
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  : (node.selected
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                          color: colors.primary,
                                        )
                                      : null),
                              onTap: () => _select(node),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
