import '../services/network_fingerprint_provider.dart';

import '../models/protocol_capability.dart';
import 'chain_adaptive_score_service.dart';

import 'dart:math' as math;

import 'package:fluxora/models/chain_fallback_pool.dart';

import 'package:fluxora/models/chain_proxy.dart';

import 'package:fluxora/services/chain_probe_service.dart';

import 'package:fluxora/models/chain_telemetry.dart';

import 'package:fluxora/services/chain_telemetry_service.dart';

import 'package:fluxora/services/chain_compatibility_validator.dart';

/// 澶囩敤鑺傜偣閫変妇绛栫暐閰嶇?

class ChainFallbackPolicy {
  /// 鏈€澶ц繑鍥炲€欓€夋暟閲忎笂?(榛樿?5)

  final int maxCandidates;

  /// 鍏佽鐨勬渶宸仴搴风姸?(榛樿?ChainHealthStatus.degraded锛屽?healthy ?degraded 鍧囧厑璁?

  final ChainHealthStatus minHealthStatus;

  /// 鍏佽鐨勬渶澶ц繛缁け璐ユ?(杈惧埌鎴栬秴杩囧垯涓嶅彲鐢紝榛樿 3)

  final int maxFailureCount;

  /// 鍐峰嵈鏃堕暱 (榛樿?5 鍒嗛?

  final Duration cooldownDuration;

  /// 鏄惁涓ユ牸鎺掗櫎褰撳墠閾惧紡浠ｇ悊涓凡鍗犵敤鐨勬墍鏈夎妭?(榛樿?true锛岄槻姝㈤噸?Hop)

  final bool excludeActiveChainHops;

  /// 鏄惁蹇呴』閫氳繃 ChainTopologyValidator 鎷撴墤鍏煎鎬ч獙?(榛樿?true锛岄槻姝㈡寰?鑷?

  final bool validateTopologyCompatibility;

  /// 鍗曞厓娴嬭瘯鍙敞鍏ョ殑鏃堕挓鍑芥暟 (榛樿涓?DateTime.now)

  final DateTime Function()? clock;

  const ChainFallbackPolicy({
    this.maxCandidates = 5,

    this.minHealthStatus = ChainHealthStatus.degraded,

    this.maxFailureCount = 3,

    this.cooldownDuration = const Duration(minutes: 5),

    this.excludeActiveChainHops = true,

    this.validateTopologyCompatibility = true,

    this.clock,
  });

  DateTime now() => clock != null ? clock!() : DateTime.now();
}

/// 澶囩敤鏁呴殰杞Щ鍩虹鏈嶅姟鎺ュ?

abstract class IChainFallbackService {
  /// 瀵规寚瀹氳鑹蹭粠鍊欓€夋睜涓墽琛屾帓闄ゃ€佹嫇鎵戞牎楠屼笌纭畾鎬ф帓搴忥紝杩斿洖閫変妇缁撴?

  CandidateSelectionResult selectCandidates({
    required ChainProxyConfig currentConfig,

    required FallbackCandidateRole role,

    required ChainFallbackPool pool,

    ChainFallbackPolicy policy = const ChainFallbackPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  });

  /// 鍒涘缓澶囩敤浼氳瘽锛堜负 Phase 3.2-C 鍑嗗锛屾湰闃舵涓嶆墽琛屼换浣曠綉缁滄帰閽堟垨鑺傜偣绡℃敼?

  FallbackSession createSession({
    required ChainProxyConfig currentConfig,

    required FallbackCandidateRole role,

    required ChainFallbackPool pool,

    ChainFallbackPolicy policy = const ChainFallbackPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  });
}

/// 澶囩敤鑺傜偣姹犱笌鏁呴殰杞Щ绛栫暐鍩虹灞傚疄鐜?

class ChainFallbackService implements IChainFallbackService {
  const ChainFallbackService();

  @override
  CandidateSelectionResult selectCandidates({
    required ChainProxyConfig currentConfig,

    required FallbackCandidateRole role,

    required ChainFallbackPool pool,

    ChainFallbackPolicy policy = const ChainFallbackPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  }) {
    final rawCandidates = pool.getCandidatesByRole(role);

    final fingerprint = networkFingerprintProvider.getCurrentFingerprint();
    int globalTotalTrials = 0;
    for (final c in rawCandidates) {
      final stats = c.statsByContext[fingerprint];
      if (stats != null) {
        globalTotalTrials += stats.totalSamples;
      }
    }

    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.fallbackEvaluationStarted,

        role: role.name,

        message: '寮€濮嬩?${role.label} 璇勪及澶囩敤鍊欓€夎妭鐐?..',

        metadata: {'poolSize': rawCandidates.length},
      ),
    );

    if (rawCandidates.isEmpty) {
      return CandidateSelectionResult(
        role: role,

        selected: null,

        rankedCandidates: const [],

        excluded: const [],

        explanation: '未配置任何备选节点',
      );
    }

    final now = policy.now();

    // 1. 鑾峰彇褰撳墠閾捐矾鍚勮烦瀹為檯浣跨敤鐨勮妭鐐瑰悕?

    final currentHop1 = currentConfig.effectiveHop1.trim();

    final currentHop2 = currentConfig.hop2Node.trim();

    final currentHop3 = currentConfig.hopMode == ChainHopMode.threeHop
        ? currentConfig.hop3Node.trim()
        : '';

    // 褰撳墠瑙掕壊瀵瑰簲鑺傜偣

    final String currentRoleNode = switch (role) {
      FallbackCandidateRole.entry => currentHop1,

      FallbackCandidateRole.relay => currentHop2,

      FallbackCandidateRole.exit => currentConfig.effectiveExitNode.trim(),
    };

    final eligible = <ChainFallbackCandidate>[];

    final excluded = <CandidateExclusionRecord>[];

    final seenCandidateNames = <String>{};

    for (final candidate in rawCandidates) {
      final name = candidate.nodeName.trim();

      // 瑙勫?1: 鑺傜偣鍚嶇О涓嶅彲涓虹?

      if (name.isEmpty) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'EMPTY_NAME',

            message: '鍊欓€夎妭鐐瑰悕绉颁负绌',
          ),
        );

        continue;
      }

      // 瑙勫?2: 鍊欓€夋睜鍐呴儴鍘婚噸锛堜互棣栨鍑虹幇鐨勮褰曚负鍑嗭?

      if (seenCandidateNames.contains(name)) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'DUPLICATE_CANDIDATE',

            message: '鍊欓€夊垪琛ㄤ腑瀛樺湪閲嶅鑺傜偣鍚?[$name]',
          ),
        );

        continue;
      }

      seenCandidateNames.add(name);

      // 瑙勫?3: 妫€鏌ュ€欓€夊紑鍏?enabled

      if (!candidate.enabled) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'DISABLED_NODE',

            message: '鍊欓€夎妭鐐瑰凡琚鐢',
          ),
        );

        continue;
      }

      // 瑙勫?4: 瀛樺湪鎬ф牎楠岋紙鑻ヤ笂灞傛彁渚涗簡鍙敤鑺傜偣鍒楄〃锛?

      if (availableProxyNames != null && !availableProxyNames.contains(name)) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'MISSING_NODE',

            message: '鑺傜偣鍦ㄥ綋鍓嶅彲鐢ㄤ唬鐞嗛泦鍚堜腑涓嶅瓨鍦',
          ),
        );

        continue;
      }

      // 瑙勫?5: 鎺掗櫎褰撳墠姝ｅ湪浣跨敤鐨勫悓瑙掕壊鑺傜?

      if (name == currentRoleNode) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'CURRENT_ACTIVE_NODE',

            message: '褰撳墠姝ｅ湪浣跨敤璇ヨ妭鐐逛綔?[${role.label}]',
          ),
        );

        continue;
      }

      // 瑙勫?6: 鎺掗櫎褰撳墠閾惧紡浠ｇ悊涓凡鍗犵敤鐨勫叾浠栬烦鑺傜偣锛堜弗绂佽鑹查噸鍙犳垨澶嶇敤鍚屼竴鑺傜偣瀵艰嚧鍥炵幆?

      if (policy.excludeActiveChainHops) {
        bool isOccupiedInOtherHops = false;
        String occupiedReason = 'occupied';

        if (role == FallbackCandidateRole.entry) {
          if (name == currentHop2 && currentHop2.isNotEmpty) {
            isOccupiedInOtherHops = true;

            occupiedReason = 'occupied';
          } else if (name == currentHop3 && currentHop3.isNotEmpty) {
            isOccupiedInOtherHops = true;

            occupiedReason = 'occupied';
          }
        } else if (role == FallbackCandidateRole.relay) {
          if (name == currentHop1 && currentHop1.isNotEmpty) {
            isOccupiedInOtherHops = true;

            occupiedReason = 'occupied';
          } else if (name == currentHop3 && currentHop3.isNotEmpty) {
            isOccupiedInOtherHops = true;

            occupiedReason = 'occupied';
          }
        } else if (role == FallbackCandidateRole.exit) {
          if (name == currentHop1 && currentHop1.isNotEmpty) {
            isOccupiedInOtherHops = true;
          } else if (name == currentHop2 && currentHop2.isNotEmpty) {
            isOccupiedInOtherHops = true;
          }
        }

        if (isOccupiedInOtherHops) {
          excluded.add(
            CandidateExclusionRecord(
              candidate: candidate,

              reasonCode: 'OCCUPIED_IN_TOPOLOGY',

              message: occupiedReason,
            ),
          );

          continue;
        }
      }

      // 瑙勫?7: 鍋ュ悍鐘舵€佽繃?

      if (candidate.health == ChainHealthStatus.failed) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'HEALTH_FAILED',

            message: '鑺傜偣鏈€杩戝仴搴锋帰娴嬬姸鎬佷负寮傚父 (failed)',
          ),
        );

        continue;
      }

      if (candidate.health == ChainHealthStatus.unavailable ||
          candidate.health == ChainHealthStatus.cancelled) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'HEALTH_UNAVAILABLE',

            message: '鑺傜偣鏈€杩戠姸鎬佷负涓嶅彲?(${candidate.health.label})',
          ),
        );

        continue;
      }

      // 瑙勫?8: 杩炵画澶辫触娆℃暟闄愬埗

      if (candidate.failureCount >= policy.maxFailureCount) {
        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'MAX_FAILURES_EXCEEDED',

            message:
                '杩炵画澶辫触娆℃?(${candidate.failureCount}) 瓒呰繃涓婇檺 (${policy.maxFailureCount})',
          ),
        );

        continue;
      }

      // 瑙勫?9: 鍐峰嵈鏈熻繃?

      if (candidate.isCoolingDown(now)) {
        final remainingSec = candidate.cooldownUntil!.difference(now).inSeconds;

        excluded.add(
          CandidateExclusionRecord(
            candidate: candidate,

            reasonCode: 'IN_COOLDOWN',

            message: '鑺傜偣澶勪簬鍐峰嵈淇濇姢?(鍓╀?${remainingSec}s)',
          ),
        );

        continue;
      }

      // 瑙勫?10: 鎷撴墤鍏煎鎬т笌闃茬幆鏍￠獙 (涓ユ牸璋冪敤 ChainTopologyValidator)

      if (policy.validateTopologyCompatibility) {
        final hypoHop1 = role == FallbackCandidateRole.entry
            ? name
            : currentHop1;

        final hypoHop2 = role == FallbackCandidateRole.relay
            ? name
            : (role == FallbackCandidateRole.exit &&
                      currentConfig.hopMode == ChainHopMode.twoHop
                  ? name
                  : currentHop2);

        final hypoHop3 =
            role == FallbackCandidateRole.exit &&
                currentConfig.hopMode == ChainHopMode.threeHop
            ? name
            : (currentConfig.hopMode == ChainHopMode.threeHop
                  ? currentHop3
                  : null);

        final validation = ChainTopologyValidator.validate(
          mode: currentConfig.hopMode,

          hop1: hypoHop1,

          hop2: hypoHop2,

          hop3: hypoHop3,

          availableProxyNames: availableProxyNames,

          dedicatedGroupName: currentConfig.dedicatedGroupName,
        );

        if (!validation.isValid) {
          excluded.add(
            CandidateExclusionRecord(
              candidate: candidate,

              reasonCode: 'TOPOLOGY_CONFLICT',

              message: '鏇挎崲鍚庢嫇鎵戝啿绐? ${validation.message}',
            ),
          );

          continue;
        }
      }

      // 瑙勫?11: 鍗忚鍏煎鎬ф牎?(Compatibility Gate)

      if (availableProxyProfiles != null) {
        final hypoHop1 = role == FallbackCandidateRole.entry
            ? name
            : currentHop1;

        final hypoHop2 = role == FallbackCandidateRole.relay
            ? name
            : (role == FallbackCandidateRole.exit &&
                      currentConfig.hopMode == ChainHopMode.twoHop
                  ? name
                  : currentHop2);

        final hypoHop3 =
            role == FallbackCandidateRole.exit &&
                currentConfig.hopMode == ChainHopMode.threeHop
            ? name
            : (currentConfig.hopMode == ChainHopMode.threeHop
                  ? currentHop3
                  : null);

        final type1 = availableProxyProfiles[hypoHop1];

        final type2 = availableProxyProfiles[hypoHop2];

        final type3 = hypoHop3 != null
            ? availableProxyProfiles[hypoHop3]
            : null;

        CompatibilityResult compatResult =
            const CompatibilityResult.compatible();

        if (currentConfig.hopMode == ChainHopMode.twoHop) {
          compatResult = ChainCompatibilityValidator.validateEdge(type1, type2);
        } else {
          compatResult = ChainCompatibilityValidator.validateEdge(type1, type2);

          if (compatResult.compatible) {
            compatResult = ChainCompatibilityValidator.validateEdge(
              type2,
              type3,
            );
          }
        }

        if (!compatResult.compatible) {
          excluded.add(
            CandidateExclusionRecord(
              candidate: candidate,

              reasonCode: 'PROTOCOL_INCOMPATIBLE',

              message:
                  '鍗忚涓嶅吋? ${compatResult.reason} (鎷︽埅鍗忚: ${compatResult.blockingProtocol ?? "Unknown"})',
            ),
          );

          continue;
        }
      }

      eligible.add(candidate);
    }

    // 2. 瀵瑰叆鍥村€欓€夎妭鐐规墽琛?100% 纭畾鎬ф帓搴?(Deterministic Ranking)

    // 2. 确定性多维排序 (Adaptive Score Engine Ranking)
    eligible.sort((a, b) {
      // 1. 健康等级绝对前置 (保证 failed/unknown 永远垫底)
      int healthRank(ChainHealthStatus s) => switch (s) {
        ChainHealthStatus.healthy => 1,
        ChainHealthStatus.degraded => 2,
        ChainHealthStatus.unknown => 3,
        _ => 4,
      };

      final hA = healthRank(a.health);
      final hB = healthRank(b.health);
      if (hA != hB) return hA.compareTo(hB);

      // 2. 优先级前置 (0 < 1 < 2)
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);

      // 3. Adaptive Score Engine 算分排序 (降序，高分优先)
      final profileA = availableProxyProfiles?[a.nodeName];
      final profileB = availableProxyProfiles?[b.nodeName];

      final scoreA = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: a,
        capabilityProfile: profileA,
        globalTotalTrials: globalTotalTrials,
      );
      final scoreB = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: b,
        capabilityProfile: profileB,
        globalTotalTrials: globalTotalTrials,
      );

      if (scoreA.totalScore != scoreB.totalScore) {
        return scoreB.totalScore.compareTo(scoreA.totalScore); // Descending
      }

      // 4. 确定性字母序 (同分时保证绝对稳定)
      return a.nodeName.compareTo(b.nodeName);
    });

    // 3. 鎴柇鏈€澶у€欓€夋暟閲?

    final ranked = eligible.take(policy.maxCandidates).toList();

    final selected = ranked.firstOrNull;

    // 4. 鐢熸垚鍙В閲婃€у垎鏋愯?

    final explanationBuffer = StringBuffer();

    if (selected != null) {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateSelected,

          nodeName: selected.nodeName,

          role: role.name,

          message: '?${role.label} 浼橀€夊嚭鍊欓€夎妭? ${selected.nodeName}',

          metadata: {
            'health': selected.health.name,

            'priority': selected.priority,

            'latencyMs': selected.latencyMs,
          },
        ),
      );

      explanationBuffer.write(
        '宸叉垚鍔熶粠澶囩敤姹犱腑?[${role.label}] 浼橀€夊€欓€夎妭鐐? [${selected.nodeName}] (鍋ュ悍鐘舵€? ${selected.health.label}, 浼樺厛绾? ${selected.priority}',
      );

      if (selected.latencyMs != null && selected.latencyMs! > 0) {
        explanationBuffer.write(', 寤惰? ${selected.latencyMs}ms');
      }

      explanationBuffer.write(' (未配置任何备用节点或全不符合要求)');
    } else {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateRejected,

          role: role.name,

          errorCode: 'NO_CANDIDATE',

          message: '?${role.label} 璇勪及澶囩敤鍊欓€夊け璐? 鏃犵鍚堟潯浠剁殑鑺傜偣',

          metadata: {
            'poolSize': rawCandidates.length,

            'excludedCount': excluded.length,
          },
        ),
      );

      explanationBuffer.write(' (未配置任何备用节点或全不符合要求)');

      if (excluded.isNotEmpty) {
        explanationBuffer.write(' 鎺掗櫎鍘熷洜鎽樿  ? ');

        explanationBuffer.write(
          excluded
              .map((e) => '${e.candidate.nodeName}(${e.reasonCode})')
              .take(3)
              .join(', '),
        );

        if (excluded.length > 3) {
          explanationBuffer.write(' (未配置任何备用节点或全不符合要求)');
        }
      }
    }

    return CandidateSelectionResult(
      role: role,

      selected: selected,

      rankedCandidates: List.unmodifiable(ranked),

      excluded: List.unmodifiable(excluded),

      explanation: explanationBuffer.toString(),
    );
  }

  /// 纭畾鎬у缁存帓搴忔瘮杈冨櫒

  ///

  /// 缁村害浼樺厛绾э細

  /// 1. 鍋ュ悍鐘舵€?(healthy > degraded > unknown > failed)

  /// 2. 鍊欓€変紭鍏堢骇 priority 鍗囧?(0 < 1 < 2)

  /// 3. 鍘嗗彶澶辫触娆℃?failureCount 鍗囧?(0 < 1 < 2)

  /// 4. 鍘嗗彶鎴愬姛娆℃?successCount 闄嶅?(澶氳€呬紭鍏?

  /// 5. 娴嬮噺寤惰繜 latencyMs 鍗囧?(宸茬煡浣庡欢?> 宸茬煡楂樺欢?> 鏈?null 寤惰?

  /// 6. 纭畾鎬у瓧姣嶅簭 nodeName 鍗囧?(淇濊瘉缁濆绋冲?

  @override
  FallbackSession createSession({
    required ChainProxyConfig currentConfig,

    required FallbackCandidateRole role,

    required ChainFallbackPool pool,

    ChainFallbackPolicy policy = const ChainFallbackPolicy(),

    List<String>? availableProxyNames,

    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  }) {
    final result = selectCandidates(
      currentConfig: currentConfig,

      role: role,

      pool: pool,

      policy: policy,

      availableProxyNames: availableProxyNames,

      availableProxyProfiles: availableProxyProfiles,
    );

    final currentRoleNode = switch (role) {
      FallbackCandidateRole.entry => currentConfig.effectiveHop1,

      FallbackCandidateRole.relay => currentConfig.hop2Node,

      FallbackCandidateRole.exit => currentConfig.effectiveExitNode,
    };

    final random = math.Random();

    final randomSuffix = random.nextInt(1000000).toString().padLeft(6, '0');

    final sessionId =
        'fallback-${role.name}-${policy.now().millisecondsSinceEpoch}-$randomSuffix';

    return FallbackSession(
      sessionId: sessionId,

      role: role,

      currentNode: currentRoleNode,

      candidateIndex: 0,

      candidateList: result.rankedCandidates,

      startedAt: policy.now(),

      status: result.hasCandidate
          ? FallbackSessionStatus.candidateFound
          : FallbackSessionStatus.noCandidateAvailable,

      note: result.explanation,
    );
  }
}

final chainFallbackService = ChainFallbackService();
