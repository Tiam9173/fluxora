import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/identity.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/tun_readback.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.6-F — desktop TUN actual-state readback.
///
/// Every platform is driven through the readback's own
/// `listInterfaceNamesOverride` seam, so no real OS interface is enumerated and
/// no MethodChannel / process is needed.

/// Strips `//` line comments so the structural guards below test *code*, not
/// prose (the service's own doc comments legitimately name the Android VPN
/// types it deliberately does **not** use).
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

void main() {
  final service = TunReadbackService.instance;
  final tun = AppIdentity.tunDeviceName;

  setUp(() {
    TunReadbackService.listInterfaceNamesOverride = null;
    TunReadbackService.platformOverride = null;
    TunReadbackService.interfaceNameOverride = null;
    service.lastReadback.value = null;
  });

  tearDown(() {
    TunReadbackService.listInterfaceNamesOverride = null;
    TunReadbackService.platformOverride = null;
    TunReadbackService.interfaceNameOverride = null;
    service.lastReadback.value = null;
  });

  List<String> withTun() => <String>['Ethernet', 'Wi-Fi', tun];
  List<String> withoutTun() => <String>['Ethernet', 'Wi-Fi'];

  // ── A: Android reports elsewhere; this readback stays out of the way ─────
  test('A. Android is unsupported+unknown and runs no OS query', () async {
    TunReadbackService.platformOverride = 'android';
    TunReadbackService.listInterfaceNamesOverride = () async =>
        fail('no OS interface query may run on Android');

    final r = await service.read();
    expect(r.actualState, TunActualState.unknown);
    expect(r.unsupported, isTrue);
    expect(r.matchesDesired(desiredEnabled: true), isFalse);
    expect(r.matchesDesired(desiredEnabled: false), isFalse);
  });

  test('A2. the readback never references the Android VPN status path', () {
    final source = _codeOnly(
      File('lib/services/tun_readback.dart').readAsStringSync(),
    );
    for (final forbidden in const [
      'getStatus',
      'vpn_service',
      'VpnService',
      'vpnSettingProvider',
    ]) {
      expect(
        source.contains(forbidden),
        isFalse,
        reason: 'P2.6-F must not couple to the Android VPN path ($forbidden)',
      );
    }
  });

  // ── B: platform mapping ─────────────────────────────────────────────────
  test(
    'B1/B2. Windows honours the configured name in both directions',
    () async {
      TunReadbackService.platformOverride = 'windows';

      TunReadbackService.listInterfaceNamesOverride = () async => withTun();
      final on = await service.read();
      expect(on.actualState, TunActualState.enabled);
      expect(on.interfaceName, tun);
      expect(on.unsupported, isFalse);

      TunReadbackService.listInterfaceNamesOverride = () async => withoutTun();
      final off = await service.read();
      expect(off.actualState, TunActualState.disabled);
      expect(off.interfaceName, isNull);
    },
  );

  test('B3/B4. Linux honours the configured name in both directions', () async {
    TunReadbackService.platformOverride = 'linux';

    TunReadbackService.listInterfaceNamesOverride = () async => withTun();
    expect((await service.read()).actualState, TunActualState.enabled);

    TunReadbackService.listInterfaceNamesOverride = () async => withoutTun();
    expect((await service.read()).actualState, TunActualState.disabled);
  });

  test(
    'B5/B6. macOS is conclusive when present, unknown (never disabled) when absent',
    () async {
      TunReadbackService.platformOverride = 'macos';

      // Present ⇒ conclusive: the interface exists, so TUN is up.
      TunReadbackService.listInterfaceNamesOverride = () async => withTun();
      expect((await service.read()).actualState, TunActualState.enabled);

      // Absent ⇒ ambiguous: macOS assigns `utunN` and ignores the configured
      // name, so "no Fluxora interface" cannot be read as "not running".
      TunReadbackService.listInterfaceNamesOverride = () async => withoutTun();
      final absent = await service.read();
      expect(
        absent.actualState,
        TunActualState.unknown,
        reason: 'macOS must not fabricate `disabled` from an unmatched name',
      );
      expect(absent.error, isNotNull);
    },
  );

  test('B7. a platform without desktop TUN is unsupported', () async {
    TunReadbackService.platformOverride = 'fuchsia';
    TunReadbackService.listInterfaceNamesOverride = () async =>
        fail('no OS interface query may run on an unsupported platform');

    final r = await service.read();
    expect(r.actualState, TunActualState.unknown);
    expect(r.unsupported, isTrue);
  });

  test('B8. an empty interface list is unknown, never disabled', () async {
    TunReadbackService.platformOverride = 'windows';
    TunReadbackService.listInterfaceNamesOverride = () async => <String>[];

    final r = await service.read();
    expect(
      r.actualState,
      TunActualState.unknown,
      reason: 'an enumeration that returned nothing proves nothing',
    );
    expect(r.error, isNotNull);
  });

  // ── C: failure ⇒ unknown, never a guess, never a throw ──────────────────
  test('C. a throwing readback yields unknown and never throws', () async {
    TunReadbackService.platformOverride = 'windows';
    TunReadbackService.listInterfaceNamesOverride = () async =>
        throw const SocketException('boom');

    final r = await service.read();
    expect(r.actualState, TunActualState.unknown);
    expect(r.error, isNotNull);
    expect(r.matchesDesired(desiredEnabled: true), isFalse);
  });

  // ── F: bounded timeout — a hanging backend cannot hang the UI ───────────
  test('F. a never-completing readback is bounded to readTimeout', () async {
    TunReadbackService.platformOverride = 'windows';
    final never = Completer<List<String>>();
    TunReadbackService.listInterfaceNamesOverride = () => never.future;

    final started = DateTime.now();
    final r = await service.read();
    final elapsed = DateTime.now().difference(started);

    expect(r.actualState, TunActualState.unknown);
    expect(r.error, isNotNull);
    expect(
      elapsed,
      lessThan(TunReadbackService.readTimeout * 2),
      reason: 'the observation must be bounded, not open-ended',
    );
    // never completed ⇒ the seam was abandoned, not awaited forever.
    expect(never.isCompleted, isFalse);
  });

  // ── D: desired != actual is preserved, never auto-overwritten ───────────
  test('D. desired=enabled with OS=disabled stays a mismatch', () async {
    TunReadbackService.platformOverride = 'windows';
    TunReadbackService.listInterfaceNamesOverride = () async => withoutTun();

    final r = await service.read();
    expect(r.actualState, TunActualState.disabled);
    expect(
      r.matchesDesired(desiredEnabled: true),
      isFalse,
      reason: 'a mismatch must remain observable, never silently reconciled',
    );
    expect(r.matchesDesired(desiredEnabled: false), isTrue);
    expect(
      resolveTunStatus(desiredEnabled: true, checking: false, readback: r),
      TunStatusKind.mismatchOn,
    );
    expect(
      resolveTunStatus(desiredEnabled: false, checking: false, readback: r),
      TunStatusKind.off,
    );
  });

  test('D2. a desired state alone can never produce `on`', () {
    expect(
      resolveTunStatus(desiredEnabled: true, checking: false, readback: null),
      TunStatusKind.notChecked,
    );
    expect(
      resolveTunStatus(
        desiredEnabled: true,
        checking: false,
        readback: TunReadback.unknown('windows', error: 'n/a'),
      ),
      TunStatusKind.unknown,
    );
    expect(
      resolveTunStatus(
        desiredEnabled: true,
        checking: false,
        readback: TunReadback.unknown('android', unsupported: true),
      ),
      TunStatusKind.unsupported,
    );
    expect(
      resolveTunStatus(desiredEnabled: true, checking: true, readback: null),
      TunStatusKind.checking,
    );
  });

  // ── E: the readback mutates nothing ─────────────────────────────────────
  test('E. the readback cannot mutate anything (no write/exec primitives)', () {
    final source = _codeOnly(
      File('lib/services/tun_readback.dart').readAsStringSync(),
    );
    for (final forbidden in const [
      'writeAsString',
      'writeAsBytes',
      'Process.run',
      'Process.start',
      'setBool',
      'updateConfig',
      'setupConfig',
      'sharedPreferences',
    ]) {
      expect(
        source.contains(forbidden),
        isFalse,
        reason: 'the readback must stay strictly read-only ($forbidden)',
      );
    }
  });

  test(
    'E2. a readback leaves chain config / fallback pool untouched',
    () async {
      final tmp = Directory.systemTemp.createTempSync('fluxora_p26f_');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
      ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
        tmp.path,
        'chain_reliability_stats.json',
      );
      try {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, hop1Node: 'T-1', hop2Node: 'T-2'),
          reloadCore: false,
        );
        final configBefore = manager.config.toJson();
        final poolBefore = manager.fallbackPool.toJson();

        TunReadbackService.platformOverride = 'windows';
        TunReadbackService.listInterfaceNamesOverride = () async => withTun();
        await service.read();

        expect(manager.config.toJson(), configBefore);
        expect(manager.fallbackPool.toJson(), poolBefore);
      } finally {
        await ChainProxyManager().flushReliabilityStats();
        ChainProxyManager.configFilePathOverride = null;
        ChainProxyManager.fallbackPoolFilePathOverride = null;
        ChainProxyManager.reliabilityStatsFilePathOverride = null;
        await deleteTempDirWithRetry(tmp);
      }
    },
  );

  // ── published observation ───────────────────────────────────────────────
  test('read() publishes to lastReadback and clears isChecking', () async {
    TunReadbackService.platformOverride = 'linux';
    TunReadbackService.listInterfaceNamesOverride = () async => withTun();

    expect(service.lastReadback.value, isNull);
    await service.read();
    expect(service.lastReadback.value?.actualState, TunActualState.enabled);
    expect(service.isChecking.value, isFalse);
  });
}
