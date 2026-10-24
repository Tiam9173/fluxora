import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/models/node_share_link.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:fluxora/views/proxies/node_details_dialog.dart';

class ProfileNodesView extends StatefulWidget {
  final Profile profile;

  const ProfileNodesView({super.key, required this.profile});

  @override
  State<ProfileNodesView> createState() => _ProfileNodesViewState();
}

enum _NodeSortMode { original, name, protocol, delay }

class _ProfileNodesViewState extends State<ProfileNodesView> {
  late Profile _profile;
  List<Map<String, dynamic>> _proxies = [];

  /// 批量导出：进入选择模式后按节点名记录勾选项。
  bool _exportMode = false;
  final Set<String> _selected = {};
  bool _isLoading = true;
  final Map<String, int?> _delays = {};
  _NodeSortMode _sortMode = _NodeSortMode.original;
  bool _batchTesting = false;
  bool _cancelBatch = false;
  int _batchDone = 0;
  int _batchTotal = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadProxies();
  }

  Future<void> _loadProxies() async {
    setState(() => _isLoading = true);
    final list = await ManualProxyHelper.getProfileProxies(_profile);
    if (mounted) {
      final names = {
        for (final proxy in list)
          if (proxy['name'] is String) proxy['name'] as String,
      };
      setState(() {
        _proxies = list;
        _delays.removeWhere((name, _) => !names.contains(name));
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeleteProxy(String proxyName) async {
    final confirm = await globalState.showMessage(
      title: appLocalizations.confirmDelete,
      message: TextSpan(
        text: appLocalizations.confirmDeleteNodeMsg(proxyName),
      ),
    );
    if (confirm != true) return;

    final updated = await ManualProxyHelper.deleteProxyFromProfile(
      _profile,
      proxyName,
    );
    setState(() => _profile = updated);
    await _loadProxies();
    if (mounted) {
      context.showNotifier(appLocalizations.nodeDeleted(proxyName));
    }
    // Reload core if active
    if (globalState.config.currentProfileId == _profile.id) {
      globalState.appController.applyProfileDebounce(silence: true);
    }
  }

  void _showBatchImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.blueAccent),
              const SizedBox(width: 8),
              // item 4 — unwrapped this dialog title overflowed by 32 px at
              // 320 dp and 72 px at 280 dp under the 1.4x text scale.
              Flexible(
                child: Text(
                  appLocalizations.batchImportShareLinks,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            // RC.7: this content is taller than a small window (the protocol
            // list plus an 8-line input) and `AlertDialog` does not scroll its
            // content, so it used to overflow by up to 497 px. Same treatment as
            // `_ManualNodeFormDialog` below.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appLocalizations.batchImportSupportHint}\n'
                    // 只列内核真正支持的协议：trojan-go / awg / juicity / naive
                    // 是 sing-box 的东西，导入进来也加载不了。
                    'vmess://, vless://, ss://, ssr://, trojan://, hy2://, hysteria://, tuic://, '
                    'wireguard://, snell://, anytls://, ssh://, shadow-tls://, socks5://, http://, direct://',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: appLocalizations.batchImportPasteHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: Text(appLocalizations.pasteFromClipboard),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          controller.text = data!.text!;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final parsedList = ManualProxyHelper.parseMultipleLinks(text);
                if (parsedList.isEmpty) {
                  if (ctx.mounted) {
                    ctx.showSnackBar(appLocalizations.batchImportParseFailed);
                  }
                  return;
                }
                Navigator.of(ctx).pop();
                setState(() => _isLoading = true);
                final updated =
                    await ManualProxyHelper.addOrUpdateProxiesToProfile(
                      _profile,
                      parsedList,
                    );
                setState(() => _profile = updated);
                await _loadProxies();
                if (mounted) {
                  context.showNotifier(
                    appLocalizations.batchImportSuccess(parsedList.length),
                  );
                }
                if (globalState.config.currentProfileId == _profile.id) {
                  globalState.appController.applyProfileDebounce(silence: true);
                }
              },
              child: Text(appLocalizations.confirmImport),
            ),
          ],
        );
      },
    );
  }

  void _showAddManualNodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ManualNodeFormDialog(
        profile: _profile,
        onSaved: (updatedProfile) async {
          setState(() => _profile = updatedProfile);
          await _loadProxies();
          if (globalState.config.currentProfileId == _profile.id) {
            globalState.appController.applyProfileDebounce(silence: true);
          }
        },
      ),
    );
  }

  Color _getProtocolColor(String type) {
    switch (type.toLowerCase()) {
      case 'vless':
        return Colors.indigoAccent;
      case 'vmess':
        return Colors.blueAccent;
      case 'ss':
      case 'ssr':
        return Colors.teal;
      case 'trojan':
      case 'trojan-go':
        return Colors.deepPurpleAccent;
      case 'hysteria':
        return Colors.pinkAccent;
      case 'hysteria2':
      case 'hy2':
        return Colors.deepOrangeAccent;
      case 'tuic':
        return Colors.purpleAccent;
      case 'wireguard':
      case 'amnezia-wg':
      case 'awg':
        return Colors.green;
      case 'snell':
        return Colors.indigo;
      case 'ssh':
        return Colors.brown;
      case 'shadow-tls':
        return Colors.purple;
      case 'juicity':
        return Colors.lime.shade900;
      case 'socks5':
      case 'socks':
      case 'http':
        return Colors.amber.shade800;
      case 'direct':
        return Colors.green.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  bool get _isActiveProfile =>
      globalState.config.currentProfileId == _profile.id;

  String get _testUrl {
    final configured = globalState.config.appSetting.testUrl.trim();
    return configured.isEmpty ? defaultTestUrl : configured;
  }

  Future<void> _testProxy(String name) async {
    if (_delays[name] == 0) return;
    if (!_isActiveProfile) {
      if (mounted) {
        context.showSnackBar(appLocalizations.nodeTestUnavailable);
      }
      return;
    }
    setState(() => _delays[name] = 0);
    try {
      final result = await clashCore.getDelay(_testUrl, name);
      final value = result.value;
      if (!mounted) return;
      setState(() {
        _delays[name] = value == null || value <= 0 ? -1 : value;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _delays[name] = -1);
    }
  }

  Future<void> _testAll() async {
    if (_batchTesting) {
      setState(() => _cancelBatch = true);
      return;
    }
    if (!_isActiveProfile) {
      context.showSnackBar(appLocalizations.nodeTestUnavailable);
      return;
    }
    final names = _sortedProxies
        .map((proxy) => proxy['name']?.toString())
        .whereType<String>()
        .toList();
    if (names.isEmpty) return;
    setState(() {
      _batchTesting = true;
      _cancelBatch = false;
      _batchDone = 0;
      _batchTotal = names.length;
    });
    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (_cancelBatch) return;
        final index = next++;
        if (index >= names.length) return;
        await _testProxy(names[index]);
        if (!mounted) return;
        setState(() => _batchDone++);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    if (!mounted) return;
    setState(() => _batchTesting = false);
  }

  List<Map<String, dynamic>> get _sortedProxies {
    final list = List<Map<String, dynamic>>.from(_proxies);
    switch (_sortMode) {
      case _NodeSortMode.original:
        return list;
      case _NodeSortMode.name:
        list.sort(
          (a, b) => (a['name']?.toString() ?? '').compareTo(
            b['name']?.toString() ?? '',
          ),
        );
        break;
      case _NodeSortMode.protocol:
        list.sort(
          (a, b) => (a['type']?.toString() ?? '').compareTo(
            b['type']?.toString() ?? '',
          ),
        );
        break;
      case _NodeSortMode.delay:
        int rank(int? value) => value == null ? 2 : (value <= 0 ? 1 : 0);
        list.sort((a, b) {
          final left = _delays[a['name']?.toString() ?? ''];
          final right = _delays[b['name']?.toString() ?? ''];
          final byRank = rank(left).compareTo(rank(right));
          if (byRank != 0) return byRank;
          if (left != null && right != null && left > 0 && right > 0) {
            return left.compareTo(right);
          }
          return 0;
        });
        break;
    }
    return list;
  }

  void _toggleSelected(String name) {
    setState(() {
      if (!_selected.remove(name)) _selected.add(name);
    });
  }

  /// 把勾选的节点转成分享链接并放进剪贴板。
  ///
  /// 复制而不是只展示：这些链接的用途就是粘到导入框里，剪贴板是最近的一步。
  Future<void> _exportSelected() async {
    final chosen = _proxies
        .where((p) => _selected.contains(p['name']?.toString() ?? ''))
        .toList();
    if (chosen.isEmpty) {
      context.showSnackBar(appLocalizations.nodeExportEmpty);
      return;
    }
    final text = NodeShareLink.exportAll(chosen);
    if (text.isEmpty) {
      // 选中的全是导出不了的协议（wireguard 之类），要说清楚而不是静默复制空串。
      context.showSnackBar(appLocalizations.nodeExportEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() {
      _exportMode = false;
      _selected.clear();
    });
    context.showSnackBar(appLocalizations.nodeExportDone);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final visibleProxies = _sortedProxies;
    return CommonScaffold(
      titleWidget: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: EmojiText(
          appLocalizations.nodeManagement(_profile.label ?? _profile.id),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.link_rounded),
          tooltip: appLocalizations.batchImportLinks,
          onPressed: _showBatchImportDialog,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: appLocalizations.refresh,
          onPressed: _loadProxies,
        ),
        IconButton(
          icon: Icon(
            _batchTesting
                ? Icons.stop_circle_outlined
                : Icons.speed_rounded,
          ),
          tooltip: _batchTesting
              ? appLocalizations.nodeTestCancel
              : appLocalizations.nodeTestAll,
          onPressed: _testAll,
        ),
        PopupMenuButton<_NodeSortMode>(
          icon: const Icon(Icons.sort_rounded),
          tooltip: appLocalizations.sort,
          initialValue: _sortMode,
          onSelected: (value) => setState(() => _sortMode = value),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _NodeSortMode.original,
              child: Text(appLocalizations.nodeSortDefault),
            ),
            PopupMenuItem(
              value: _NodeSortMode.name,
              child: Text(appLocalizations.nodeSortName),
            ),
            PopupMenuItem(
              value: _NodeSortMode.protocol,
              child: Text(appLocalizations.nodeSortProtocol),
            ),
            PopupMenuItem(
              value: _NodeSortMode.delay,
              child: Text(appLocalizations.nodeSortDelay),
            ),
          ],
        ),
        if (_exportMode) ...[
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: appLocalizations.nodeSelectAll,
            onPressed: () {
              setState(() {
                _selected
                  ..clear()
                  ..addAll(_proxies.map((p) => p['name']?.toString() ?? ''));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: appLocalizations.nodeExport,
            onPressed: _exportSelected,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: appLocalizations.cancel,
            onPressed: () => setState(() {
              _exportMode = false;
              _selected.clear();
            }),
          ),
        ] else
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: appLocalizations.nodeExport,
            onPressed: () => setState(() => _exportMode = true),
          ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showAddManualNodeDialog,
        icon: const Icon(Icons.add_rounded),
        label: Text(appLocalizations.manualAddNode),
      ),
      body: Stack(
        children: [
          _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _proxies.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 64,
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appLocalizations.noNodesInGroup,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appLocalizations.noNodesInGroupHint,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // item 4 — the two actions must be allowed to wrap: side by
                  // side they overflow by 1.8 px at 320 dp and 42 px at 280 dp
                  // under the app's maximum 1.4x text scale.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.link_rounded),
                        label: Text(appLocalizations.importShareLinks),
                        onPressed: _showBatchImportDialog,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(appLocalizations.manualEntry),
                        onPressed: _showAddManualNodeDialog,
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: visibleProxies.length,
              itemBuilder: (ctx, index) {
                final p = visibleProxies[index];
                final name =
                    p['name']?.toString() ?? appLocalizations.unnamedNode;
                final type = p['type']?.toString().toUpperCase() ?? 'PROXY';
                final server = p['server']?.toString() ?? '';
                final port = p['port']?.toString() ?? '';
                final protoColor = _getProtocolColor(type);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    // 导出模式下点按即勾选；平时长按看完整配置（和代理页一致）。
                    onTap: _exportMode ? () => _toggleSelected(name) : null,
                    onLongPress: () {
                      if (_exportMode) {
                        _toggleSelected(name);
                        return;
                      }
                      showNodeDetailsDialog(
                        context,
                        proxyName: name,
                        profileId: _profile.id,
                      );
                    },
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: protoColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: protoColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: protoColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      server.isNotEmpty
                          ? '$server:$port'
                          : appLocalizations.customConfigNode,
                      style: TextStyle(
                        color: colorScheme.outline,
                        fontSize: 13,
                      ),
                    ),
                    trailing: _exportMode
                        ? Checkbox(
                            value: _selected.contains(name),
                            onChanged: (_) => _toggleSelected(name),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FluxoraLatencyBadge(
                                delay: _delays[name],
                                timeoutLabel: appLocalizations.timeoutLabel,
                                onTap: () => _testProxy(name),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                tooltip: appLocalizations.deleteNode,
                                onPressed: () => _handleDeleteProxy(name),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          if (_batchTesting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _batchBanner(context),
            ),
        ],
      ),
    );
  }

  Widget _batchBanner(BuildContext context) {
    final progress = _batchTotal == 0 ? null : _batchDone / _batchTotal;
    return Material(
      color: context.colorScheme.surfaceContainerHigh,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              appLocalizations.nodeTestingProgress(
                '$_batchDone',
                '$_batchTotal',
              ),
              style: context.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualNodeFormDialog extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onSaved;

  const _ManualNodeFormDialog({required this.profile, required this.onSaved});

  @override
  State<_ManualNodeFormDialog> createState() => _ManualNodeFormDialogState();
}

class _ManualNodeFormDialogState extends State<_ManualNodeFormDialog> {
  ManualProtocol _protocol = ManualProtocol.vless;

  final _nameCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '443');
  final _uuidPasswordCtrl = TextEditingController();
  final _sniCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _cipherCtrl = TextEditingController(text: 'aes-256-gcm');
  final _flowCtrl = TextEditingController(text: 'xtls-rprx-vision');
  final _pbkCtrl = TextEditingController(); // Reality / WireGuard public key
  final _sidCtrl = TextEditingController(); // Reality short id
  final _customConfigCtrl = TextEditingController();

  // AmneziaWG fields
  final _jcCtrl = TextEditingController(text: '4');
  final _jminCtrl = TextEditingController(text: '40');
  final _jmaxCtrl = TextEditingController(text: '70');
  final _s1Ctrl = TextEditingController(text: '0');
  final _s2Ctrl = TextEditingController(text: '0');
  final _h1Ctrl = TextEditingController(text: '1');
  final _h2Ctrl = TextEditingController(text: '2');
  final _h3Ctrl = TextEditingController(text: '3');
  final _h4Ctrl = TextEditingController(text: '4');

  String _network = 'tcp'; // tcp, ws, grpc, httpupgrade
  String _security = 'reality'; // none, tls, reality
  bool _udp = true;
  bool _skipCertVerify = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serverCtrl.dispose();
    _portCtrl.dispose();
    _uuidPasswordCtrl.dispose();
    _sniCtrl.dispose();
    _pathCtrl.dispose();
    _hostCtrl.dispose();
    _cipherCtrl.dispose();
    _flowCtrl.dispose();
    _pbkCtrl.dispose();
    _sidCtrl.dispose();
    _customConfigCtrl.dispose();
    _jcCtrl.dispose();
    _jminCtrl.dispose();
    _jmaxCtrl.dispose();
    _s1Ctrl.dispose();
    _s2Ctrl.dispose();
    _h1Ctrl.dispose();
    _h2Ctrl.dispose();
    _h3Ctrl.dispose();
    _h4Ctrl.dispose();
    super.dispose();
  }

  void _onProtocolChanged(ManualProtocol proto) {
    setState(() {
      _protocol = proto;
      switch (proto) {
        case ManualProtocol.vless:
          _portCtrl.text = '443';
          _security = 'reality';
          _network = 'tcp';
          break;
        case ManualProtocol.vmess:
          _portCtrl.text = '443';
          _security = 'tls';
          _network = 'ws';
          break;
        case ManualProtocol.ss:
          _portCtrl.text = '8388';
          _cipherCtrl.text = 'aes-256-gcm';
          break;
        case ManualProtocol.ssr:
          _portCtrl.text = '8388';
          _cipherCtrl.text = 'aes-256-cfb';
          break;
        case ManualProtocol.trojan:
          _portCtrl.text = '443';
          _security = 'tls';
          _network = 'tcp';
          break;
        case ManualProtocol.trojanGo:
          _portCtrl.text = '443';
          _security = 'tls';
          _network = 'ws';
          break;
        case ManualProtocol.hysteria:
          _portCtrl.text = '443';
          _flowCtrl.text = '30 Mbps';
          _cipherCtrl.text = '100 Mbps';
          break;
        case ManualProtocol.hysteria2:
          _portCtrl.text = '443';
          _security = 'tls';
          break;
        case ManualProtocol.anytls:
          _portCtrl.text = '443';
          _security = 'tls';
          break;
        case ManualProtocol.tuic:
          _portCtrl.text = '8443';
          _security = 'tls';
          break;
        case ManualProtocol.wireguard:
          _portCtrl.text = '51820';
          _pathCtrl.text = '10.0.0.2';
          break;
        case ManualProtocol.amneziaWg:
          _portCtrl.text = '51820';
          _pathCtrl.text = '10.0.0.2';
          break;
        case ManualProtocol.snell:
          _portCtrl.text = '443';
          _flowCtrl.text = '4'; // version 4
          _security = 'tls';
          break;
        case ManualProtocol.ssh:
          _portCtrl.text = '22';
          _hostCtrl.text = 'root';
          break;
        case ManualProtocol.shadowTls:
          _portCtrl.text = '443';
          _flowCtrl.text = '3'; // version 3
          break;
        case ManualProtocol.juicity:
          _portCtrl.text = '443';
          break;
        case ManualProtocol.naive:
          _portCtrl.text = '443';
          break;
        case ManualProtocol.socks5:
          _portCtrl.text = '1080';
          break;
        case ManualProtocol.http:
          _portCtrl.text = '8080';
          break;
        case ManualProtocol.direct:
          _nameCtrl.text = 'DIRECT_NODE';
          break;
        case ManualProtocol.custom:
          _customConfigCtrl.text =
              'name: CustomNode\ntype: vless\nserver: 1.2.3.4\nport: 443\nuuid: 00000000-0000-0000-0000-000000000000';
          break;
      }
    });
  }

  Map<String, dynamic> _buildProxyMap() {
    if (_protocol == ManualProtocol.custom) {
      try {
        final loaded = loadYaml(_customConfigCtrl.text.trim());
        if (loaded is Map) {
          return ManualProxyHelper.deepConvertYamlMap(loaded);
        }
      } catch (_) {}
      return {
        'name': 'Custom_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'direct',
      };
    }

    if (_protocol == ManualProtocol.direct) {
      return {
        'name': _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : 'DIRECT_NODE',
        'type': 'direct',
      };
    }

    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : '${_protocol.displayName}_${_serverCtrl.text.trim()}';
    final server = _serverCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 443;
    final secret = _uuidPasswordCtrl.text.trim();
    final sni = _sniCtrl.text.trim();
    final path = _pathCtrl.text.trim();
    final host = _hostCtrl.text.trim();

    final map = <String, dynamic>{
      'name': name,
      'type': _protocol.typeKey,
      'server': server,
      'port': port,
      'udp': _udp,
    };

    switch (_protocol) {
      case ManualProtocol.anytls:
        // anytls 只有密码 + TLS，没有 uuid/flow。
        map['password'] = secret;
        map['skip-cert-verify'] = _skipCertVerify;
        if (sni.isNotEmpty) map['sni'] = sni;
      case ManualProtocol.vless:
        map['uuid'] = secret;
        if (_flowCtrl.text.trim().isNotEmpty) {
          map['flow'] = _flowCtrl.text.trim();
        }
        if (_security == 'tls') {
          map['tls'] = true;
          map['skip-cert-verify'] = _skipCertVerify;
          if (sni.isNotEmpty) map['servername'] = sni;
        } else if (_security == 'reality') {
          map['tls'] = true;
          map['skip-cert-verify'] = _skipCertVerify;
          if (sni.isNotEmpty) map['servername'] = sni;
          map['reality-opts'] = {
            if (_pbkCtrl.text.trim().isNotEmpty)
              'public-key': _pbkCtrl.text.trim(),
            if (_sidCtrl.text.trim().isNotEmpty)
              'short-id': _sidCtrl.text.trim(),
          };
          map['client-fingerprint'] = 'chrome';
        }
        if (_network == 'ws') {
          map['network'] = 'ws';
          map['ws-opts'] = {
            if (path.isNotEmpty) 'path': path,
            if (host.isNotEmpty) 'headers': {'Host': host},
          };
        } else if (_network == 'grpc') {
          map['network'] = 'grpc';
          map['grpc-opts'] = {if (path.isNotEmpty) 'grpc-service-name': path};
        } else if (_network == 'httpupgrade') {
          map['network'] = 'httpupgrade';
          map['httpupgrade-opts'] = {
            if (path.isNotEmpty) 'path': path,
            if (host.isNotEmpty) 'headers': {'Host': host},
          };
        }
        break;

      case ManualProtocol.vmess:
        map['uuid'] = secret;
        map['alterId'] = 0;
        map['cipher'] = 'auto';
        if (_security == 'tls') {
          map['tls'] = true;
          map['skip-cert-verify'] = _skipCertVerify;
          if (sni.isNotEmpty) map['servername'] = sni;
        }
        if (_network == 'ws') {
          map['network'] = 'ws';
          map['ws-opts'] = {
            if (path.isNotEmpty) 'path': path,
            if (host.isNotEmpty) 'headers': {'Host': host},
          };
        } else if (_network == 'grpc') {
          map['network'] = 'grpc';
          map['grpc-opts'] = {if (path.isNotEmpty) 'grpc-service-name': path};
        }
        break;

      case ManualProtocol.ss:
        map['cipher'] = _cipherCtrl.text.trim().isNotEmpty
            ? _cipherCtrl.text.trim()
            : 'aes-256-gcm';
        map['password'] = secret;
        break;

      case ManualProtocol.ssr:
        map['cipher'] = _cipherCtrl.text.trim().isNotEmpty
            ? _cipherCtrl.text.trim()
            : 'aes-256-cfb';
        map['password'] = secret;
        map['protocol'] = 'auth_aes128_md5';
        map['obfs'] = 'tls1.2_ticket_auth';
        break;

      case ManualProtocol.trojan:
        map['password'] = secret;
        map['skip-cert-verify'] = _skipCertVerify;
        if (sni.isNotEmpty) map['sni'] = sni;
        if (_network == 'ws') {
          map['network'] = 'ws';
          map['ws-opts'] = {if (path.isNotEmpty) 'path': path};
        }
        break;

      case ManualProtocol.trojanGo:
        map['type'] = 'trojan';
        map['password'] = secret;
        map['skip-cert-verify'] = _skipCertVerify;
        if (sni.isNotEmpty) map['sni'] = sni;
        map['network'] = 'ws';
        map['ws-opts'] = {
          'path': path.isNotEmpty ? path : '/',
          if (host.isNotEmpty) 'headers': {'Host': host},
        };
        break;

      case ManualProtocol.hysteria:
        map['auth_str'] = secret;
        map['up'] = _flowCtrl.text.trim().isNotEmpty
            ? _flowCtrl.text.trim()
            : '30 Mbps';
        map['down'] = _cipherCtrl.text.trim().isNotEmpty
            ? _cipherCtrl.text.trim()
            : '100 Mbps';
        if (sni.isNotEmpty) map['sni'] = sni;
        if (path.isNotEmpty) map['obfs'] = path;
        map['protocol'] = 'udp';
        map['skip-cert-verify'] = _skipCertVerify;
        break;

      case ManualProtocol.hysteria2:
        map['password'] = secret;
        map['skip-cert-verify'] = _skipCertVerify;
        if (sni.isNotEmpty) map['sni'] = sni;
        break;

      case ManualProtocol.tuic:
        map['uuid'] = secret;
        map['password'] = _hostCtrl.text.trim();
        map['congestion-controller'] = 'bbr';
        map['udp-relay-mode'] = 'native';
        map['skip-cert-verify'] = _skipCertVerify;
        if (sni.isNotEmpty) map['sni'] = sni;
        break;

      case ManualProtocol.wireguard:
        map['private-key'] = secret;
        map['public-key'] = _pbkCtrl.text.trim();
        map['ip'] = _pathCtrl.text.trim().isNotEmpty
            ? _pathCtrl.text.trim()
            : '10.0.0.2';
        map['remote-dns-resolve'] = true;
        break;

      case ManualProtocol.amneziaWg:
        map['type'] = 'wireguard';
        map['private-key'] = secret;
        map['public-key'] = _pbkCtrl.text.trim();
        map['ip'] = _pathCtrl.text.trim().isNotEmpty
            ? _pathCtrl.text.trim()
            : '10.0.0.2';
        map['remote-dns-resolve'] = true;
        map['jc'] = int.tryParse(_jcCtrl.text.trim()) ?? 4;
        map['jmin'] = int.tryParse(_jminCtrl.text.trim()) ?? 40;
        map['jmax'] = int.tryParse(_jmaxCtrl.text.trim()) ?? 70;
        map['s1'] = int.tryParse(_s1Ctrl.text.trim()) ?? 0;
        map['s2'] = int.tryParse(_s2Ctrl.text.trim()) ?? 0;
        map['h1'] = int.tryParse(_h1Ctrl.text.trim()) ?? 1;
        map['h2'] = int.tryParse(_h2Ctrl.text.trim()) ?? 2;
        map['h3'] = int.tryParse(_h3Ctrl.text.trim()) ?? 3;
        map['h4'] = int.tryParse(_h4Ctrl.text.trim()) ?? 4;
        break;

      case ManualProtocol.snell:
        map['psk'] = secret;
        map['version'] = int.tryParse(_flowCtrl.text.trim()) ?? 4;
        if (_security != 'none') {
          map['obfs-opts'] = {
            'mode': _security,
            if (sni.isNotEmpty) 'host': sni,
          };
        }
        break;

      case ManualProtocol.ssh:
        map['username'] = _hostCtrl.text.trim().isNotEmpty
            ? _hostCtrl.text.trim()
            : 'root';
        map['password'] = secret;
        break;

      case ManualProtocol.shadowTls:
        map['password'] = secret;
        map['sni'] = sni;
        map['version'] = int.tryParse(_flowCtrl.text.trim()) ?? 3;
        break;

      case ManualProtocol.juicity:
        map['uuid'] = secret;
        map['password'] = _hostCtrl.text.trim();
        map['sni'] = sni;
        map['congestion-control'] = 'bbr';
        map['allow-insecure'] = _skipCertVerify;
        break;

      case ManualProtocol.naive:
        map['type'] = 'http';
        map['username'] = _hostCtrl.text.trim();
        map['password'] = secret;
        map['tls'] = true;
        if (sni.isNotEmpty) map['sni'] = sni;
        map['skip-cert-verify'] = _skipCertVerify;
        break;

      case ManualProtocol.socks5:
      case ManualProtocol.http:
        if (secret.isNotEmpty) map['password'] = secret;
        if (_hostCtrl.text.trim().isNotEmpty) {
          map['username'] = _hostCtrl.text.trim();
        }
        if (_security == 'tls') map['tls'] = true;
        break;

      case ManualProtocol.direct:
      case ManualProtocol.custom:
        break;
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
          const SizedBox(width: 8),
          // item 4 — unwrapped this dialog title overflowed by 24 px at 280 dp
          // under the 1.4x text scale.
          Flexible(
            child: Text(
              appLocalizations.manualAddNode,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部留白：第一个字段的浮动标签画在边框之上，紧贴内容顶部
              // 会被裁掉一半（"节点协议"显示不全就是这个原因）。
              const SizedBox(height: 10),
              // Protocol Picker
              DropdownButtonFormField<ManualProtocol>(
                key: ValueKey(_protocol),
                // RC.7: without this the button sizes to its content and the
                // decorator's internal Row overflows by up to 181 px in a
                // narrow window.
                isExpanded: true,
                initialValue: _protocol,
                decoration: InputDecoration(
                  labelText: appLocalizations.nodeProtocol,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: ManualProtocol.values
                    .where((p) => p.kernelSupported)
                    .map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // item 4 — long protocol names overflowed the dropdown
                        // by 2.8 px at 280 dp under the 1.4x text scale.
                        Flexible(
                          child: Text(
                            p.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _onProtocolChanged(val);
                },
              ),
              const SizedBox(height: 12),

              if (_protocol == ManualProtocol.custom) ...[
                Text(
                  appLocalizations.customConfigHintText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customConfigCtrl,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: appLocalizations.customConfigLabel,
                    hintText:
                        'name: Custom_01\ntype: wireguard\nserver: 1.2.3.4\n...',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else if (_protocol == ManualProtocol.direct) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: appLocalizations.nodeNameLabel,
                    hintText: 'DIRECT_NODE',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                // Name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: appLocalizations.nodeNameLabel,
                    hintText: appLocalizations.nodeNameHint(
                      _protocol.displayName,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Server & Port
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _serverCtrl,
                        decoration: InputDecoration(
                          labelText: appLocalizations.serverAddressLabel,
                          hintText: appLocalizations.serverAddressHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: appLocalizations.portLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Secret (UUID / Password / PrivateKey)
                if (_protocol != ManualProtocol.direct) ...[
                  TextField(
                    controller: _uuidPasswordCtrl,
                    decoration: InputDecoration(
                      labelText: switch (_protocol) {
                        ManualProtocol.vless || ManualProtocol.vmess => 'UUID',
                        ManualProtocol.wireguard ||
                        ManualProtocol.amneziaWg => appLocalizations.privateKey,
                        ManualProtocol.snell => appLocalizations.pskKey,
                        _ => appLocalizations.passwordAuth,
                      },
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // SSH or Juicity or Naive Username / Password
                if (_protocol == ManualProtocol.ssh ||
                    _protocol == ManualProtocol.juicity ||
                    _protocol == ManualProtocol.naive ||
                    _protocol == ManualProtocol.socks5 ||
                    _protocol == ManualProtocol.http) ...[
                  TextField(
                    controller: _hostCtrl,
                    decoration: InputDecoration(
                      labelText: switch (_protocol) {
                        ManualProtocol.juicity =>
                          appLocalizations.juicityPassword,
                        _ => appLocalizations.usernameOptional,
                      },
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Protocol-specific fields
                if (_protocol == ManualProtocol.vless ||
                    _protocol == ManualProtocol.vmess ||
                    _protocol == ManualProtocol.trojan) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('net_$_network'),
                          // RC.7: see the protocol picker above.
                          isExpanded: true,
                          initialValue: _network,
                          decoration: InputDecoration(
                            labelText: appLocalizations.networkLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                            DropdownMenuItem(
                              value: 'ws',
                              child: Text('WebSocket'),
                            ),
                            DropdownMenuItem(
                              value: 'grpc',
                              child: Text('gRPC'),
                            ),
                            DropdownMenuItem(
                              value: 'httpupgrade',
                              child: Text('HTTPUpgrade'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _network = val ?? 'tcp'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('sec_$_security'),
                          // RC.7: see the protocol picker above.
                          isExpanded: true,
                          initialValue: _security,
                          decoration: InputDecoration(
                            labelText: appLocalizations.securityLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text(
                                appLocalizations.securityNonePlain,
                              ),
                            ),
                            const DropdownMenuItem(
                              value: 'tls',
                              child: Text('TLS'),
                            ),
                            if (_protocol == ManualProtocol.vless)
                              const DropdownMenuItem(
                                value: 'reality',
                                child: Text('REALITY'),
                              ),
                          ],
                          onChanged: (val) =>
                              setState(() => _security = val ?? 'none'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Snell obfs
                if (_protocol == ManualProtocol.snell) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('snell_obfs_$_security'),
                          initialValue: _security,
                          decoration: InputDecoration(
                            labelText: appLocalizations.obfsModeLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text(appLocalizations.obfsNoneOff),
                            ),
                            DropdownMenuItem(
                              value: 'http',
                              child: Text('HTTP'),
                            ),
                            DropdownMenuItem(value: 'tls', child: Text('TLS')),
                          ],
                          onChanged: (val) =>
                              setState(() => _security = val ?? 'none'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _flowCtrl,
                          decoration: InputDecoration(
                            labelText: appLocalizations.snellVersion,
                            hintText: '4',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // REALITY fields
                if (_protocol == ManualProtocol.vless &&
                    _security == 'reality') ...[
                  TextField(
                    controller: _pbkCtrl,
                    decoration: InputDecoration(
                      labelText: appLocalizations.realityPublicKey,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Short ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _flowCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Flow',
                            hintText: 'xtls-rprx-vision',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // SNI field for TLS / REALITY / Trojan / Hysteria / Juicity / ShadowTLS / Naive
                if ((_protocol == ManualProtocol.vless &&
                        _security != 'none') ||
                    (_protocol == ManualProtocol.vmess && _security == 'tls') ||
                    _protocol == ManualProtocol.trojan ||
                    _protocol == ManualProtocol.trojanGo ||
                    _protocol == ManualProtocol.hysteria ||
                    _protocol == ManualProtocol.hysteria2 ||
                    _protocol == ManualProtocol.tuic ||
                    _protocol == ManualProtocol.shadowTls ||
                    _protocol == ManualProtocol.juicity ||
                    _protocol == ManualProtocol.naive ||
                    (_protocol == ManualProtocol.snell &&
                        _security != 'none')) ...[
                  TextField(
                    controller: _sniCtrl,
                    decoration: InputDecoration(
                      labelText: appLocalizations.sniLabel,
                      hintText: appLocalizations.sniHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // WebSocket Path / Host
                if (_network == 'ws' ||
                    _network == 'httpupgrade' ||
                    _protocol == ManualProtocol.trojanGo) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pathCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Path',
                            hintText: '/ws',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // SS / SSR Cipher
                if (_protocol == ManualProtocol.ss ||
                    _protocol == ManualProtocol.ssr) ...[
                  TextField(
                    controller: _cipherCtrl,
                    decoration: InputDecoration(
                      labelText: appLocalizations.cipherLabel,
                      hintText: 'aes-256-gcm / chacha20-poly1305',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Hysteria 1 rates
                if (_protocol == ManualProtocol.hysteria) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _flowCtrl,
                          decoration: InputDecoration(
                            labelText: appLocalizations.upLabel,
                            hintText: '30 Mbps',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cipherCtrl,
                          decoration: InputDecoration(
                            labelText: appLocalizations.downLabel,
                            hintText: '100 Mbps',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // WireGuard & AmneziaWG fields
                if (_protocol == ManualProtocol.wireguard ||
                    _protocol == ManualProtocol.amneziaWg) ...[
                  TextField(
                    controller: _pbkCtrl,
                    decoration: InputDecoration(
                      labelText: appLocalizations.peerPublicKey,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      labelText: appLocalizations.localIpLabel,
                      hintText: '10.0.0.2',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // AmneziaWG 2/3 Obfuscation Parameters
                if (_protocol == ManualProtocol.amneziaWg) ...[
                  Text(
                    appLocalizations.amneziaObfsParams,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _jcCtrl,
                          decoration: InputDecoration(
                            labelText: appLocalizations.jcLabel,
                            hintText: '4',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _jminCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Jmin',
                            hintText: '40',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _jmaxCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Jmax',
                            hintText: '70',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _s1Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'S1',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _s2Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'S2',
                            hintText: '0',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _h1Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'H1',
                            hintText: '1',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _h2Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'H2',
                            hintText: '2',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _h3Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'H3',
                            hintText: '3',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _h4Ctrl,
                          decoration: const InputDecoration(
                            labelText: 'H4',
                            hintText: '4',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Options
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(appLocalizations.enableUdpForwarding),
                  value: _udp,
                  onChanged: (v) => setState(() => _udp = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(appLocalizations.skipCertVerify),
                  subtitle: Text(
                    appLocalizations.skipCertVerifyDesc,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: _skipCertVerify,
                  onChanged: (v) => setState(() => _skipCertVerify = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_protocol != ManualProtocol.custom &&
                _protocol != ManualProtocol.direct &&
                _serverCtrl.text.trim().isEmpty) {
              context.showSnackBar(appLocalizations.serverAddressRequired);
              return;
            }
            final proxyMap = _buildProxyMap();
            Navigator.of(context).pop();

            final updated = await ManualProxyHelper.addOrUpdateProxiesToProfile(
              widget.profile,
              [proxyMap],
            );
            widget.onSaved(updated);
            if (context.mounted) {
              context.showNotifier(
                appLocalizations.nodeAdded(proxyMap['name']),
              );
            }
          },
          child: Text(appLocalizations.saveNode),
        ),
      ],
    );
  }
}
