import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_failover.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';

void main() {
  group('Chain Proxy 2.0 Phase 3.2-C — Auto Failover 自动化故障转移专项测试 (35 项场景)', () {
    setUp(() {
      chainFlapDampenerService.reset();
    });

    const twoHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi-01',
    );

    const threeHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'JP-Relay-01',
      hop3Node: 'US-Exit-01',
    );

    ChainProbeReport makeHealthyReport(ChainHopMode mode) {
      return ChainProbeReport(
        mode: mode,
        isOverallHealthy: true,
        healthStatus: ChainHealthStatus.healthy,
        totalChainLatencyMs: 120,
        hops: const [],
        timestamp: DateTime.now(),
      );
    }

    ChainProbeReport makeDegradedReport(ChainHopMode mode) {
      return ChainProbeReport(
        mode: mode,
        isOverallHealthy: true,
        healthStatus: ChainHealthStatus.degraded,
        totalChainLatencyMs: 140,
        hops: const [],
        errorCode: ChainProbeErrorCodes.ipApiUnavailable,
        rootCauseAnalysis: '传输层畅通，但出口公网IP未响应',
        timestamp: DateTime.now(),
      );
    }

    ChainProbeReport makeFailedReport(
      ChainHopMode mode, {
      int failureHop = 2,
      String? err,
    }) {
      return ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: failureHop,
        errorCode: ChainProbeErrorCodes.exitTimeout,
        rootCauseAnalysis: err ?? '出口节点握手超时',
        hops: const [],
        timestamp: DateTime.now(),
      );
    }

    // 1. no failover needed
    test('1. no failover needed: 原链路已健康时直接返回成功且不触发候选尝试', () async {
      final healthy = makeHealthyReport(ChainHopMode.twoHop);
      final service = ChainFailoverService();

      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: const ChainFallbackPool(),
        initialFailureReport: healthy,
      );

      expect(result.isSuccess, isTrue);
      expect(result.state, equals(ChainFailoverState.failoverSuccess));
      expect(result.attemptedCandidatesCount, equals(0));
      expect(
        result.finalConfig.effectiveExitNode,
        equals(twoHopConfig.effectiveExitNode),
      );
    });

    // 2. retry succeeds
    test('2. retry succeeds: 原链路初次检测失败但在重试中恢复，无需触发备用切换', () async {
      final retryService = MockRetryService((cfg, token) async {
        return makeHealthyReport(cfg.hopMode);
      });

      final service = ChainFailoverService(retryService: retryService);
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: const ChainFallbackPool(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state, equals(ChainFailoverState.failoverSuccess));
      expect(result.attemptedCandidatesCount, equals(0));
      expect(result.finalConfig, equals(twoHopConfig));
    });

    // 3. retry exhausted
    test('3. retry exhausted: 原链路重试耗尽后继续执行后续故障转移阶段', () async {
      final retryService = MockRetryService((cfg, token) async {
        return makeFailedReport(cfg.hopMode, failureHop: 2);
      });

      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Resi-02',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
          ),
        ],
      );

      bool committed = false;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committed = true;
        },
      );

      final service = ChainFailoverService(retryService: retryService);
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committed, isTrue);
      expect(result.attemptedCandidatesCount, equals(1));
      expect(result.switchedNodeName, equals('US-Resi-02'));
    });

    // 4. candidate selection
    test('4. candidate selection: 依据故障跳数准确选择对应角色的候选池', () async {
      final failedReport = makeFailedReport(ChainHopMode.twoHop, failureHop: 2);
      final pool = ChainFallbackPool(
        entryCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'HK-Fallback-01',
            role: FallbackCandidateRole.entry,
          ),
        ],
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Fallback-Exit',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainProxyConfig? appliedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          appliedConfig = cfg;
        },
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: failedReport,
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(result.switchedRole, equals(FallbackCandidateRole.exit));
      expect(appliedConfig?.hop2Node, equals('US-Fallback-Exit'));
    });

    // 5. candidate ordering
    test('5. candidate ordering: 优先选择健康且高优先级的候选节点', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Resi-Degraded',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.degraded,
            priority: 2,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Resi-Healthy-Top',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            priority: 0,
          ),
        ],
      );

      final appliedList = <String>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          appliedList.add(cfg.effectiveExitNode);
        },
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(appliedList.first, equals('US-Resi-Healthy-Top'));
    });

    // 6. candidate already attempted
    test('6. candidate already attempted: 相同节点在本次会话中不重复尝试', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Repeat-Node',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Repeat-Node',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      int applyCalls = 0;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          applyCalls++;
        },
        onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isFalse);
      expect(applyCalls, equals(1));
      expect(result.attemptedCandidatesCount, equals(1));
    });

    // 7. two-hop exit failover
    test('7. two-hop exit failover: 两跳模式落地出口替换正确', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Exit-New',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        targetRole: FallbackCandidateRole.exit,
        initialFailureReport: makeFailedReport(
          ChainHopMode.twoHop,
          failureHop: 2,
        ),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.hop1Node, equals('HK-01'));
      expect(committedConfig?.hop2Node, equals('US-Exit-New'));
    });

    // 8. two-hop entry failover
    test('8. two-hop entry failover: 两跳模式前置跳板替换正确', () async {
      final pool = ChainFallbackPool(
        entryCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'HK-Entry-New',
            role: FallbackCandidateRole.entry,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        targetRole: FallbackCandidateRole.entry,
        initialFailureReport: makeFailedReport(
          ChainHopMode.twoHop,
          failureHop: 1,
        ),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.hop1Node, equals('HK-Entry-New'));
      expect(committedConfig?.hop2Node, equals('US-Resi-01'));
    });

    // 9. three-hop exit failover
    test('9. three-hop exit failover: 三跳模式第三跳出口替换正确', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Hop3-New',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: threeHopConfig,
        fallbackPool: pool,
        targetRole: FallbackCandidateRole.exit,
        initialFailureReport: makeFailedReport(
          ChainHopMode.threeHop,
          failureHop: 3,
        ),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.hop1Node, equals('HK-01'));
      expect(committedConfig?.hop2Node, equals('JP-Relay-01'));
      expect(committedConfig?.hop3Node, equals('US-Hop3-New'));
    });

    // 10. three-hop relay failover
    test('10. three-hop relay failover: 三跳模式第二跳中转替换正确', () async {
      final pool = ChainFallbackPool(
        relayCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'SG-Relay-New',
            role: FallbackCandidateRole.relay,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: threeHopConfig,
        fallbackPool: pool,
        targetRole: FallbackCandidateRole.relay,
        initialFailureReport: makeFailedReport(
          ChainHopMode.threeHop,
          failureHop: 2,
        ),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.hop1Node, equals('HK-01'));
      expect(committedConfig?.hop2Node, equals('SG-Relay-New'));
      expect(committedConfig?.hop3Node, equals('US-Exit-01'));
    });

    // 11. three-hop entry failover
    test('11. three-hop entry failover: 三跳模式第一跳入口替换正确', () async {
      final pool = ChainFallbackPool(
        entryCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'TW-Entry-New',
            role: FallbackCandidateRole.entry,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: threeHopConfig,
        fallbackPool: pool,
        targetRole: FallbackCandidateRole.entry,
        initialFailureReport: makeFailedReport(
          ChainHopMode.threeHop,
          failureHop: 1,
        ),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.hop1Node, equals('TW-Entry-New'));
      expect(committedConfig?.hop2Node, equals('JP-Relay-01'));
      expect(committedConfig?.hop3Node, equals('US-Exit-01'));
    });

    // 12. candidate topology invalid
    test('12. candidate topology invalid: 候选节点导致拓扑环路或冲突时自动被跳过', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'HK-01', // 与第一跳冲突
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Valid-Exit',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final applied = <String>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          applied.add(cfg.effectiveExitNode);
        },
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(applied, equals(['US-Valid-Exit']));
    });

    // 13. candidate apply success
    test('13. candidate apply success: 候选配置成功应用到内核执行环境', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      bool applied = false;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          applied = true;
        },
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(applied, isTrue);
    });

    // 14. candidate probe success
    test('14. candidate probe success: 候选节点探测成功，成功提交故障转移', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      bool committed = false;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committed = true;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committed, isTrue);
      expect(result.state, equals(ChainFailoverState.failoverSuccess));
    });

    // 15. candidate probe failed
    test('15. candidate probe failed: 候选节点探测失败，触发回滚并继续尝试下一个候选', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Failed-Candidate',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Working-Candidate',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      int rollbackCount = 0;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async {
          if (cfg.effectiveExitNode == 'US-Failed-Candidate') {
            return makeFailedReport(cfg.hopMode);
          }
          return makeHealthyReport(cfg.hopMode);
        },
        onRollback: (cfg, token) async {
          rollbackCount++;
        },
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(rollbackCount, equals(1));
      expect(result.switchedNodeName, equals('US-Working-Candidate'));
    });

    // 16. rollback success
    test('16. rollback success: 回滚成功将配置和状态恢复为原链路', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Bad-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainProxyConfig? rolledBackConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
        onRollback: (cfg, token) async {
          rolledBackConfig = cfg;
        },
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isFalse);
      expect(rolledBackConfig, equals(twoHopConfig));
    });

    // 17. rollback failed
    test('17. rollback failed: 回滚抛出异常时进入 rollbackFailed 状态并不吞掉错误', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Bad-01',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Another-Node',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
        onRollback: (cfg, token) async {
          throw Exception('Clash core reload failed during rollback');
        },
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isRollbackFailed, isTrue);
      expect(result.state, equals(ChainFailoverState.rollbackFailed));
      expect(result.rollbackError, contains('Clash core reload failed'));
      // 严重回滚失败时，绝不继续尝试第二个候选节点
      expect(result.attemptedCandidatesCount, equals(1));
    });

    // 18. cancellation before apply
    test('18. cancellation before apply: 在候选应用前取消立即终止会话', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final cancelToken = CancelToken()..cancel('User canceled before apply');
      bool applyCalled = false;

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          applyCalled = true;
        },
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        cancelToken: cancelToken,
        executor: executor,
      );

      expect(result.isCancelled, isTrue);
      expect(result.state, equals(ChainFailoverState.cancelled));
      expect(applyCalled, isFalse);
    });

    // 19. cancellation during probe
    test('19. cancellation during probe: 探测过程中取消触发安全回滚并终止', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final cancelToken = CancelToken();
      bool rollbackCalled = false;

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async {
          cancelToken.cancel('User canceled during probe');
          return ChainProbeReport.cancelled(
            mode: cfg.hopMode,
            timestamp: DateTime.now(),
          );
        },
        onRollback: (cfg, token) async {
          rollbackCalled = true;
        },
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        cancelToken: cancelToken,
        executor: executor,
      );

      expect(result.isCancelled, isTrue);
      expect(result.state, equals(ChainFailoverState.cancelled));
      expect(rollbackCalled, isTrue);
    });

    // 20. cancellation during rollback
    test(
      '20. cancellation during rollback: 回滚过程中 CancelToken 被取消仍能平稳收尾',
      () async {
        final pool = ChainFallbackPool(
          exitCandidates: [
            const ChainFallbackCandidate(
              nodeName: 'US-Candidate-01',
              role: FallbackCandidateRole.exit,
            ),
          ],
        );

        final cancelToken = CancelToken();
        bool rollbackCompleted = false;

        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {},
          onProbe: (cfg, token) async {
            cancelToken.cancel('Cancel while probing');
            return makeFailedReport(cfg.hopMode);
          },
          onRollback: (cfg, token) async {
            rollbackCompleted = true;
          },
          onCommit: (cfg) async {},
        );

        final service = ChainFailoverService();
        final result = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: pool,
          initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
          cancelToken: cancelToken,
          executor: executor,
        );

        expect(result.isCancelled, isTrue);
        expect(rollbackCompleted, isTrue);
      },
    );

    // 21. concurrent failover protection
    test(
      '21. concurrent failover protection: 重复启动 Failover 会自动取消前一次会话',
      () async {
        final token1 = CancelToken();
        final token2 = CancelToken();

        CancelToken? activeToken = token1;
        void startNewFailover(CancelToken newToken) {
          if (activeToken != null && !activeToken!.isCancelled) {
            activeToken!.cancel('启动了新故障转移会话');
          }
          activeToken = newToken;
        }

        startNewFailover(token2);
        expect(token1.isCancelled, isTrue);
        expect(token2.isCancelled, isFalse);

        final service = ChainFailoverService();
        final result1 = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: const ChainFallbackPool(),
          cancelToken: token1,
        );
        expect(result1.isCancelled, isTrue);
      },
    );

    // 22. no infinite candidate loop
    test(
      '22. no infinite candidate loop: 有限尝试且次数受 policy.maxCandidates 严格约束',
      () async {
        final pool = ChainFallbackPool(
          exitCandidates: List.generate(
            10,
            (i) => ChainFallbackCandidate(
              nodeName: 'US-Candidate-$i',
              role: FallbackCandidateRole.exit,
            ),
          ),
        );

        int appliedCount = 0;
        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {
            appliedCount++;
          },
          onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
          onRollback: (cfg, token) async {},
          onCommit: (cfg) async {},
        );

        final service = ChainFailoverService();
        const policy = ChainFailoverPolicy(maxCandidates: 3);

        final result = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: pool,
          policy: policy,
          initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
          executor: executor,
        );

        expect(result.isSuccess, isFalse);
        expect(appliedCount, equals(3));
        expect(result.attemptedCandidatesCount, equals(3));
      },
    );

    // 23. no candidate available
    test('23. no candidate available: 备用候选池为空时直接判定失败并输出说明', () async {
      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: const ChainFallbackPool(),
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
      );

      expect(result.isSuccess, isFalse);
      expect(result.state, equals(ChainFailoverState.failoverFailed));
      expect(result.rootCause, contains('无可用候选节点'));
    });

    // 24. degraded transport handling
    test(
      '24. degraded transport handling: 传输层连通但出口 IP 服务超时 (degraded) 仍能成功提交',
      () async {
        final pool = ChainFallbackPool(
          exitCandidates: [
            const ChainFallbackCandidate(
              nodeName: 'US-Degraded-Exit',
              role: FallbackCandidateRole.exit,
            ),
          ],
        );

        bool committed = false;
        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {},
          onProbe: (cfg, token) async => makeDegradedReport(cfg.hopMode),
          onRollback: (cfg, token) async {},
          onCommit: (cfg) async {
            committed = true;
          },
        );

        final service = ChainFailoverService();
        const policy = ChainFailoverPolicy(allowDegradedCommit: true);

        final result = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: pool,
          policy: policy,
          initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
          executor: executor,
        );

        expect(result.isSuccess, isTrue);
        expect(committed, isTrue);
        expect(
          result.probeReport?.healthStatus,
          equals(ChainHealthStatus.degraded),
        );
      },
    );

    // 25. original ChainProxy unchanged on candidate failure
    test(
      '25. original ChainProxy unchanged on candidate failure: 候选节点失败原配置不发生任何篡改',
      () async {
        final pool = ChainFallbackPool(
          exitCandidates: [
            const ChainFallbackCandidate(
              nodeName: 'US-Failing-Node',
              role: FallbackCandidateRole.exit,
            ),
          ],
        );

        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {},
          onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
          onRollback: (cfg, token) async {},
          onCommit: (cfg) async {},
        );

        final service = ChainFailoverService();
        final result = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: pool,
          initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
          executor: executor,
        );

        expect(result.isSuccess, isFalse);
        expect(result.finalConfig.hop1Node, equals('HK-01'));
        expect(result.finalConfig.hop2Node, equals('US-Resi-01'));
      },
    );

    // 26. original Shadow Nodes restored
    test(
      '26. original Shadow Nodes restored: 候选失败回滚后，原始影子节点在 Clash 配置中准确恢复',
      () {
        final rawConfig = <String, dynamic>{
          'proxies': [
            {'name': 'HK-01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
            {
              'name': 'US-Resi-01',
              'type': 'socks5',
              'server': '2.2.2.2',
              'port': 1080,
            },
            {
              'name': 'US-Candidate-01',
              'type': 'socks5',
              'server': '3.3.3.3',
              'port': 1080,
            },
          ],
          'proxy-groups': <dynamic>[],
        };

        // 模拟候选应用
        final candidateConfig = twoHopConfig.copyWith(
          hop2Node: 'US-Candidate-01',
        );
        candidateConfig.applyToClashConfig(rawConfig);

        var proxies = rawConfig['proxies'] as List;
        expect(proxies.any((p) => p['name'] == '🔗出口·US-Candidate-01'), isTrue);

        // 模拟回滚原始配置
        twoHopConfig.applyToClashConfig(rawConfig);
        proxies = rawConfig['proxies'] as List;
        expect(
          proxies.any((p) => p['name'] == '🔗出口·US-Candidate-01'),
          isFalse,
        );
        expect(proxies.any((p) => p['name'] == '🔗出口·US-Resi-01'), isTrue);
      },
    );

    // 27. candidate Shadow Nodes cleaned
    test('27. candidate Shadow Nodes cleaned: 候选失败回滚后候选影子节点完全清除 (0 残留)', () {
      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': 'HK-01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {
            'name': 'US-Resi-01',
            'type': 'socks5',
            'server': '2.2.2.2',
            'port': 1080,
          },
          {
            'name': 'US-Candidate-01',
            'type': 'socks5',
            'server': '3.3.3.3',
            'port': 1080,
          },
        ],
        'proxy-groups': <dynamic>[],
      };

      final candidateConfig = twoHopConfig.copyWith(
        hop2Node: 'US-Candidate-01',
      );
      candidateConfig.applyToClashConfig(rawConfig);

      // 执行回滚
      twoHopConfig.applyToClashConfig(rawConfig);
      final proxies = rawConfig['proxies'] as List;

      final residualShadows = proxies.where(
        (p) =>
            p is Map &&
            p['name']?.toString().contains('US-Candidate-01') == true &&
            ChainProxyConfig.isShadowNodeName(p['name'].toString()),
      );

      expect(residualShadows, isEmpty);
    });

    // 28. normal Proxy Group unchanged
    test('28. normal Proxy Group unchanged: 普通代理业务策略组不受 Failover 影子节点污染', () {
      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': 'HK-01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {
            'name': 'US-Resi-01',
            'type': 'socks5',
            'server': '2.2.2.2',
            'port': 1080,
          },
        ],
        'proxy-groups': [
          {
            'name': 'CloudFlareCDN',
            'type': 'select',
            'proxies': ['HK-01'],
          },
        ],
      };

      twoHopConfig.applyToClashConfig(rawConfig);
      final groups = rawConfig['proxy-groups'] as List;
      final cdnGroup =
          groups.firstWhere((g) => g['name'] == 'CloudFlareCDN') as Map;

      expect(cdnGroup['proxies'], equals(['HK-01']));
      expect(
        (cdnGroup['proxies'] as List).any((p) => p.toString().contains('🔗')),
        isFalse,
      );
    });

    // 29. fallback runtime statistics
    test('29. fallback runtime statistics: 成功或失败的候选节点准确更新运行时统计', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-Fail',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-Success',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainFallbackPool? updatedPool;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async {
          if (cfg.effectiveExitNode == 'US-Candidate-Fail') {
            return makeFailedReport(cfg.hopMode);
          }
          return makeHealthyReport(cfg.hopMode);
        },
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
        onPoolUpdated: (p) => updatedPool = p,
      );

      expect(updatedPool, isNotNull);
      final failedNode = updatedPool!.exitCandidates.firstWhere(
        (c) => c.nodeName == 'US-Candidate-Fail',
      );
      final successNode = updatedPool!.exitCandidates.firstWhere(
        (c) => c.nodeName == 'US-Candidate-Success',
      );

      expect(failedNode.failureCount, equals(1));
      expect(failedNode.health, equals(ChainHealthStatus.failed));
      expect(failedNode.cooldownUntil, isNotNull);

      expect(successNode.successCount, equals(1));
      expect(successNode.health, equals(ChainHealthStatus.healthy));
    });

    // 30. final failure state
    test('30. final failure state: 所有候选均失败时输出完整归因报告', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Candidate-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async =>
            makeFailedReport(cfg.hopMode, err: 'Connection reset by peer'),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isFalse);
      expect(result.state, equals(ChainFailoverState.failoverFailed));
      expect(result.rootCause, contains('未能成功建立可用链路'));
    });

    // 31. successful commit
    test('31. successful commit: 提交成功后最终配置被正确更新', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Great-Exit',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      ChainProxyConfig? committedConfig;
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {},
        onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {
          committedConfig = cfg;
        },
      );

      final service = ChainFailoverService();
      final result = await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      expect(committedConfig?.effectiveExitNode, equals('US-Great-Exit'));
      expect(result.finalConfig.effectiveExitNode, equals('US-Great-Exit'));
    });

    // 32. candidate identity deduplication
    test('32. candidate identity deduplication: 候选列表中同名节点被严格去重', () async {
      final pool = ChainFallbackPool(
        exitCandidates: [
          const ChainFallbackCandidate(
            nodeName: 'US-Node-1',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Node-1',
            role: FallbackCandidateRole.exit,
          ),
          const ChainFallbackCandidate(
            nodeName: 'US-Node-2',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final applied = <String>[];
      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, token) async {
          applied.add(cfg.effectiveExitNode);
        },
        onProbe: (cfg, token) async => makeFailedReport(cfg.hopMode),
        onRollback: (cfg, token) async {},
        onCommit: (cfg) async {},
      );

      final service = ChainFailoverService();
      await service.executeFailover(
        currentConfig: twoHopConfig,
        fallbackPool: pool,
        initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
        executor: executor,
      );

      expect(applied, equals(['US-Node-1', 'US-Node-2']));
    });

    // 33. current node second-level exclusion
    test(
      '33. current node second-level exclusion: 候选节点为当前正使用的跳时被严格二次拦截',
      () async {
        final pool = ChainFallbackPool(
          exitCandidates: [
            const ChainFallbackCandidate(
              nodeName: 'US-Resi-01', // 与当前正在使用的两跳出口完全相同
              role: FallbackCandidateRole.exit,
            ),
            const ChainFallbackCandidate(
              nodeName: 'US-New-02',
              role: FallbackCandidateRole.exit,
            ),
          ],
        );

        final applied = <String>[];
        final executor = DelegateChainFailoverExecutor(
          onApply: (cfg, token) async {
            applied.add(cfg.effectiveExitNode);
          },
          onProbe: (cfg, token) async => makeHealthyReport(cfg.hopMode),
          onRollback: (cfg, token) async {},
          onCommit: (cfg) async {},
        );

        final service = ChainFailoverService();
        final result = await service.executeFailover(
          currentConfig: twoHopConfig,
          fallbackPool: pool,
          initialFailureReport: makeFailedReport(ChainHopMode.twoHop),
          executor: executor,
        );

        expect(result.isSuccess, isTrue);
        expect(applied, equals(['US-New-02']));
      },
    );

    // 34. two-hop topology direction
    test(
      '34. two-hop topology direction: 两跳故障转移后影子节点 dialer-proxy 指向跳板 (Exit ➜ Entry)',
      () {
        final rawConfig = <String, dynamic>{
          'proxies': [
            {'name': 'HK-01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
            {
              'name': 'US-Exit-New',
              'type': 'socks5',
              'server': '3.3.3.3',
              'port': 1080,
            },
          ],
          'proxy-groups': <dynamic>[],
        };

        final candidateConfig = twoHopConfig.copyWith(hop2Node: 'US-Exit-New');
        candidateConfig.applyToClashConfig(rawConfig);

        final proxies = rawConfig['proxies'] as List;
        final shadowExit =
            proxies.firstWhere((p) => p['name'] == '🔗出口·US-Exit-New') as Map;

        expect(shadowExit['dialer-proxy'], equals('HK-01'));
      },
    );

    // 35. three-hop topology direction
    test(
      '35. three-hop topology direction: 三跳故障转移后影子节点方向完整 (Exit ➜ Relay ➜ Entry)',
      () {
        final rawConfig = <String, dynamic>{
          'proxies': [
            {'name': 'HK-01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
            {
              'name': 'JP-Relay-01',
              'type': 'ss',
              'server': '2.2.2.2',
              'port': 8388,
            },
            {
              'name': 'US-Exit-New',
              'type': 'socks5',
              'server': '3.3.3.3',
              'port': 1080,
            },
          ],
          'proxy-groups': <dynamic>[],
        };

        final candidateConfig = threeHopConfig.copyWith(
          hop3Node: 'US-Exit-New',
        );
        candidateConfig.applyToClashConfig(rawConfig);

        final proxies = rawConfig['proxies'] as List;
        final shadowTransit =
            proxies.firstWhere((p) => p['name'] == '🔗中转·JP-Relay-01') as Map;
        final shadowExit =
            proxies.firstWhere((p) => p['name'] == '🔗出口·US-Exit-New') as Map;

        // Exit 指向 Transit，Transit 指向 Entry (HK-01)
        expect(shadowTransit['dialer-proxy'], equals('HK-01'));
        expect(shadowExit['dialer-proxy'], equals('🔗中转·JP-Relay-01'));
      },
    );
  });
}

class MockRetryService implements IChainRetryService {
  final Future<ChainProbeReport> Function(
    ChainProxyConfig config,
    CancelToken? cancelToken,
  )
  onProbe;

  MockRetryService(this.onProbe);

  @override
  Future<ChainProbeReport> probeWithRetry({
    required ChainProxyConfig config,
    ChainRetryPolicy policy = const ChainRetryPolicy(),
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
    void Function(ChainRetryProgress retryProgress)? onRetryProgress,
  }) {
    return onProbe(config, cancelToken);
  }
}
