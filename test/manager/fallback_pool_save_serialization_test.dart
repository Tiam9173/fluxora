import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:path/path.dart' as p;

/// Phase 06.7-B — the fallback-pool save queue.
///
/// The bug this guards is an *ordering* bug: `updateFallbackPool` reads
/// `_fallbackPool` while saving, so two concurrent updates could read state1 and
/// state2 and rename them in the opposite order, leaving the file one state
/// behind memory. Final-JSON equality alone cannot prove the queue works (a
/// single last writer would also pass), so these tests observe the **sequence**
/// and the **concurrency** of the saves themselves.
void main() {
  late Directory tmp;
  late String poolPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_067b_pool_');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
  });

  tearDown(() {
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.saveInterceptor = null;
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {
        // Best effort.
      }
    }
  });

  Map<String, dynamic> readDisk() =>
      jsonDecode(File(poolPath).readAsStringSync()) as Map<String, dynamic>;

  /// The updater the tests use: identity, so the only variable under test is the
  /// queue itself. `_fallbackPool` starts empty, and every save writes whatever
  /// is in memory at that moment.
  ChainFallbackPool identity(ChainFallbackPool pool) => pool;

  test('A — sequential updates save in order and leave the file current', () async {
    final order = <int>[];
    var seq = 0;
    ChainProxyManager.saveInterceptor = (save) async {
      order.add(++seq);
      await save();
    };

    final manager = ChainProxyManager();
    for (var i = 0; i < 3; i++) {
      await manager.updateFallbackPool(identity);
    }

    expect(order, [1, 2, 3], reason: 'saves run one after another, in order');
    expect(File(poolPath).existsSync(), isTrue);
    expect(readDisk()['version'], isNotNull);
  });

  test('B — Future.wait submits three updates but never more than one save runs', () async {
    var active = 0;
    var maxActive = 0;
    final started = <int>[];
    var seq = 0;
    final firstSaveGate = Completer<void>();

    ChainProxyManager.saveInterceptor = (save) async {
      final id = ++seq;
      started.add(id);
      active++;
      if (active > maxActive) maxActive = active;
      try {
        if (id == 1) {
          // Hold the first save open so the other two are forced to queue.
          await firstSaveGate.future;
        }
        await save();
      } finally {
        active--;
      }
    };

    final manager = ChainProxyManager();
    final futures = [
      manager.updateFallbackPool(identity),
      manager.updateFallbackPool(identity),
      manager.updateFallbackPool(identity),
    ];

    // Let the first save start and the other two enqueue behind it.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(started, [1], reason: 'the second save must not start yet');

    firstSaveGate.complete();
    await Future.wait(futures);

    expect(started, [1, 2, 3]);
    expect(maxActive, 1, reason: 'strictly one save at a time');
    expect(File(poolPath).existsSync(), isTrue);
  });

  test('C — a failed save surfaces to its caller and the queue keeps going', () async {
    var calls = 0;
    ChainProxyManager.saveInterceptor = (save) async {
      calls++;
      if (calls == 1) {
        throw StateError('injected save failure');
      }
      await save();
    };

    final manager = ChainProxyManager();

    await expectLater(
      manager.updateFallbackPool(identity),
      throwsA(isA<StateError>()),
      reason: 'the caller must receive its own failure',
    );
    expect(File(poolPath).existsSync(), isFalse, reason: 'first save never wrote');

    // The chain must not be wedged by the failure.
    await manager.updateFallbackPool(identity);

    expect(calls, 2);
    expect(File(poolPath).existsSync(), isTrue);
    expect(readDisk()['version'], isNotNull);
  });

  test('D — three distinct states: last write wins, disk matches memory', () async {
    // Three genuinely different pools. `ChainFallbackCandidate` is the real
    // model, so this goes through the real `toJson()` / version stamp.
    const stateA = ChainFallbackPool(
      entryCandidates: [
        ChainFallbackCandidate(
          nodeName: 'A-01',
          role: FallbackCandidateRole.entry,
        ),
      ],
    );
    const stateB = ChainFallbackPool(
      entryCandidates: [
        ChainFallbackCandidate(
          nodeName: 'B-01',
          role: FallbackCandidateRole.entry,
        ),
        ChainFallbackCandidate(
          nodeName: 'B-02',
          role: FallbackCandidateRole.entry,
          priority: 2,
        ),
      ],
    );
    const stateC = ChainFallbackPool(
      entryCandidates: [
        ChainFallbackCandidate(
          nodeName: 'C-01',
          role: FallbackCandidateRole.entry,
        ),
        ChainFallbackCandidate(
          nodeName: 'C-02',
          role: FallbackCandidateRole.entry,
          enabled: false,
        ),
        ChainFallbackCandidate(
          nodeName: 'C-03',
          role: FallbackCandidateRole.entry,
          priority: 3,
        ),
      ],
    );

    List<String> names(ChainFallbackPool pool) =>
        pool.entryCandidates.map((c) => c.nodeName).toList();

    // Precondition: the three states really are different.
    expect(names(stateA), ['A-01']);
    expect(names(stateB), ['B-01', 'B-02']);
    expect(names(stateC), ['C-01', 'C-02', 'C-03']);
    expect(names(stateA), isNot(names(stateB)));
    expect(names(stateB), isNot(names(stateC)));

    var active = 0;
    var maxActive = 0;
    final started = <int>[];
    final firstSaveGate = Completer<void>();

    ChainProxyManager.saveInterceptor = (save) async {
      final id = started.length + 1;
      started.add(id);
      active++;
      if (active > maxActive) maxActive = active;
      try {
        if (id == 1) await firstSaveGate.future;
        await save();
      } finally {
        active--;
      }
    };

    final manager = ChainProxyManager();
    final futures = [
      manager.updateFallbackPool((_) => stateA),
      manager.updateFallbackPool((_) => stateB),
      manager.updateFallbackPool((_) => stateC),
    ];

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(started, [1], reason: 'only the first save may run');
    firstSaveGate.complete();
    await Future.wait(futures);

    expect(started, [1, 2, 3], reason: 'saves ran in submission order');
    expect(maxActive, 1, reason: 'never more than one save at a time');

    final disk = readDisk();
    final entry = (disk['entryCandidates'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => e['nodeName'] as String)
        .toList();

    // The queue's contract: the final file is whatever memory held when the
    // *last* save ran, which is state C.
    expect(entry, names(stateC), reason: 'disk must hold the final state');
    // The stamp is added by the save path (PersistenceSchema.versionKey), not
    // by the pool's own toJson(), so it is asserted for presence only.
    expect(disk['version'], isNotNull, reason: 'schema stamp preserved');

    // Memory holds C by construction (the last updater returned it), so
    // "disk == memory" reduces to "disk == C", asserted above.
    expect(names(stateC), ['C-01', 'C-02', 'C-03']);
  });
}
