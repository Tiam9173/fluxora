import '../models/chain_reliability_stats.dart';
import '../services/network_fingerprint_provider.dart';
import '../models/protocol_capability.dart';

import 'dart:async';

import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'package:fluxora/models/chain_fallback_pool.dart';

import 'package:fluxora/models/chain_failover.dart';

import 'package:fluxora/models/chain_proxy.dart';

import 'package:fluxora/services/chain_fallback_service.dart';

import 'package:fluxora/services/chain_flap_dampener_service.dart';

import 'package:fluxora/services/chain_probe_service.dart';

import 'package:fluxora/services/chain_retry_service.dart';

import 'package:fluxora/models/chain_telemetry.dart';

import 'package:fluxora/services/chain_telemetry_service.dart';

/// 鑷姩鏁呴殰杞Щ鎵ц鍣ㄦ帴鍙ｏ紙渚夸簬鐢熶骇鎵ц涓庡崟鍏冩祴璇?Mock/Failure Injection锛?

abstract class IChainFailoverExecutor {
  /// 搴旂敤鍊欓€夐摼璺厤缃埌 Clash 鍐呮牳锛堟敞鍏ヤ复鏃跺奖瀛愯妭鐐癸級

  Future<void> applyCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  );

  /// 瀵瑰簲鐢ㄥ悗鐨勫€欓€夐摼璺墽琛岀綉缁滆繛閫氭€ф帰娴?

  Future<ChainProbeReport> probeCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  );

  /// 鍥炴粴鍒板師濮嬮摼璺厤缃紙褰诲簳娓呴櫎鍊欓€夊奖瀛愯妭鐐癸紝鎭㈠鍘熼摼璺級

  Future<void> rollbackToOriginal(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  );

  /// 鍊欓€夎妭鐐规帰娴嬮€氳繃鍚庯紝鏈€缁堟彁浜ょ敓鏁?

  Future<void> commitSuccess(ChainProxyConfig finalConfig);
}

/// 榛樿鏁呴殰杞Щ濮旀墭鎵ц鍣紙鏀寔娉ㄥ叆鐙珛鐨勫嚱鏁伴棴鍖咃級

class DelegateChainFailoverExecutor implements IChainFailoverExecutor {
  final Future<void> Function(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  )
  onApply;

  final Future<ChainProbeReport> Function(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  )
  onProbe;

  final Future<void> Function(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  )
  onRollback;

  final Future<void> Function(ChainProxyConfig finalConfig) onCommit;

  const DelegateChainFailoverExecutor({
    required this.onApply,

    required this.onProbe,

    required this.onRollback,

    required this.onCommit,
  });

  @override
  Future<void> applyCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) => onApply(candidateConfig, cancelToken);

  @override
  Future<ChainProbeReport> probeCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) => onProbe(candidateConfig, cancelToken);

  @override
  Future<void> rollbackToOriginal(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  ) => onRollback(originalConfig, cancelToken);

  @override
  Future<void> commitSuccess(ChainProxyConfig finalConfig) =>
      onCommit(finalConfig);
}

/// 鑷姩鏁呴殰杞Щ鏈嶅姟鎺ュ彛

abstract class IChainFailoverService {
  /// 鎵ц鑷姩鏁呴殰杞Щ娴佺▼

  Future<ChainFailoverResult> executeFailover({
    required ChainProxyConfig currentConfig,

    required ChainFallbackPool fallbackPool,

    FallbackCandidateRole? targetRole,

    ChainFailoverPolicy policy = const ChainFailoverPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,

    CancelToken? cancelToken,

    IChainFailoverExecutor? executor,

    IChainFlapDampenerService? flapDampener,

    void Function(ChainFailoverProgress progress)? onProgress,

    void Function(ChainFallbackPool updatedPool)? onPoolUpdated,

    ChainProbeReport? initialFailureReport,
  });
}

/// 閾惧紡浠ｇ悊鑷姩鏁呴殰杞Щ鎵ц灞傚疄鐜?

class ChainFailoverService implements IChainFailoverService {
  final IChainRetryService _retryService;

  final IChainFallbackService _fallbackService;

  final IChainFlapDampenerService _flapDampener;

  ChainFailoverService({
    IChainRetryService? retryService,

    IChainFallbackService? fallbackService,

    IChainFlapDampenerService? flapDampenerService,
  }) : _retryService = retryService ?? chainRetryService,

       _fallbackService = fallbackService ?? chainFallbackService,

       _flapDampener = flapDampenerService ?? chainFlapDampenerService;

  /// 鏍规嵁鏁呴殰璺虫暟鎺ㄥ澶囩敤鍊欓€夎鑹?

  static FallbackCandidateRole deduceRoleFromFailureHop(
    ChainHopMode mode,
    int? failureHop,
  ) {
    if (failureHop == 1) return FallbackCandidateRole.entry;

    if (mode == ChainHopMode.threeHop) {
      if (failureHop == 2) return FallbackCandidateRole.relay;

      if (failureHop == 3) return FallbackCandidateRole.exit;
    } else {
      if (failureHop == 2) return FallbackCandidateRole.exit;
    }

    // 榛樿澶囩敤钀藉湴鍑哄彛

    return FallbackCandidateRole.exit;
  }

  @override
  Future<ChainFailoverResult> executeFailover({
    required ChainProxyConfig currentConfig,

    required ChainFallbackPool fallbackPool,

    FallbackCandidateRole? targetRole,

    ChainFailoverPolicy policy = const ChainFailoverPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,

    CancelToken? cancelToken,

    IChainFailoverExecutor? executor,

    IChainFlapDampenerService? flapDampener,

    void Function(ChainFailoverProgress progress)? onProgress,

    void Function(ChainFallbackPool updatedPool)? onPoolUpdated,

    ChainProbeReport? initialFailureReport,
  }) async {
    // 0. 妫€鏌ユ槸鍚﹀紑鍚摼寮忎唬鐞嗭細鍏ㄥ眬鍏抽棴鐘舵€佷笅绂佹鎵ц Failover

    if (!currentConfig.enable) {
      return ChainFailoverResult.noFailoverNeeded(
        currentConfig: currentConfig,

        probeReport: initialFailureReport,
      );
    }

    if (cancelToken?.isCancelled == true) {
      return ChainFailoverResult.cancelled(
        originalConfig: currentConfig,

        reason: cancelToken?.cancelError?.message ?? '鎵ц鍓嶅凡鍙栨秷',
      );
    }

    ChainProbeReport? lastReport = initialFailureReport;

    // 1. Phase B: 鍘熼摼璺湁闄愰噸璇曪紙鑻ユ湭鎻愪緵鏄庣‘宸插け璐ョ殑鍒濇鎶ュ憡锛?

    if (lastReport == null) {
      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.retrying,

          message: '鍘熼摼璺娴嬪紓甯革紝姝ｅ湪鎵ц鏈夐檺閲嶈瘯...',

          timestamp: DateTime.now(),
        ),
      );

      lastReport = await _retryService.probeWithRetry(
        config: currentConfig,

        policy: policy.retryPolicy,

        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled == true || lastReport.isCancelled) {
        return ChainFailoverResult.cancelled(
          originalConfig: currentConfig,

          reason: '閲嶈瘯闃舵宸茶鍙栨秷',
        );
      }
    }

    // 鑻ラ噸璇曞悗鎭㈠鍋ュ悍鎴栧彲鎺ュ彈鐨勯檷绾х姸鎬侊紝鏃犻渶瑙﹀彂鏁呴殰杞Щ

    final bool initialAcceptable =
        lastReport.healthStatus == ChainHealthStatus.healthy ||
        (policy.allowDegradedCommit &&
            lastReport.healthStatus == ChainHealthStatus.degraded);

    if (initialAcceptable) {
      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.failoverSuccess,

          message: '鍘熼摼璺噸璇曞悗鎭㈠姝ｅ父锛屾棤闇€鍒囨崲澶囩敤鑺傜偣',

          lastReport: lastReport,

          timestamp: DateTime.now(),
        ),
      );

      return ChainFailoverResult.noFailoverNeeded(
        currentConfig: currentConfig,

        probeReport: lastReport,
      );
    }

    if (cancelToken?.isCancelled == true) {
      return ChainFailoverResult.cancelled(
        originalConfig: currentConfig,

        reason: 'garbled',
      );
    }

    // 2. 妫€鏌ユ姈鍔ㄦ姂鍒舵帶鍒?(Phase 3.2-D Flap Dampening)

    final activeDampener = flapDampener ?? _flapDampener;

    if (!policy.bypassDampening) {
      final verdict = activeDampener.evaluate(policy: policy.flapPolicy);

      if (verdict.isDampened) {
        final reason = verdict.reason ?? '瑙﹀彂楂橀閾捐矾鎶栧姩鎶戝埗淇濇姢';

        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.dampened,

            message: reason,

            lastReport: lastReport,

            timestamp: DateTime.now(),
          ),
        );

        return ChainFailoverResult.dampened(
          currentConfig: currentConfig,

          penalty: verdict.penalty,

          suppressedUntil: verdict.suppressedUntil,

          reason: reason,

          probeReport: lastReport,
        );
      }
    }

    // 3. 鍒ゅ畾鏁呴殰瑙掕壊

    final role =
        targetRole ??
        deduceRoleFromFailureHop(currentConfig.hopMode, lastReport.failureHop);

    // 4. Phase C: 鍊欓€夎妭鐐逛紭閫?

    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.failoverStarted,

        role: role.name,

        message: '鍘熼摼璺噸璇曡€楀敖锛屽紑濮嬩负 ${role.label} 瑙掕壊鎵ц鏁呴殰杞Щ',

        metadata: {'failureHop': lastReport.failureHop},
      ),
    );

    onProgress?.call(
      ChainFailoverProgress(
        state: ChainFailoverState.selectingCandidate,

        role: role,

        message: '鍘熼摼璺噸璇曡€楀敖锛屾鍦ㄤ紭閫?[${role.label}] 澶囩敤鍊欓€夎妭鐐?..',

        lastReport: lastReport,

        timestamp: DateTime.now(),
      ),
    );

    final selectionResult = _fallbackService.selectCandidates(
      currentConfig: currentConfig,

      role: role,

      pool: fallbackPool,

      policy: policy.fallbackPolicy,

      availableProxyNames: availableProxyNames,

      availableProxyProfiles: availableProxyProfiles,
    );

    final rawCandidateList = selectionResult.rankedCandidates;

    if (rawCandidateList.isEmpty) {
      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.failoverFailed,

          role: role,

          message:
              '鏈壘鍒板彲鐢ㄧ殑 [${role.label}] 澶囩敤鍊欓€夎妭鐐?(${selectionResult.explanation})',

          lastReport: lastReport,

          failureReason: 'NO_CANDIDATES_AVAILABLE',

          timestamp: DateTime.now(),
        ),
      );

      return ChainFailoverResult.failed(
        originalConfig: currentConfig,

        attemptedCandidatesCount: 0,

        attemptedNodeNames: const [],

        lastProbeReport: lastReport,

        rootCause: '备用候选池中无可用候选节点: ${selectionResult.explanation}',
      );
    }

    if (cancelToken?.isCancelled == true) {
      return ChainFailoverResult.cancelled(
        originalConfig: currentConfig,

        reason: '鍊欓€変紭閫夊悗宸茶鍙栨秷',
      );
    }

    // 4. 鍊欓€夎妭鐐归亶鍘嗕笌鏈夐檺灏濊瘯 (Bounded Execution)

    final attemptedNames = <String>[];

    final attemptedSet = <String>{};

    ChainFallbackPool currentPool = fallbackPool;

    // 浜屾闃叉姢锛氭彁鍙栧綋鍓嶆鍦ㄧ敓鏁堢殑鍚勮烦鑺傜偣鍚嶇О锛岄槻姝换浣曡鑹查噸鍙?

    final activeHops = <String>{
      currentConfig.effectiveHop1.trim(),

      currentConfig.hop2Node.trim(),

      if (currentConfig.hopMode == ChainHopMode.threeHop)
        currentConfig.hop3Node.trim(),
    }..removeWhere((n) => n.isEmpty || n == 'DIRECT');

    final maxToTry = math.min(rawCandidateList.length, policy.maxCandidates);

    for (int i = 0; i < maxToTry; i++) {
      if (cancelToken?.isCancelled == true) {
        return ChainFailoverResult.cancelled(
          originalConfig: currentConfig,

          attemptedCandidatesCount: attemptedNames.length,

          attemptedNodeNames: List.unmodifiable(attemptedNames),

          reason: '灏濊瘯鍊欓€夎妭鐐瑰墠宸茶鍙栨秷',
        );
      }

      final candidate = rawCandidateList[i];

      final candidateName = candidate.nodeName.trim();

      // 鍘婚噸涓庨槻閲嶈瘯闃叉姢

      if (attemptedSet.contains(candidateName)) {
        continue;
      }

      attemptedSet.add(candidateName);

      attemptedNames.add(candidateName);

      // 浜屾闃叉姢锛氫弗绂佸皾璇曞綋鍓嶅凡琚摼璺崰鐢ㄧ殑鑺傜偣

      if (activeHops.contains(candidateName)) {
        continue;
      }

      // 5. Phase D & E: 鏋勫缓鍊欓€?ChainProxyConfig 骞舵墽琛屾嫇鎵戞牎楠?

      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.buildingCandidate,

          role: role,

          candidateNodeName: candidateName,

          candidateIndex: i,

          totalCandidates: maxToTry,

          message: '姝ｅ湪鏋勫缓鍊欓€夐摼璺嫇鎵?[$candidateName] (${i + 1}/$maxToTry)...',

          timestamp: DateTime.now(),
        ),
      );

      final ChainProxyConfig candidateConfig;

      if (currentConfig.hopMode == ChainHopMode.twoHop) {
        if (role == FallbackCandidateRole.entry) {
          candidateConfig = currentConfig.copyWith(hop1Node: candidateName);
        } else if (role == FallbackCandidateRole.exit) {
          candidateConfig = currentConfig.copyWith(hop2Node: candidateName);
        } else {
          // 涓よ烦妯″紡鏃犱腑杞烦锛岃鑹蹭笉鍏煎

          continue;
        }
      } else {
        if (role == FallbackCandidateRole.entry) {
          candidateConfig = currentConfig.copyWith(hop1Node: candidateName);
        } else if (role == FallbackCandidateRole.relay) {
          candidateConfig = currentConfig.copyWith(hop2Node: candidateName);
        } else {
          candidateConfig = currentConfig.copyWith(hop3Node: candidateName);
        }
      }

      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.validatingCandidate,

          role: role,

          candidateNodeName: candidateName,

          candidateIndex: i,

          totalCandidates: maxToTry,

          message: '姝ｅ湪鏍￠獙鍊欓€夐摼璺嫇鎵?[$candidateName]...',

          timestamp: DateTime.now(),
        ),
      );

      final validation = ChainTopologyValidator.validate(
        mode: candidateConfig.hopMode,

        hop1: candidateConfig.effectiveHop1,

        hop2: candidateConfig.hop2Node,

        hop3: candidateConfig.hopMode == ChainHopMode.threeHop
            ? candidateConfig.hop3Node
            : null,

        availableProxyNames: availableProxyNames,

        dedicatedGroupName: candidateConfig.dedicatedGroupName,
      );

      if (!validation.isValid) {
        // 鎷撴墤闈炴硶锛岃褰曞苟璺宠繃

        currentPool = _updateCandidateStats(
          pool: currentPool,

          role: role,

          nodeName: candidateName,

          isSuccess: false,

          health: ChainHealthStatus.failed,

          cooldownDuration: policy.fallbackPolicy.cooldownDuration,
        );

        onPoolUpdated?.call(currentPool);

        continue;
      }

      if (cancelToken?.isCancelled == true) {
        return ChainFailoverResult.cancelled(
          originalConfig: currentConfig,

          attemptedCandidatesCount: attemptedNames.length,

          attemptedNodeNames: List.unmodifiable(attemptedNames),

          reason: '搴旂敤鍊欓€夊墠宸茶鍙栨秷',
        );
      }

      // 6. Phase F & G: 搴旂敤鍊欓€夐摼璺厤缃?(鐢熸垚涓存椂褰卞瓙鑺傜偣骞跺簲鐢?

      bool candidateApplied = false;

      try {
        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.applyingCandidate,

            role: role,

            candidateNodeName: candidateName,

            candidateIndex: i,

            totalCandidates: maxToTry,

            message: '姝ｅ湪鐑噸杞藉€欓€夐厤缃?[$candidateName]...',

            timestamp: DateTime.now(),
          ),
        );

        if (executor != null) {
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.failoverCandidateApplied,

              nodeName: candidateName,

              role: role.name,

              message: '搴旂敤鍊欓€夐厤缃?[$candidateName] 骞舵敞鍏ュ奖瀛愯妭鐐',

              metadata: {'candidateIndex': i, 'totalCandidates': maxToTry},
            ),
          );

          await executor.applyCandidate(candidateConfig, cancelToken);
        }

        candidateApplied = true;
      } catch (applyErr) {
        // Apply 澶辫触锛屽皾璇曞畨鍏ㄦ竻鐞?

        if (executor != null) {
          try {
            await executor.rollbackToOriginal(currentConfig, cancelToken);
          } catch (_) {}
        }

        currentPool = _updateCandidateStats(
          pool: currentPool,

          role: role,

          nodeName: candidateName,

          isSuccess: false,

          health: ChainHealthStatus.failed,

          cooldownDuration: policy.fallbackPolicy.cooldownDuration,
        );

        onPoolUpdated?.call(currentPool);

        continue;
      }

      if (cancelToken?.isCancelled == true) {
        // 宸插簲鐢ㄥ€欓€変絾琚彇娑堬紝蹇呴』鎵ц鍥炴粴娓呯悊

        if (candidateApplied && executor != null) {
          try {
            await executor.rollbackToOriginal(currentConfig, null);
          } catch (_) {}
        }

        return ChainFailoverResult.cancelled(
          originalConfig: currentConfig,

          attemptedCandidatesCount: attemptedNames.length,

          attemptedNodeNames: List.unmodifiable(attemptedNames),

          reason: 'garbled',
        );
      }

      // 7. Phase H: 鎺㈡祴鏂板€欓€夐摼璺?

      onProgress?.call(
        ChainFailoverProgress(
          state: ChainFailoverState.probingCandidate,

          role: role,

          candidateNodeName: candidateName,

          candidateIndex: i,

          totalCandidates: maxToTry,

          message: '姝ｅ湪楠岃瘉鏂板€欓€夐摼璺?[$candidateName]...',

          timestamp: DateTime.now(),
        ),
      );

      ChainProbeReport candidateReport;

      try {
        if (executor != null) {
          candidateReport = await executor.probeCandidate(
            candidateConfig,
            cancelToken,
          );
        } else {
          candidateReport = await chainProbeService.probeChain(
            config: candidateConfig,

            timeout: policy.probeTimeout,

            cancelToken: cancelToken,
          );
        }
      } catch (probeErr) {
        candidateReport = ChainProbeReport(
          mode: candidateConfig.hopMode,

          isOverallHealthy: false,

          healthStatus: ChainHealthStatus.failed,

          hops: const [],

          errorCode: ChainProbeErrorCodes.unknown,

          rootCauseAnalysis: '鍊欓€夋帰娴嬫墽琛屽紓甯? $probeErr',

          timestamp: DateTime.now(),
        );
      }

      if (cancelToken?.isCancelled == true || candidateReport.isCancelled) {
        // 鎺㈡祴鏈熼棿琚彇娑堬紝鎵ц鍥炴粴

        if (executor != null) {
          try {
            await executor.rollbackToOriginal(currentConfig, null);
          } catch (_) {}
        }

        return ChainFailoverResult.cancelled(
          originalConfig: currentConfig,

          attemptedCandidatesCount: attemptedNames.length,

          attemptedNodeNames: List.unmodifiable(attemptedNames),

          reason: 'garbled',
        );
      }

      // 8. Phase I: 鍋ュ悍搴﹁鍐充笌鎻愪氦 / 鍥炴粴

      final bool candidateHealthy =
          candidateReport.healthStatus == ChainHealthStatus.healthy ||
          (policy.allowDegradedCommit &&
              candidateReport.healthStatus == ChainHealthStatus.degraded);

      if (candidateHealthy) {
        // === 鎴愬姛鍒ゅ畾 ===

        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.candidateHealthy,

            role: role,

            candidateNodeName: candidateName,

            candidateIndex: i,

            totalCandidates: maxToTry,

            message: '鍊欓€夎妭鐐?[$candidateName] 楠岃瘉閫氳繃锛屾鍦ㄦ彁浜ゆ晠闅滆浆绉?..',

            lastReport: candidateReport,

            timestamp: DateTime.now(),
          ),
        );

        // 鎻愪氦閰嶇疆涓庢寔涔呭寲

        if (executor != null) {
          await executor.commitSuccess(candidateConfig);
        }

        // 璁板綍鎶栧姩鍒囨祦浜嬩欢 (Phase 3.2-D)

        final String previousNode = switch (role) {
          FallbackCandidateRole.entry => currentConfig.effectiveHop1,

          FallbackCandidateRole.relay => currentConfig.hop2Node,

          FallbackCandidateRole.exit =>
            currentConfig.hopMode == ChainHopMode.threeHop
                ? currentConfig.hop3Node
                : currentConfig.hop2Node,
        };

        activeDampener.recordFlap(
          role: role,

          fromNode: previousNode,

          toNode: candidateName,

          reason: lastReport.rootCauseAnalysis,

          isSuccess: true,

          policy: policy.flapPolicy,
        );

        // 鏇存柊澶囩敤姹犳垚鍔熺粺璁?

        currentPool = _updateCandidateStats(
          pool: currentPool,

          role: role,

          nodeName: candidateName,

          isSuccess: true,

          health: candidateReport.healthStatus,

          latencyMs: candidateReport.totalChainLatencyMs,

          cooldownDuration: policy.fallbackPolicy.cooldownDuration,
        );

        onPoolUpdated?.call(currentPool);

        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.failoverSuccess,

            nodeName: candidateName,

            role: role.name,

            message: '鏁呴殰杞Щ鎴愬姛锛屽凡骞虫粦鍒囨崲鑷?[$candidateName]',

            metadata: {
              'attemptedCandidatesCount': attemptedNames.length,

              'latencyMs': candidateReport.totalChainLatencyMs,
            },
          ),
        );

        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.failoverSuccess,

            role: role,

            candidateNodeName: candidateName,

            candidateIndex: i,

            totalCandidates: maxToTry,

            message: '鏁呴殰杞Щ鎴愬姛锛屽凡骞虫粦鍒囨崲鑷?[$candidateName]',

            lastReport: candidateReport,

            timestamp: DateTime.now(),
          ),
        );

        return ChainFailoverResult.success(
          finalConfig: candidateConfig,

          switchedNodeName: candidateName,

          switchedRole: role,

          attemptedCandidatesCount: attemptedNames.length,

          attemptedNodeNames: List.unmodifiable(attemptedNames),

          probeReport: candidateReport,
        );
      } else {
        // === 鍊欓€夊け璐ワ紝杩涘叆鍥炴粴娴佺▼ ===

        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.candidateFailed,

            role: role,

            candidateNodeName: candidateName,

            candidateIndex: i,

            totalCandidates: maxToTry,

            message:
                '鍊欓€夎妭鐐?[$candidateName] 楠岃瘉鏈€氳繃 (${candidateReport.rootCauseAnalysis ?? "杩炴帴瓒呮椂"})锛屾鍦ㄥ洖婊?..',

            lastReport: candidateReport,

            failureReason: candidateReport.rootCauseAnalysis,

            timestamp: DateTime.now(),
          ),
        );

        onProgress?.call(
          ChainFailoverProgress(
            state: ChainFailoverState.rollingBack,

            role: role,

            candidateNodeName: candidateName,

            candidateIndex: i,

            totalCandidates: maxToTry,

            message: '姝ｅ湪鍥炴粴鍘熼摼璺厤缃?..',

            timestamp: DateTime.now(),
          ),
        );

        // 鎵ц鍥炴粴

        if (executor != null) {
          try {
            chainTelemetryService.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.failoverRollback,

                nodeName: candidateName,

                role: role.name,

                message: '鍊欓€夎妭鐐规帰娴嬪け璐ワ紝鍥炴粴鍘熼摼璺厤缃',

                metadata: {'errorCode': candidateReport.errorCode},
              ),
            );

            await executor.rollbackToOriginal(currentConfig, cancelToken);
          } catch (rollbackErr) {
            // 鍥炴粴鍙戠敓寮傚父锛岀粷涓嶅悶鎺夛紝鐩存帴杩涘叆 ROLLBACK_FAILED 鐘舵€?

            onProgress?.call(
              ChainFailoverProgress(
                state: ChainFailoverState.rollbackFailed,

                role: role,

                candidateNodeName: candidateName,

                message: '鍥炴粴鍘熼摼璺弗閲嶅け璐? $rollbackErr',

                failureReason: 'ROLLBACK_EXCEPTION',

                timestamp: DateTime.now(),
              ),
            );

            return ChainFailoverResult.rollbackFailed(
              originalConfig: currentConfig,

              attemptedCandidatesCount: attemptedNames.length,

              attemptedNodeNames: List.unmodifiable(attemptedNames),

              rollbackError: rollbackErr.toString(),

              lastProbeReport: candidateReport,

              rootCause:
                  '鍊欓€夎妭鐐?[$candidateName] 澶辫触涓斿洖婊氬師閰嶇疆閬亣寮傚父: $rollbackErr',
            );
          }
        }

        // 璁板綍澶辫触缁熻骞惰繘鍏ュ喎鍗?

        currentPool = _updateCandidateStats(
          pool: currentPool,

          role: role,

          nodeName: candidateName,

          isSuccess: false,

          health: ChainHealthStatus.failed,

          cooldownDuration: policy.fallbackPolicy.cooldownDuration,
        );

        onPoolUpdated?.call(currentPool);

        // 缁х画灏濊瘯涓嬩竴涓€欓€夎妭鐐?
      }
    }

    // 鎵€鏈夊€欓€夊皾璇曞畬姣曞潎鏈兘鎭㈠

    onProgress?.call(
      ChainFailoverProgress(
        state: ChainFailoverState.failoverFailed,

        role: role,

        message: '鎵€鏈夊鐢ㄥ€欓€夎妭鐐瑰潎灏濊瘯瀹屾瘯涓斾笉鍙敤锛屾晠闅滆浆绉诲け璐',

        lastReport: lastReport,

        failureReason: 'ALL_CANDIDATES_EXHAUSTED',

        timestamp: DateTime.now(),
      ),
    );

    return ChainFailoverResult.failed(
      originalConfig: currentConfig,

      attemptedCandidatesCount: attemptedNames.length,

      attemptedNodeNames: List.unmodifiable(attemptedNames),

      lastProbeReport: lastReport,

      rootCause: '共尝试 ${attemptedNames.length} 个备用节点，均未能成功建立可用链路',
    );
  }

  /// 绾唴瀛樻洿鏂板€欓€夎妭鐐圭粺璁′俊鎭?

  ChainFallbackPool _updateCandidateStats({
    required ChainFallbackPool pool,

    required FallbackCandidateRole role,

    required String nodeName,

    required bool isSuccess,

    required ChainHealthStatus health,

    int? latencyMs,

    required Duration cooldownDuration,
  }) {
    List<ChainFallbackCandidate> updateList(List<ChainFallbackCandidate> list) {
      return list.map((c) {
        if (c.nodeName == nodeName) {
          final fingerprint = networkFingerprintProvider
              .getCurrentFingerprint();
          final currentStats =
              c.statsByContext[fingerprint] ??
              ChainReliabilityStats.initial(networkFingerprint: fingerprint);

          final updatedStats = currentStats.recordEvent(
            isSuccess: isSuccess,
            now: DateTime.now(),
            lambda: 0.0288,
          );

          final newStatsByContext = Map<String, ChainReliabilityStats>.from(
            c.statsByContext,
          );
          newStatsByContext[fingerprint] = updatedStats;

          return c.copyWith(
            health: health,
            latencyMs: latencyMs ?? c.latencyMs,
            lastChecked: DateTime.now(),
            statsByContext: newStatsByContext,
            cooldownUntil: !isSuccess
                ? DateTime.now().add(cooldownDuration)
                : null,
          );
        }

        return c;
      }).toList();
    }

    return switch (role) {
      FallbackCandidateRole.entry => pool.copyWith(
        entryCandidates: updateList(pool.entryCandidates),
      ),

      FallbackCandidateRole.relay => pool.copyWith(
        relayCandidates: updateList(pool.relayCandidates),
      ),

      FallbackCandidateRole.exit => pool.copyWith(
        exitCandidates: updateList(pool.exitCandidates),
      ),
    };
  }
}

final chainFailoverService = ChainFailoverService();
