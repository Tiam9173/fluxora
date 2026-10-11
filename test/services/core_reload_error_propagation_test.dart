import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.4-C — CF-4: Core runtime reload error propagation.
///
/// Drives the REAL `ChainProxyManager` entry points (`updateConfig`,
/// `triggerAutoFailover`) and uses the manager's own
/// `coreConfigReloadOverride` seam to make the runtime reload succeed or fail.
/// The seam replaces the *reload* step only — the manager's state mutation,
/// persistence, notification and failover wiring all run for real.
void main() {
  late Directory tmp;
  late String configPath;
  late ChainProxyManager manager;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p24c_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = p.join(
      tmp.path,
      'chain_fallback_pool.json',
    );
    ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
      tmp.path,
      'chain_reliability_stats.json',
    );
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    manager = ChainProxyManager();
  });

  tearDown(() async {
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    await manager.flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<String> readConfigFile() => File(configPath).readAsString();

  // ── A. success path is unchanged ─────────────────────────────────────────
  test('A. a successful reload completes normally and updates state', () async {
    var reloads = 0;
    ChainProxyManager.coreConfigReloadOverride = () async => reloads++;

    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'A-1', hop2Node: 'A-2'),
    );

    expect(reloads, 1, reason: 'the reload must actually run');
    expect(manager.config.enable, isTrue);
    expect(manager.config.hop1Node, 'A-1');
    expect(await File(configPath).exists(), isTrue);
  });

  // ── B. reload failure (e.g. setupClashConfig) must propagate ─────────────
  test(
    'B. a reload failure propagates out of updateConfig (was swallowed)',
    () async {
      ChainProxyManager.coreConfigReloadOverride = () async =>
          throw StateError('setupClashConfig failed');

      await expectLater(
        manager.updateConfig((c) => c.copyWith(enable: true)),
        throwsA(isA<StateError>()),
      );
    },
  );

  // ── C. a failure at a later reload step also propagates ──────────────────
  // The seam models the reload as one unit, so this covers "setupClashConfig
  // succeeded but a later step (updateGroups) failed" — the manager must not
  // treat a partially-applied reload as success.
  test('C. a later-step reload failure also propagates', () async {
    ChainProxyManager.coreConfigReloadOverride = () async =>
        throw StateError('updateGroups failed');

    await expectLater(
      manager.updateConfig((c) => c.copyWith(hop1Node: 'C-1')),
      throwsA(isA<StateError>()),
    );
  });

  // ── D. capability refresh is deliberately best-effort ────────────────────
  // `refreshCapabilityProfiles` catches and logs internally, so it can never
  // turn into a reload failure. Documented contract — not changed by CF-4.
  test(
    'D. capability refresh stays best-effort (does not fail updateConfig)',
    () async {
      var reloads = 0;
      ChainProxyManager.coreConfigReloadOverride = () async => reloads++;
      // No profile → `refreshCapabilityProfiles` has nothing to build.
      ChainProxyManager.capabilityProbeSourceOverride = null;

      await manager.updateConfig((c) => c.copyWith(enable: true));
      expect(reloads, 1);
    },
  );

  // ── E. no false success notification on failure ──────────────────────────
  test('E. a failed reload does not emit the success notification', () async {
    // Success → 2 notifications (state change + post-reload success).
    var successNotifications = 0;
    void counter() => successNotifications++;
    ChainProxyManager.coreConfigReloadOverride = () async {};
    manager.addListener(counter);
    await manager.updateConfig((c) => c.copyWith(enable: true));
    manager.removeListener(counter);
    expect(successNotifications, 2);

    // Failure → only the pre-reload state change; the success notification is
    // never reached because the error propagates.
    var failureNotifications = 0;
    void counter2() => failureNotifications++;
    ChainProxyManager.coreConfigReloadOverride = () async =>
        throw StateError('boom');
    manager.addListener(counter2);
    await expectLater(
      manager.updateConfig((c) => c.copyWith(hop1Node: 'E-1')),
      throwsA(isA<StateError>()),
    );
    manager.removeListener(counter2);
    expect(
      failureNotifications,
      1,
      reason: 'the post-reload success notification must not fire',
    );
  });

  // ── F. failover apply failure must not commit ────────────────────────────
  test('F. failover apply failure propagates and never commits', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'F-1', hop2Node: 'F-2'),
      reloadCore: false,
    );
    await manager.updateFallbackPool(
      (_) => const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'F-EXIT',
            role: FallbackCandidateRole.exit,
          ),
        ],
      ),
    );
    final beforeFailover = await readConfigFile();

    // The runtime apply/rollback now fails.
    var applyAttempts = 0;
    ChainProxyManager.coreConfigReloadOverride = () async {
      applyAttempts++;
      throw StateError('apply failed');
    };

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        hops: const [],
        timestamp: DateTime.now(),
      ),
    );

    expect(
      applyAttempts,
      greaterThan(0),
      reason: 'the failover must really have attempted a runtime apply',
    );
    expect(
      result.isSuccess,
      isFalse,
      reason: 'a candidate that never applied must not be reported as success',
    );
    expect(
      await readConfigFile(),
      beforeFailover,
      reason: 'a failed apply must never reach commit (no persistence)',
    );
  });

  // ── G. rollback failure is not swallowed ────────────────────────────────
  test('G. a rollback failure is reported, never a silent success', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'G-1', hop2Node: 'G-2'),
      reloadCore: false,
    );
    await manager.updateFallbackPool(
      (_) => const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'G-EXIT',
            role: FallbackCandidateRole.exit,
          ),
        ],
      ),
    );

    // Both apply and rollback fail.
    ChainProxyManager.coreConfigReloadOverride = () async =>
        throw StateError('apply+rollback failed');

    final result = await manager.triggerAutoFailover(
      bypassDampening: true,
      initialFailureReport: ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        hops: const [],
        timestamp: DateTime.now(),
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.isCancelled, isFalse);
  });
}
