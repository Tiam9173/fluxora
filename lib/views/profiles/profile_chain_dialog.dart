import 'package:fluxora/common/common.dart';
import 'package:fluxora/manager/profile_chain_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/clash/clash.dart';

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

  /// 每个节点的延迟，键是节点名。值 `-1` 表示测过但失败。
  final Map<String, int> _delays = {};
  bool _testingDelays = false;
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
        _seedKnownDelays();
      });
    }
  }

  /// 把已有测量结果读进 `_delays`，让面板一打开就有数字。
  void _seedKnownDelays() {
    final map = globalState.appState.delayMap;
    for (final perUrl in map.values) {
      for (final entry in perUrl.entries) {
        if (!_candidateProxies.contains(entry.key)) continue;
        final value = entry.value;
        if (value == null || value == 0) continue; // 0 = 排队未测，不是结果
        _delays[entry.key] = value;
      }
    }
  }

  /// 逐个测延迟。
  ///
  /// 这些节点属于**当前订阅**，只有正在运行的那个订阅的节点才在内核里，所以
  /// 非活动订阅会全部失败——面板上会显示「—」，不会假装测过。
  Future<void> _testDelays() async {
    if (_testingDelays) return;
    setState(() => _testingDelays = true);
    const int concurrency = 6;
    final url = globalState.appController.getRealTestUrl('');
    try {
      for (var i = 0; i < _candidateProxies.length; i += concurrency) {
        if (!mounted) return;
        final batch = _candidateProxies.skip(i).take(concurrency);
        final results = await Future.wait(batch.map((name) async {
          try {
            final delay = await clashCore.getDelay(url, name);
            return MapEntry(name, delay.value);
          } catch (_) {
            return MapEntry(name, -1);
          }
        }));
        if (!mounted) return;
        setState(() {
          for (final e in results) {
            final value = e.value;
            if (value != null && value != 0) _delays[e.key] = value;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _testingDelays = false);
    }
  }

  /// 延迟徽标：未测不占位，失败显示超时，正常显示毫秒。
  Widget _delayBadge(String name) {
    if (_testingDelays && !_delays.containsKey(name)) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    final value = _delays[name];
    if (value == null) return const SizedBox.shrink();
    final failed = value < 0;
    final color = failed
        ? Colors.redAccent
        : (value < 200 ? Colors.green : (value < 500 ? Colors.orange : Colors.red));
    return Text(
      failed ? appLocalizations.chainTimeout : '${value}ms',
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
    );
  }

  /// 从当前订阅自己的节点里选一个。
  ///
  /// 这里不能用切换卡片：卡片读的是**正在运行**的订阅，而这个对话框编辑的
  /// 是任意一个订阅的链路，用卡片会拿到错的节点列表。所以列表来自
  /// `_candidateProxies`（本订阅配置里的 proxies），再加一个搜索框——节点
  /// 多的时候，下拉列表根本翻不动。
  Future<void> _showProxyPicker({
    required String title,
    required String? current,
    required ValueChanged<String?> onSelect,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var keyword = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final options = _candidateProxies
                .where((n) => keyword.isEmpty || n.toLowerCase().contains(keyword.toLowerCase()))
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
                  TextButton.icon(
                    onPressed: _testingDelays ? null : _testDelays,
                    icon: _testingDelays
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.speed, size: 16),
                    label: Text(appLocalizations.chainSpeedTest, style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: appLocalizations.chainSearchNode,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setLocal(() => keyword = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.block, size: 18),
                            title: Text(appLocalizations.chainNoneDirect,
                                style: TextStyle(fontSize: 13)),
                            trailing: (current == null || current.isEmpty)
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onTap: () => Navigator.of(ctx).pop(''),
                          ),
                          for (final name in options)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.dns_outlined, size: 18),
                              title: Text(name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _delayBadge(name),
                                  if (name == current) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check, size: 18),
                                  ],
                                ],
                              ),
                              onTap: () => Navigator.of(ctx).pop(name),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(appLocalizations.cancel),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null) onSelect(selected.isEmpty ? null : selected);
  }

  /// Shows what a section actually does.
  ///
  /// The explanation used to sit under every title, which pushed the pickers
  /// below the fold on a phone. It is one tap away instead.
  void _showSectionHelp(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(appLocalizations.confirm),
          ),
        ],
      ),
    );
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
              appLocalizations.profileChainDialogTitle(profileName),
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
                                appLocalizations.chainTopologyPreview,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // 横向滚动而不是压缩：窄屏时四个节点会被挤成
                          // 一列小方块，字都截断。宁可滑动，也不缩水。
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // RC.8: each node is `Flexible` so the row shrinks
                              // with the dialog instead of overflowing. The bare
                              // Row overflowed by 112 px at 360 px width.
                              SizedBox(
                                width: 96,
                                child: _buildHopNode(
                                  appLocalizations.chainNodeDeviceApp,
                                  appLocalizations.chainNodeLocal,
                                  Colors.grey,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              SizedBox(
                                width: 96,
                                child: _buildHopNode(
                                  appLocalizations.chainNodePreProxy,
                                  _config.preProxy?.isNotEmpty == true ? _config.preProxy! : appLocalizations.chainPreProxyNone,
                                  _config.preProxy?.isNotEmpty == true ? Colors.blue : Colors.grey,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              SizedBox(
                                width: 96,
                                child: _buildHopNode(
                                  appLocalizations.chainNodeSubscription,
                                  appLocalizations.chainNodeGroupNodes,
                                  Colors.teal,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              SizedBox(
                                width: 96,
                                child: _buildHopNode(
                                  appLocalizations.roleExit,
                                  _config.landingProxy?.isNotEmpty == true ? _config.landingProxy! : appLocalizations.chainLandingProxyNone,
                                  _config.landingProxy?.isNotEmpty == true ? Colors.deepPurple : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enable Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(appLocalizations.enableProfileChain),
                      subtitle: Text(appLocalizations.enableProfileChainDesc),
                      value: _config.enable,
                      onChanged: (val) {
                        setState(() => _config = _config.copyWith(enable: val));
                      },
                    ),
                    const Divider(height: 24),

                    // 1. Pre-Proxy (前置代理)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appLocalizations.preProxySectionTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.info_outline, size: 16),
                          onPressed: () => _showSectionHelp(
                            appLocalizations.preProxySectionTitle,
                            appLocalizations.preProxySectionDesc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListItem(
                      leading: const Icon(Icons.hub_outlined),
                      title: Text(
                        _config.preProxy?.isNotEmpty == true
                            ? _config.preProxy!
                            : appLocalizations.preProxyOptionNone,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showProxyPicker(
                        title: appLocalizations.preProxySectionTitle,
                        current: _config.preProxy,
                        onSelect: (val) => setState(() {
                          if (val == null) {
                            _config = _config.copyWith(clearPreProxy: true);
                            _customPreCtrl.clear();
                          } else {
                            _config = _config.copyWith(preProxy: val);
                            _customPreCtrl.text = val;
                          }
                        }),
                      ),
                    ),
                    if (_config.preProxy?.isNotEmpty == true &&
                        !_candidateProxies.contains(_config.preProxy)) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customPreCtrl,
                        decoration: InputDecoration(
                          labelText: appLocalizations.customPreProxyName,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _config = _config.copyWith(preProxy: v.trim());
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 2. Landing Proxy (落地代理)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appLocalizations.landingProxySectionTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.info_outline, size: 16),
                          onPressed: () => _showSectionHelp(
                            appLocalizations.landingProxySectionTitle,
                            appLocalizations.landingProxySectionDesc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListItem(
                      leading: const Icon(Icons.flight_land_outlined),
                      title: Text(
                        _config.landingProxy?.isNotEmpty == true
                            ? _config.landingProxy!
                            : appLocalizations.landingProxyOptionNone,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showProxyPicker(
                        title: appLocalizations.landingProxySectionTitle,
                        current: _config.landingProxy,
                        onSelect: (val) => setState(() {
                          if (val == null) {
                            _config = _config.copyWith(clearLandingProxy: true);
                            _customLandingCtrl.clear();
                          } else {
                            _config = _config.copyWith(landingProxy: val);
                            _customLandingCtrl.text = val;
                          }
                        }),
                      ),
                    ),
                    if (_config.landingProxy?.isNotEmpty == true &&
                        !_candidateProxies.contains(_config.landingProxy)) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customLandingCtrl,
                        decoration: InputDecoration(
                          labelText: appLocalizations.customLandingProxyName,
                          border: const OutlineInputBorder(),
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
          child: Text(appLocalizations.cancel),
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
              context.showNotifier(appLocalizations.profileChainSaved);
            }
          },
          child: Text(appLocalizations.saveAndApply),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 3),
        // RC.8: a hard `SizedBox(width: 68)` refused to shrink, which is what
        // forced the row past the dialog width. `maxWidth` keeps the layout but
        // lets the node contract.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 68),
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
