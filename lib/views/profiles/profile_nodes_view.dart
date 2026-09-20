import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ProfileNodesView extends StatefulWidget {
  final Profile profile;

  const ProfileNodesView({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileNodesView> createState() => _ProfileNodesViewState();
}

class _ProfileNodesViewState extends State<ProfileNodesView> {
  late Profile _profile;
  List<Map<String, dynamic>> _proxies = [];
  bool _isLoading = true;

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
      setState(() {
        _proxies = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeleteProxy(String proxyName) async {
    final confirm = await globalState.showMessage(
      title: '确认删除',
      message: TextSpan(text: '确定要删除节点 "$proxyName" 吗？'),
    );
    if (confirm != true) return;

    final updated = await ManualProxyHelper.deleteProxyFromProfile(_profile, proxyName);
    setState(() => _profile = updated);
    await _loadProxies();
    if (mounted) {
      context.showNotifier('已删除节点: $proxyName');
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
          title: const Row(
            children: [
              Icon(Icons.link_rounded, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('批量导入分享链接'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '支持单条/多行链接或 YAML/JSON 节点片段：\n'
                  'vmess://, vless://, ss://, ssr://, trojan://, trojan-go://, hy2://, hysteria://, tuic://, '
                  'wireguard://, awg://, snell://, ssh://, shadow-tls://, juicity://, naive://, socks5://, http://, direct://',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '在此粘贴节点分享链接或节点配置 (YAML/JSON)...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('从剪贴板粘贴'),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        controller.text = data!.text!;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final parsedList = ManualProxyHelper.parseMultipleLinks(text);
                if (parsedList.isEmpty) {
                  if (ctx.mounted) {
                    ctx.showSnackBar('未能解析到有效节点链接，请核对格式');
                  }
                  return;
                }
                Navigator.of(ctx).pop();
                setState(() => _isLoading = true);
                final updated = await ManualProxyHelper.addOrUpdateProxiesToProfile(
                  _profile,
                  parsedList,
                );
                setState(() => _profile = updated);
                await _loadProxies();
                if (mounted) {
                  context.showNotifier('成功导入 ${parsedList.length} 个节点');
                }
                if (globalState.config.currentProfileId == _profile.id) {
                  globalState.appController.applyProfileDebounce(silence: true);
                }
              },
              child: const Text('确认导入'),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '节点管理 · ${_profile.label ?? _profile.id}',
      actions: [
        IconButton(
          icon: const Icon(Icons.link_rounded),
          tooltip: '批量导入链接',
          onPressed: _showBatchImportDialog,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
          onPressed: _loadProxies,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showAddManualNodeDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('手动添加节点'),
      ),
      body: _isLoading
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
                        '当前分组内暂无节点',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击右下方「手动添加节点」或右上角「批量导入链接」',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('导入分享链接'),
                            onPressed: _showBatchImportDialog,
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('手动录入'),
                            onPressed: _showAddManualNodeDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _proxies.length,
                  itemBuilder: (ctx, index) {
                    final p = _proxies[index];
                    final name = p['name']?.toString() ?? '未命名节点';
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
                          server.isNotEmpty ? '$server:$port' : '自定义配置节点',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          tooltip: '删除节点',
                          onPressed: () => _handleDeleteProxy(name),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ManualNodeFormDialog extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onSaved;

  const _ManualNodeFormDialog({
    required this.profile,
    required this.onSaved,
  });

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
          _customConfigCtrl.text = 'name: CustomNode\ntype: vless\nserver: 1.2.3.4\nport: 443\nuuid: 00000000-0000-0000-0000-000000000000';
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
      return {'name': 'Custom_${DateTime.now().millisecondsSinceEpoch}', 'type': 'direct'};
    }

    if (_protocol == ManualProtocol.direct) {
      return {
        'name': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'DIRECT_NODE',
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
            if (_pbkCtrl.text.trim().isNotEmpty) 'public-key': _pbkCtrl.text.trim(),
            if (_sidCtrl.text.trim().isNotEmpty) 'short-id': _sidCtrl.text.trim(),
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
        map['cipher'] = _cipherCtrl.text.trim().isNotEmpty ? _cipherCtrl.text.trim() : 'aes-256-gcm';
        map['password'] = secret;
        break;

      case ManualProtocol.ssr:
        map['cipher'] = _cipherCtrl.text.trim().isNotEmpty ? _cipherCtrl.text.trim() : 'aes-256-cfb';
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
        map['up'] = _flowCtrl.text.trim().isNotEmpty ? _flowCtrl.text.trim() : '30 Mbps';
        map['down'] = _cipherCtrl.text.trim().isNotEmpty ? _cipherCtrl.text.trim() : '100 Mbps';
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
        map['ip'] = _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '10.0.0.2';
        map['remote-dns-resolve'] = true;
        break;

      case ManualProtocol.amneziaWg:
        map['type'] = 'wireguard';
        map['private-key'] = secret;
        map['public-key'] = _pbkCtrl.text.trim();
        map['ip'] = _pathCtrl.text.trim().isNotEmpty ? _pathCtrl.text.trim() : '10.0.0.2';
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
        map['username'] = _hostCtrl.text.trim().isNotEmpty ? _hostCtrl.text.trim() : 'root';
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
        if (_hostCtrl.text.trim().isNotEmpty) map['username'] = _hostCtrl.text.trim();
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
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
          SizedBox(width: 8),
          Text('手动添加节点'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Protocol Picker
              DropdownButtonFormField<ManualProtocol>(
                key: ValueKey(_protocol),
                initialValue: _protocol,
                decoration: const InputDecoration(
                  labelText: '节点协议 (Protocol)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ManualProtocol.values.map((p) {
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
                        Text(p.displayName),
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
                const Text(
                  '在此输入或粘贴完整的节点 YAML 或 JSON 配置片段：',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customConfigCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '自定义配置 (YAML / JSON)',
                    hintText: 'name: Custom_01\ntype: wireguard\nserver: 1.2.3.4\n...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (_protocol == ManualProtocol.direct) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '节点名称 (Name)',
                    hintText: 'DIRECT_NODE',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                // Name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: '节点名称 (Name)',
                    hintText: '如: 香港 01 - ${_protocol.displayName}',
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
                        decoration: const InputDecoration(
                          labelText: '服务器地址 (Server)',
                          hintText: 'IP 或域名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '端口 (Port)',
                          border: OutlineInputBorder(),
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
                        ManualProtocol.wireguard || ManualProtocol.amneziaWg => '私钥 (Private Key)',
                        ManualProtocol.snell => 'PSK 预共享密钥',
                        _ => '密码 (Password / Auth)',
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
                        ManualProtocol.juicity => 'Juicity 密码 (上方填写 UUID)',
                        _ => '用户名 (Username，可选)',
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
                          initialValue: _network,
                          decoration: const InputDecoration(
                            labelText: '传输层 (Network)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                            DropdownMenuItem(value: 'ws', child: Text('WebSocket')),
                            DropdownMenuItem(value: 'grpc', child: Text('gRPC')),
                            DropdownMenuItem(value: 'httpupgrade', child: Text('HTTPUpgrade')),
                          ],
                          onChanged: (val) => setState(() => _network = val ?? 'tcp'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('sec_$_security'),
                          initialValue: _security,
                          decoration: const InputDecoration(
                            labelText: '安全/TLS (Security)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'none', child: Text('None (明文)')),
                            const DropdownMenuItem(value: 'tls', child: Text('TLS')),
                            if (_protocol == ManualProtocol.vless)
                              const DropdownMenuItem(value: 'reality', child: Text('REALITY')),
                          ],
                          onChanged: (val) => setState(() => _security = val ?? 'none'),
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
                          decoration: const InputDecoration(
                            labelText: '混淆模式 (Obfs Mode)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('None (关闭)')),
                            DropdownMenuItem(value: 'http', child: Text('HTTP')),
                            DropdownMenuItem(value: 'tls', child: Text('TLS')),
                          ],
                          onChanged: (val) => setState(() => _security = val ?? 'none'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _flowCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Snell 版本 (1-4)',
                            hintText: '4',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // REALITY fields
                if (_protocol == ManualProtocol.vless && _security == 'reality') ...[
                  TextField(
                    controller: _pbkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'REALITY 公钥 (Public Key)',
                      border: OutlineInputBorder(),
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
                if ((_protocol == ManualProtocol.vless && _security != 'none') ||
                    (_protocol == ManualProtocol.vmess && _security == 'tls') ||
                    _protocol == ManualProtocol.trojan ||
                    _protocol == ManualProtocol.trojanGo ||
                    _protocol == ManualProtocol.hysteria ||
                    _protocol == ManualProtocol.hysteria2 ||
                    _protocol == ManualProtocol.tuic ||
                    _protocol == ManualProtocol.shadowTls ||
                    _protocol == ManualProtocol.juicity ||
                    _protocol == ManualProtocol.naive ||
                    (_protocol == ManualProtocol.snell && _security != 'none')) ...[
                  TextField(
                    controller: _sniCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SNI (ServerName / 伪装域名)',
                      hintText: '留空默认与服务器地址一致',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // WebSocket Path / Host
                if (_network == 'ws' || _network == 'httpupgrade' || _protocol == ManualProtocol.trojanGo) ...[
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
                if (_protocol == ManualProtocol.ss || _protocol == ManualProtocol.ssr) ...[
                  TextField(
                    controller: _cipherCtrl,
                    decoration: const InputDecoration(
                      labelText: '加密方式 (Cipher)',
                      hintText: 'aes-256-gcm / chacha20-poly1305',
                      border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: '上行 (Up)',
                            hintText: '30 Mbps',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cipherCtrl,
                          decoration: const InputDecoration(
                            labelText: '下行 (Down)',
                            hintText: '100 Mbps',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // WireGuard & AmneziaWG fields
                if (_protocol == ManualProtocol.wireguard || _protocol == ManualProtocol.amneziaWg) ...[
                  TextField(
                    controller: _pbkCtrl,
                    decoration: const InputDecoration(
                      labelText: '对端公钥 (Public Key)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pathCtrl,
                    decoration: const InputDecoration(
                      labelText: '本地 IP (Local IP)',
                      hintText: '10.0.0.2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // AmneziaWG 2/3 Obfuscation Parameters
                if (_protocol == ManualProtocol.amneziaWg) ...[
                  const Text(
                    'AmneziaWG 2/3 混淆参数 (Jc / Jmin / Jmax / S1 / S2 / H1-H4)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _jcCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Jc (垃圾包数)',
                            hintText: '4',
                            border: OutlineInputBorder(),
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
                      Expanded(child: TextField(controller: _h1Ctrl, decoration: const InputDecoration(labelText: 'H1', hintText: '1', border: OutlineInputBorder()))),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _h2Ctrl, decoration: const InputDecoration(labelText: 'H2', hintText: '2', border: OutlineInputBorder()))),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _h3Ctrl, decoration: const InputDecoration(labelText: 'H3', hintText: '3', border: OutlineInputBorder()))),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _h4Ctrl, decoration: const InputDecoration(labelText: 'H4', hintText: '4', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Options
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用 UDP 转发'),
                  value: _udp,
                  onChanged: (v) => setState(() => _udp = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('跳过证书校验 (Skip Cert Verify)'),
                  subtitle: const Text('解决自签证书或 TLS 握手报错', style: TextStyle(fontSize: 11)),
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            if (_protocol != ManualProtocol.custom &&
                _protocol != ManualProtocol.direct &&
                _serverCtrl.text.trim().isEmpty) {
              context.showSnackBar('请填写服务器地址');
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
              context.showNotifier('已添加节点: ${proxyMap['name']}');
            }
          },
          child: const Text('保存节点'),
        ),
      ],
    );
  }
}
