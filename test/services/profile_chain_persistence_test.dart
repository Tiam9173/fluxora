import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/profile_chain_manager.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.8-B — Profile-Chain persistence truth.
///
/// Before P2.8-B `_saveConfig()` was a bare `File.writeAsString` inside a
/// `catch → log` block, and `updateChain()` mutated `_chains` **before**
/// saving. A failed write therefore returned normally, left memory/UI showing
/// the new value, and the dialog showed "已保存…" — a false success.
///
/// Now the manager persists through the shared [AtomicConfigStorage] **first**
/// (tmp → validate → `.bak` → atomic rename) and only commits to memory after
/// the write succeeded; a failure is logged, surfaced to the user and
/// rethrown.
///
/// The failure path is injected **without any mock**: the config path is
/// pointed at a *directory*, which `AtomicConfigStorage.save()` cannot write
/// and reports as a real failure. Production still runs the real storage.
///
/// No widget binding is initialized in this file, so `globalState.showNotifier`
/// (the best-effort user notice) is itself unavailable. Test **B** therefore
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
  final manager = ProfileChainManager();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p28b_pc_');
    configPath = p.join(tmp.path, 'profile_chains.json');
    ProfileChainManager.configFilePathOverride = configPath;
  });

  tearDown(() async {
    ProfileChainManager.configFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<Map<String, dynamic>?> onDisk() =>
      AtomicConfigStorage(configPath).load();

  // ── A: normal save → atomic write → reload preserves the data ───────────
  test('A. updateChain persists atomically and survives a reload', () async {
    await manager.updateChain(
      'P-A',
      (c) => c.copyWith(preProxy: 'PRE-1'),
      reloadCore: false,
    );
    // A second save is what produces the `.bak` — the first one has no prior
    // target to back up (verified against the real AtomicConfigStorage).
    await manager.updateChain(
      'P-A',
      (c) => c.copyWith(landingProxy: 'LAND-1'),
      reloadCore: false,
    );

    expect(manager.getChain('P-A').preProxy, 'PRE-1');
    expect(manager.getChain('P-A').landingProxy, 'LAND-1');

    // The write really landed on disk, through the shared atomic storage.
    final stored = await onDisk();
    expect(stored, isNotNull);
    expect((stored!['P-A'] as Map)['preProxy'], 'PRE-1');
    expect((stored['P-A'] as Map)['landingProxy'], 'LAND-1');

    // Atomic storage semantics: the second save produced a `.bak`.
    expect(File('$configPath.bak').existsSync(), isTrue);
  });

  // ── B: save failure is visible AND leaves memory untouched ──────────────
  test('B. a failed save propagates and never fakes success', () async {
    // Establish a known-good baseline (twice, so a `.bak` exists).
    await manager.updateChain(
      'P-B',
      (c) => c.copyWith(preProxy: 'PRE-BEFORE-1'),
      reloadCore: false,
    );
    await manager.updateChain(
      'P-B',
      (c) => c.copyWith(preProxy: 'PRE-BEFORE'),
      reloadCore: false,
    );
    final before = manager.getChain('P-B').preProxy;

    // Inject a real write failure: the config path is a directory.
    await File(configPath).delete();
    Directory(configPath).createSync(recursive: true);

    await expectLater(
      manager.updateChain(
        'P-B',
        (c) => c.copyWith(preProxy: 'PRE-AFTER'),
        reloadCore: false,
      ),
      throwsA(isA<FileSystemException>()),
      reason: 'a failed save must be visible to the caller',
    );

    // No false success: memory still holds the pre-failure value …
    expect(
      manager.getChain('P-B').preProxy,
      before,
      reason: 'memory must not claim a change the disk never received',
    );

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
      after?['P-B']?['preProxy'],
      isNot('PRE-AFTER'),
      reason: 'the failed change must never reach the disk',
    );
  });

  test('B2. a failed save does not leave an orphan .tmp behind', () async {
    Directory(configPath).createSync(recursive: true);
    try {
      await manager.updateChain(
        'P-B2',
        (c) => c.copyWith(preProxy: 'X'),
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

  // ── C: recovery through the real production entry point ─────────────────
  //
  // `init()` is guarded by `_initialized` and the manager is a process
  // singleton, so this is the only test in this file that may call it (same
  // contract as `persistence_read_recovery_test.dart` case W).
  test('C. init() recovers profile_chains.json from .bak', () async {
    // A corrupt primary + a valid `.bak` is exactly the crash-during-save
    // shape AtomicConfigStorage recovers from.
    await File(configPath).writeAsString('{ this is not json', flush: true);
    await File('$configPath.bak').writeAsString(
      jsonEncode({
        'P-RECOVERED': {
          'profileId': 'P-RECOVERED',
          'enable': true,
          'preProxy': 'PRE-REC',
        },
      }),
      flush: true,
    );

    await manager.init();

    expect(manager.isInitialized, isTrue);
    expect(
      manager.getChain('P-RECOVERED').preProxy,
      'PRE-REC',
      reason:
          'the manager must read through AtomicConfigStorage, not a bare read',
    );
  });

  // ── structural: production really uses the shared atomic storage ─────────
  test(
    'the manager persists through AtomicConfigStorage (no test-only path)',
    () {
      final src = File(
        'lib/manager/profile_chain_manager.dart',
      ).readAsStringSync();

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
