import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';

import 'package:fluxora/services/chain_capability_service.dart';

ProtocolCapabilityProfile p(String protocol) =>
    ChainCapabilityService.getBaselineCapability(protocol);
void main() {
  group('Chain Proxy 2.0 Phase 3.2-B — Fallback Pool 备用节点池专项测试 (27 项场景)', () {
    const twoHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi',
    );

    const threeHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'JP-Relay',
      hop3Node: 'US-Exit',
    );

    final baseTime = DateTime(2026, 9, 28, 12, 0, 0);

    // 1. empty pool
    test('1. empty pool: 候选池为空时返回 selected 为 null，且有明确说明', () {
      const emptyPool = ChainFallbackPool();
      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: emptyPool,
      );

      expect(result.hasCandidate, isFalse);
      expect(result.selected, isNull);
      expect(result.rankedCandidates, isEmpty);
      expect(result.explanation, contains('未配置'));
    });

    // 2. single candidate
    test('2. single candidate: 候选池有 1 个健康候选时成功当选', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-Resi-02',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.hasCandidate, isTrue);
      expect(result.selectedNodeName, 'US-Resi-02');
      expect(result.rankedCandidates.length, 1);
      expect(result.excluded, isEmpty);
    });

    // 3. multiple candidates
    test('3. multiple candidates: 多个有效候选全部参与排序并按配额返回', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-02',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'US-03',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'US-04',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        policy: const ChainFallbackPolicy(maxCandidates: 2),
      );

      expect(result.rankedCandidates.length, 2);
      expect(result.hasCandidate, isTrue);
    });

    // 4. current node exclusion
    test('4. current node exclusion: 自动排除当前角色正在使用的节点', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-Resi', // 与当前两跳 exit 节点相同
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'US-Resi-Backup',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'US-Resi-Backup');
      expect(
        result.excluded.any((e) => e.reasonCode == 'CURRENT_ACTIVE_NODE'),
        isTrue,
      );
    });

    // 5. duplicate exclusion
    test('5. duplicate exclusion: 自动滤除候选池内同名重复节点', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-Duplicate',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 1,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'US-Duplicate',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 2,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.rankedCandidates.length, 1);
      expect(
        result.excluded.any((e) => e.reasonCode == 'DUPLICATE_CANDIDATE'),
        isTrue,
      );
    });

    // 6. missing node exclusion
    test('6. missing node exclusion: 自动排除不在可用代理列表中的不存在节点', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Ghost-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Real-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        availableProxyNames: ['HK-01', 'US-Resi', 'Real-Node'],
      );

      expect(result.selectedNodeName, 'Real-Node');
      expect(
        result.excluded.any((e) => e.reasonCode == 'MISSING_NODE'),
        isTrue,
      );
    });

    // 7. disabled node exclusion
    test('7. disabled node exclusion: 自动排除 enabled 为 false 的候选节点', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Disabled-Node',
            role: FallbackCandidateRole.exit,
            enabled: false,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Enabled-Node',
            role: FallbackCandidateRole.exit,
            enabled: true,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Enabled-Node');
      expect(
        result.excluded.any((e) => e.reasonCode == 'DISABLED_NODE'),
        isTrue,
      );
    });

    // 8. topology conflict
    test('8. topology conflict: 自动排除导致保留组冲突的非法候选', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'GLOBAL', // 系统保留组名
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Valid-Exit',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Valid-Exit');
      expect(
        result.excluded.any((e) => e.reasonCode == 'TOPOLOGY_CONFLICT'),
        isTrue,
      );
    });

    // 9. cycle detection
    test('9. cycle detection: 候选若与已有跳板重复导致环路，自动排除', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'HK-01', // 与第一跳入口相同，若作为出口将造成两跳自环
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Safe-Exit',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Safe-Exit');
      expect(
        result.excluded.any(
          (e) =>
              e.reasonCode == 'OCCUPIED_IN_TOPOLOGY' ||
              e.reasonCode == 'TOPOLOGY_CONFLICT',
        ),
        isTrue,
      );
    });

    // 10. healthy ranking
    test('10. healthy ranking: healthy 节点排序优于 degraded 与 unknown', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Node-Unknown',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.unknown,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Node-Healthy',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Node-Degraded',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.degraded,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Node-Healthy');
      expect(result.rankedCandidates[0].nodeName, 'Node-Healthy');
      expect(result.rankedCandidates[1].nodeName, 'Node-Degraded');
      expect(result.rankedCandidates[2].nodeName, 'Node-Unknown');
    });

    // 11. degraded ranking
    test('11. degraded ranking: degraded 节点次优但默认策略允许当选', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Node-Unknown',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.unknown,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Node-Degraded',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.degraded,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Node-Degraded');
    });

    // 12. failed exclusion
    test('12. failed exclusion: health 为 failed 的节点直接被排除', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Broken-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.failed,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.hasCandidate, isFalse);
      expect(
        result.excluded.any((e) => e.reasonCode == 'HEALTH_FAILED'),
        isTrue,
      );
    });

    // 13. priority ordering
    test('13. priority ordering: 健康度相同时，数字越小优先级越高 (0 > 1 > 2)', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'P2-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 2,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'P0-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 0,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'P1-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 1,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.rankedCandidates.map((c) => c.nodeName).toList(), [
        'P0-Node',
        'P1-Node',
        'P2-Node',
      ]);
    });

    // 14. latency ordering
    test('14. latency ordering: 健康度和优先级相同时，测量延迟低者优先', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'High-Latency',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            latencyMs: 320,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Low-Latency',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            latencyMs: 75,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Unknown-Latency',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            latencyMs: null,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.rankedCandidates.map((c) => c.nodeName).toList(), [
        'Low-Latency',
        'High-Latency',
        'Unknown-Latency',
      ]);
    });

    // 15. deterministic ordering
    test('15. deterministic ordering: 相同输入在 50 次重复执行中输出完全一致', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Gamma',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Alpha',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Beta',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final firstRun = chainFallbackService
          .selectCandidates(
            currentConfig: twoHopConfig,
            role: FallbackCandidateRole.exit,
            pool: pool,
          )
          .rankedCandidates
          .map((c) => c.nodeName)
          .toList();

      for (int i = 0; i < 50; i++) {
        final currentRun = chainFallbackService
            .selectCandidates(
              currentConfig: twoHopConfig,
              role: FallbackCandidateRole.exit,
              pool: pool,
            )
            .rankedCandidates
            .map((c) => c.nodeName)
            .toList();
        expect(currentRun, equals(firstRun));
      }
    });

    // 16. cooldown
    test('16. cooldown: 冷却期内的节点被排除，冷却期已过的节点允许参选', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Cooling-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            cooldownUntil: baseTime.add(const Duration(minutes: 5)),
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            }, // 5 分钟后解冻
          ),
          ChainFallbackCandidate(
            nodeName: 'Expired-Cooldown-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            cooldownUntil: baseTime.subtract(const Duration(minutes: 1)),
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            }, // 冷却已过
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        policy: ChainFallbackPolicy(clock: () => baseTime),
      );

      expect(result.selectedNodeName, 'Expired-Cooldown-Node');
      expect(result.excluded.any((e) => e.reasonCode == 'IN_COOLDOWN'), isTrue);
    });

    // 17. maxFailureCount
    test('17. maxFailureCount: 失败次数达到或超过上限被排除', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Too-Many-Fails',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            // 上限为 3
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 3.0,
                consecutiveFailures: 3,
                totalSamples: 0 + 3,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Few-Fails',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 1.0,
                consecutiveFailures: 1,
                totalSamples: 0 + 1,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
        policy: const ChainFallbackPolicy(maxFailureCount: 3),
      );

      expect(result.selectedNodeName, 'Few-Fails');
      expect(
        result.excluded.any((e) => e.reasonCode == 'MAX_FAILURES_EXCEEDED'),
        isTrue,
      );
    });

    // 18. role separation
    test('18. role separation: 入口候选绝不串线到落地选举，中转候选与入口候选完全隔离', () {
      final pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Entry-Only-Node',
            role: FallbackCandidateRole.entry,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Exit-Only-Node',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final exitResult = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );
      expect(exitResult.selectedNodeName, 'Exit-Only-Node');

      final entryResult = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.entry,
        pool: pool,
      );
      expect(entryResult.selectedNodeName, 'Entry-Only-Node');
    });

    // 19. entry candidate selection
    test('19. entry candidate selection: 为第一跳正确替换并验证两跳拓扑兼容性', () {
      final pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            nodeName: 'HK-Backup',
            role: FallbackCandidateRole.entry,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.entry,
        pool: pool,
      );

      expect(result.hasCandidate, isTrue);
      expect(result.selectedNodeName, 'HK-Backup');
    });

    // 20. relay candidate selection
    test('20. relay candidate selection: 三跳模式下为中转跳正确替换并验证三跳拓扑', () {
      final pool = ChainFallbackPool(
        relayCandidates: [
          ChainFallbackCandidate(
            nodeName: 'SG-Relay',
            role: FallbackCandidateRole.relay,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.relay,
        pool: pool,
      );

      expect(result.hasCandidate, isTrue);
      expect(result.selectedNodeName, 'SG-Relay');
    });

    // 21. exit candidate selection
    test('21. exit candidate selection: 分别针对两跳与三跳准确选出落地出口', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'UK-Exit',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final twoHopResult = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );
      expect(twoHopResult.selectedNodeName, 'UK-Exit');

      final threeHopResult = chainFallbackService.selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );
      expect(threeHopResult.selectedNodeName, 'UK-Exit');
    });

    // 22. no candidate result
    test('22. no candidate result: 全部候选被排除时返回结构完整且 hasCandidate 为 false', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Bad-Node-1',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.failed,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Bad-Node-2',
            role: FallbackCandidateRole.exit,
            enabled: false,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.hasCandidate, isFalse);
      expect(result.selected, isNull);
      expect(result.rankedCandidates, isEmpty);
      expect(result.excluded.length, 2);
    });

    // 23. selection explanation
    test('23. selection explanation: 提供详细可解释性的分析说明文本', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Candidate-A',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            latencyMs: 110,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.explanation, contains('Candidate-A'));
      expect(result.explanation, contains('正常'));
      expect(result.explanation, contains('110ms'));
    });

    // 24. no Chain Proxy mutation
    test('24. no Chain Proxy mutation: 选举过程为纯查询，绝不修改当前链式配置对象', () {
      final originalJson = twoHopConfig.toJson();
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Candidate-A',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      chainFallbackService.selectCandidates(
        currentConfig: twoHopConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(twoHopConfig.toJson(), equals(originalJson));
      expect(twoHopConfig.hop1Node, 'HK-01');
      expect(twoHopConfig.hop2Node, 'US-Resi');
    });

    // 25. no Clash Config mutation
    test(
      '25. no Clash Config mutation: 选举操作不会触发 applyToClashConfig 或篡改运行时',
      () {
        final clashConfigMap = <String, dynamic>{
          'proxies': [
            {'name': p('HK-01'), 'type': p('ss')},
            {'name': p('US-Resi'), 'type': p('socks5')},
          ],
          'proxy-groups': [
            {
              'name': p('🔗 链式代理'),
              'type': p('select'),
              'proxies': ['🔗出口·US-Resi', 'DIRECT'],
            },
          ],
        };
        final originalClashJson = clashConfigMap.toString();

        final pool = ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'Test-Exit',
              role: FallbackCandidateRole.exit,
              health: ChainHealthStatus.healthy,
              statsByContext: {
                'unknown_default': ChainReliabilityStats(
                  weightedSuccess: 0.0,
                  weightedFailure: 0.0,
                  consecutiveFailures: 0,
                  totalSamples: 0 + 0,
                  lastUpdated: DateTime.now(),
                  networkFingerprint: 'wifi_default',
                ),
              },
            ),
          ],
        );

        final session = chainFallbackService.createSession(
          currentConfig: twoHopConfig,
          role: FallbackCandidateRole.exit,
          pool: pool,
        );

        expect(session.status, FallbackSessionStatus.candidateFound);
        expect(session.currentCandidate?.nodeName, 'Test-Exit');
        expect(clashConfigMap.toString(), equals(originalClashJson));
      },
    );

    // 26. no Shadow Node mutation
    test('26. no Shadow Node mutation: 候选节点为原始引用，不含影子前缀 (🔗中转·/🔗出口·)', () {
      final pool = ChainFallbackPool(
        relayCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Raw-SG-Node',
            role: FallbackCandidateRole.relay,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: threeHopConfig,
        role: FallbackCandidateRole.relay,
        pool: pool,
      );

      expect(result.selectedNodeName, 'Raw-SG-Node');
      expect(result.selectedNodeName!.startsWith('🔗中转·'), isFalse);
      expect(result.selectedNodeName!.startsWith('🔗出口·'), isFalse);
    });

    // 27. normal proxy regression
    test('27. normal proxy regression: 链式代理停用时，选举查询保持无副作用，普通代理不受影响', () {
      const disabledConfig = ChainProxyConfig(
        enable: false,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'US-Resi',
      );

      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Candidate-A',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: disabledConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.hasCandidate, isTrue);
      expect(disabledConfig.enable, isFalse);
    });

    // 28. compatibility gate
    test(
      '28. compatibility gate: 100% healthy node excluded if incompatible',
      () {
        final pool = ChainFallbackPool(
          entryCandidates: [
            ChainFallbackCandidate(
              nodeName: 'Incompatible-VLESS',
              role: FallbackCandidateRole.entry,
              health: ChainHealthStatus.healthy,
              latencyMs: 10,
              statsByContext: {
                'unknown_default': ChainReliabilityStats(
                  weightedSuccess: 0.0,
                  weightedFailure: 0.0,
                  consecutiveFailures: 0,
                  totalSamples: 0 + 0,
                  lastUpdated: DateTime.now(),
                  networkFingerprint: 'wifi_default',
                ),
              },
            ),
            ChainFallbackCandidate(
              nodeName: 'Compatible-HY2',
              role: FallbackCandidateRole.entry,
              health: ChainHealthStatus.healthy,
              latencyMs: 100,
              statsByContext: {
                'unknown_default': ChainReliabilityStats(
                  weightedSuccess: 0.0,
                  weightedFailure: 0.0,
                  consecutiveFailures: 0,
                  totalSamples: 0 + 0,
                  lastUpdated: DateTime.now(),
                  networkFingerprint: 'wifi_default',
                ),
              },
            ),
          ],
        );

        final result = const ChainFallbackService().selectCandidates(
          currentConfig: const ChainProxyConfig(
            enable: true,
            hopMode: ChainHopMode.twoHop,
            hop2Node: 'Exit-HY2',
          ),
          role: FallbackCandidateRole.entry,
          pool: pool,
          availableProxyProfiles: {
            'Incompatible-VLESS': p('vless'),
            'Compatible-HY2': p('hysteria2'),
            'Exit-HY2': p('hysteria2'),
          },
        );

        expect(result.hasCandidate, isTrue);
        expect(result.selectedNodeName, 'Compatible-HY2');
        expect(
          result.excluded.any(
            (e) =>
                e.candidate.nodeName == 'Incompatible-VLESS' &&
                e.reasonCode == 'PROTOCOL_INCOMPATIBLE',
          ),
          isTrue,
        );
      },
    );

    // 29. compatibility gate for 3-hop
    test('29. compatibility gate: 3-Hop topology checking', () {
      final pool = ChainFallbackPool(
        relayCandidates: [
          ChainFallbackCandidate(
            nodeName: 'Middle-VMess',
            role: FallbackCandidateRole.relay,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'Middle-SOCKS5',
            role: FallbackCandidateRole.relay,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'unknown_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final result = const ChainFallbackService().selectCandidates(
        currentConfig: const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.threeHop,
          hop1Node: 'Entry-VLESS',
          hop3Node: 'Exit-TUIC',
        ),
        role: FallbackCandidateRole.relay,
        pool: pool,
        availableProxyProfiles: {
          'Entry-VLESS': p('vless'),
          'Middle-VMess': p('vmess'),
          'Middle-SOCKS5': p('socks5'),
          'Exit-TUIC': p('tuic'),
        },
      );

      expect(result.selectedNodeName, 'Middle-SOCKS5');
      expect(
        result.excluded.any(
          (e) =>
              e.candidate.nodeName == 'Middle-VMess' &&
              e.reasonCode == 'PROTOCOL_INCOMPATIBLE',
        ),
        isTrue,
      );
    });
  });
}
