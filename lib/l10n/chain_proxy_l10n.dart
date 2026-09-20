import 'package:intl/intl.dart';
import 'package:bett_box/l10n/l10n.dart';

extension ChainProxyLocalizations on AppLocalizations {
  String get chainProxy => Intl.message(
        '链式代理',
        name: 'chainProxy',
        desc: 'Chain proxy title',
      );

  String get chainProxyDesc => Intl.message(
        '配置前置跳板与落地静态住宅IP代理',
        name: 'chainProxyDesc',
        desc: 'Chain proxy description',
      );

  String get enableChainProxy => Intl.message(
        '启用链式代理',
        name: 'enableChainProxy',
        desc: 'Enable chain proxy switch',
      );

  String get enableChainProxyDesc => Intl.message(
        '通过前置节点中转连接落地代理，绕过网络限制并保持真实住宅出口',
        name: 'enableChainProxyDesc',
        desc: 'Enable chain proxy description',
      );

  String get defaultDialerProxy => Intl.message(
        '默认前置跳板',
        name: 'defaultDialerProxy',
        desc: 'Default entry proxy',
      );

  String get defaultDialerProxyDesc => Intl.message(
        '落地代理默认使用的前置节点或策略组（推荐设置为节点选择组）',
        name: 'defaultDialerProxyDesc',
        desc: 'Default entry proxy description',
      );

  String get followMainSelector => Intl.message(
        '跟随当前节点选择组 (推荐)',
        name: 'followMainSelector',
        desc: 'Follow current selector group',
      );

  String get dedicatedGroup => Intl.message(
        '创建专属链式代理组',
        name: 'dedicatedGroup',
        desc: 'Create dedicated chain proxy group',
      );

  String get dedicatedGroupDesc => Intl.message(
        '在代理页面生成「🔗 链式代理」独立策略组卡片',
        name: 'dedicatedGroupDesc',
        desc: 'Create dedicated group description',
      );

  String get autoInjectGroups => Intl.message(
        '自动注入主选择组',
        name: 'autoInjectGroups',
        desc: 'Auto inject into main selector groups',
      );

  String get autoInjectGroupsDesc => Intl.message(
        '将启用的落地代理自动添加到「节点选择」等主要分流策略组',
        name: 'autoInjectGroupsDesc',
        desc: 'Auto inject description',
      );

  String get preventWebRtcLeak => Intl.message(
        '防 WebRTC 真实 IP 泄露',
        name: 'preventWebRtcLeak',
        desc: 'Prevent WebRTC IP leak',
      );

  String get preventWebRtcLeakDesc => Intl.message(
        '拦截 STUN/TURN 探测，彻底杜绝真实公网 IP 暴露，保障海外养号与跨境电商安全',
        name: 'preventWebRtcLeakDesc',
        desc: 'Prevent WebRTC IP leak description',
      );

  String get landingProxies => Intl.message(
        '落地住宅节点',
        name: 'landingProxies',
        desc: 'Landing proxies section title',
      );

  String get addLandingProxy => Intl.message(
        '添加落地代理',
        name: 'addLandingProxy',
        desc: 'Add landing proxy',
      );

  String get quickImport => Intl.message(
        '快速智能导入',
        name: 'quickImport',
        desc: 'Smart quick import',
      );

  String get quickImportDesc => Intl.message(
        '支持 IP:端口:用户名:密码、链接等格式一键导入',
        name: 'quickImportDesc',
        desc: 'Smart quick import description',
      );

  String get pasteFromClipboard => Intl.message(
        '从剪贴板粘贴',
        name: 'pasteFromClipboard',
        desc: 'Paste from clipboard',
      );

  String get testAll => Intl.message(
        '全部测速',
        name: 'testAll',
        desc: 'Test all delays',
      );

  String get emptyLandingTip => Intl.message(
        '暂无落地住宅节点。支持主流住宅IP提供商（如 IPRoyal、LunaProxy、Oxylabs 等）常见格式一键粘贴导入。',
        name: 'emptyLandingTip',
        desc: 'Empty landing proxies tip',
      );

  String get nodeName => Intl.message(
        '节点名称',
        name: 'nodeName',
        desc: 'Node name',
      );

  String get protocol => Intl.message(
        '代理协议',
        name: 'protocol',
        desc: 'Proxy protocol',
      );

  String get serverAddress => Intl.message(
        '服务器地址',
        name: 'serverAddress',
        desc: 'Server address',
      );

  String get port => Intl.message(
        '端口',
        name: 'port',
        desc: 'Port',
      );

  String get username => Intl.message(
        '用户名',
        name: 'username',
        desc: 'Username',
      );

  String get password => Intl.message(
        '密码',
        name: 'password',
        desc: 'Password',
      );

  String get cipher => Intl.message(
        '加密方式',
        name: 'cipher',
        desc: 'Cipher',
      );

  String get udpForwarding => Intl.message(
        'UDP 转发',
        name: 'udpForwarding',
        desc: 'UDP forwarding',
      );

  String get udpForwardingDesc => Intl.message(
        '若住宅IP不支持 UDP 导致异常，可关闭此项',
        name: 'udpForwardingDesc',
        desc: 'UDP forwarding tip',
      );

  String get specificDialerProxy => Intl.message(
        '独立指定跳板',
        name: 'specificDialerProxy',
        desc: 'Specific dialer proxy',
      );

  String get inheritDefaultDialer => Intl.message(
        '继承全局默认跳板',
        name: 'inheritDefaultDialer',
        desc: 'Inherit default dialer proxy',
      );

  String get directConnection => Intl.message(
        'DIRECT (直连不走跳板)',
        name: 'directConnection',
        desc: 'Direct connection without hop',
      );

  String get hop => Intl.message(
        '跳板',
        name: 'hop',
        desc: 'Hop badge',
      );

  String get inputProxyTextHint => Intl.message(
        '粘贴住宅IP信息，例如：\n198.51.100.1:8000:username:password\n或 socks5://user:pass@198.51.100.1:8000\n支持多行批量粘贴',
        name: 'inputProxyTextHint',
        desc: 'Input proxy text hint',
      );

  String importSuccessCount(int count) => Intl.message(
        '成功导入 $count 个落地代理节点',
        name: 'importSuccessCount',
        args: [count],
        desc: 'Import success count',
      );

  String get parseNoValidNode => Intl.message(
        '未能识别到有效代理信息，请检查格式',
        name: 'parseNoValidNode',
        desc: 'Parse no valid node tip',
      );

  String get healthCheck => Intl.message(
        '可用性体检',
        name: 'healthCheck',
        desc: 'Health check',
      );

  String get healthCheckAll => Intl.message(
        '全项体检',
        name: 'healthCheckAll',
        desc: 'Verify all proxies',
      );

  String get healthReport => Intl.message(
        '住宅 IP 连通性报告',
        name: 'healthReport',
        desc: 'Residential IP health report',
      );

  String get testingHealth => Intl.message(
        '正在检测...',
        name: 'testingHealth',
        desc: 'Testing health status',
      );

  String get healthHealthy => Intl.message(
        '正常可用',
        name: 'healthHealthy',
        desc: 'Healthy status',
      );

  String get healthWarning => Intl.message(
        '部分受限',
        name: 'healthWarning',
        desc: 'Warning status',
      );

  String get healthError => Intl.message(
        '异常不可用',
        name: 'healthError',
        desc: 'Error status',
      );

  String get healthUntested => Intl.message(
        '未体检',
        name: 'healthUntested',
        desc: 'Untested status',
      );

  String get filterAll => Intl.message(
        '全部',
        name: 'filterAll',
        desc: 'Filter all',
      );

  String get filterHealthy => Intl.message(
        '仅看可用',
        name: 'filterHealthy',
        desc: 'Filter healthy',
      );

  String get filterError => Intl.message(
        '异常/未测',
        name: 'filterError',
        desc: 'Filter error or untested',
      );

  String get clearInvalidProxies => Intl.message(
        '清理不可用节点',
        name: 'clearInvalidProxies',
        desc: 'Clear dead proxies',
      );

  String clearedInvalidCount(int count) => Intl.message(
        '已清理 $count 个失效节点',
        name: 'clearedInvalidCount',
        args: [count],
        desc: 'Cleared invalid count',
      );

  String get noInvalidProxies => Intl.message(
        '当前没有不可用的失效节点',
        name: 'noInvalidProxies',
        desc: 'No dead proxies found',
      );

  String get testCurrentProxy => Intl.message(
        '测试可用性',
        name: 'testCurrentProxy',
        desc: 'Test availability button',
      );

  String get testing => Intl.message(
        '测试中...',
        name: 'testing',
        desc: 'Testing text',
      );

  String batchCheckingProgress(int completed, int total) => Intl.message(
        '正在体检 ($completed/$total)...',
        name: 'batchCheckingProgress',
        args: [completed, total],
        desc: 'Batch checking progress',
      );

  String get topologyClient => Intl.message(
        '本机客户端',
        name: 'topologyClient',
        desc: 'Client node',
      );

  String get topologyHop => Intl.message(
        '前置跳板',
        name: 'topologyHop',
        desc: 'Dialer hop node',
      );

  String get topologyLanding => Intl.message(
        '住宅落地',
        name: 'topologyLanding',
        desc: 'Landing residential IP node',
      );

  String get topologyTarget => Intl.message(
        '目标服务',
        name: 'topologyTarget',
        desc: 'Target services',
      );

  String get diagnosticAdvice => Intl.message(
        '智能排障建议',
        name: 'diagnosticAdvice',
        desc: 'Diagnostic advice',
      );

  String get retest => Intl.message(
        '重新体检',
        name: 'retest',
        desc: 'Retest button',
      );

  String get confirmClearInvalid => Intl.message(
        '确定清理所有检测为不可用的住宅 IP 吗？',
        name: 'confirmClearInvalid',
        desc: 'Confirm clear dead proxies',
      );
}
