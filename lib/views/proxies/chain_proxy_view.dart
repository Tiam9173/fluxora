import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/chain_proxy_l10n.dart';
import 'package:bett_box/manager/chain_proxy_manager.dart';
import 'package:bett_box/models/chain_proxy.dart';
import 'package:bett_box/providers/chain_proxy.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChainProxyView extends ConsumerStatefulWidget {
  const ChainProxyView({super.key});

  @override
  ConsumerState<ChainProxyView> createState() => _ChainProxyViewState();
}

class _ChainProxyViewState extends ConsumerState<ChainProxyView> {
  bool _isGuideExpanded = false;

  @override
  void initState() {
    super.initState();
    chainProxyManager.init();
  }

  void _showHopPickerSheet({
    required String currentHop,
    required Function(String) onSelect,
  }) {
    final groups = ref.read(groupsProvider);
    final groupNames = groups
        .map((g) => g.name)
        .where((name) => name != '🔗 链式代理')
        .toList();

    final allProxies = <String>{};
    for (final g in groups) {
      if (g.name == '🔗 链式代理') continue;
      for (final p in g.all) {
        if (p.name != 'DIRECT' &&
            p.name != 'REJECT' &&
            p.name != 'REJECT-DROP' &&
            p.name != 'PASS') {
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
          title: appLocalizations.defaultDialerProxy,
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.auto_mode, color: Colors.blue),
                title: Text(appLocalizations.followMainSelector),
                subtitle: Text(appLocalizations.defaultDialerProxyDesc),
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
                title: Text(appLocalizations.directConnection),
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
                    '具体节点',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                for (final p in proxyList)
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
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

  void _showQuickImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _QuickImportDialog(
        onImport: (proxies) {
          chainProxyManager.addLandingProxies(proxies);
          context.showSnackBar(
            appLocalizations.importSuccessCount(proxies.length),
          );
        },
      ),
    );
  }

  void _showEditProxyDialog([LandingProxy? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _EditLandingProxyDialog(
        proxy: existing,
        onSave: (proxy) {
          if (existing == null) {
            chainProxyManager.addLandingProxies([proxy]);
          } else {
            chainProxyManager.updateLandingProxy(proxy);
          }
        },
      ),
    );
  }

  int _selectedFilter = 0; // 0: 全部, 1: 仅可用, 2: 异常/未测

  void _testAll() {
    final testUrl = globalState.config.appSetting.testUrl;
    chainProxyManager.testAllDelays(testUrl);
  }

  void _checkAllHealth() {
    chainProxyManager.checkAllProxiesHealth();
  }

  void _clearInvalidProxies() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocalizations.clearInvalidProxies),
        content: Text(appLocalizations.confirmClearInvalid),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(appLocalizations.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final count = await chainProxyManager.clearInvalidProxies();
      if (!mounted) return;
      if (count > 0) {
        context.showSnackBar(appLocalizations.clearedInvalidCount(count));
      } else {
        context.showSnackBar(appLocalizations.noInvalidProxies);
      }
    }
  }

  void _showHealthReportDialog(LandingProxy proxy) {
    showDialog(
      context: context,
      builder: (ctx) => _ProxyHealthReportDialog(
        proxy: proxy,
        defaultHop: ref.read(chainProxyConfigProvider).config.defaultDialerProxy,
      ),
    );
  }

  List<LandingProxy> _filterProxies(List<LandingProxy> list) {
    if (_selectedFilter == 1) {
      return list.where((p) {
        final report = chainProxyManager.getHealthReport(p.id);
        return report != null && report.status == HealthStatus.healthy;
      }).toList();
    } else if (_selectedFilter == 2) {
      return list.where((p) {
        final report = chainProxyManager.getHealthReport(p.id);
        return report == null ||
            report.status == HealthStatus.error ||
            report.status == HealthStatus.untested;
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(chainProxyConfigProvider);
    final config = manager.config;
    final landingProxies = config.landingProxies;
    final filteredProxies = _filterProxies(landingProxies);

    final healthyCount = landingProxies.where((p) {
      final r = chainProxyManager.getHealthReport(p.id);
      return r != null && r.status == HealthStatus.healthy;
    }).length;

    final errorCount = landingProxies.where((p) {
      final r = chainProxyManager.getHealthReport(p.id);
      return r == null ||
          r.status == HealthStatus.error ||
          r.status == HealthStatus.untested;
    }).length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Master enable card
          CommonCard(
            type: CommonCardType.filled,
            child: Column(
              children: [
                ListItem(
                  leading: const Icon(Icons.alt_route, size: 28),
                  title: Text(
                    appLocalizations.enableChainProxy,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(appLocalizations.enableChainProxyDesc),
                  trailing: Switch(
                    value: config.enable,
                    onChanged: (val) => chainProxyManager.setEnable(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Default Hop & Integration settings
          CommonCard(
            type: CommonCardType.filled,
            child: Column(
              children: [
                ListItem(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(appLocalizations.defaultDialerProxy),
                  subtitle: Text(
                    config.defaultDialerProxy.isEmpty
                        ? appLocalizations.followMainSelector
                        : config.defaultDialerProxy,
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showHopPickerSheet(
                      currentHop: config.defaultDialerProxy,
                      onSelect: (hop) => chainProxyManager.setDefaultDialer(hop),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.layers_outlined),
                  title: Text(appLocalizations.dedicatedGroup),
                  subtitle: Text(appLocalizations.dedicatedGroupDesc),
                  trailing: Switch(
                    value: config.createDedicatedGroup,
                    onChanged: (val) =>
                        chainProxyManager.setCreateDedicatedGroup(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.input_outlined),
                  title: Text(appLocalizations.autoInjectGroups),
                  subtitle: Text(appLocalizations.autoInjectGroupsDesc),
                  trailing: Switch(
                    value: config.autoInjectGroups,
                    onChanged: (val) =>
                        chainProxyManager.setAutoInjectGroups(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.security, color: Colors.blueAccent),
                  title: Text(appLocalizations.preventWebRtcLeak),
                  subtitle: Text(appLocalizations.preventWebRtcLeakDesc),
                  trailing: Switch(
                    value: config.preventWebRtcLeak,
                    onChanged: (val) =>
                        chainProxyManager.setPreventWebRtcLeak(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFingerprintGuideCard(context),
          const SizedBox(height: 16),

          // 3. Section Header for Landing Proxies with Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${appLocalizations.landingProxies} (${landingProxies.length})',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (landingProxies.isNotEmpty) ...[
                    IconButton(
                      icon: manager.isBatchHealthChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety, color: Colors.green),
                      tooltip: appLocalizations.healthCheckAll,
                      onPressed: manager.isBatchHealthChecking ? null : _checkAllHealth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cleaning_services_outlined),
                      tooltip: appLocalizations.clearInvalidProxies,
                      onPressed: _clearInvalidProxies,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bolt, color: Colors.amber),
                      tooltip: appLocalizations.testAll,
                      onPressed: _testAll,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.content_paste_go),
                    tooltip: appLocalizations.quickImport,
                    onPressed: _showQuickImportDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: appLocalizations.addLandingProxy,
                    onPressed: () => _showEditProxyDialog(),
                  ),
                ],
              ),
            ],
          ),

          // Batch Checking Progress Banner
          if (manager.isBatchHealthChecking) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: manager.batchCheckTotal > 0
                    ? manager.batchCheckCompleted / manager.batchCheckTotal
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appLocalizations.batchCheckingProgress(
                manager.batchCheckCompleted,
                manager.batchCheckTotal,
              ),
              style: TextStyle(fontSize: 12, color: context.colorScheme.primary),
            ),
          ],

          // Filter Segmented Chips (All / Healthy / Error)
          if (landingProxies.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('${appLocalizations.filterAll} (${landingProxies.length})'),
                    selected: _selectedFilter == 0,
                    onSelected: (_) => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    label: Text('${appLocalizations.filterHealthy} ($healthyCount)'),
                    selected: _selectedFilter == 1,
                    onSelected: (_) => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    label: Text('${appLocalizations.filterError} ($errorCount)'),
                    selected: _selectedFilter == 2,
                    onSelected: (_) => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // 4. Landing Proxies List or Empty State
          if (landingProxies.isEmpty)
            CommonCard(
              type: CommonCardType.filled,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.router_outlined,
                      size: 48,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appLocalizations.emptyLandingTip,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colorScheme.outline),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.content_paste),
                      label: Text(appLocalizations.quickImport),
                      onPressed: _showQuickImportDialog,
                    ),
                  ],
                ),
              ),
            )
          else if (filteredProxies.isEmpty)
            CommonCard(
              type: CommonCardType.filled,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '当前筛选条件下没有节点',
                    style: TextStyle(color: context.colorScheme.outline),
                  ),
                ),
              ),
            )
          else
            for (final proxy in filteredProxies)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LandingProxyCard(
                  proxy: proxy,
                  defaultHop: config.defaultDialerProxy,
                  onEdit: () => _showEditProxyDialog(proxy),
                  onDelete: () => chainProxyManager.deleteLandingProxy(proxy.id),
                  onToggle: (val) =>
                      chainProxyManager.toggleLandingProxy(proxy.id, val),
                  onTest: () {
                    final testUrl = globalState.config.appSetting.testUrl;
                    chainProxyManager.testProxyDelay(proxy, testUrl);
                  },
                  onCheckHealth: () => chainProxyManager.checkProxyHealth(proxy),
                  onShowReport: () => _showHealthReportDialog(proxy),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFingerprintGuideCard(BuildContext context) {
    final now = DateTime.now();
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = (now.timeZoneOffset.inMinutes % 60).abs();
    final offsetStr = 'UTC${offsetHours >= 0 ? '+$offsetHours' : '$offsetHours'}'
        '${offsetMinutes > 0 ? ':${offsetMinutes.toString().padLeft(2, '0')}' : ''}';
    final tzName = now.timeZoneName.isNotEmpty ? ' (${now.timeZoneName})' : '';

    return CommonCard(
      type: CommonCardType.filled,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isGuideExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isGuideExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(
            Icons.fingerprint,
            color: Colors.teal,
            size: 28,
          ),
          title: const Text(
            '🎯 跨境养号与指纹防关联环境指南',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '针对 ToDetect / Whoer / IPpure 检测的时区与风控排查建议',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            const Text(
                              '当前设备系统时区：',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                '$offsetStr$tzName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'WebRTC 泄露防护：',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Expanded(
                              child: Text(
                                '已硬核拦截 STUN/TURN (0泄露)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ 针对 ToDetect 检测到“IP地址时区”异常标红的原因与方案：',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. 产生原因：网页端（如 ToDetect/Pixelscan）通过前端 JavaScript 读取操作系统的实际时区并与住宅 IP 地理时区对比。若住宅 IP 在美国加州 (America/Los_Angeles, UTC-8)，而手机设置为北京时间 (UTC+8)，网页端将标红提示“时区不一致”。\n'
                    '2. 手机端养号建议：前往手机「设置 -> 日期与时间」，关闭“自动设置”，将时区修改为落地 IP 对应时区（如「美国/洛杉矶」），系统语言设为 en-US。\n'
                    '3. 电脑端养号最佳实践：强烈建议在电脑端搭配专业指纹浏览器（如 AdsPower、比特、Hubstudio），指纹浏览器将基于住宅代理 IP 自动伪装匹配系统时区、Canvas 指纹与语言，实现 100% 满分纯净养号防关联！\n'
                    '4. 适用场景：亚马逊/eBay 店铺运营、TikTok 本土小店、Facebook/Instagram 矩阵、ChatGPT/Claude/Gemini 账号防风控封禁。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingProxyCard extends ConsumerWidget {
  final LandingProxy proxy;
  final String defaultHop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onCheckHealth;
  final VoidCallback onShowReport;

  const _LandingProxyCard({
    required this.proxy,
    required this.defaultHop,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onTest,
    required this.onCheckHealth,
    required this.onShowReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(chainProxyDelayProvider(proxy.id));
    final report = chainProxyManager.getHealthReport(proxy.id);
    final effectiveHop = (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
        ? proxy.dialerProxy!
        : (defaultHop.isEmpty ? '跟随主选择' : defaultHop);

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Protocol Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    proxy.protocol.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Proxy Name
                Expanded(
                  child: Text(
                    proxy.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Health status badge
                _buildHealthStatusBadge(context, report, delay),
                const SizedBox(width: 4),
                // Enable Switch
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: proxy.enable,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Server address, port, username & service capability tags
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    proxy.username.isNotEmpty
                        ? '${proxy.server}:${proxy.port} (${proxy.username})'
                        : '${proxy.server}:${proxy.port}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (report != null &&
                    (report.status == HealthStatus.healthy ||
                        report.status == HealthStatus.warning)) ...[
                  const SizedBox(width: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (report.isTargetAvailable(TargetService.openai))
                        _buildServiceMiniTag('ChatGPT', Colors.green),
                      if (report.isTargetAvailable(TargetService.tiktok))
                        _buildServiceMiniTag('TikTok', Colors.green),
                      if (report.isTargetAvailable(TargetService.google))
                        _buildServiceMiniTag('Google', Colors.blue),
                      if (report.isTargetAvailable(TargetService.amazon))
                        _buildServiceMiniTag('Amazon', Colors.orange),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Hop info, Delay badge & Action buttons
            Row(
              children: [
                // Hop chip
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 13, color: Colors.blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '跳板: $effectiveHop',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildDelayBadge(context, delay),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: Icons.health_and_safety_outlined,
                  color: Colors.green,
                  tooltip: appLocalizations.healthCheck,
                  onPressed: onCheckHealth,
                ),
                _buildActionButton(
                  icon: Icons.analytics_outlined,
                  color: Colors.blue,
                  tooltip: appLocalizations.healthReport,
                  onPressed: onShowReport,
                ),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: null,
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  tooltip: '删除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color? color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildServiceMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildHealthStatusBadge(BuildContext context, ProxyHealthReport? report, int? delay) {
    if (report == null) {
      return InkWell(
        onTap: onCheckHealth,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.health_and_safety_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 3),
              Text(
                appLocalizations.healthCheck,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (report.isTesting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 4),
            Text(
              appLocalizations.testingHealth,
              style: const TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    final (color, text) = switch (report.status) {
      HealthStatus.healthy => (Colors.green, '${appLocalizations.healthHealthy} ${report.minDelay ?? delay ?? ''}ms'.trim()),
      HealthStatus.warning => (Colors.orange, appLocalizations.healthWarning),
      HealthStatus.error => (Colors.red, appLocalizations.healthError),
      HealthStatus.testing => (Colors.blue, appLocalizations.testingHealth),
      HealthStatus.untested => (Colors.grey, appLocalizations.healthUntested),
    };

    return InkWell(
      onTap: onShowReport,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              report.status == HealthStatus.healthy
                  ? Icons.check_circle
                  : (report.status == HealthStatus.warning
                      ? Icons.warning_amber
                      : Icons.cancel),
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayBadge(BuildContext context, int? delay) {
    if (delay == 0) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (delay == null) {
      return InkWell(
        onTap: onTest,
        borderRadius: BorderRadius.circular(4),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, size: 14, color: Colors.grey),
              SizedBox(width: 2),
              Text('测速', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final Color color = switch (delay) {
      > 0 && < 300 => Colors.green,
      >= 300 && < 800 => Colors.orange,
      _ => Colors.red,
    };

    final text = delay > 0 ? '$delay ms' : '超时';

    return InkWell(
      onTap: onTest,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _QuickImportDialog extends StatefulWidget {
  final Function(List<LandingProxy>) onImport;

  const _QuickImportDialog({required this.onImport});

  @override
  State<_QuickImportDialog> createState() => _QuickImportDialogState();
}

class _QuickImportDialogState extends State<_QuickImportDialog> {
  final TextEditingController _controller = TextEditingController();
  List<LandingProxy> _parsed = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _checkClipboardAutoPaste();
  }

  Future<void> _checkClipboardAutoPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty && mounted) {
      final list = LandingProxyParser.parseText(text);
      if (list.isNotEmpty) {
        _controller.text = text;
      }
    }
  }

  void _handleTextChanged() {
    final list = LandingProxyParser.parseText(_controller.text);
    setState(() {
      _parsed = list;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(appLocalizations.quickImport),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appLocalizations.quickImportDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.paste, size: 16),
                  label: Text(appLocalizations.pasteFromClipboard),
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: appLocalizations.inputProxyTextHint,
                hintStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            if (_parsed.isNotEmpty)
              Text(
                '已识别 ${_parsed.length} 个节点：${_parsed.map((e) => e.name).take(3).join(', ')}${_parsed.length > 3 ? ' 等' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              )
            else if (_controller.text.trim().isNotEmpty)
              Text(
                appLocalizations.parseNoValidNode,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: _parsed.isEmpty
              ? null
              : () {
                  widget.onImport(_parsed);
                  Navigator.of(context).pop();
                },
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }
}

class _EditLandingProxyDialog extends StatefulWidget {
  final LandingProxy? proxy;
  final Function(LandingProxy) onSave;

  const _EditLandingProxyDialog({this.proxy, required this.onSave});

  @override
  State<_EditLandingProxyDialog> createState() =>
      _EditLandingProxyDialogState();
}

class _EditLandingProxyDialogState extends State<_EditLandingProxyDialog> {
  late TextEditingController _nameController;
  late TextEditingController _serverController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _dialerController;
  ChainProxyProtocol _protocol = ChainProxyProtocol.socks5;
  bool _udp = true;
  bool _showPassword = false;
  bool _isTesting = false;
  DirectCheckResult? _testResult;

  @override
  void initState() {
    super.initState();
    final p = widget.proxy;
    _nameController = TextEditingController(text: p?.name ?? '');
    _serverController = TextEditingController(text: p?.server ?? '');
    _portController = TextEditingController(
      text: p?.port != null ? p!.port.toString() : '1080',
    );
    _userController = TextEditingController(text: p?.username ?? '');
    _passController = TextEditingController(text: p?.password ?? '');
    _dialerController = TextEditingController(text: p?.dialerProxy ?? '');
    _protocol = p?.protocol ?? ChainProxyProtocol.socks5;
    _udp = p?.udp ?? true;
  }

  void _testCurrentProxy() async {
    final server = _serverController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? _protocol.defaultPort;
    if (server.isEmpty) {
      context.showSnackBar('请先输入服务器地址');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await chainProxyManager.directCheckProxy(
      server: server,
      port: port,
      protocol: _protocol,
      username: _userController.text.trim(),
      password: _passController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = res;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dialerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.proxy == null
            ? appLocalizations.addLandingProxy
            : '编辑落地代理',
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: appLocalizations.nodeName,
                  hintText: '例：美国家庭住宅IP 01',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ChainProxyProtocol>(
                initialValue: _protocol,
                decoration: InputDecoration(
                  labelText: appLocalizations.protocol,
                ),
                items: ChainProxyProtocol.values.map((proto) {
                  return DropdownMenuItem(
                    value: proto,
                    child: Text(proto.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _protocol = val;
                      if (_portController.text.isEmpty ||
                          _portController.text == '1080' ||
                          _portController.text == '8080' ||
                          _portController.text == '8388') {
                        _portController.text = val.defaultPort.toString();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        labelText: appLocalizations.serverAddress,
                        hintText: 'IP 或域名',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: appLocalizations.port,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: appLocalizations.username,
                  hintText: '可选',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: appLocalizations.password,
                  hintText: '可选',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dialerController,
                decoration: InputDecoration(
                  labelText: appLocalizations.specificDialerProxy,
                  hintText: '留空则继承全局默认跳板',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(appLocalizations.udpForwarding),
                subtitle: Text(appLocalizations.udpForwardingDesc),
                value: _udp,
                onChanged: (val) => setState(() => _udp = val),
              ),
              if (_isTesting) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(appLocalizations.testing, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ] else if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_testResult!.isSuccess
                            ? Colors.green
                            : (_testResult!.isAuthError ? Colors.red : Colors.orange))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (_testResult!.isSuccess
                              ? Colors.green
                              : (_testResult!.isAuthError ? Colors.red : Colors.orange))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.isSuccess
                            ? Icons.check_circle
                            : (_testResult!.isAuthError
                                ? Icons.lock_clock
                                : Icons.error_outline),
                        size: 16,
                        color: _testResult!.isSuccess
                            ? Colors.green
                            : (_testResult!.isAuthError ? Colors.red : Colors.orange),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testResult!.isSuccess
                              ? '${_testResult!.message} (${_testResult!.delay}ms)'
                              : _testResult!.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testResult!.isSuccess
                                ? Colors.green.shade800
                                : (_testResult!.isAuthError
                                    ? Colors.red.shade800
                                    : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.network_check, size: 16),
          label: Text(appLocalizations.testCurrentProxy),
          onPressed: _isTesting ? null : _testCurrentProxy,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () {
            final server = _serverController.text.trim();
            final port = int.tryParse(_portController.text.trim()) ?? 1080;
            if (server.isEmpty) {
              context.showSnackBar('请输入服务器地址');
              return;
            }

            final name = _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : '住宅IP-$server:$port';

            final updated = LandingProxy(
              id: widget.proxy?.id ?? utils.uuidV4,
              name: name,
              protocol: _protocol,
              server: server,
              port: port,
              username: _userController.text.trim(),
              password: _passController.text.trim(),
              dialerProxy: _dialerController.text.trim(),
              udp: _udp,
              enable: widget.proxy?.enable ?? true,
            );

            widget.onSave(updated);
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }
}

class _ProxyHealthReportDialog extends ConsumerWidget {
  final LandingProxy proxy;
  final String defaultHop;

  const _ProxyHealthReportDialog({
    required this.proxy,
    required this.defaultHop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chainProxyConfigProvider);
    final report = chainProxyManager.getHealthReport(proxy.id);
    final effectiveHop = (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
        ? proxy.dialerProxy!
        : (defaultHop.isEmpty ? '主选择组' : defaultHop);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appLocalizations.healthReport,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Topology link diagram
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTopologyNode(Icons.computer, appLocalizations.topologyClient, context),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.alt_route, '$effectiveHop\n(${appLocalizations.topologyHop})', context, color: Colors.blue),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.home_outlined, '${proxy.name}\n(${appLocalizations.topologyLanding})', context, color: Colors.teal),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.public, appLocalizations.topologyTarget, context, color: Colors.orange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Health status card
              _buildOverallStatusCard(context, report),
              const SizedBox(height: 12),

              // 3. Targets test results
              Text(
                '主流目标服务连通性',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              if (report == null || report.targets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Text(
                    '点击下方「${appLocalizations.retest}」开始体检',
                    style: TextStyle(color: context.colorScheme.outline),
                  ),
                )
              else
                ...report.targets.map((target) => _buildTargetRow(context, target)),

              // 4. Diagnostic advice
              if (report != null && report.diagnosticTips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (report.status == HealthStatus.error
                            ? Colors.red
                            : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (report.status == HealthStatus.error
                              ? Colors.red
                              : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: report.status == HealthStatus.error
                            ? Colors.red
                            : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.diagnosticTips,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonalIcon(
          icon: report?.isTesting == true
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 16),
          label: Text(report?.isTesting == true
              ? appLocalizations.testingHealth
              : appLocalizations.retest),
          onPressed: report?.isTesting == true
              ? null
              : () => chainProxyManager.checkProxyHealth(proxy),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }

  Widget _buildTopologyNode(IconData icon, String text, BuildContext context, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? context.colorScheme.primary),
        const SizedBox(height: 2),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOverallStatusCard(BuildContext context, ProxyHealthReport? report) {
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.grey),
            const SizedBox(width: 8),
            Text(appLocalizations.healthUntested),
          ],
        ),
      );
    }

    final (color, icon, title) = switch (report.status) {
      HealthStatus.healthy => (Colors.green, Icons.check_circle_outline, appLocalizations.healthHealthy),
      HealthStatus.warning => (Colors.orange, Icons.warning_amber_outlined, appLocalizations.healthWarning),
      HealthStatus.error => (Colors.red, Icons.error_outline, appLocalizations.healthError),
      HealthStatus.testing => (Colors.blue, Icons.sync, appLocalizations.testingHealth),
      HealthStatus.untested => (Colors.grey, Icons.help_outline, appLocalizations.healthUntested),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (report.minDelay != null && report.minDelay! > 0)
                  Text(
                    '响应延迟: 最优 ${report.minDelay}ms | 平均 ${report.avgDelay ?? report.minDelay}ms',
                    style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetRow(BuildContext context, TargetHealthResult target) {
    final isOk = target.isSuccess;
    final color = isOk ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.service.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  target.service.desc,
                  style: TextStyle(fontSize: 10, color: context.colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOk ? '${target.delay} ms' : (target.error ?? '失败'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

