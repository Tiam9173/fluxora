import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/public_ip_info.dart';
import 'package:fluxora/services/public_ip_service.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

enum HopRole {
  hop1Entry('第一跳（入口/中转）'),
  hop2Relay('第二跳（中转）'),
  hop2Exit('第二跳（出口/落地）'),
  hop3Exit('第三跳（出口/落地）'),
  finalExit('最终全链路出口');

  final String label;
  const HopRole(this.label);
}

enum ChainHealthStatus {
  unknown('未检测'),
  checking('检测中'),
  healthy('正常'),
  degraded('部分受限'),
  failed('异常'),
  unavailable('不可用'),
  cancelled('已取消');

  final String label;
  const ChainHealthStatus(this.label);

  bool get isHealthy => this == ChainHealthStatus.healthy;
  bool get isDegraded => this == ChainHealthStatus.degraded;
  bool get isFailed => this == ChainHealthStatus.failed;
  bool get isChecking => this == ChainHealthStatus.checking;
  bool get isCancelled => this == ChainHealthStatus.cancelled;
  bool get isUnknown => this == ChainHealthStatus.unknown;
}

class ChainProbeErrorCodes {
  static const String none = 'NONE';
  static const String topologyInvalid = 'TOPOLOGY_INVALID';
  static const String hop1Failed = 'HOP1_FAILED';
  static const String hop1Timeout = 'HOP1_TIMEOUT';
  static const String hop2Failed = 'HOP2_FAILED';
  static const String hop2Timeout = 'HOP2_TIMEOUT';
  static const String exitFailed = 'EXIT_FAILED';
  static const String exitTimeout = 'EXIT_TIMEOUT';
  static const String upstreamFailed = 'UPSTREAM_FAILED';
  static const String internetUnreachable = 'INTERNET_UNREACHABLE';
  static const String ipApiUnavailable = 'IP_API_UNAVAILABLE';
  static const String cancelled = 'CANCELLED';
  static const String unknown = 'UNKNOWN_ERROR';
}

enum HopProbeStatus {
  unknown('未知'),
  checking('检测中'),
  healthy('正常'),
  warning('告警'),
  failed('失败'),
  timeout('超时'),
  degraded('部分受限'),
  unavailable('不可用'),
  cancelled('已取消');

  final String label;
  const HopProbeStatus(this.label);

  ChainHealthStatus toHealthStatus() {
    return switch (this) {
      HopProbeStatus.unknown => ChainHealthStatus.unknown,
      HopProbeStatus.checking => ChainHealthStatus.checking,
      HopProbeStatus.healthy => ChainHealthStatus.healthy,
      HopProbeStatus.warning ||
      HopProbeStatus.degraded => ChainHealthStatus.degraded,
      HopProbeStatus.failed ||
      HopProbeStatus.timeout => ChainHealthStatus.failed,
      HopProbeStatus.unavailable => ChainHealthStatus.unavailable,
      HopProbeStatus.cancelled => ChainHealthStatus.cancelled,
    };
  }
}

enum IpObservationStatus {
  /// 真实通过探针或该跳对外发出的请求观测到的公网 IP
  observed('已观测'),

  /// 在当前级联封装下，由于流量直接在隧道内部封装转发，无法直接观测中间跳的公网 IP
  unavailable('不可直接观测（内部隧道传输）'),

  /// 当前 Mihomo 架构不支持无感提取该跳的独立公网 IP，严禁伪造
  unsupported('暂不支持独立提取（需独立回环探针）');

  final String label;
  const IpObservationStatus(this.label);
}

class HopProbeState {
  final int hopIndex;
  final HopRole role;
  final String nodeName;
  final String nodeAddress; // 配置中的服务器地址（可能是域名或内部IP）
  final int? nodePort;
  final HopProbeStatus status;
  final ChainHealthStatus healthStatus;
  final int? latencyMs;
  final PublicIpInfo? observedPublicIp;
  final IpObservationStatus ipStatus;
  final String? ipStatusReason;
  final String? errorMessage;
  final String? errorCode;
  final String? diagnosticTip;
  final DateTime? testedAt;

  int? get latency => latencyMs;
  String? get error => errorMessage;
  IpObservationStatus get observationStatus => ipStatus;
  DateTime? get checkedAt => testedAt;

  const HopProbeState({
    required this.hopIndex,
    required this.role,
    required this.nodeName,
    required this.nodeAddress,
    this.nodePort,
    this.status = HopProbeStatus.unknown,
    ChainHealthStatus? healthStatus,
    this.latencyMs,
    this.observedPublicIp,
    this.ipStatus = IpObservationStatus.unavailable,
    this.ipStatusReason,
    this.errorMessage,
    this.errorCode,
    this.diagnosticTip,
    this.testedAt,
  }) : healthStatus =
           healthStatus ??
           (status == HopProbeStatus.healthy
               ? ChainHealthStatus.healthy
               : (status == HopProbeStatus.checking
                     ? ChainHealthStatus.checking
                     : (status == HopProbeStatus.warning ||
                               status == HopProbeStatus.degraded
                           ? ChainHealthStatus.degraded
                           : (status == HopProbeStatus.failed ||
                                     status == HopProbeStatus.timeout
                                 ? ChainHealthStatus.failed
                                 : (status == HopProbeStatus.cancelled
                                       ? ChainHealthStatus.cancelled
                                       : ChainHealthStatus.unknown)))));

  HopProbeState copyWith({
    int? hopIndex,
    HopRole? role,
    String? nodeName,
    String? nodeAddress,
    int? nodePort,
    HopProbeStatus? status,
    ChainHealthStatus? healthStatus,
    int? latencyMs,
    PublicIpInfo? observedPublicIp,
    IpObservationStatus? ipStatus,
    String? ipStatusReason,
    String? errorMessage,
    String? errorCode,
    String? diagnosticTip,
    DateTime? testedAt,
  }) {
    return HopProbeState(
      hopIndex: hopIndex ?? this.hopIndex,
      role: role ?? this.role,
      nodeName: nodeName ?? this.nodeName,
      nodeAddress: nodeAddress ?? this.nodeAddress,
      nodePort: nodePort ?? this.nodePort,
      status: status ?? this.status,
      healthStatus: healthStatus ?? this.healthStatus,
      latencyMs: latencyMs ?? this.latencyMs,
      observedPublicIp: observedPublicIp ?? this.observedPublicIp,
      ipStatus: ipStatus ?? this.ipStatus,
      ipStatusReason: ipStatusReason ?? this.ipStatusReason,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      diagnosticTip: diagnosticTip ?? this.diagnosticTip,
      testedAt: testedAt ?? this.testedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'hopIndex': hopIndex,
    'role': role.name,
    'nodeName': nodeName,
    'nodeAddress': nodeAddress,
    if (nodePort != null) 'nodePort': nodePort,
    'status': status.name,
    'healthStatus': healthStatus.name,
    if (latencyMs != null) 'latencyMs': latencyMs,
    if (observedPublicIp != null)
      'observedPublicIp': observedPublicIp!.toJson(),
    'ipStatus': ipStatus.name,
    if (ipStatusReason != null) 'ipStatusReason': ipStatusReason,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (errorCode != null) 'errorCode': errorCode,
    if (diagnosticTip != null) 'diagnosticTip': diagnosticTip,
    if (testedAt != null) 'testedAt': testedAt!.toIso8601String(),
  };

  factory HopProbeState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString();
    final status = HopProbeStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => HopProbeStatus.unknown,
    );
    final healthName = json['healthStatus']?.toString();
    final healthStatus = ChainHealthStatus.values.firstWhere(
      (e) => e.name == healthName,
      orElse: () => status.toHealthStatus(),
    );
    final roleName = json['role']?.toString();
    final role = HopRole.values.firstWhere(
      (e) => e.name == roleName,
      orElse: () => HopRole.hop1Entry,
    );
    final ipStatusName = json['ipStatus']?.toString();
    final ipStatus = IpObservationStatus.values.firstWhere(
      (e) => e.name == ipStatusName,
      orElse: () => IpObservationStatus.unavailable,
    );

    return HopProbeState(
      hopIndex: json['hopIndex'] as int? ?? 1,
      role: role,
      nodeName: json['nodeName']?.toString() ?? '',
      nodeAddress: json['nodeAddress']?.toString() ?? '',
      nodePort: json['nodePort'] as int?,
      status: status,
      healthStatus: healthStatus,
      latencyMs: json['latencyMs'] as int?,
      observedPublicIp: json['observedPublicIp'] is Map<String, dynamic>
          ? PublicIpInfo.fromJson(
              json['observedPublicIp'] as Map<String, dynamic>,
            )
          : null,
      ipStatus: ipStatus,
      ipStatusReason: json['ipStatusReason']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      errorCode: json['errorCode']?.toString(),
      diagnosticTip: json['diagnosticTip']?.toString(),
      testedAt: DateTime.tryParse(json['testedAt']?.toString() ?? ''),
    );
  }
}

class ChainProbeReport {
  final ChainHopMode mode;
  final bool isOverallHealthy;
  final ChainHealthStatus healthStatus;
  final int? totalChainLatencyMs;
  final List<HopProbeState> hops;
  final HopProbeState? finalExit;
  final String? rootCauseAnalysis;
  final int? failureHop;
  final String? errorCode;
  final bool isCancelled;
  final int attemptCount;
  final DateTime timestamp;

  ChainHealthStatus get status => healthStatus;
  int? get totalLatency => totalChainLatencyMs;
  HopProbeState? get exit => finalExit;
  String? get failureReason => rootCauseAnalysis;
  DateTime get checkedAt => timestamp;

  const ChainProbeReport({
    required this.mode,
    required this.isOverallHealthy,
    ChainHealthStatus? healthStatus,
    this.totalChainLatencyMs,
    required this.hops,
    this.finalExit,
    this.rootCauseAnalysis,
    this.failureHop,
    this.errorCode,
    this.isCancelled = false,
    this.attemptCount = 1,
    required this.timestamp,
  }) : healthStatus =
           healthStatus ??
           (isCancelled
               ? ChainHealthStatus.cancelled
               : (isOverallHealthy
                     ? ChainHealthStatus.healthy
                     : ChainHealthStatus.failed));

  factory ChainProbeReport.initial(ChainHopMode mode) {
    return ChainProbeReport(
      mode: mode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.unknown,
      hops: const [],
      attemptCount: 0,
      timestamp: DateTime.now(),
    );
  }

  factory ChainProbeReport.cancelled({
    required ChainHopMode mode,
    required DateTime timestamp,
    int attemptCount = 1,
  }) {
    return ChainProbeReport(
      mode: mode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.cancelled,
      hops: const [],
      errorCode: ChainProbeErrorCodes.cancelled,
      rootCauseAnalysis: '用户取消了链路健康检测',
      isCancelled: true,
      attemptCount: attemptCount,
      timestamp: timestamp,
    );
  }

  ChainProbeReport copyWith({
    ChainHopMode? mode,
    bool? isOverallHealthy,
    ChainHealthStatus? healthStatus,
    int? totalChainLatencyMs,
    List<HopProbeState>? hops,
    HopProbeState? finalExit,
    String? rootCauseAnalysis,
    int? failureHop,
    String? errorCode,
    bool? isCancelled,
    int? attemptCount,
    DateTime? timestamp,
  }) {
    return ChainProbeReport(
      mode: mode ?? this.mode,
      isOverallHealthy: isOverallHealthy ?? this.isOverallHealthy,
      healthStatus: healthStatus ?? this.healthStatus,
      totalChainLatencyMs: totalChainLatencyMs ?? this.totalChainLatencyMs,
      hops: hops ?? this.hops,
      finalExit: finalExit ?? this.finalExit,
      rootCauseAnalysis: rootCauseAnalysis ?? this.rootCauseAnalysis,
      failureHop: failureHop ?? this.failureHop,
      errorCode: errorCode ?? this.errorCode,
      isCancelled: isCancelled ?? this.isCancelled,
      attemptCount: attemptCount ?? this.attemptCount,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'isOverallHealthy': isOverallHealthy,
    'healthStatus': healthStatus.name,
    if (totalChainLatencyMs != null) 'totalChainLatencyMs': totalChainLatencyMs,
    'hops': hops.map((e) => e.toJson()).toList(),
    if (finalExit != null) 'finalExit': finalExit!.toJson(),
    if (rootCauseAnalysis != null) 'rootCauseAnalysis': rootCauseAnalysis,
    if (failureHop != null) 'failureHop': failureHop,
    if (errorCode != null) 'errorCode': errorCode,
    'isCancelled': isCancelled,
    'attemptCount': attemptCount,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChainProbeReport.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode']?.toString();
    final mode = ChainHopMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => ChainHopMode.twoHop,
    );
    final healthName = json['healthStatus']?.toString();
    final healthStatus = ChainHealthStatus.values.firstWhere(
      (e) => e.name == healthName,
      orElse: () => json['isOverallHealthy'] == true
          ? ChainHealthStatus.healthy
          : ChainHealthStatus.failed,
    );
    final hopsList = json['hops'] as List<dynamic>? ?? [];

    return ChainProbeReport(
      mode: mode,
      isOverallHealthy: json['isOverallHealthy'] == true,
      healthStatus: healthStatus,
      totalChainLatencyMs: json['totalChainLatencyMs'] as int?,
      hops: hopsList
          .whereType<Map<String, dynamic>>()
          .map((e) => HopProbeState.fromJson(e))
          .toList(),
      finalExit: json['finalExit'] is Map<String, dynamic>
          ? HopProbeState.fromJson(json['finalExit'] as Map<String, dynamic>)
          : null,
      rootCauseAnalysis: json['rootCauseAnalysis']?.toString(),
      failureHop: json['failureHop'] as int?,
      errorCode: json['errorCode']?.toString(),
      isCancelled: json['isCancelled'] == true,
      attemptCount: json['attemptCount'] as int? ?? 1,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

typedef ChainHealthResult = ChainProbeReport;
typedef HopHealthState = HopProbeState;

typedef DelayTester = Future<int?> Function(String proxyName, String testUrl);
typedef IpDetector = Future<PublicIpInfo?> Function();

abstract class IChainProbeService {
  Future<ChainProbeReport> probeChain({
    required ChainProxyConfig config,
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
  });
}

class ChainProbeService implements IChainProbeService {
  final PublicIpService _ipService;
  final DelayTester? _customDelayTester;
  final IpDetector? _customExitIpDetector;
  DelayTester? customDelayTesterOverride;

  ChainProbeService({
    PublicIpService? ipService,
    DelayTester? customDelayTester,
    IpDetector? customExitIpDetector,
  }) : _ipService = ipService ?? publicIpService,
       _customDelayTester = customDelayTester,
       _customExitIpDetector = customExitIpDetector;

  Future<int?> _testDelay(
    String proxyName,
    String testUrl, {
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) return null;
    final tester = customDelayTesterOverride ?? _customDelayTester;
    if (tester != null) {
      return tester(proxyName, testUrl);
    }
    try {
      final effectiveTimeout = timeout ?? const Duration(seconds: 4);
      final delayFuture = clashCore.getDelay(testUrl, proxyName);
      final res = await delayFuture.timeout(effectiveTimeout);
      return res.value;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ChainProbeReport> probeChain({
    required ChainProxyConfig config,
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
  }) async {
    final now = DateTime.now();
    final effectiveTestUrl = testUrl ?? 'https://www.gstatic.com/generate_204';
    final mode = config.hopMode;

    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeStarted,
        nodeName: config.effectiveHop1,
        role: 'Entry',
        message: '发起 ${mode.label} 链路健康检测',
        metadata: {
          'hopMode': mode.name,
          'hop1': config.effectiveHop1,
          'hop2': config.hop2Node,
          if (mode == ChainHopMode.threeHop) 'hop3': config.hop3Node,
        },
      ),
    );

    // 1. Topology pre-validation check
    final hop1 = config.effectiveHop1;
    final hop2 = config.hop2Node;
    final hop3 = config.hop3Node;

    final validation = ChainTopologyValidator.validate(
      mode: mode,
      hop1: hop1,
      hop2: hop2,
      hop3: mode == ChainHopMode.threeHop ? hop3 : null,
      dedicatedGroupName: config.dedicatedGroupName,
    );

    if (!validation.isValid) {
      final invalidReport = ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        hops: const [],
        failureHop: validation.affectedHop,
        errorCode: ChainProbeErrorCodes.topologyInvalid,
        rootCauseAnalysis: '链路拓扑非法: ${validation.message}',
        timestamp: now,
      );

      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          nodeName: config.effectiveHop1,
          role: 'Entry',
          errorCode: ChainProbeErrorCodes.topologyInvalid,
          message: '探测失败: 链路拓扑非法 (${validation.message})',
          metadata: {'hopMode': mode.name},
        ),
      );

      onProgress?.call(invalidReport);
      return invalidReport;
    }

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: now);
    }

    // Initialize hops in checking state
    final hops = <HopProbeState>[
      HopProbeState(
        hopIndex: 1,
        role: HopRole.hop1Entry,
        nodeName: hop1,
        nodeAddress: hop1,
        status: HopProbeStatus.checking,
        healthStatus: ChainHealthStatus.checking,
        ipStatus: IpObservationStatus.unavailable,
        ipStatusReason: '第一跳作为前置代理，后续流量直接经由加密隧道发往中转/落地节点，出口流量未在此处解密观测',
        diagnosticTip: '正在检测入口节点连通性...',
        testedAt: now,
      ),
      HopProbeState(
        hopIndex: 2,
        role: mode == ChainHopMode.threeHop
            ? HopRole.hop2Relay
            : HopRole.hop2Exit,
        nodeName: hop2,
        nodeAddress: hop2,
        status: HopProbeStatus.unknown,
        healthStatus: ChainHealthStatus.unknown,
        ipStatus: IpObservationStatus.unavailable,
        ipStatusReason: mode == ChainHopMode.threeHop
            ? '第二跳作为中转隧道，流量继续流向第三跳，无法直接提取独立出口 IP'
            : '第二跳作为最终出口，请参考下方最终全链路出口观测结果',
        diagnosticTip: '等待前置跳检测完成...',
        testedAt: now,
      ),
      if (mode == ChainHopMode.threeHop)
        HopProbeState(
          hopIndex: 3,
          role: HopRole.hop3Exit,
          nodeName: hop3,
          nodeAddress: hop3,
          status: HopProbeStatus.unknown,
          healthStatus: ChainHealthStatus.unknown,
          ipStatus: IpObservationStatus.unavailable,
          ipStatusReason: '第三跳最终出口 IP 请参考下方全链路出口观测结果',
          diagnosticTip: '等待前置跳检测完成...',
          testedAt: now,
        ),
    ];

    onProgress?.call(
      ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.checking,
        hops: List.unmodifiable(hops),
        timestamp: now,
      ),
    );

    // 2. Probe Hop 1
    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: DateTime.now());
    }

    final hop1Delay = await _testDelay(
      hop1,
      effectiveTestUrl,
      timeout: timeout,
      cancelToken: cancelToken,
    );

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: DateTime.now());
    }

    final bool hop1Timeout = hop1Delay == null;
    final bool hop1Healthy = hop1Delay != null && hop1Delay > 0;
    final hop1Status = hop1Healthy
        ? HopProbeStatus.healthy
        : (hop1Timeout ? HopProbeStatus.timeout : HopProbeStatus.failed);
    final hop1HealthStatus = hop1Healthy
        ? ChainHealthStatus.healthy
        : ChainHealthStatus.failed;

    hops[0] = hops[0].copyWith(
      status: hop1Status,
      healthStatus: hop1HealthStatus,
      latencyMs: hop1Delay,
      errorMessage: hop1Healthy
          ? null
          : (hop1Timeout ? '入口节点 [$hop1] 连接超时' : '入口节点 [$hop1] 握手失败或网络不可达'),
      errorCode: hop1Healthy
          ? ChainProbeErrorCodes.none
          : (hop1Timeout
                ? ChainProbeErrorCodes.hop1Timeout
                : ChainProbeErrorCodes.hop1Failed),
      diagnosticTip: hop1Healthy ? '入口连通顺畅' : '请检查第一跳节点服务器状态或本地宽带连通性',
      testedAt: DateTime.now(),
    );
    onHopUpdate?.call(hops[0]);

    if (!hop1Healthy) {
      final failureReason = hop1Timeout
          ? '第一跳 [$hop1] 连通失败（连接超时），导致整条链路无法建立'
          : '第一跳 [$hop1] 连通失败，导致整条链路无法建立';

      for (int i = 1; i < hops.length; i++) {
        hops[i] = hops[i].copyWith(
          status: HopProbeStatus.failed,
          healthStatus: ChainHealthStatus.failed,
          errorMessage: '上游第一跳中断导致此跳无法连接',
          errorCode: ChainProbeErrorCodes.upstreamFailed,
          diagnosticTip: '需先修复入口第一跳网络连通性',
          testedAt: DateTime.now(),
        );
        onHopUpdate?.call(hops[i]);
      }

      final finalExit = HopProbeState(
        hopIndex: mode.hopCount,
        role: HopRole.finalExit,
        nodeName: mode == ChainHopMode.threeHop ? hop3 : hop2,
        nodeAddress: mode == ChainHopMode.threeHop ? hop3 : hop2,
        status: HopProbeStatus.failed,
        healthStatus: ChainHealthStatus.failed,
        errorMessage: failureReason,
        errorCode: hop1Timeout
            ? ChainProbeErrorCodes.hop1Timeout
            : ChainProbeErrorCodes.hop1Failed,
        diagnosticTip: '链路前置跳故障，无法建立端到端连接',
        testedAt: DateTime.now(),
      );

      final failReport = ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        hops: List.unmodifiable(hops),
        finalExit: finalExit,
        failureHop: 1,
        errorCode: hop1Timeout
            ? ChainProbeErrorCodes.hop1Timeout
            : ChainProbeErrorCodes.hop1Failed,
        rootCauseAnalysis: failureReason,
        timestamp: DateTime.now(),
      );

      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          nodeName: hop1,
          role: 'Entry',
          errorCode: hop1Timeout
              ? ChainProbeErrorCodes.hop1Timeout
              : ChainProbeErrorCodes.hop1Failed,
          message: '探测失败: $failureReason',
          metadata: {'hopMode': mode.name},
        ),
      );

      onProgress?.call(failReport);
      return failReport;
    }

    // 3. Probe Hop 2 (Hop 1 is healthy)
    hops[1] = hops[1].copyWith(
      status: HopProbeStatus.checking,
      healthStatus: ChainHealthStatus.checking,
      diagnosticTip: mode == ChainHopMode.threeHop
          ? '正在检测中转节点连通性...'
          : '正在检测落地出口连通性...',
      testedAt: DateTime.now(),
    );
    onHopUpdate?.call(hops[1]);
    onProgress?.call(
      ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.checking,
        hops: List.unmodifiable(hops),
        timestamp: DateTime.now(),
      ),
    );

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: DateTime.now());
    }

    final hop2Delay = await _testDelay(
      hop2,
      effectiveTestUrl,
      timeout: timeout,
      cancelToken: cancelToken,
    );

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: DateTime.now());
    }

    final bool hop2Timeout = hop2Delay == null;
    final bool hop2Healthy = hop2Delay != null && hop2Delay > 0;
    final hop2Status = hop2Healthy
        ? HopProbeStatus.healthy
        : (hop2Timeout ? HopProbeStatus.timeout : HopProbeStatus.failed);
    final hop2HealthStatus = hop2Healthy
        ? ChainHealthStatus.healthy
        : ChainHealthStatus.failed;

    hops[1] = hops[1].copyWith(
      status: hop2Status,
      healthStatus: hop2HealthStatus,
      latencyMs: hop2Delay,
      errorMessage: hop2Healthy
          ? null
          : (mode == ChainHopMode.threeHop
                ? (hop2Timeout
                      ? '第二跳中转节点 [$hop2] 连接超时'
                      : '第二跳中转节点 [$hop2] 握手失败')
                : (hop2Timeout
                      ? '第二跳落地出口节点 [$hop2] 连接超时'
                      : '第二跳落地出口节点 [$hop2] 握手失败')),
      errorCode: hop2Healthy
          ? ChainProbeErrorCodes.none
          : (mode == ChainHopMode.threeHop
                ? (hop2Timeout
                      ? ChainProbeErrorCodes.hop2Timeout
                      : ChainProbeErrorCodes.hop2Failed)
                : (hop2Timeout
                      ? ChainProbeErrorCodes.exitTimeout
                      : ChainProbeErrorCodes.exitFailed)),
      diagnosticTip: hop2Healthy
          ? (mode == ChainHopMode.threeHop ? '中转连通顺畅' : '落地出口连通顺畅')
          : (mode == ChainHopMode.threeHop
                ? '建议更换中转跳节点或核查配置'
                : '建议更换落地出口节点或核查账号凭据'),
      testedAt: DateTime.now(),
    );
    onHopUpdate?.call(hops[1]);

    if (!hop2Healthy) {
      final failureReason = mode == ChainHopMode.threeHop
          ? (hop2Timeout
                ? '第一跳就绪，但第二跳中转节点 [$hop2] 连通失败（连接超时）'
                : '第一跳就绪，但第二跳中转节点 [$hop2] 连通失败')
          : (hop2Timeout
                ? '第一跳就绪，但第二跳落地节点 [$hop2] 握手失败（连接超时）'
                : '第一跳就绪，但第二跳落地节点 [$hop2] 握手失败');

      if (mode == ChainHopMode.threeHop && hops.length > 2) {
        hops[2] = hops[2].copyWith(
          status: HopProbeStatus.failed,
          healthStatus: ChainHealthStatus.failed,
          errorMessage: '上游中转跳中断导致此跳无法连接',
          errorCode: ChainProbeErrorCodes.upstreamFailed,
          diagnosticTip: '需先修复第二跳中转网络连通性',
          testedAt: DateTime.now(),
        );
        onHopUpdate?.call(hops[2]);
      }

      final finalExit = HopProbeState(
        hopIndex: mode.hopCount,
        role: HopRole.finalExit,
        nodeName: mode == ChainHopMode.threeHop ? hop3 : hop2,
        nodeAddress: mode == ChainHopMode.threeHop ? hop3 : hop2,
        status: HopProbeStatus.failed,
        healthStatus: ChainHealthStatus.failed,
        errorMessage: failureReason,
        errorCode: mode == ChainHopMode.threeHop
            ? (hop2Timeout
                  ? ChainProbeErrorCodes.hop2Timeout
                  : ChainProbeErrorCodes.hop2Failed)
            : (hop2Timeout
                  ? ChainProbeErrorCodes.exitTimeout
                  : ChainProbeErrorCodes.exitFailed),
        diagnosticTip: '第二跳节点连接异常，全链路建立失败',
        testedAt: DateTime.now(),
      );

      final failReport = ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        hops: List.unmodifiable(hops),
        finalExit: finalExit,
        failureHop: 2,
        errorCode: mode == ChainHopMode.threeHop
            ? (hop2Timeout
                  ? ChainProbeErrorCodes.hop2Timeout
                  : ChainProbeErrorCodes.hop2Failed)
            : (hop2Timeout
                  ? ChainProbeErrorCodes.exitTimeout
                  : ChainProbeErrorCodes.exitFailed),
        rootCauseAnalysis: failureReason,
        timestamp: DateTime.now(),
      );

      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          nodeName: hop2,
          role: mode == ChainHopMode.threeHop ? 'Relay' : 'Exit',
          errorCode: mode == ChainHopMode.threeHop
              ? (hop2Timeout
                    ? ChainProbeErrorCodes.hop2Timeout
                    : ChainProbeErrorCodes.hop2Failed)
              : (hop2Timeout
                    ? ChainProbeErrorCodes.exitTimeout
                    : ChainProbeErrorCodes.exitFailed),
          message: '探测失败: $failureReason',
          metadata: {'hopMode': mode.name},
        ),
      );

      onProgress?.call(failReport);
      return failReport;
    }

    // 4. Probe Hop 3 (if threeHop)
    int? hop3Delay;
    HopProbeStatus hop3Status = HopProbeStatus.unknown;

    if (mode == ChainHopMode.threeHop) {
      hops[2] = hops[2].copyWith(
        status: HopProbeStatus.checking,
        healthStatus: ChainHealthStatus.checking,
        diagnosticTip: '正在检测落地出口节点连通性...',
        testedAt: DateTime.now(),
      );
      onHopUpdate?.call(hops[2]);
      onProgress?.call(
        ChainProbeReport(
          mode: mode,
          isOverallHealthy: false,
          healthStatus: ChainHealthStatus.checking,
          hops: List.unmodifiable(hops),
          timestamp: DateTime.now(),
        ),
      );

      if (cancelToken?.isCancelled == true) {
        return ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
        );
      }

      hop3Delay = await _testDelay(
        hop3,
        effectiveTestUrl,
        timeout: timeout,
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled == true) {
        return ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
        );
      }

      final bool hop3Timeout = hop3Delay == null;
      final bool hop3Healthy = hop3Delay != null && hop3Delay > 0;
      hop3Status = hop3Healthy
          ? HopProbeStatus.healthy
          : (hop3Timeout ? HopProbeStatus.timeout : HopProbeStatus.failed);
      final hop3HealthStatus = hop3Healthy
          ? ChainHealthStatus.healthy
          : ChainHealthStatus.failed;

      hops[2] = hops[2].copyWith(
        status: hop3Status,
        healthStatus: hop3HealthStatus,
        latencyMs: hop3Delay,
        errorMessage: hop3Healthy
            ? null
            : (hop3Timeout
                  ? '最后一跳落地出口节点 [$hop3] 连接超时'
                  : '最后一跳落地出口节点 [$hop3] 无法建立连接或认证失败'),
        errorCode: hop3Healthy
            ? ChainProbeErrorCodes.none
            : (hop3Timeout
                  ? ChainProbeErrorCodes.exitTimeout
                  : ChainProbeErrorCodes.exitFailed),
        diagnosticTip: hop3Healthy ? '落地出口连通顺畅' : '请核实落地住宅节点的有效性与账号凭据',
        testedAt: DateTime.now(),
      );
      onHopUpdate?.call(hops[2]);

      if (!hop3Healthy) {
        final failureReason = hop3Timeout
            ? '前两跳畅通，但最后一跳落地出口节点 [$hop3] 连接超时'
            : '前两跳畅通，但最后一跳落地出口节点 [$hop3] 无法建立连接或认证失败';

        final finalExit = HopProbeState(
          hopIndex: 3,
          role: HopRole.finalExit,
          nodeName: hop3,
          nodeAddress: hop3,
          status: HopProbeStatus.failed,
          healthStatus: ChainHealthStatus.failed,
          errorMessage: failureReason,
          errorCode: hop3Timeout
              ? ChainProbeErrorCodes.exitTimeout
              : ChainProbeErrorCodes.exitFailed,
          diagnosticTip: '出口落地节点异常，链路无法访问外网',
          testedAt: DateTime.now(),
        );

        final failReport = ChainProbeReport(
          mode: mode,
          isOverallHealthy: false,
          healthStatus: ChainHealthStatus.failed,
          hops: List.unmodifiable(hops),
          finalExit: finalExit,
          failureHop: 3,
          errorCode: hop3Timeout
              ? ChainProbeErrorCodes.exitTimeout
              : ChainProbeErrorCodes.exitFailed,
          rootCauseAnalysis: failureReason,
          timestamp: DateTime.now(),
        );

        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeFailed,
            nodeName: hop3,
            role: 'Exit',
            errorCode: hop3Timeout
                ? ChainProbeErrorCodes.exitTimeout
                : ChainProbeErrorCodes.exitFailed,
            message: '探测失败: $failureReason',
            metadata: {'hopMode': mode.name},
          ),
        );

        onProgress?.call(failReport);
        return failReport;
      }
    }

    // 5. Final Exit Detection & Public IP Probe
    final lastHopStatus = mode == ChainHopMode.threeHop
        ? hop3Status
        : hop2Status;
    final lastHopDelay = mode == ChainHopMode.threeHop ? hop3Delay : hop2Delay;
    final bool isChainFullyConnected = lastHopStatus == HopProbeStatus.healthy;

    PublicIpInfo? exitIpInfo;
    String? ipProbeError;
    bool ipApiUnavailable = false;

    if (isChainFullyConnected && checkExitPublicIp) {
      if (cancelToken?.isCancelled == true) {
        return ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
        );
      }

      if (_customExitIpDetector != null) {
        exitIpInfo = await _customExitIpDetector();
        if (exitIpInfo == null) {
          ipApiUnavailable = true;
          ipProbeError = '公网 IP 探测服务未返回有效数据';
        }
      } else {
        final ipRes = await _ipService.fetchPublicIp(
          forceRefresh: true,
          cancelToken: cancelToken,
          timeout: timeout ?? const Duration(seconds: 5),
        );
        if (ipRes.isSuccess && ipRes.data != null) {
          exitIpInfo = ipRes.data;
        } else {
          ipProbeError = ipRes.message;
          ipApiUnavailable = true;
        }
      }
    }

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(mode: mode, timestamp: DateTime.now());
    }

    // Determine final status:
    // If transport is healthy but IP API failed, chain is DEGRADED (transport functional), NOT failed!
    final ChainHealthStatus finalOverallHealth;
    final String? finalErrorCode;
    final String? finalRootCause;
    final HopProbeStatus finalExitProbeStatus;
    final ChainHealthStatus finalExitHealthStatus;
    final IpObservationStatus finalIpStatus;
    final String? finalIpReason;

    if (isChainFullyConnected) {
      if (exitIpInfo != null) {
        finalOverallHealth = ChainHealthStatus.healthy;
        finalErrorCode = ChainProbeErrorCodes.none;
        finalRootCause = null;
        finalExitProbeStatus = HopProbeStatus.healthy;
        finalExitHealthStatus = ChainHealthStatus.healthy;
        finalIpStatus = IpObservationStatus.observed;
        finalIpReason = '成功通过完整链式隧道测得最终互联网呈现公网出口 IP';
      } else if (ipApiUnavailable) {
        finalOverallHealth = ChainHealthStatus.degraded;
        finalErrorCode = ChainProbeErrorCodes.ipApiUnavailable;
        finalRootCause =
            '代理链路传输层已正常建立，但公网 IP 查询服务超时或不可用 (${ipProbeError ?? "无响应"})';
        finalExitProbeStatus = HopProbeStatus.warning;
        finalExitHealthStatus = ChainHealthStatus.degraded;
        finalIpStatus = IpObservationStatus.unavailable;
        finalIpReason = '链路传输层畅通，但公网 IP 查询源未能响应有效数据';
      } else {
        finalOverallHealth = ChainHealthStatus.healthy;
        finalErrorCode = ChainProbeErrorCodes.none;
        finalRootCause = null;
        finalExitProbeStatus = HopProbeStatus.healthy;
        finalExitHealthStatus = ChainHealthStatus.healthy;
        finalIpStatus = IpObservationStatus.unavailable;
        finalIpReason = '未执行公网 IP 嗅探';
      }
    } else {
      finalOverallHealth = ChainHealthStatus.failed;
      finalErrorCode = ChainProbeErrorCodes.unknown;
      finalRootCause = '链路中断，未能完成全跳连通';
      finalExitProbeStatus = HopProbeStatus.failed;
      finalExitHealthStatus = ChainHealthStatus.failed;
      finalIpStatus = IpObservationStatus.unavailable;
      finalIpReason = '链路中断，无法探测出口 IP';
    }

    final finalExit = HopProbeState(
      hopIndex: mode.hopCount,
      role: HopRole.finalExit,
      nodeName: mode == ChainHopMode.threeHop ? hop3 : hop2,
      nodeAddress: mode == ChainHopMode.threeHop ? hop3 : hop2,
      status: finalExitProbeStatus,
      healthStatus: finalExitHealthStatus,
      latencyMs: lastHopDelay,
      observedPublicIp: exitIpInfo,
      ipStatus: finalIpStatus,
      ipStatusReason: finalIpReason,
      errorMessage: finalOverallHealth == ChainHealthStatus.failed
          ? finalRootCause
          : null,
      errorCode: finalErrorCode,
      diagnosticTip: finalOverallHealth == ChainHealthStatus.healthy
          ? '全链路健康就绪'
          : (finalOverallHealth == ChainHealthStatus.degraded
                ? '代理传输畅通，外网流量可正常代理；如需查看公网IP，请检查查询源连通性'
                : '请根据各跳断点排障提示检查相关节点配置'),
      testedAt: now,
    );

    final finalReport = ChainProbeReport(
      mode: mode,
      isOverallHealthy: isChainFullyConnected, // Transport health
      healthStatus: finalOverallHealth,
      totalChainLatencyMs: lastHopDelay,
      hops: List.unmodifiable(hops),
      finalExit: finalExit,
      errorCode: finalErrorCode,
      rootCauseAnalysis: finalRootCause,
      timestamp: now,
    );

    if (finalOverallHealth == ChainHealthStatus.healthy ||
        finalOverallHealth == ChainHealthStatus.degraded) {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          nodeName: mode == ChainHopMode.threeHop
              ? config.hop3Node
              : config.hop2Node,
          role: 'Exit',
          message: finalOverallHealth == ChainHealthStatus.degraded
              ? '链路代理连通，但公网 IP 嗅探失败'
              : '链路连通性检测通过',
          errorCode: finalOverallHealth == ChainHealthStatus.degraded
              ? ChainProbeErrorCodes.ipApiUnavailable
              : null,
          metadata: {'hopMode': mode.name, 'latencyMs': lastHopDelay},
        ),
      );
    } else {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          nodeName: mode == ChainHopMode.threeHop
              ? config.hop3Node
              : config.hop2Node,
          role: 'Exit',
          errorCode: finalErrorCode,
          message: '探测失败: $finalRootCause',
          metadata: {'hopMode': mode.name},
        ),
      );
    }

    onProgress?.call(finalReport);
    return finalReport;
  }
}

final chainProbeService = ChainProbeService();
