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

  void _showEndpointDialog(WarpConfig config) {
    final serverCtrl = TextEditingController(text: config.server);
    final portCtrl = TextEditingController(text: config.port.toString());

    final presets = [
      {'name': '官方推荐 1', 'server': '162.159.192.1', 'port': 2408},
      {'name': '官方推荐 2', 'server': '162.159.193.1', 'port': 2408},
      {'name': '官方推荐 3', 'server': '162.159.195.1', 'port': 2408},
      {'name': '域名端点', 'server': 'engage.cloudflareclient.com', 'port': 2408},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置 Cloudflare 端点'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('常用优质预设端点：',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: presets.map((p) {
                  return ActionChip(
                    label: Text('${p['name']}: ${p['server']}'),
                    onPressed: () {
                      serverCtrl.text = p['server'].toString();
                      portCtrl.text = p['port'].toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: serverCtrl,
                decoration: const InputDecoration(
                  labelText: '服务器 IP 或域名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '端口 (默认 2408)',
                  border: OutlineInputBorder(),
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
            onPressed: () {
              final port = int.tryParse(portCtrl.text.trim()) ?? 2408;
              warpManager.setEndpoint(serverCtrl.text.trim(), port);
              Navigator.of(ctx).pop();
              context.showSnackBar('端点已更新为 ${serverCtrl.text.trim()}:$port');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(WarpConfig config) {
    final ctrl = TextEditingController(text: config.licenseKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定 WARP+ / Teams 密钥'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '如拥有 WARP+ 24 位许可证密钥或 Cloudflare Zero Trust 团队凭证，输入后将为您自动升级至极速专用线路。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '24 位许可证密钥 (License Key)',
                hintText: '例如: xxxxxxxx-xxxxxxxx-xxxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
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
              _buildKeyField('客户端保留字段 (Reserved)', config.reserved.toString()),
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
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11),
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

        // 2. Master Switch Card
        _buildMasterSwitchCard(config, colorScheme),

        const SizedBox(height: 16),

        // 3. Visual Diagnostic Card (Hero Card)
        _buildDiagnosticHeroCard(report, config, isTesting, colorScheme),

        const SizedBox(height: 16),

        // 4. Mode Selection Card
        _buildModeSelectorCard(config, colorScheme),

        const SizedBox(height: 16),

        // 5. Hop Node Selection Card
        _buildHopSelectorCard(config, colorScheme),

        const SizedBox(height: 16),

        // 6. Account & Key Management Card
        _buildAccountCard(config, isRegistering, colorScheme),

        const SizedBox(height: 16),

        // 7. Advanced Endpoint & MTU Card
        _buildEndpointCard(config, colorScheme),

        const SizedBox(height: 32),
      ],
    );

    if (widget.type != null) {
      return AdaptiveSheetScaffold(
        type: widget.type!,
        title: '🛡️ 机场节点套 WARP (WARP on Proxy)',
        actions: actions,
        body: body,
      );
    }

    return CommonScaffold(
      title: '🛡️ 机场节点套 WARP (WARP on Proxy)',
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
                  '💡 使用场景与链式隧道原理 (借鉴 Hiddify)',
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
              '• 解决 Google 送中：机场节点常用机房 IP 容易被 Google 判定为数据中心并频繁弹出人机验证（Captcha），或被强制重定向到香港/大陆域名。\n'
              '• 解锁限制平台：OpenAI/ChatGPT、Claude、Gemini、流媒体等常屏蔽机场 IP，套上 WARP 后出口变为干净的 Cloudflare Anycast/家庭宽带出口。\n'
              '• 隐藏机场落地：您的流量经由机场节点穿透墙体，再在出口处通过 WireGuard 封装直接连入 Cloudflare 边缘网络，目标站点完全看不到机场真实落地 IP，极大提升隐私安全性。\n'
              '• 智能分流推荐：默认开启「智能防送中与 AI 解锁」模式，Google 与 AI 平台走 WARP 出口，机场其它流量保持原节点原生高速！',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSwitchCard(WarpConfig config, ColorScheme colorScheme) {
    return Card(
      elevation: config.enable ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: config.enable
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: config.enable
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            config.enable ? Icons.shield : Icons.shield_outlined,
            color: config.enable
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 26,
          ),
        ),
        title: const Text(
          '启用 机场节点套 WARP',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          config.enable
              ? '🛡️ WARP 出口已激活 (Mihomo WireGuard 隧道级联运行中)'
              : '为选定前置机场节点套上 Cloudflare WireGuard 出口',
          style: TextStyle(
            fontSize: 12,
            color: config.enable ? colorScheme.primary : Colors.grey,
          ),
        ),
        value: config.enable,
        onChanged: (val) {
          warpManager.setEnable(val);
          context.showSnackBar(val ? '已开启 WARP on Proxy' : '已关闭 WARP on Proxy');
        },
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
        leading: Icon(Icons.alt_route, color: colorScheme.primary),
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
                      'WARP 账号与设备凭据',
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
              config.accountId.isNotEmpty
                  ? '设备 ID: ${config.accountId}'
                  : '已为您自动生成 Curve25519 密钥对。您也可以点击下方一键向 Cloudflare 官方注册独立设备。',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: isRegistering
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.app_registration, size: 16),
                  label: Text(isRegistering ? '正在注册...' : '一键注册官方设备'),
                  onPressed: isRegistering
                      ? null
                      : () async {
                          context.showSnackBar('正在调用 Cloudflare 官方接口注册设备...');
                          final ok =
                              await warpManager.registerCloudflareAccount();
                          if (mounted) {
                            if (ok) {
                              context.showSnackBar('🎉 官方设备注册成功！已分配专属 Client ID');
                            } else {
                              context.showSnackBar(
                                  '官方接口注册失败，已使用内置合法密钥对正常工作');
                            }
                          }
                        },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.key, size: 16),
                  label: const Text('绑定 WARP+ License'),
                  onPressed: () => _showLicenseDialog(config),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined, size: 16),
                  label: const Text('查看 WireGuard 密钥'),
                  onPressed: () => _showKeyDetailsDialog(config),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointCard(WarpConfig config, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.dns, color: colorScheme.primary),
            title: const Text('Cloudflare 节点端点',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${config.server}:${config.port}',
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () => _showEndpointDialog(config),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.compress, color: colorScheme.primary),
            title: const Text('WireGuard MTU',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${config.mtu} (推荐 1280，避免 UDP 隧道分包丢包)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: PopupMenuButton<int>(
              initialValue: config.mtu,
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 1280, child: Text('1280 (推荐，UDP代理最优)')),
                const PopupMenuItem(value: 1360, child: Text('1360 (适中)')),
                const PopupMenuItem(value: 1420, child: Text('1420 (标准)')),
              ],
              onSelected: (val) {
                warpManager.setMtu(val);
                context.showSnackBar('MTU 已设为 $val');
              },
            ),
          ),
        ],
      ),
    );
  }
}
