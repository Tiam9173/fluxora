import 'package:flutter/material.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';

/// 手动节点管理。
///
/// 只做一件事：粘贴分享链接 → 解析 → 存起来。节点在生成配置时被注入
/// `proxies` 并归到「📌 手动节点」组，所以这里不需要选订阅。
class ManualNodesView extends StatefulWidget {
  const ManualNodesView({super.key});

  @override
  State<ManualNodesView> createState() => _ManualNodesViewState();
}

class _ManualNodesViewState extends State<ManualNodesView> {
  List<Map<String, dynamic>> _nodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nodes = await ManualNodeStore.instance.load();
    if (!mounted) return;
    setState(() {
      _nodes = List.of(nodes);
      _loading = false;
    });
  }

  Future<void> _paste() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴分享链接'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'ss:// vmess:// vless:// trojan:// hysteria2:// tuic://',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(appLocalizations.confirm),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final node = parseShareLink(text);
    if (node == null) {
      if (mounted) {
        context.showSnackBar('链接无法解析，请检查协议或内容');
      }
      return;
    }
    await ManualNodeStore.instance.add(node);
    await _load();
    if (mounted) {
      context.showSnackBar('已添加：${node['name']}');
    }
  }

  Future<void> _remove(int index) async {
    await ManualNodeStore.instance.removeAt(index);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动节点'),
        actions: [
          IconButton(
            tooltip: '粘贴链接',
            onPressed: _paste,
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '还没有手动节点。\n点右上角粘贴分享链接即可添加。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _nodes.length,
                  itemBuilder: (context, index) {
                    final node = _nodes[index];
                    return ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(node['name']?.toString() ?? '未命名'),
                      subtitle: Text(
                        '${node['type']} · ${node['server']}:${node['port']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(index),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _paste,
        icon: const Icon(Icons.add_link),
        label: const Text('粘贴链接'),
      ),
    );
  }
}
