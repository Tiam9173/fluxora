import 'package:fluxora/common/common.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/manager/warp_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/warp_config.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/providers/warp.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/manager/warp_clean_ip_scanner.dart';
import 'package:fluxora/views/proxies/chain_hop_picker.dart';
import 'package:fluxora/l10n/l10n.dart';

String _modeLabel(WarpMode m, AppLocalizations l) => switch (m) {
  WarpMode.googleAndAi => l.warpModeSmart,
  WarpMode.all => l.warpModeAll,
  WarpMode.custom => l.warpModeCustom,
};

String _coloCityLabel(WarpStatusReport report) {
  final city = report.coloCityName;
  if (city.startsWith('边缘节点 ')) {
    return appLocalizations.warpEdgeNode(report.colo);
  }
  if (city == '未知边缘节点') return appLocalizations.warpUnknownColo;
  return city;
}

String _routingLabel(WarpRoutingMode m, AppLocalizations l) => switch (m) {
  WarpRoutingMode.warpOverProxy => l.warpRouteWarpOverProxy,
  WarpRoutingMode.proxyOverWarp => l.warpRouteProxyOverWarp,
};


String _modeDesc(WarpMode m, AppLocalizations l) => switch (m) {
  WarpMode.googleAndAi => l.warpModeSmartDesc,
  WarpMode.all => l.warpModeAllDesc,
  WarpMode.custom => l.warpModeCustomDesc,
};

class WarpView extends ConsumerStatefulWidget {
  final SheetType? type;
  const WarpView({super.key, this.type});

  @override
  ConsumerState<WarpView> createState() => _WarpViewState();
}

class _WarpViewState extends ConsumerState<WarpView> {
  bool _isGuideExpanded = false;

  @override
  void initState() {
    super.initState();
    warpManager.init();
  }

  void _showHopPickerSheet({
    required WarpConfig config,
    required String currentHop,
    required Function(String) onSelect,
  }) {
    // B4.1: derive the internal group names from live state instead of
    // hard-coding them — the chain group and the WARP exit group are both
    // user-configurable (`ChainProxyConfig.dedicatedGroupName` /
    // `WarpConfig.dedicatedGroupName`), so a literal would silently stop
    // matching once the user renames them.
    final chainGroupName = chainProxyManager.config.dedicatedGroupName;
    final warpExitGroupName = config.dedicatedGroupName;
    // The WARP hop group is the single exception: its only definition is a
    // function-local `const` inside `warp_config.dart` that is not exported, so
    // there is no accessible source to reference.
    const warpHopGroupName = WarpConfig.warpHopGroupName;

    bool isInternalGroup(String name) =>
        name == chainGroupName ||
        name == warpExitGroupName ||
        name == warpHopGroupName;

    final groups = ref.read(groupsProvider);
    final groupNames = groups
        .map((g) => g.name)
        .where((name) => !isInternalGroup(name))
        .toList();

    final allProxies = <String>{};
    for (final g in groups) {
      if (isInternalGroup(g.name)) {
        continue;
      }
      for (final p in g.all) {
        // B4.1: reuse the shared classification rule — built-in policies
        // (DIRECT / REJECT / PASS / COMPATIBLE …), proxy groups and chain shadow
        // nodes are not ordinary nodes; unknown types are kept. The WARP-specific
        // exclusion is retained, but against the LIVE `proxyName` so a renamed
        // WARP outbound can never be offered as its own dialer.
        if (ChainProxyConfig.isSelectableProxy(name: p.name, type: p.type) &&
            p.name != config.proxyName) {
          allProxies.add(p.name);
        }
      }
    }
    final proxyList = allProxies.toList()..sort();

    showSheet(
      context: context,
      props: SheetProps(isScrollControlled: true),
      builder: (ctx, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: appLocalizations.warpStr98,
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // 和链式跳板用同一套视觉：圆角卡片 + 带底色的图标块 + 右侧对勾。
              _hopOption(
                icon: Icons.grid_view_rounded,
                color: Colors.teal,
                title: appLocalizations.warpStr28,
                subtitle: appLocalizations.warpStr27,
                onTap: () {
                  Navigator.of(ctx).pop();
                  showChainHopPicker(
                    context: context,
                    title: appLocalizations.warpStr98,
                    excludeNames: {config.proxyName},
                    onSelect: onSelect,
                  );
                },
              ),
              _hopOption(
                icon: Icons.auto_mode,
                color: Colors.blue,
                title: appLocalizations.warpStr20,
                subtitle: appLocalizations.warpStr86,
                selected: currentHop.isEmpty,
                onTap: () {
                  onSelect('');
                  Navigator.of(ctx).pop();
                },
              ),
              _hopOption(
                icon: Icons.directions,
                color: Colors.green,
                title: appLocalizations.warpStr6,
                subtitle: '不经过机场直接连接 WARP（需本地网络未屏蔽 CF Anycast IP）',
                selected: currentHop == 'DIRECT',
                onTap: () {
                  onSelect('DIRECT');
                  Navigator.of(ctx).pop();
                },
              ),
              if (groupNames.isNotEmpty) ...[
                _hopSection(appLocalizations.warpStr84),
                for (final g in groupNames)
                  _hopOption(
                    icon: Icons.folder_outlined,
                    color: Colors.amber,
                    title: g,
                    selected: currentHop == g,
                    onTap: () {
                      onSelect(g);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
              if (proxyList.isNotEmpty) ...[
                _hopSection(appLocalizations.warpStr63),
                for (final p in proxyList)
                  _hopOption(
                    icon: Icons.flight_takeoff,
                    color: Colors.indigo,
                    title: p,
                    selected: currentHop == p,
                    onTap: () {
                      onSelect(p);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 分区标题：和卡片之间的间距保持一致。
  Widget _hopSection(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 单个可选项：圆角卡片 + 带底色的图标块，和链式跳板的 SwitchCard 一致。
  Widget _hopOption({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoutingModeDialog(WarpConfig config) {
    var selected = config.routingMode;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text(
                appLocalizations.warpStr13,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: RadioGroup<WarpRoutingMode>(
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() => selected = val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<WarpRoutingMode>(
                      value: WarpRoutingMode.proxyOverWarp,
                      title: Text(appLocalizations.warpStr100),
                      subtitle: Text(appLocalizations.warpStr71),
                    ),
                    RadioListTile<WarpRoutingMode>(
                      value: WarpRoutingMode.warpOverProxy,
                      title: Text(appLocalizations.warpStr101),
                      subtitle: Text(appLocalizations.warpStr72),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    warpManager.setRoutingMode(WarpRoutingMode.warpOverProxy);
                    Navigator.of(ctx).pop();
                    context.showSnackBar(appLocalizations.warpStr56);
                  },
                  child: Text(appLocalizations.warpStr103),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(appLocalizations.warpStr42),
                ),
                FilledButton(
                  onPressed: () {
                    warpManager.setRoutingMode(selected);
                    Navigator.of(ctx).pop();
                    context.showSnackBar(
                      appLocalizations.warpSwitchedTo(selected.label),
                    );
                  },
                  child: Text(appLocalizations.warpStr78),
                ),
              ],
            );
          },
        );
      },
    );
  }


  /// Probes a spread of Cloudflare endpoints and lets the user pick the fastest.
  ///
  /// Kept as a dialog rather than a background job: the numbers depend on the
  /// network at this moment, so a result the user did not just watch being
  /// measured would be misleading.
  void _showCleanIpScanDialog(TextEditingController ctrl) {
    var scanning = true;
    var started = false;
    var done = 0;
    var total = 0;
    List<CleanIpResult> results = const [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (scanning && !started) {
              started = true;
              final candidates = WarpCleanIpScanner.defaultCandidates();
              total = candidates.length;
              warpCleanIpScanner
                  .scan(
                    candidates,
                    onProgress: (d, t) {
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        done = d;
                        total = t;
                      });
                    },
                  )
                  .then((value) {
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      results = value;
                      scanning = false;
                    });
                  });
            }

            final reachable = results.where((r) => r.ok).take(8).toList();

            return AlertDialog(
              title: Text(appLocalizations.warpStr33),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        appLocalizations.warpStr60,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    if (scanning)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '正在探测 Cloudflare 节点… $done/$total',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: total == 0 ? null : done / total,
                          ),
                        ],
                      )
                    else if (reachable.isEmpty)
                      Text(
                        appLocalizations.warpStr70,
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final r in reachable)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    r.ip,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  trailing: Text(
                                    '${r.latencyMs} ms',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: r.latencyMs! < 100
                                          ? Colors.green
                                          : r.latencyMs! < 200
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                  onTap: () {
                                    ctrl.text = r.ip;
                                    Navigator.of(ctx).pop();
                                    context.showSnackBar(appLocalizations.warpIpChosen(r.ip));
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: scanning ? null : () => Navigator.of(ctx).pop(),
                  child: Text(appLocalizations.warpStr38),
                ),
                if (!scanning && reachable.isNotEmpty)
                  FilledButton(
                    onPressed: () {
                      ctrl.text = reachable.first.ip;
                      Navigator.of(ctx).pop();
                      context.showSnackBar(
                        appLocalizations.warpFastestChosen(reachable.first.ip),
                      );
                    },
                    child: Text(appLocalizations.warpStr36),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCleanIpDialog(WarpConfig config) {
    final ctrl = TextEditingController(text: config.cleanIp);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('优选 IP (Clean IP)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appLocalizations.warpStr94,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                appLocalizations.warpStr34,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: appLocalizations.warpStr30,
                  hintText: appLocalizations.warpStr17,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.auto_awesome),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(appLocalizations.warpStr16),
                    onPressed: () => ctrl.text = 'auto',
                  ),
                  ActionChip(
                    label: const Text('162.159.193.1'),
                    onPressed: () => ctrl.text = '162.159.193.1',
                  ),
                  ActionChip(
                    label: const Text('188.114.96.1'),
                    onPressed: () => ctrl.text = '188.114.96.1',
                  ),
                  ActionChip(
                    label: const Text('162.159.192.1'),
                    onPressed: () => ctrl.text = '162.159.192.1',
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                warpManager.setCleanIp('auto');
                Navigator.of(ctx).pop();
                context.showSnackBar(appLocalizations.warpStr32);
              },
              child: Text(appLocalizations.warpStr103),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCleanIpScanDialog(ctrl);
              },
              child: Text(appLocalizations.warpStr24),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.warpStr42),
            ),
            FilledButton(
              onPressed: () {
                final val = ctrl.text.trim();
                warpManager.setCleanIp(val.isEmpty ? 'auto' : val);
                Navigator.of(ctx).pop();
                context.showSnackBar(appLocalizations.warpStr31);
              },
              child: Text(appLocalizations.warpStr37),
            ),
          ],
        );
      },
    );
  }

  void _showPortDialog(WarpConfig config) {
    final ctrl = TextEditingController(
      text: config.port == 0 ? '0' : config.port.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(appLocalizations.warpStr80),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appLocalizations.warpStr93,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: appLocalizations.warpStr81,
                  hintText: '0, 2408, 500, 1701, 4500',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.device_hub),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(appLocalizations.warpStr0),
                    onPressed: () => ctrl.text = '0',
                  ),
                  ActionChip(
                    label: const Text('2408'),
                    onPressed: () => ctrl.text = '2408',
                  ),
                  ActionChip(
                    label: const Text('500'),
                    onPressed: () => ctrl.text = '500',
                  ),
                  ActionChip(
                    label: const Text('1701'),
                    onPressed: () => ctrl.text = '1701',
                  ),
                  ActionChip(
                    label: const Text('4500'),
                    onPressed: () => ctrl.text = '4500',
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                warpManager.setPort(0);
                Navigator.of(ctx).pop();
                context.showSnackBar(appLocalizations.warpStr83);
              },
              child: Text(appLocalizations.warpStr103),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.warpStr42),
            ),
            FilledButton(
              onPressed: () {
                final p = int.tryParse(ctrl.text.trim()) ?? 0;
                warpManager.setPort(p);
                Navigator.of(ctx).pop();
                context.showSnackBar(appLocalizations.warpStr82);
              },
              child: Text(appLocalizations.warpStr37),
            ),
          ],
        );
      },
    );
  }

  void _showLicenseDialog(WarpConfig config) {
    final ctrl = TextEditingController(text: config.licenseKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocalizations.warpStr85),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '输入您的 24 位 WARP+ License 密钥（例如通过 1.1.1.1 机器人、促销或购买获得）：',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'License Key (24 位字符)',
                hintText: 'xxxx-xxxx-xxxx-xxxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(appLocalizations.warpStr42),
          ),
          if (config.licenseKey.isNotEmpty)
            TextButton(
              onPressed: () {
                warpManager.setLicenseKey('');
                Navigator.of(ctx).pop();
                context.showSnackBar(appLocalizations.warpStr53);
              },
              child: Text(appLocalizations.warpStr91),
            ),
          FilledButton(
            onPressed: () async {
              final lic = ctrl.text.trim();
              Navigator.of(ctx).pop();
              context.showSnackBar(appLocalizations.warpStr69);
              final success = await warpManager.registerCloudflareAccount(
                license: lic,
              );
              if (mounted) {
                if (success) {
                  context.showSnackBar(appLocalizations.warpStr105);
                } else {
                  context.showSnackBar(appLocalizations.warpStr49);
                  warpManager.setLicenseKey(lic);
                }
              }
            },
            child: Text(appLocalizations.warpStr73),
          ),
        ],
      ),
    );
  }

  void _showKeyDetailsDialog(WarpConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocalizations.warpStr15),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyField(appLocalizations.warpStr45, config.privateKey),
              const SizedBox(height: 12),
              _buildKeyField(appLocalizations.warpStr44, config.publicKey),
              const SizedBox(height: 12),
              _buildKeyField(appLocalizations.warpStr5, config.peerPublicKey),
              const SizedBox(height: 12),
              _buildKeyField(appLocalizations.warpStr46, config.reserved.toString()),
              const SizedBox(height: 12),
              _buildKeyField(appLocalizations.warpStr88, config.ip),
              const SizedBox(height: 12),
              _buildKeyField(appLocalizations.warpStr89, config.ipv6),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await warpManager.generateNewKeys();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (mounted) {
                context.showSnackBar(appLocalizations.warpStr55);
              }
            },
            child: Text(appLocalizations.warpStr102),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(appLocalizations.warpStr38),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value.isNotEmpty ? value : appLocalizations.warpStr62,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  context.showSnackBar(appLocalizations.warpCopied(label));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(warpProvider);
    final config = manager.config;
    final report = manager.latestReport;
    final isTesting = manager.isTesting;
    final isRegistering = manager.isRegistering;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final actions = [
      IconButton(
        tooltip: appLocalizations.warpStr26,
        icon: isTesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.speed),
        onPressed: isTesting ? null : () => warpManager.checkWarpStatus(),
      ),
      IconButton(
        tooltip: appLocalizations.warpStr104,
        icon: const Icon(Icons.restart_alt),
        onPressed: () async {
          await warpManager.resetConfig();
          if (context.mounted) {
            context.showSnackBar(appLocalizations.warpStr12);
          }
        },
      ),
      IconButton(
        tooltip: appLocalizations.warpStr35,
        icon: Icon(
          _isGuideExpanded ? Icons.info : Icons.info_outline,
          color: _isGuideExpanded ? colorScheme.primary : null,
        ),
        onPressed: () => setState(() => _isGuideExpanded = !_isGuideExpanded),
      ),
    ];

    final body = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Usage Guide Card (Collapsible)
        if (_isGuideExpanded) _buildGuideCard(colorScheme),

        // 2. Visual Diagnostic Card (Hero Card)
        _buildDiagnosticHeroCard(report, config, isTesting, colorScheme),

        const SizedBox(height: 16),

        // 3. Main Settings List
        _buildSettingsCard(config, isRegistering, colorScheme),

        const SizedBox(height: 16),

        // 4. Contextual Routing Configuration Card
        if (config.routingMode == WarpRoutingMode.warpOverProxy) ...[
          _buildHopSelectorCard(config, colorScheme),
          const SizedBox(height: 16),
          _buildModeSelectorCard(config, colorScheme),
          const SizedBox(height: 16),
        ] else ...[
          _buildProxyOverWarpNoticeCard(colorScheme),
          const SizedBox(height: 16),
        ],

        // 5. Account, Keys & Advanced Card
        _buildAccountCard(config, isRegistering, colorScheme),

        const SizedBox(height: 32),
      ],
    );

    if (widget.type != null) {
      return AdaptiveSheetScaffold(
        type: widget.type!,
        title: 'WARP',
        actions: actions,
        body: body,
      );
    }

    return CommonScaffold(title: 'WARP', actions: actions, body: body);
  }

  Widget _buildGuideCard(ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  appLocalizations.warpStr108,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '• 通过代理路由 WARP (推荐)：流量经机场节点中转后再接入 Cloudflare WireGuard 网络，隐藏机场落地机房 IP，获得干净 Anycast 出口，彻底规避 Google Captcha 人机验证并解锁 ChatGPT、Claude 及流媒体。\n'
              '• 通过 WARP 路由代理：流量先通过 WARP 隧道穿透，再连向机场代理节点。当机场节点服务器 IP 在国内被封锁阻断时，WARP 作为前置穿透通道拯救被封节点！\n'
              '• 优选 IP 支持：国内网络若直连官方 IP 缓慢，可在「优选 IP」输入低延迟 Cloudflare IP，实现流畅加速。\n'
              '• 真实诊断核验：顶部卡片直连 Cloudflare cdn-cgi/trace 深度检测，实时显示 warp=on/plus 状态、出口 IP 与 Google 防送中评定。',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticHeroCard(
    WarpStatusReport? report,
    WarpConfig config,
    bool isTesting,
    ColorScheme colorScheme,
  ) {
    final bool isWarp = report?.isWarpActive ?? false;
    final bool isPlus = report?.warpType == 'plus';
    final Color badgeColor = isWarp
        ? (isPlus ? Colors.amber : Colors.green)
        : (report?.isSuccess == true ? Colors.blue : Colors.grey);

    final statusText = isWarp
        ? (isPlus ? appLocalizations.warpStr14 : 'WARP 正常接管保护中 (warp=on)')
        : (report == null
              ? appLocalizations.warpStr48
              : (report.isSuccess ? appLocalizations.warpStr77 : appLocalizations.warpStr97));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [badgeColor.withValues(alpha: 0.12), colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWarp ? badgeColor : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (report?.latencyMs != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${report!.latencyMs} ms',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const Divider(height: 24),

            // Diagnostic Grid: IP, Colo, Anti-Redirect, AI
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: appLocalizations.warpStr40,
                    value: report?.ip.isNotEmpty == true
                        ? report!.ip
                        : (config.enable ? appLocalizations.warpStr65 : appLocalizations.warpStr61),
                    subtitle: 'Cloudflare Anycast',
                    icon: Icons.public,
                    onCopy: report?.ip.isNotEmpty == true ? report!.ip : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: appLocalizations.warpStr96,
                    // 城市名保留模型里的中英对照；只有"未知/边缘节点"这种
                    // 兜底文案需要跟随语言。
                    value: report?.colo.isNotEmpty == true
                        ? '${report!.colo} (${_coloCityLabel(report)})'
                        : appLocalizations.warpStr58,
                    subtitle: report?.loc.isNotEmpty == true
                        ? appLocalizations.warpRegion(report!.loc)
                        : 'Anycast 节点',
                    icon: Icons.business,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: appLocalizations.warpStr7,
                    value: report?.isGoogleAntiRedirect == true
                        ? appLocalizations.warpStr109
                        : (report == null ? appLocalizations.warpStr58 : appLocalizations.warpStr18),
                    subtitle: report?.googleStatus ?? appLocalizations.warpStr90,
                    icon: Icons.search,
                    valueColor: report?.isGoogleAntiRedirect == true
                        ? Colors.green
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: appLocalizations.warpStr4,
                    value: isWarp ? appLocalizations.warpStr111 : appLocalizations.warpStr95,
                    subtitle: 'OpenAI / Claude / Gemini',
                    icon: Icons.psychology,
                    valueColor: isWarp ? Colors.green : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flash_on, size: 18),
                    label: Text(isTesting ? appLocalizations.warpStr67 : appLocalizations.warpStr19),
                    onPressed: isTesting
                        ? null
                        : () async {
                            final res = await warpManager.checkWarpStatus();
                            if (mounted) {
                              if (res.isWarpActive) {
                                context.showSnackBar(
                                  appLocalizations.warpDiagOk(res.colo, res.ip),
                                );
                              } else if (res.isSuccess) {
                                context.showSnackBar(
                                  appLocalizations.warpNoSignature(res.ip),
                                );
                              } else {
                                context.showSnackBar(res.googleStatus);
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    String? onCopy,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCopy != null)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: onCopy));
                    context.showSnackBar(appLocalizations.warpCopied(onCopy));
                  },
                  child: const Icon(Icons.copy, size: 13, color: Colors.blue),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Main Settings Card layout
  Widget _buildSettingsCard(
    WarpConfig config,
    bool isRegistering,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // 1. 启用 WARP
          SwitchListTile(
            secondary: Icon(Icons.cloud, color: colorScheme.primary),
            title: Text(
              appLocalizations.warpStr43,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              config.enable ? appLocalizations.warpStr51 : appLocalizations.warpStr74,
              style: TextStyle(
                fontSize: 12,
                color: config.enable ? colorScheme.primary : Colors.grey,
              ),
            ),
            value: config.enable,
            onChanged: (val) {
              warpManager.setEnable(val);
              context.showSnackBar(val ? appLocalizations.warpStr52 : appLocalizations.warpStr50);
            },
          ),
          const Divider(height: 1),

          // 2. 生成 WARP 配置
          ListTile(
            leading: Icon(Icons.build_rounded, color: colorScheme.primary),
            title: Text(appLocalizations.warpStr75),
            subtitle: isRegistering
                ? Text(
                    appLocalizations.warpStr66,
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  )
                : Text(
                    config.accountId.isNotEmpty
                        ? '设备已就绪 (ID: ${config.accountId})，点击可重新生成'
                        : appLocalizations.warpStr25,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
            trailing: isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: isRegistering
                ? null
                : () async {
                    context.showSnackBar(appLocalizations.warpStr68);
                    final ok = await warpManager.registerCloudflareAccount();
                    if (mounted) {
                      if (ok) {
                        context.showSnackBar(appLocalizations.warpStr106);
                      } else {
                        context.showSnackBar(appLocalizations.warpStr76);
                      }
                    }
                  },
          ),
          const Divider(height: 1),

          // 3. WARP 路由模式
          ListTile(
            leading: Icon(Icons.alt_route_rounded, color: colorScheme.primary),
            title: Text(appLocalizations.warpStr13),
            subtitle: Text(
              _routingLabel(config.routingMode, appLocalizations),
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showRoutingModeDialog(config),
          ),
          const Divider(height: 1),

          // 4. 许可证密钥
          ListTile(
            leading: Icon(Icons.vpn_key_rounded, color: colorScheme.primary),
            title: Text(appLocalizations.warpStr92),
            subtitle: Text(
              config.licenseKey.isEmpty
                  ? appLocalizations.warpStr62
                  : (config.accountType == 'plus'
                        ? '👑 WARP+ (已激活): ${config.licenseKey}'
                        : config.licenseKey),
              style: TextStyle(
                fontSize: 12,
                color: config.licenseKey.isEmpty
                    ? Colors.grey
                    : colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showLicenseDialog(config),
          ),
          const Divider(height: 1),

          // 5. 优选 IP
          ListTile(
            leading: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.primary,
            ),
            title: Text(appLocalizations.warpStr29),
            subtitle: Text(
              config.cleanIp.isEmpty ? 'auto' : config.cleanIp,
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showCleanIpDialog(config),
          ),
          const Divider(height: 1),

          // 6. 端口
          ListTile(
            leading: Icon(Icons.device_hub_rounded, color: colorScheme.primary),
            title: Text(appLocalizations.warpStr79),
            subtitle: Text(
              config.port == 0 ? '0' : config.port.toString(),
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showPortDialog(config),
          ),
          const Divider(height: 1),

        ],
      ),
    );
  }

  Widget _buildProxyOverWarpNoticeCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: Colors.blue.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                appLocalizations.warpStr57,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectorCard(WarpConfig config, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  appLocalizations.warpModeTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RadioGroup<WarpMode>(
              groupValue: config.mode,
              onChanged: (val) {
                if (val != null) {
                  warpManager.setMode(val);
                  context.showSnackBar(
                    appLocalizations.warpSwitchedTo(val.label),
                  );
                }
              },
              child: Column(
                children: [
                  for (final m in WarpMode.values)
                    RadioListTile<WarpMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _modeLabel(m, appLocalizations),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _modeDesc(m, appLocalizations),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      value: m,
                    ),
                ],
              ),
            ),
            if (config.mode == WarpMode.custom) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.rule, color: colorScheme.primary),
                title: Text(appLocalizations.warpStr87),
                subtitle: Text(
                  config.customRules.isEmpty
                      ? appLocalizations.warpStr47
                      : '已配置 ${config.customRules.length} 条规则',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _showCustomRulesDialog(config),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Editor for [WarpMode.custom] rules. One complete Clash rule per line —
  /// the rules are prepended verbatim, so a half-written rule would be a
  /// config error rather than a silently ignored preference.
  void _showCustomRulesDialog(WarpConfig config) {
    final ctrl = TextEditingController(
      text: config.customRules.join('\n'),
    );
    final group = config.dedicatedGroupName.trim().isEmpty
        ? WarpConfig.defaultDedicatedGroupName
        : config.dedicatedGroupName;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(appLocalizations.warpStr87),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每行一条完整 Clash 规则，例如：\n'
                  'DOMAIN-SUFFIX,openai.com,$group',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: 'DOMAIN-SUFFIX,example.com,$group',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.warpStr42),
            ),
            FilledButton(
              onPressed: () {
                final lines = ctrl.text
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList();
                warpManager.setCustomRules(lines);
                Navigator.of(ctx).pop();
                context.showSnackBar('已保存 ${lines.length} 条自定义规则');
              },
              child: Text(appLocalizations.warpStr37),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHopSelectorCard(WarpConfig config, ColorScheme colorScheme) {
    final hopName = config.defaultDialerProxy.isEmpty
        ? appLocalizations.warpStr21
        : (config.defaultDialerProxy == 'DIRECT'
              ? appLocalizations.warpStr6
              : '✈️ 指定前置节点: ${config.defaultDialerProxy}');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.flight_takeoff, color: colorScheme.primary),
        title: Text(
          appLocalizations.warpStr41,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          hopName,
          style: TextStyle(fontSize: 12, color: colorScheme.primary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          _showHopPickerSheet(
            config: config,
            currentHop: config.defaultDialerProxy,
            onSelect: (selected) {
              warpManager.setDefaultDialer(selected);
              context.showSnackBar(
                selected.isEmpty ? appLocalizations.warpStr54 : appLocalizations.warpDialerSet(selected),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(
    WarpConfig config,
    bool isRegistering,
    ColorScheme colorScheme,
  ) {
    final accountText = config.accountType == 'plus'
        ? appLocalizations.warpStr107
        : (config.accountId.isNotEmpty ? appLocalizations.warpStr110 : appLocalizations.warpStr22);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appLocalizations.warpStr11,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    accountText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '端点: ${config.effectiveServer}:${config.effectivePort} | MTU: ${config.mtu} | Reserved: ${config.reserved}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined, size: 16),
                  label: Text(appLocalizations.warpStr64),
                  onPressed: () => _showKeyDetailsDialog(config),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.compress, size: 16),
                  label: Text('MTU: ${config.mtu}'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: Text(appLocalizations.warpStr99),
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1280);
                              Navigator.of(ctx).pop();
                              context.showSnackBar(appLocalizations.warpStr8);
                            },
                            child: Text(appLocalizations.warpStr1),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1360);
                              Navigator.of(ctx).pop();
                              context.showSnackBar(appLocalizations.warpStr9);
                            },
                            child: Text(appLocalizations.warpStr2),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1420);
                              Navigator.of(ctx).pop();
                              context.showSnackBar(appLocalizations.warpStr10);
                            },
                            child: Text(appLocalizations.warpStr3),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
