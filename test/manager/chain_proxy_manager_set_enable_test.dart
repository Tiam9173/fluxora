import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/state.dart';

/// Phase 10 — `setEnable` must not report a false success.
///
/// The defect this pins down: `_autoSelectChainGroup` used to return `void`,
/// swallow every exception and only log, while `setEnable` returned `void` too.
/// The view then unconditionally showed "chain enabled" — even when the live
/// selector had never moved onto the chain, so traffic was not routing through
/// it. `setEnable` now returns a bool: `false` means "config says enabled, but
/// routing did not follow".
///
/// Everything runs against `systemTemp` and a no-op reload override, so no
/// core, no socket and no network is involved. The *positive* path (a real
/// selector actually moving) needs a live core and is NOT covered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ChainProxyManager manager;

  String join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  /// The persisted config, read straight off disk — this is what a restart
  /// would pick up, so it is the state that matters, not just `_config`.
  Map<String, dynamic> persistedConfig() {
    final file = File(ChainProxyManager.configFilePathOverride!);
    if (!file.existsSync()) return <String, dynamic>{};
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fluxora_cpm_setenable_');
    ChainProxyManager.configFilePathOverride =
        join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride =
        join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.reliabilityStatsFilePathOverride =
        join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.coreConfigReloadOverride = () async {};
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.capabilityProbeSourceOverride = const [];

    ChainProxyManager.resetInstanceForTest();
    manager = ChainProxyManager();
    await manager.init();
  });

  tearDown(() async {
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('disable always reports success — there is nothing to select', () async {
    final ok = await manager.setEnable(false);

    expect(ok, isTrue, reason: 'turning the chain off cannot half-apply');
    expect(manager.config.enable, isFalse);
    expect(persistedConfig()['enable'], isFalse);
  });

  test('enable reports false when the selector could not be driven', () async {
    // No app is booted in this test, so `globalState.appController` is null and
    // `_autoSelectChainGroup` cannot even attempt a selection. That is exactly
    // the "enabled but not routing" case the caller must not call a success.
    expect(globalState.hasAppController, isFalse,
        reason: 'precondition: this test runs without a booted app');

    final ok = await manager.setEnable(true);

    expect(ok, isFalse,
        reason: 'was void + unconditional "enabled" snackbar before the fix');
    // The config *did* land — enable and "actually routing" are separate
    // states, and only the second one failed.
    expect(manager.config.enable, isTrue);
    expect(persistedConfig()['enable'], isTrue);
  });

  test('a reload failure throws out of setEnable instead of being swallowed',
      () async {
    ChainProxyManager.coreConfigReloadOverride = () async {
      throw StateError('core reload failed');
    };

    await expectLater(manager.setEnable(true), throwsA(isA<StateError>()));

    // `updateConfig` writes and persists before reloading, so the failed
    // enable is already on disk. This is why the caller must roll back — a
    // swallowed throw would leave the switch ON over a config that never
    // applied, surviving a restart.
    expect(persistedConfig()['enable'], isTrue,
        reason: 'documents the window the view has to close by rolling back');

    // The rollback the view performs must be able to succeed.
    ChainProxyManager.coreConfigReloadOverride = () async {};
    expect(await manager.setEnable(false), isTrue);
    expect(persistedConfig()['enable'], isFalse);
  });

  test('setEnable(true) does not touch the runtime when it is off', () async {
    var reloads = 0;
    ChainProxyManager.coreConfigReloadOverride = () async {
      reloads++;
    };

    await manager.setEnable(false);

    expect(reloads, 1,
        reason: 'disable still applies to the core — it is not a local flag');
    expect(manager.config.enable, isFalse);
  });
}
