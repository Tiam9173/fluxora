import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChainProxyManager Isolated Tests', () {
    late ChainProxyManager manager;
    int probeInvocationCount = 0;
    Completer<Delay>? probeCompleter;
    int testIndex = 0;

    setUp(() {
      probeInvocationCount = 0;
      probeCompleter = null;
      testIndex++;
      
      ChainProxyManager.coreRunningOverride = true;
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Node_$testIndex', 'type': 'ss', 'server': '127.0.0.$testIndex'}
      ];

      ChainCapabilityProbeService.delayProbeOverride = (url, proxyName) {
        probeInvocationCount++;
        if (probeCompleter != null) {
          return probeCompleter!.future;
        }
        return Future.value(Delay(name: proxyName, url: url, value: 100));
      };

      manager = ChainProxyManager();
    });

    tearDown(() async {
      if (probeCompleter != null && !probeCompleter!.isCompleted) {
        probeCompleter!.complete(const Delay(name: 'Cleanup', url: '', value: 100));
      }
      await Future.delayed(Duration.zero);
      
      ChainProxyManager.coreRunningOverride = null;
      ChainProxyManager.capabilityProbeSourceOverride = null;
      ChainCapabilityProbeService.delayProbeOverride = null;
    });

    test('initializes with expected default state', () {
      expect(manager.capabilityRevision, greaterThanOrEqualTo(0));
    });

    test('does not duplicate concurrent capability probes', () async {
      probeCompleter = Completer<Delay>();

      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 1);

      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 1);

      probeCompleter!.complete(const Delay(name: 'Node_2', url: '...', value: 100));
      await Future.delayed(Duration.zero);
    });

    test('clears in-flight probe after successful completion', () async {
      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 1);
      
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Node_$testIndex', 'type': 'ss', 'server': '127.0.0.99_$testIndex'}
      ];
      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 2);
    });

    test('clears in-flight probe after probe failure', () async {
      ChainCapabilityProbeService.delayProbeOverride = (url, proxyName) async {
        probeInvocationCount++;
        throw Exception('Probe simulated failure');
      };

      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 1);

      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Node_$testIndex', 'type': 'ss', 'server': '127.0.0.99_$testIndex'}
      ];
      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      expect(probeInvocationCount, 2);
    });

    test('preserves manager state when probe fails', () async {
      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);
      final initialRevision = manager.capabilityRevision;

      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Node_$testIndex', 'type': 'ss', 'server': '127.0.0.99_$testIndex'}
      ];
      ChainCapabilityProbeService.delayProbeOverride = (url, proxyName) async {
        throw Exception('Failure');
      };

      await manager.refreshCapabilityProfiles();
      await Future.delayed(Duration.zero);

      expect(manager.capabilityRevision, initialRevision + 1); 
      expect(
        manager.capabilityProfiles['Node_$testIndex']?.tcp.evidence, 
        CapabilityEvidenceType.unknown 
      );
    });

    test('bounds the capability probe fan-out to concurrencyLimit', () async {
      // P1.2-G3 (K1): 10 nodes with a cap of 3 → never more than 3 probes in
      // flight, instead of the previous unbounded `for` + `unawaited` fan-out.
      ChainProxyManager.capabilityProbeSourceOverride = [
        for (var i = 0; i < 10; i++)
          {'name': 'Fanout_$i', 'type': 'ss', 'server': '10.0.0.$i'},
      ];

      final previousConfig = globalState.config;
      globalState.config = previousConfig.copyWith(
        proxiesStyle: previousConfig.proxiesStyle.copyWith(concurrencyLimit: 3),
      );
      addTearDown(() => globalState.config = previousConfig);

      var inFlight = 0;
      var maxInFlight = 0;
      final gate = Completer<void>();
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        probeInvocationCount++;
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await gate.future;
        inFlight--;
        return Delay(name: name, url: url, value: 100);
      };

      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);

      expect(
        maxInFlight,
        lessThanOrEqualTo(3),
        reason: 'must never exceed ProxiesStyle.concurrencyLimit',
      );
      expect(maxInFlight, 3, reason: 'the first batch should fill the cap');

      // Releasing the gate lets every remaining batch drain.
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(probeInvocationCount, 10, reason: 'every node is still probed');
      expect(maxInFlight, lessThanOrEqualTo(3));
    });

    test('discards a probe whose capability view generation is stale', () async {
      // P1.2-K3 (S1): a probe started against view N must not write back after
      // the view has been rebuilt to N+1 — its result carries the *previous*
      // config's declared dimensions (notably `udp`) and would otherwise
      // overwrite the new baseline by node name.
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Gen-A', 'type': 'ss', 'server': '10.1.0.1', 'udp': true},
      ];

      final gate = Completer<Delay>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete(const Delay(name: 'Gen-A', url: 'u', value: 100));
        }
      });
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        probeInvocationCount++;
        return gate.future;
      };

      // View #1: the probe for Gen-A starts and is held open.
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);
      expect(probeInvocationCount, 1);

      // View #2: the node keeps its name but its declared capability changes
      // (`udp: true` → `udp: false`). The in-flight name still suppresses a
      // second probe, so the pending one is now stale.
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Gen-A', 'type': 'ss', 'server': '10.1.0.2', 'udp': false},
      ];
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);
      expect(
        probeInvocationCount,
        1,
        reason: 'the in-flight name is suppressed',
      );

      final revisionBeforeRelease = manager.capabilityRevision;
      expect(
        manager.capabilityProfiles['Gen-A']?.udp.status,
        CapabilityStatus.verifiedUnsupported,
        reason: 'view #2 declares udp: false',
      );

      // Release the stale probe: its result must be discarded.
      gate.complete(const Delay(name: 'Gen-A', url: 'u', value: 100));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        manager.capabilityRevision,
        revisionBeforeRelease,
        reason: 'a stale probe must not bump the revision',
      );
      expect(
        manager.capabilityProfiles['Gen-A']?.udp.status,
        CapabilityStatus.verifiedUnsupported,
        reason: 'the stale probe must not overwrite the new baseline',
      );
      expect(
        manager.capabilityProfiles['Gen-A']?.tcp.evidence,
        isNot(CapabilityEvidenceType.runtimeVerified),
        reason: 'the stale probe result must be discarded',
      );
    });

    test('H2: prunes profiles for nodes no longer in the config', () async {
      // View #1: two nodes.
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Keep-A', 'type': 'ss', 'server': '10.3.0.1'},
        {'name': 'Drop-B', 'type': 'ss', 'server': '10.3.0.2'},
      ];
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);
      expect(
        manager.capabilityProfiles.keys,
        containsAll(<String>['Keep-A', 'Drop-B']),
      );

      // View #2: Drop-B is gone from the config.
      ChainProxyManager.capabilityProbeSourceOverride = [
        {'name': 'Keep-A', 'type': 'ss', 'server': '10.3.0.1'},
      ];
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);

      expect(manager.capabilityProfiles.containsKey('Keep-A'), isTrue);
      expect(
        manager.capabilityProfiles.containsKey('Drop-B'),
        isFalse,
        reason: 'a node absent from the current config must not linger',
      );
    });

    // ⚠️ THIS MUST REMAIN THE LAST TEST IN THIS FILE.
    //
    // `ChainProxyManager` is a process-wide singleton (`factory` + `_instance`),
    // so `dispose()` disposes it permanently for the remainder of this file —
    // the same constraint documented in `runtime_lifecycle_test.dart:104-107`.
    // Flutter runs each test FILE in its own isolate, so other files are
    // unaffected by this dispose().
    test('H3: dispose stops the batch loop from starting further probes',
        () async {
      ChainProxyManager.capabilityProbeSourceOverride = [
        for (var i = 0; i < 4; i++)
          {'name': 'Dispose_$i', 'type': 'ss', 'server': '10.4.0.$i'},
      ];
      final previousConfig = globalState.config;
      globalState.config = previousConfig.copyWith(
        proxiesStyle: previousConfig.proxiesStyle.copyWith(concurrencyLimit: 1),
      );
      addTearDown(() => globalState.config = previousConfig);

      final gate = Completer<Delay>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete(const Delay(name: 'x', url: 'u', value: 100));
        }
      });
      ChainCapabilityProbeService.delayProbeOverride = (url, name) async {
        probeInvocationCount++;
        return gate.future;
      };

      // Batch 1 (limit = 1) starts exactly one probe and is held open.
      await manager.refreshCapabilityProfiles();
      await Future<void>.delayed(Duration.zero);
      expect(probeInvocationCount, 1);

      manager.dispose();

      // Releasing batch 1 must not let batches 2..4 start.
      gate.complete(const Delay(name: 'x', url: 'u', value: 100));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        probeInvocationCount,
        1,
        reason: 'a disposed manager must not start further batches',
      );
    });
  });
}
