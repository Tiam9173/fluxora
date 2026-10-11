import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/system_proxy_readback.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.4-D (CF-3) — system-proxy readback.
///
/// Every platform is driven through the readback's own `processRunOverride`
/// seam, so no real OS state is read or written and no MethodChannel is needed.
ProcessResult _res(int code, [String out = '', String err = '']) =>
    ProcessResult(0, code, out, err);

void main() {
  final service = SystemProxyReadbackService.instance;

  setUp(() {
    SystemProxyReadbackService.processRunOverride = null;
    SystemProxyReadbackService.platformOverride = null;
    service.lastReadback.value = null;
  });

  tearDown(() {
    SystemProxyReadbackService.processRunOverride = null;
    SystemProxyReadbackService.platformOverride = null;
    service.lastReadback.value = null;
  });

  /// Windows `reg query` stdout for a value.
  String winOut(String name, String value) =>
      '\r\nHKEY_CURRENT_USER\\...\\Internet Settings\r\n'
      '    $name    REG_DWORD    $value\r\n\r\n';

  // ── A / B: SET enabled / disabled → readback agrees ──────────────────────
  test('A. Windows readback reports enabled when ProxyEnable is 0x1', () async {
    SystemProxyReadbackService.platformOverride = 'windows';
    SystemProxyReadbackService.processRunOverride = (exe, args) async {
      if (args.contains('ProxyEnable')) {
        return _res(0, winOut('ProxyEnable', '0x1'));
      }
      return _res(0, winOut('ProxyServer', '127.0.0.1:7890'));
    };

    final r = await service.read();
    expect(r.actualState, SystemProxyActualState.enabled);
    expect(r.host, '127.0.0.1');
    expect(r.port, 7890);
    expect(r.matchesDesired(desiredEnabled: true), isTrue);
  });

  test(
    'B. Windows readback reports disabled when ProxyEnable is 0x0',
    () async {
      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride = (exe, args) async =>
          _res(0, winOut('ProxyEnable', '0x0'));

      final r = await service.read();
      expect(r.actualState, SystemProxyActualState.disabled);
      expect(r.matchesDesired(desiredEnabled: false), isTrue);
    },
  );

  // ── C / F: desired != actual → mismatch ─────────────────────────────────
  test('C/F. desired=enabled but OS=disabled is a mismatch', () async {
    SystemProxyReadbackService.platformOverride = 'windows';
    SystemProxyReadbackService.processRunOverride = (exe, args) async =>
        _res(0, winOut('ProxyEnable', '0x0'));

    final r = await service.read();
    expect(r.actualState, SystemProxyActualState.disabled);
    expect(
      r.matchesDesired(desiredEnabled: true),
      isFalse,
      reason: 'external change must be detectable as a mismatch',
    );
    expect(r.matchesDesired(desiredEnabled: false), isTrue);
  });

  // ── D / E: unavailable / failing readback → unknown (never a guess) ──────
  test(
    'D. a failing readback yields unknown, never enabled/disabled',
    () async {
      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride = (exe, args) async =>
          _res(1, '', 'ERROR');

      final r = await service.read();
      expect(r.actualState, SystemProxyActualState.unknown);
      expect(r.error, isNotNull);
      expect(r.matchesDesired(desiredEnabled: true), isFalse);
    },
  );

  test('E. a throwing readback yields unknown and never throws', () async {
    SystemProxyReadbackService.platformOverride = 'windows';
    SystemProxyReadbackService.processRunOverride = (exe, args) async =>
        throw ProcessException(exe, args, 'boom');

    final r = await service.read();
    expect(r.actualState, SystemProxyActualState.unknown);
    expect(r.error, isNotNull);
  });

  // ── macOS ───────────────────────────────────────────────────────────────
  test('G. macOS readback parses networksetup -getwebproxy', () async {
    SystemProxyReadbackService.platformOverride = 'macos';
    SystemProxyReadbackService.processRunOverride = (exe, args) async {
      if (args.first == '-listallnetworkservices') {
        return _res(0, 'An asterisk (*) denotes disabled\nWi-Fi\nEthernet\n');
      }
      return _res(
        0,
        'Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\nAuthenticated Proxy Enabled: 0\n',
      );
    };

    final r = await service.read();
    expect(r.actualState, SystemProxyActualState.enabled);
    expect(r.host, '127.0.0.1');
    expect(r.port, 7890);

    SystemProxyReadbackService.processRunOverride = (exe, args) async {
      if (args.first == '-listallnetworkservices') {
        return _res(0, 'Wi-Fi\n');
      }
      return _res(0, 'Enabled: No\nServer: \nPort: 0\n');
    };
    final off = await service.read();
    expect(off.actualState, SystemProxyActualState.disabled);
  });

  // ── Linux ───────────────────────────────────────────────────────────────
  test('H. Linux readback parses gsettings, else KDE, else unknown', () async {
    SystemProxyReadbackService.platformOverride = 'linux';
    SystemProxyReadbackService.processRunOverride = (exe, args) async {
      if (exe == 'gsettings' && args.last == 'mode') return _res(0, "'manual'");
      if (exe == 'gsettings' && args.last == 'host') {
        return _res(0, "'127.0.0.1'");
      }
      if (exe == 'gsettings' && args.last == 'port') return _res(0, '7890');
      return _res(1);
    };
    final on = await service.read();
    expect(on.actualState, SystemProxyActualState.enabled);
    expect(on.port, 7890);

    SystemProxyReadbackService.processRunOverride = (exe, args) async =>
        exe == 'gsettings' ? _res(0, "'none'") : _res(1);
    expect((await service.read()).actualState, SystemProxyActualState.disabled);

    // KDE fallback.
    SystemProxyReadbackService.processRunOverride = (exe, args) async =>
        exe == 'kreadconfig5' ? _res(0, '1') : _res(1);
    expect((await service.read()).actualState, SystemProxyActualState.enabled);

    // No supported backend ⇒ unknown, never a guess.
    SystemProxyReadbackService.processRunOverride = (exe, args) async =>
        _res(1);
    final none = await service.read();
    expect(none.actualState, SystemProxyActualState.unknown);
    expect(none.error, isNotNull);
  });

  // ── I / L: unsupported platform ─────────────────────────────────────────
  test(
    'I/L. an unsupported platform is unknown + unsupported, not success',
    () async {
      SystemProxyReadbackService.platformOverride = 'android';
      SystemProxyReadbackService.processRunOverride = (exe, args) async {
        fail('no OS command may run on an unsupported platform');
      };

      final r = await service.read();
      expect(r.actualState, SystemProxyActualState.unknown);
      expect(r.unsupported, isTrue);
      expect(r.matchesDesired(desiredEnabled: true), isFalse);
      expect(r.matchesDesired(desiredEnabled: false), isFalse);
    },
  );

  // ── J / K: readback is strictly read-only w.r.t. Fluxora state ──────────
  test('J/K. a readback never touches chain config / fallback pool', () async {
    final tmp = Directory.systemTemp.createTempSync('fluxora_p24d_');
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
        (c) => c.copyWith(enable: true, hop1Node: 'P-1', hop2Node: 'P-2'),
        reloadCore: false,
      );
      final configBefore = manager.config.toJson();
      final poolBefore = manager.fallbackPool.toJson();

      SystemProxyReadbackService.platformOverride = 'windows';
      SystemProxyReadbackService.processRunOverride = (exe, args) async =>
          _res(0, winOut('ProxyEnable', '0x1'));
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
  });
}
