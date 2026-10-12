import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:path/path.dart' as p;

/// P0 — automatic failover lifecycle.
///
/// The periodic health check is the **only** production driver of automatic
/// failover (`runChainHealthCheck` → `_maybeAutoFailover` → `triggerAutoFailover`),
/// but nothing used to start it: `startChainHealthCheck()` had a single caller
/// (`setAutoFailover`), which itself had no production caller. A persisted
/// `autoFailover: true` therefore never resumed after a restart, and there was
/// no UI control to turn the feature on at all.
///
/// These tests pin the reconciliation contract that fixes that:
///   * `init()`            — restores the loop from persisted config
///   * `setEnable()`       — reconciles on every chain toggle
///   * `setAutoFailover()` — reconciles on the explicit user toggle
///   * `dispose()`         — stops the loop
///
/// They assert the **timer lifecycle only** — never the network — so they need
/// no probe stub and cannot become flaky.
///
/// NOTE: `ChainProxyManager` is a process-wide singleton (`factory` +
/// `_instance`) with a one-shot `_initialized` flag, so `init()` can only be
/// exercised once per isolate. The first test below is therefore the only one
/// that drives `init()`; every later test arranges state through the same
/// production entry points (`updateConfig` / `setAutoFailover` / `setEnable`).
void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p0_lifecycle_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
  });

  tearDown(() {
    ChainProxyManager().stopChainHealthCheck();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.autoHealthCheckInterval = const Duration(seconds: 60);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Arranges in-memory config through the real production write path.
  /// Deliberately does NOT call `init()` — see the file-level note.
  Future<ChainProxyManager> arrange({
    required bool enable,
    required bool autoFailover,
  }) async {
    final manager = ChainProxyManager();
    await manager.updateConfig(
      (c) => c.copyWith(
        enable: enable,
        autoFailover: autoFailover,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'US-01',
        defaultDialerProxy: 'HK-01',
      ),
    );
    manager.stopChainHealthCheck();
    return manager;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MUST RUN FIRST: the only test that can observe `init()`'s restore path,
  // because `_initialized` is a one-shot flag on the process-wide singleton.
  // ───────────────────────────────────────────────────────────────────────────
  group('P0 — init() restores the loop from persisted config', () {
    test('persisted autoFailover=true + enable=true → loop starts', () async {
      // Persist a real chain_proxies.json through the production save path,
      // WITHOUT calling init() first, so `_initialized` is still false.
      final manager = await arrange(enable: true, autoFailover: true);
      expect(
        File(configPath).existsSync(),
        isTrue,
        reason: 'updateConfig must have persisted the config to disk',
      );
      expect(manager.isInitialized, isFalse);
      expect(manager.isAutoHealthCheckRunning, isFalse);

      // The production lifecycle entry (`state.dart` calls exactly this).
      await manager.init();

      expect(manager.config.autoFailover, isTrue);
      expect(manager.config.enable, isTrue);
      expect(
        manager.isAutoHealthCheckRunning,
        isTrue,
        reason: 'a persisted autoFailover flag must actually resume the loop',
      );
    });
  });

  group('P0 — setEnable() reconciles the loop', () {
    test('setEnable(true) starts the loop when autoFailover is on', () async {
      final manager = await arrange(enable: false, autoFailover: true);

      await manager.setEnable(true);

      expect(manager.isAutoHealthCheckRunning, isTrue);
    });

    test('setEnable(false) stops the loop', () async {
      final manager = await arrange(enable: true, autoFailover: true);
      await manager.setAutoFailover(true);
      expect(manager.isAutoHealthCheckRunning, isTrue);

      await manager.setEnable(false);

      expect(manager.isAutoHealthCheckRunning, isFalse);
    });
  });

  group('P0 — setAutoFailover() respects the chain switch', () {
    test('enabling it while the chain is disabled does not start the loop',
        () async {
      final manager = await arrange(enable: false, autoFailover: false);

      await manager.setAutoFailover(true);

      expect(manager.config.autoFailover, isTrue);
      expect(
        manager.isAutoHealthCheckRunning,
        isFalse,
        reason: 'the chain is disabled, so there is nothing to monitor yet',
      );

      // Turning the chain on afterwards is what actually starts the loop.
      await manager.setEnable(true);
      expect(manager.isAutoHealthCheckRunning, isTrue);
    });

    test('disabling it stops a running loop', () async {
      final manager = await arrange(enable: true, autoFailover: false);
      await manager.setAutoFailover(true);
      expect(manager.isAutoHealthCheckRunning, isTrue);

      await manager.setAutoFailover(false);

      expect(manager.isAutoHealthCheckRunning, isFalse);
    });
  });

  group('P0 — teardown stops the loop', () {
    test('stopChainHealthCheck() stops the loop', () async {
      final manager = await arrange(enable: true, autoFailover: true);
      await manager.setAutoFailover(true);
      expect(manager.isAutoHealthCheckRunning, isTrue);

      manager.stopChainHealthCheck();

      expect(manager.isAutoHealthCheckRunning, isFalse);
    });
  });

  group('P0 — reconciliation is idempotent', () {
    test('repeated setEnable(true) does not restart a running loop', () async {
      final manager = await arrange(enable: true, autoFailover: true);
      await manager.setAutoFailover(true);
      expect(manager.isAutoHealthCheckRunning, isTrue);

      await manager.setEnable(true);
      await manager.setEnable(true);

      expect(
        manager.isAutoHealthCheckRunning,
        isTrue,
        reason: 'a running loop must never be torn down and rebuilt',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MUST RUN LAST: `dispose()` tears down the process-wide singleton, so no
  // later test could use it (ChangeNotifier rejects use-after-dispose).
  // ───────────────────────────────────────────────────────────────────────────
  test('P0 — dispose() stops the loop; a late tick is a no-op', () async {
    final manager = await arrange(enable: true, autoFailover: true);
    await manager.setAutoFailover(true);
    expect(manager.isAutoHealthCheckRunning, isTrue);

    manager.dispose();

    expect(manager.isAutoHealthCheckRunning, isFalse);

    // P0 hardening: `dispose()` can race an in-flight tick, because the periodic
    // loop now actually runs in production. Neither a fired tick nor a stray
    // notify may throw (ChangeNotifier-after-dispose) from a timer callback.
    await manager.runChainHealthCheck();
    expect(() => manager.notifyListeners(), returnsNormally);
  });
}
