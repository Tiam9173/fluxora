import 'package:bett_box/common/common.dart';
import 'package:bett_box/manager/profile_chain_manager.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';

class ProfileChainDialog extends StatefulWidget {
  final Profile profile;

  const ProfileChainDialog({
    super.key,
    required this.profile,
  });

  static Future<void> show(BuildContext context, Profile profile) {
    return showDialog(
      context: context,
      builder: (_) => ProfileChainDialog(profile: profile),
    );
  }

  @override
  State<ProfileChainDialog> createState() => _ProfileChainDialogState();
}

class _ProfileChainDialogState extends State<ProfileChainDialog> {
  late ProfileChainConfig _config;
  final _customPreCtrl = TextEditingController();
  final _customLandingCtrl = TextEditingController();

  List<String> _candidateProxies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _config = profileChainManager.getChain(widget.profile.id);
    _customPreCtrl.text = _config.preProxy ?? '';
    _customLandingCtrl.text = _config.landingProxy ?? '';
    _loadCandidates();
  }

  @override
  void dispose() {
    _customPreCtrl.dispose();
    _customLandingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final candidates = <String>{'🛡️ Cloudflare WARP'};
    try {
      // Gather proxies from current runtime config or profiles
      final currentMap = await globalState.getProfileConfig(widget.profile.id);
      if (currentMap['proxies'] is List) {
        for (final p in currentMap['proxies']) {
          if (p is Map && p['name'] is String) {
            candidates.add(p['name'] as String);
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _candidateProxies = candidates.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final profileName = widget.profile.label ?? widget.profile.id;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.alt_route_rounded, color: Colors.indigoAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '前置与落地代理 · $profileName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _isLoading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topology Diagram Card (v2rayN Style)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hub_rounded, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                '链式路由拓扑预览',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHopNode('设备应用', '本机', Colors.grey),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              _buildHopNode(
                                '前置代理',
                                _config.preProxy?.isNotEmpty == true ? _config.preProxy! : '直连 (无)',
                                _config.preProxy?.isNotEmpty == true ? Colors.blue : Colors.grey,
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              _buildHopNode('订阅节点', '本组节点', Colors.teal),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              _buildHopNode(
                                '落地出口',
                                _config.landingProxy?.isNotEmpty == true ? _config.landingProxy! : '默认 (无)',
                                _config.landingProxy?.isNotEmpty == true ? Colors.deepPurple : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enable Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用此订阅的分组链式代理'),
                      subtitle: const Text('支持前置跳板中继与最终落地出口配置'),
                      value: _config.enable,
                      onChanged: (val) {
                        setState(() => _config = _config.copyWith(enable: val));
                      },
                    ),
                    const Divider(height: 24),

                    // 1. Pre-Proxy (前置代理)
                    Text(
                      '1. 前置代理 (Pre-Proxy)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '流量进入订阅节点前，先经由前置节点穿透中继。可用于拯救被封锁的节点。',
                      style: TextStyle(fontSize: 12, color: colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('preProxy_${_config.preProxy}'),
                      initialValue: _config.preProxy != null && _candidateProxies.contains(_config.preProxy)
                          ? _config.preProxy
                          : (_config.preProxy?.isNotEmpty == true ? 'CUSTOM' : 'NONE'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'NONE', child: Text('无 (直连订阅节点)')),
                        for (final p in _candidateProxies)
                          DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'CUSTOM', child: Text('✏️ 手动输入前置节点名称...')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          if (val == 'NONE') {
                            _config = _config.copyWith(clearPreProxy: true);
                            _customPreCtrl.clear();
                          } else if (val == 'CUSTOM') {
                            // keep text
                          } else if (val != null) {
                            _config = _config.copyWith(preProxy: val);
                            _customPreCtrl.text = val;
                          }
                        });
                      },
                    ),
                    if (_config.preProxy?.isNotEmpty == true &&
                        !_candidateProxies.contains(_config.preProxy)) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customPreCtrl,
                        decoration: const InputDecoration(
                          labelText: '自定义前置节点名称',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _config = _config.copyWith(preProxy: v.trim());
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 2. Landing Proxy (落地代理)
                    Text(
                      '2. 落地代理 (Landing Proxy)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '订阅节点作为前置跳板，最终以此节点为出口。可用于隐藏机场 IP、套 WARP 防送中、解锁 AI 与流媒体。',
                      style: TextStyle(fontSize: 12, color: colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('landingProxy_${_config.landingProxy}'),
                      initialValue: _config.landingProxy != null && _candidateProxies.contains(_config.landingProxy)
                          ? _config.landingProxy
                          : (_config.landingProxy?.isNotEmpty == true ? 'CUSTOM' : 'NONE'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'NONE', child: Text('无 (以订阅节点为最终出口)')),
                        for (final p in _candidateProxies)
                          DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'CUSTOM', child: Text('✏️ 手动输入落地节点名称...')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          if (val == 'NONE') {
                            _config = _config.copyWith(clearLandingProxy: true);
                            _customLandingCtrl.clear();
                          } else if (val == 'CUSTOM') {
                            // keep text
                          } else if (val != null) {
                            _config = _config.copyWith(landingProxy: val);
                            _customLandingCtrl.text = val;
                          }
                        });
                      },
                    ),
                    if (_config.landingProxy?.isNotEmpty == true &&
                        !_candidateProxies.contains(_config.landingProxy)) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customLandingCtrl,
                        decoration: const InputDecoration(
                          labelText: '自定义落地节点名称',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _config = _config.copyWith(landingProxy: v.trim());
                        },
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
            final pre = _customPreCtrl.text.trim();
            final landing = _customLandingCtrl.text.trim();
            final toSave = _config.copyWith(
              preProxy: pre.isNotEmpty ? pre : null,
              landingProxy: landing.isNotEmpty ? landing : null,
              clearPreProxy: pre.isEmpty,
              clearLandingProxy: landing.isEmpty,
            );

            await profileChainManager.updateChain(widget.profile.id, (_) => toSave);
            if (context.mounted) {
              Navigator.of(context).pop();
              context.showNotifier('已保存前置与落地代理设置');
            }
          },
          child: const Text('保存并应用'),
        ),
      ],
    );
  }

  Widget _buildHopNode(String title, String subtitle, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 68,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
