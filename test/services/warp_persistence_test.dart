import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/warp_manager.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.8-B — WARP persistence truth.
///
/// Before P2.8-B `updateConfig()` notified listeners **before** calling a
/// `_saveConfig()` that was a bare `File.writeAsString` inside a `catch → log`
/// block. The UI therefore rendered the new value even when the disk write
/// failed, and `warp_view`'s setters (fire-and-forget) still showed their
/// "已开启 WARP" style confirmations — a false success.
///
/// Now the manager persists through the shared [AtomicConfigStorage] **first**
/// (tmp → validate → `.bak` → atomic rename) and only commits `_config` +
/// notifies after the write succeeded; a failure is logged, surfaced to the
/// user and rethrown.
///
/// The failure path is injected **without any mock**: the config path is
/// pointed at a *directory*, which `AtomicConfigStorage.save()` cannot write
/// and reports as a real failure. Production still runs the real storage.
///
/// No widget binding is initialized in this file, so `globalState.showNotifier`
/// (the best-effort user notice) is itself unavailable. Test **E** therefore
/// also pins that the notice cannot mask the real failure: the caller still
/// sees the original `FileSystemException`.

/// Strips `//` line comments so the structural guard tests *code*, not prose.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

void main() {
  late Directory tmp;
  late String configPath;
  final manager = WarpManager();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p28b_warp_');
    configPath = p.join(tmp.path, 'warp_config.json');
    WarpManager.configFilePathOverride = configPath;
  });

  tearDown(() async {
    WarpManager.configFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<Map<String, dynamic>?> onDisk() =>
      AtomicConfigStorage(configPath).load();

  // ── D: normal save → atomic write → reload preserves the data ───────────
  test('D. updateConfig persists atomically and survives a reload', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true),
      reloadCore: false,
    );
    // A second save is what produces the `.bak` — the first one has no prior
    // target to back up (verified against the real AtomicConfigStorage).
    await manager.updateConfig((c) => c.copyWith(mtu: 1420), reloadCore: false);

    expect(manager.config.enable, isTrue);
    expect(manager.config.mtu, 1420);

    final stored = await onDisk();
    expect(stored, isNotNull);
    expect(stored!['enable'], isTrue);
    expect(stored['mtu'], 1420);

    // Atomic storage semantics: the second save produced a `.bak`.
    expect(File('$configPath.bak').existsSync(), isTrue);
  });

  // ── E: save failure is visible AND leaves memory/UI untouched ───────────
  test('E. a failed save propagates and never fakes success', () async {
    // Known-good baseline (twice, so a `.bak` exists).
    await manager.updateConfig(
      (c) => c.copyWith(enable: false),
      reloadCore: false,
    );
    await manager.updateConfig((c) => c.copyWith(mtu: 1360), reloadCore: false);
    final enableBefore = manager.config.enable;
    final mtuBefore = manager.config.mtu;

    // Inject a real write failure: the config path is a directory.
    await File(configPath).delete();
    Directory(configPath).createSync(recursive: true);

    await expectLater(
      manager.updateConfig(
        (c) => c.copyWith(enable: true, mtu: 9000),
        reloadCore: false,
      ),
      throwsA(isA<FileSystemException>()),
      reason: 'a failed save must be visible to the caller',
    );

    // No false success: the in-memory config still holds the pre-failure
    // values, so the UI (which is notified only on success) cannot render a
    // change the disk never received.
    expect(
      manager.config.enable,
      enableBefore,
      reason: 'memory must not claim a change the disk never received',
    );
    expect(manager.config.mtu, mtuBefore);

    // … and the failed change never reached the disk.
    //
    // `AtomicConfigStorage` recovers the `.bak` when the target is gone, and
    // the `.bak` is a copy taken BEFORE the last successful overwrite — so the
    // recovered payload is the state from *before* that save, not the value it
    // wrote. Assert on the failed value rather than on one recovery
    // generation, which keeps this independent of the backup policy.
    Directory(configPath).deleteSync();
    final after = await onDisk();
    expect(after, isNotNull, reason: 'the .bak is still recoverable');
    expect(
      after?['mtu'],
      isNot(9000),
      reason: 'the failed change must never reach the disk',
    );
  });

  test('E2. a failed save does not leave an orphan .tmp behind', () async {
    Directory(configPath).createSync(recursive: true);
    try {
      await manager.updateConfig(
        (c) => c.copyWith(mtu: 1280),
        reloadCore: false,
      );
      fail('expected the save to fail');
    } catch (_) {
      // expected
    }
    final leftovers = tmp
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.tmp'))
        .toList();
    expect(
      leftovers,
      isEmpty,
      reason: 'AtomicConfigStorage must clean up its tmp on failure',
    );
  });

  // ── F: recovery through the real production entry point ─────────────────
  //
  // `init()` is guarded by `_initialized` and the manager is a process
  // singleton, so this is the only test in this file that may call it (same
  // contract as `persistence_read_recovery_test.dart` case W).
  test('F. init() recovers warp_config.json from .bak', () async {
    await File(configPath).writeAsString('{ not json at all', flush: true);
    await File('$configPath.bak').writeAsString(
      jsonEncode({'enable': true, 'mtu': 1420, 'privateKey': 'RECOVERED-KEY'}),
      flush: true,
    );

    await manager.init();

    expect(manager.isInitialized, isTrue);
    expect(
      manager.config.privateKey,
      'RECOVERED-KEY',
      reason:
          'the manager must read through AtomicConfigStorage, not a bare read',
    );
    expect(manager.config.mtu, 1420);
  });

  // ── structural: production really uses the shared atomic storage ─────────
  test(
    'the manager persists through AtomicConfigStorage (no test-only path)',
    () {
      final src = File('lib/manager/warp_manager.dart').readAsStringSync();

      expect(src.contains('AtomicConfigStorage'), isTrue);
      expect(
        _codeOnly(src).contains('writeAsString'),
        isFalse,
        reason: 'the bare write must be gone',
      );
      // The seam overrides only the path.
      expect(src.contains('static String? configFilePathOverride'), isTrue);
    },
  );
}
