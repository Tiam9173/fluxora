import 'package:bett_box/common/common.dart';
import 'package:bett_box/manager/warp_manager.dart';
import 'package:bett_box/models/warp_config.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/providers/warp.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required String currentHop,
    required Function(String) onSelect,
  }) {
    final groups = ref.read(groupsProvider);
    final groupNames = groups
        .map((g) => g.name)
        .where((name) =>
            name != '🔗 链式代理' &&
            name != '🛡️ WARP 出口' &&
            name != '✈️ WARP跳板')
        .toList();

    final allProxies = <String>{};
    for (final g in groups) {
      if (g.name == '🔗 链式代理' ||
          g.name == '🛡️ WARP 出口' ||
          g.name == '✈️ WARP跳板') {
        continue;
      }
      for (final p in g.all) {
        if (p.name != 'DIRECT' &&
            p.name != 'REJECT' &&
            p.name != 'REJECT-DROP' &&
            p.name != 'PASS' &&
            p.name != WarpConfig.defaultProxyName) {
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
          title: '选择 WARP 前置跳板',
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.auto_mode, color: Colors.blue),
                title: const Text('⚡ 跟随后台主选择 (推荐)'),
                subtitle: const Text('自动匹配您在控制面板中选中的当前机场节点'),
                trailing: currentHop.isEmpty
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  onSelect('');
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions, color: Colors.green),
                title: const Text('DIRECT (直连 Cloudflare)'),
                subtitle: const Text('不经过机场直接连接 WARP（需本地网络未屏蔽 CF Anycast IP）'),
                trailing: currentHop == 'DIRECT'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  onSelect('DIRECT');
                  Navigator.of(ctx).pop();
                },
              ),
              if (groupNames.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '策略组',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                for (final g in groupNames)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(g),
                    trailing: currentHop == g
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onSelect(g);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
              if (proxyList.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '机场代理节点',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                for (final p in proxyList)
                  ListTile(
                    leading: const Icon(Icons.flight_takeoff, size: 20),
                    title: Text(p),
                    trailing: currentHop == p
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
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

  void _showRoutingModeDialog(WarpConfig config) {
    var selected = config.routingMode;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text(
                'WARP 路由模式',
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
                      title: const Text('通过 WARP 路由代理'),
                      subtitle: const Text('流量先经过 WARP 再连接代理节点，用于节点被阻断时救砖'),
                    ),
                    RadioListTile<WarpRoutingMode>(
                      value: WarpRoutingMode.warpOverProxy,
                      title: const Text('通过代理路由 WARP'),
                      subtitle: const Text('流量经代理节点后再连 WARP 出口，用于防送中与解锁 AI'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    warpManager.setRoutingMode(WarpRoutingMode.warpOverProxy);
                    Navigator.of(ctx).pop();
                    context.showSnackBar('已重置为默认「通过代理路由 WARP」');
                  },
                  child: const Text('重置'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    warpManager.setRoutingMode(selected);
                    Navigator.of(ctx).pop();
                    context.showSnackBar('已切换为 ${selected.label}');
                  },
                  child: const Text('确定'),
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
              const Text(
                '设置连接 Cloudflare WARP 的优选 IP，输入 auto 则自动使用官方最优 IP：',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: '优选 IP / 域名',
                  hintText: 'auto 或例如 162.159.193.1',
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
                    label: const Text('auto (默认)'),
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
                context.showSnackBar('优选 IP 已重置为 auto');
              },
              child: const Text('重置'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final val = ctrl.text.trim();
                warpManager.setCleanIp(val.isEmpty ? 'auto' : val);
                Navigator.of(ctx).pop();
                context.showSnackBar('优选 IP 已保存');
              },
              child: const Text('保存'),
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
          title: const Text('端口 (Port)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置 WireGuard 端口（0 为默认 2408 端口）：',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '端口号',
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
                    label: const Text('0 (默认 2408)'),
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
                context.showSnackBar('端口已重置为 0 (默认 2408)');
              },
              child: const Text('重置'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final p = int.tryParse(ctrl.text.trim()) ?? 0;
                warpManager.setPort(p);
                Navigator.of(ctx).pop();
                context.showSnackBar('端口已更新');
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showNoiseDialog(WarpConfig config) {
    final countCtrl = TextEditingController(text: config.noiseCount);
    final modeCtrl = TextEditingController(text: config.noiseMode);
    final sizeCtrl = TextEditingController(text: config.noiseSize);
    final delayCtrl = TextEditingController(text: config.noiseDelay);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('噪声与伪装参数'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: countCtrl,
                  decoration: const InputDecoration(
                    labelText: '噪声数量',
                    hintText: '1-3',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modeCtrl,
                  decoration: const InputDecoration(
                    labelText: '噪声模式',
                    hintText: 'm4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeCtrl,
                  decoration: const InputDecoration(
                    labelText: '噪声大小',
                    hintText: '10-30',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: delayCtrl,
                  decoration: const InputDecoration(
                    labelText: '噪声延迟',
                    hintText: '10-30',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                warpManager.setNoise(
                  count: '1-3',
                  mode: 'm4',
                  size: '10-30',
                  delay: '10-30',
                );
                Navigator.of(ctx).pop();
                context.showSnackBar('噪声参数已重置为默认值');
              },
              child: const Text('重置'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                warpManager.setNoise(
                  count: countCtrl.text.trim().isEmpty ? '1-3' : countCtrl.text.trim(),
                  mode: modeCtrl.text.trim().isEmpty ? 'm4' : modeCtrl.text.trim(),
                  size: sizeCtrl.text.trim().isEmpty ? '10-30' : sizeCtrl.text.trim(),
                  delay: delayCtrl.text.trim().isEmpty ? '10-30' : delayCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                context.showSnackBar('噪声参数已保存');
              },
              child: const Text('保存'),
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
        title: const Text('绑定 WARP+ 许可证密钥'),
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
            child: const Text('取消'),
          ),
          if (config.licenseKey.isNotEmpty)
            TextButton(
              onPressed: () {
                warpManager.setLicenseKey('');
                Navigator.of(ctx).pop();
                context.showSnackBar('已清除许可证密钥');
              },
              child: const Text('解绑'),
            ),
          FilledButton(
            onPressed: () async {
              final lic = ctrl.text.trim();
              Navigator.of(ctx).pop();
              context.showSnackBar('正在通过官方接口绑定密钥...');
              final success =
                  await warpManager.registerCloudflareAccount(license: lic);
              if (mounted) {
                if (success) {
                  context.showSnackBar('🎉 WARP+ 许可证激活成功！');
                } else {
                  context.showSnackBar('已保存密钥，将在下次握手或注册时生效');
                  warpManager.setLicenseKey(lic);
                }
              }
            },
            child: const Text('激活绑定'),
          ),
        ],
      ),
    );
  }

  void _showKeyDetailsDialog(WarpConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WireGuard 密钥信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyField('客户端私钥 (PrivateKey)', config.privateKey),
              const SizedBox(height: 12),
              _buildKeyField('客户端公钥 (PublicKey)', config.publicKey),
              const SizedBox(height: 12),
              _buildKeyField('Cloudflare 对端公钥', config.peerPublicKey),
              const SizedBox(height: 12),
              _buildKeyField('客户端预留字段 (Reserved)', config.reserved.toString()),
              const SizedBox(height: 12),
              _buildKeyField('虚拟 IPv4', config.ip),
              const SizedBox(height: 12),
              _buildKeyField('虚拟 IPv6', config.ipv6),
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
                context.showSnackBar('已重新生成 Curve25519 密钥对');
              }
            },
            child: const Text('重新生成密钥'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                  value.isNotEmpty ? value : '未设置',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  context.showSnackBar('已复制 $label');
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
        tooltip: '一键诊断检测',
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
        tooltip: '重置为默认配置',
        icon: const Icon(Icons.restart_alt),
        onPressed: () async {
          await warpManager.resetConfig();
          if (context.mounted) {
            context.showSnackBar('WARP 已重置为初始默认配置');
          }
        },
      ),
      IconButton(
        tooltip: '使用指南与原理解释',
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

    return CommonScaffold(
      title: 'WARP',
      actions: actions,
      body: body,
    );
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
                Icon(Icons.lightbulb_outline,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '💡 使用场景与路由模式原理',
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
        ? (isPlus ? 'WARP+ 极速加速激活 (warp=plus)' : 'WARP 正常接管保护中 (warp=on)')
        : (report == null
            ? '尚未进行真实有效性检测'
            : (report.isSuccess ? '直连或普通代理 (warp=off)' : '连接未完成或检测超时'));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: badgeColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              badgeColor.withValues(alpha: 0.12),
              colorScheme.surface,
            ],
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
                        horizontal: 8, vertical: 3),
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
                    title: '出口真实 IP',
                    value: report?.ip.isNotEmpty == true
                        ? report!.ip
                        : (config.enable ? '检测中...' : '未启用'),
                    subtitle: 'Cloudflare Anycast',
                    icon: Icons.public,
                    onCopy: report?.ip.isNotEmpty == true ? report!.ip : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: '边缘机房 (Colo)',
                    value: report?.colo.isNotEmpty == true
                        ? '${report!.colo} (${report.coloCityName})'
                        : '待检测',
                    subtitle: report?.loc.isNotEmpty == true
                        ? '归属地: ${report!.loc}'
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
                    title: 'Google 防送中评定',
                    value: report?.isGoogleAntiRedirect == true
                        ? '🛡️ 原生搜索 (极佳)'
                        : (report == null ? '待检测' : '⚠️ 可能送中'),
                    subtitle: report?.googleStatus ?? '规避验证码/区域锁定',
                    icon: Icons.search,
                    valueColor: report?.isGoogleAntiRedirect == true
                        ? Colors.green
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'AI 与流媒体解锁',
                    value: isWarp ? '🟢 畅通无阻' : '跟随跳板',
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
                    label: Text(
                        isTesting ? '正在深度诊断...' : '⚡ 一键检测 WARP 真实状态'),
                    onPressed: isTesting
                        ? null
                        : () async {
                            final res = await warpManager.checkWarpStatus();
                            if (mounted) {
                              if (res.isWarpActive) {
                                context.showSnackBar(
                                    '🎉 诊断成功！WARP 已生效 (机房: ${res.colo}, 出口: ${res.ip})');
                              } else if (res.isSuccess) {
                                context.showSnackBar(
                                    '提示：已连接出口 ${res.ip}，但未检测到 WARP 签名，请确认跳板配置');
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
                    context.showSnackBar('已复制 $onCopy');
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
            title: const Text(
              '启用 WARP',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              config.enable ? '已启用 Cloudflare WARP' : '点击开启 WARP 功能',
              style: TextStyle(
                fontSize: 12,
                color: config.enable ? colorScheme.primary : Colors.grey,
              ),
            ),
            value: config.enable,
            onChanged: (val) {
              warpManager.setEnable(val);
              context.showSnackBar(val ? '已开启 WARP' : '已关闭 WARP');
            },
          ),
          const Divider(height: 1),

          // 2. 生成 WARP 配置
          ListTile(
            leading: Icon(Icons.build_rounded, color: colorScheme.primary),
            title: const Text('生成 WARP 配置'),
            subtitle: isRegistering
                ? const Text('正在向 Cloudflare 官方注册设备并生成密钥...',
                    style: TextStyle(fontSize: 12, color: Colors.blue))
                : Text(
                    config.accountId.isNotEmpty
                        ? '设备已就绪 (ID: ${config.accountId})，点击可重新生成'
                        : '一键生成 X25519 密钥对并向 Cloudflare 注册设备',
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
                    context.showSnackBar('正在生成 X25519 密钥并向 Cloudflare 注册设备...');
                    final ok = await warpManager.registerCloudflareAccount();
                    if (mounted) {
                      if (ok) {
                        context.showSnackBar('🎉 官方设备与密钥生成成功！');
                      } else {
                        context.showSnackBar('生成完成（已载入内置合法密钥对）');
                      }
                    }
                  },
          ),
          const Divider(height: 1),

          // 3. WARP 路由模式
          ListTile(
            leading: Icon(Icons.alt_route_rounded, color: colorScheme.primary),
            title: const Text('WARP 路由模式'),
            subtitle: Text(
              config.routingMode.label,
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showRoutingModeDialog(config),
          ),
          const Divider(height: 1),

          // 4. 许可证密钥
          ListTile(
            leading: Icon(Icons.vpn_key_rounded, color: colorScheme.primary),
            title: const Text('许可证密钥'),
            subtitle: Text(
              config.licenseKey.isEmpty
                  ? '未设置'
                  : (config.accountType == 'plus'
                      ? '👑 WARP+ (已激活): ${config.licenseKey}'
                      : config.licenseKey),
              style: TextStyle(
                fontSize: 12,
                color: config.licenseKey.isEmpty ? Colors.grey : colorScheme.primary,
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
            leading: Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
            title: const Text('优选 IP'),
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
            title: const Text('端口'),
            subtitle: Text(
              config.port == 0 ? '0' : config.port.toString(),
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showPortDialog(config),
          ),
          const Divider(height: 1),

          // 7. 噪声数量
          ListTile(
            leading: Icon(Icons.layers_outlined, color: colorScheme.primary),
            title: const Text('噪声数量'),
            subtitle: Text(
              config.noiseCount,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showNoiseDialog(config),
          ),
          const Divider(height: 1),

          // 8. 噪声模式
          ListTile(
            leading: Icon(Icons.mode_standby_rounded, color: colorScheme.primary),
            title: const Text('噪声模式'),
            subtitle: Text(
              config.noiseMode,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showNoiseDialog(config),
          ),
          const Divider(height: 1),

          // 9. 噪声大小
          ListTile(
            leading: Icon(Icons.compare_arrows_rounded, color: colorScheme.primary),
            title: const Text('噪声大小'),
            subtitle: Text(
              config.noiseSize,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showNoiseDialog(config),
          ),
          const Divider(height: 1),

          // 10. 噪声延迟
          ListTile(
            leading: Icon(Icons.schedule_rounded, color: colorScheme.primary),
            title: const Text('噪声延迟'),
            subtitle: Text(
              config.noiseDelay,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showNoiseDialog(config),
          ),
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
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '当前为「通过 WARP 路由代理」模式：所有机场代理节点均自动级联经由 WARP 隧道出境连接，能有效拯救被 GFW 阻断的节点，无需额外选择前置跳板。',
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
                const Text(
                  '分流工作模式 (Routing Mode)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RadioGroup<WarpMode>(
              groupValue: config.mode,
              onChanged: (val) {
                if (val != null) {
                  warpManager.setMode(val);
                  context.showSnackBar('已切换为 ${val.label}');
                }
              },
              child: Column(
                children: [
                  for (final m in WarpMode.values)
                    RadioListTile<WarpMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        m.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(m.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      value: m,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHopSelectorCard(WarpConfig config, ColorScheme colorScheme) {
    final hopName = config.defaultDialerProxy.isEmpty
        ? '⚡ 跟随后台主选择 (自动匹配当前机场节点)'
        : (config.defaultDialerProxy == 'DIRECT'
            ? 'DIRECT (直连 Cloudflare)'
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
        title: const Text(
          '前置跳板代理 (Dialer-Proxy)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          hopName,
          style: TextStyle(fontSize: 12, color: colorScheme.primary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          _showHopPickerSheet(
            currentHop: config.defaultDialerProxy,
            onSelect: (selected) {
              warpManager.setDefaultDialer(selected);
              context.showSnackBar(
                selected.isEmpty
                    ? '已设为跟随后台主选择'
                    : '已指定前置跳板为 $selected',
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
        ? '👑 WARP+ 极速会员设备'
        : (config.accountId.isNotEmpty ? '🟢 官方免费设备' : '⚪ 本地密钥对');

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
                    Icon(Icons.badge_outlined,
                        color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'WARP 凭据与高级详情',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  label: const Text('查看完整 WireGuard 密钥'),
                  onPressed: () => _showKeyDetailsDialog(config),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.compress, size: 16),
                  label: Text('MTU: ${config.mtu}'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('选择 WireGuard MTU'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1280);
                              Navigator.of(ctx).pop();
                              context.showSnackBar('MTU 已设为 1280 (推荐)');
                            },
                            child: const Text('1280 (推荐，UDP代理最优)'),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1360);
                              Navigator.of(ctx).pop();
                              context.showSnackBar('MTU 已设为 1360');
                            },
                            child: const Text('1360 (适中)'),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              warpManager.setMtu(1420);
                              Navigator.of(ctx).pop();
                              context.showSnackBar('MTU 已设为 1420 (标准)');
                            },
                            child: const Text('1420 (标准)'),
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
