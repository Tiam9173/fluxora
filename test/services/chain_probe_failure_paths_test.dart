import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const multiFrontConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'Entry',
    frontHops: ['Entry', 'Relay'],
    hop2Node: 'Exit',
  );

  test(
    'failed middle hop stops before exit and fails the whole chain',
    () async {
      final tested = <String>[];
      final updates = <HopProbeState>[];
      final progress = <ChainProbeReport>[];
      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          tested.add(node);
          if (node == 'Relay') return -1;
          return node == 'Entry' ? 40 : 80;
        },
      );

      final report = await service.probeChain(
        config: multiFrontConfig,
        checkExitPublicIp: false,
        onHopUpdate: updates.add,
        onProgress: progress.add,
      );

      expect(report.isOverallHealthy, isFalse);
      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.failureHop, 2);
      expect(report.errorCode, ChainProbeErrorCodes.hop2Failed);
      expect(report.rootCauseAnalysis, contains('Relay'));
      expect(report.hops[0].healthStatus, ChainHealthStatus.healthy);
      expect(report.hops[1].healthStatus, ChainHealthStatus.failed);
      expect(report.hops[2].healthStatus, ChainHealthStatus.failed);
      expect(report.hops[2].errorCode, ChainProbeErrorCodes.upstreamFailed);
      expect(report.finalExit?.status, HopProbeStatus.failed);
      expect(tested, ['Entry', 'Relay']);
      expect(updates.map((hop) => hop.hopIndex), containsAll([2, 3]));
      expect(progress.last.failureHop, 2);
    },
  );

  test('middle-hop timeout is reported as timeout, not healthy', () async {
    final service = ChainProbeService(
      customDelayTester: (node, url) async {
        if (node == 'Relay') return null;
        return 40;
      },
    );

    final report = await service.probeChain(
      config: multiFrontConfig,
      checkExitPublicIp: false,
    );

    expect(report.isOverallHealthy, isFalse);
    expect(report.failureHop, 2);
    expect(report.errorCode, ChainProbeErrorCodes.hop2Timeout);
    expect(report.hops[1].status, HopProbeStatus.timeout);
    expect(report.hops[2].healthStatus, ChainHealthStatus.failed);
  });

  test('legacy three-hop relay failure does not probe the exit', () async {
    const config = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      hop1Node: 'Entry',
      hop2Node: 'Relay',
      hop3Node: 'Exit',
    );
    final tested = <String>[];
    final service = ChainProbeService(
      customDelayTester: (node, url) async {
        tested.add(node);
        if (node == 'Relay') return -1;
        return 40;
      },
    );

    final report = await service.probeChain(
      config: config,
      checkExitPublicIp: false,
    );

    expect(report.isOverallHealthy, isFalse);
    expect(report.failureHop, 2);
    expect(report.hops[1].healthStatus, ChainHealthStatus.failed);
    expect(report.hops[2].errorCode, ChainProbeErrorCodes.upstreamFailed);
    expect(tested, ['Entry', 'Relay']);
  });

  test('healthy multi-front chain remains healthy', () async {
    final service = ChainProbeService(
      customDelayTester: (node, url) async {
        return node == 'Entry' ? 30 : (node == 'Relay' ? 50 : 80);
      },
    );

    final report = await service.probeChain(
      config: multiFrontConfig,
      checkExitPublicIp: false,
    );

    expect(report.isOverallHealthy, isTrue);
    expect(report.healthStatus, ChainHealthStatus.healthy);
    expect(report.failureHop, isNull);
    expect(
      report.hops.map((hop) => hop.healthStatus),
      everyElement(ChainHealthStatus.healthy),
    );
  });
}
