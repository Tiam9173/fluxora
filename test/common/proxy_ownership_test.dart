import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/proxy_ownership.dart';
import 'package:flutter_test/flutter_test.dart';

/// B3 — system proxy ownership.
///
/// Nothing here touches the real WinINET settings: the snapshot reader, the
/// start/stop calls and the state file path are all injected, and the settle
/// delay is zeroed.
void main() {
  late Directory tmp;
  late String statePath;

  var stops = 0;
  var starts = 0;
  ProxySnapshot? current;
  bool? startResult;

  // P10-P0-B — what each restore path actually reached, plus the knobs needed
  // to simulate the system refusing to cooperate.
  late List<ProxySnapshot> written;
  late List<int> startPorts;
  late List<List<String>> startBypass;
  late bool writeResult;
  late bool refreshResult;
  late bool stopResult;
  late bool startLands;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fluxora_proxy_ownership');
    statePath = '${tmp.path}${Platform.pathSeparator}proxy_ownership.json';
    stops = 0;
    starts = 0;
    current = null;
    startResult = true;
    written = <ProxySnapshot>[];
    startPorts = <int>[];
    startBypass = <List<String>>[];
    writeResult = true;
    refreshResult = true;
    stopResult = true;
    startLands = true;

    ProxyOwnership.statePathForTest = statePath;
    ProxyOwnership.readForTest = () => current;

    // The fakes model the real system, because every restore is now read back:
    // a primitive that "succeeds" without changing the state must look like a
    // failure to the caller.
    ProxyOwnership.stopForTest = () async {
      stops++;
      if (!stopResult) return false;
      final prev = current;
      current = ProxySnapshot(
        enable: 0,
        server: prev?.server ?? '',
        bypass: prev?.bypass ?? '',
      );
      return true;
    };
    ProxyOwnership.startForTest = (port, bypass) async {
      starts++;
      startPorts.add(port);
      startBypass.add(bypass);
      if (startResult != true) return startResult;
      if (startLands) {
        current = ProxySnapshot(
          enable: 1,
          server: '127.0.0.1:$port',
          bypass: bypass.isEmpty ? '<local>' : '<local>;${bypass.join(';')}',
        );
      }
      return true;
    };
    ProxyOwnership.writeSnapshotForTest = (snapshot) async {
      written.add(snapshot);
      if (!writeResult) return false;
      current = snapshot;
      return true;
    };
    ProxyOwnership.refreshWinInetForTest = () => refreshResult;
    ProxyOwnership.settle = Duration.zero;
  });

  tearDown(() async {
    ProxyOwnership.readForTest = null;
    ProxyOwnership.startForTest = null;
    ProxyOwnership.stopForTest = null;
    ProxyOwnership.writeSnapshotForTest = null;
    ProxyOwnership.refreshWinInetForTest = null;
    ProxyOwnership.statePathForTest = null;
    ProxyOwnership.settle = const Duration(milliseconds: 400);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> writeState(Map<String, Object?> json) =>
      File(statePath).writeAsString(jsonEncode(json));

  Future<Map<String, Object?>?> readState() async {
    final file = File(statePath);
    if (!await file.exists()) return null;
    return json.decode(await file.readAsString()) as Map<String, Object?>;
  }

  Map<String, Object?> ownedState({
    required ProxySnapshot applied,
    ProxySnapshot? snapshot,
  }) => {
    'schema': 1,
    'owned': true,
    'pending': false,
    'pid': 1,
    'snapshot': (snapshot ?? const ProxySnapshot()).toJson(),
    'applied': applied.toJson(),
  };

  // ── T-P1 ───────────────────────────────────────────────────────────────────
  group('T-P1 — not owned means never touched', () {
    test('release on a fresh install calls nothing', () async {
      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.notOwned,
      );
      expect(stops, 0, reason: 'launching the app must not clear the proxy');
    });

    test('startup reconciliation on a fresh install calls nothing', () async {
      await ProxyOwnership.reconcileOnStart();
      expect(stops, 0);
      expect(starts, 0);
    });

    test('a corrupt state file reads as not owned', () async {
      await File(statePath).writeAsString('{not json');
      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.notOwned,
      );
      expect(stops, 0, reason: 'fail closed: unreadable state is not ownership');
    });
  });

  // ── T-P2 ───────────────────────────────────────────────────────────────────
  group('T-P2 — owned and still ours is restored', () {
    test('apply records ownership only after the read-back confirms', () async {
      current = const ProxySnapshot(enable: 0, server: '', bypass: '<local>');
      ProxyOwnership.startForTest = (port, bypass) async {
        starts++;
        current = ProxySnapshot(
          enable: 1,
          server: '127.0.0.1:$port',
          bypass: '<local>',
        );
        return true;
      };

      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isTrue);
      final state = await readState();
      expect(state?['owned'], isTrue);
      expect((state?['applied'] as Map)['server'], '127.0.0.1:7890');
      expect((state?['snapshot'] as Map)['enable'], 0);
    });

    test('release restores and clears the claim', () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      current = applied;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(stops, 1);
      expect(await readState(), isNull);
    });
  });

  // ── T-P3 ───────────────────────────────────────────────────────────────────
  group('T-P3 — an external change wins', () {
    test('a different server is left alone', () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      // Clash Verge pointed it somewhere else while we were running.
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:7891');

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.externalChange,
      );
      expect(stops, 0, reason: 'never overwrite another program\'s proxy');
      expect(await readState(), isNull);
    });

    test('an external disable is left alone too', () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      current = const ProxySnapshot(enable: 0, server: '127.0.0.1:7890');

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.externalChange,
      );
      expect(stops, 0);
    });

    test('an unreadable current state keeps the claim and calls nothing',
        () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      ProxyOwnership.readForTest = () => null;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.readFailed,
      );
      expect(stops, 0);
      expect(await readState(), isNotNull, reason: 'claim kept for next time');
    });
  });

  // ── T-P4 ───────────────────────────────────────────────────────────────────
  group('T-P4 — a failed write rolls back', () {
    test('startProxy returning false rolls back and claims nothing', () async {
      current = const ProxySnapshot(enable: 0, server: '');
      startResult = false;

      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isFalse);
      expect(
        stops,
        0,
        reason: 'P10-P0-A3: the system never changed, so the rollback is a '
            'no-op instead of a redundant write',
      );
      expect(await readState(), isNull);
    });

    test('a write that does not land is rolled back', () async {
      current = const ProxySnapshot(enable: 0, server: '');
      // startProxy reports success but the read-back still shows direct.
      startLands = false;
      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isFalse);
      expect(stops, 0, reason: 'already back at the pre-takeover value');
      expect(await readState(), isNull);
    });

    test('no snapshot means no write at all', () async {
      ProxyOwnership.readForTest = () => null;

      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isFalse);
      expect(starts, 0, reason: 'cannot undo what we cannot measure');
      expect(stops, 0);
    });
  });

  // ── T-P5 ───────────────────────────────────────────────────────────────────
  group('T-P5 — startup reconciliation', () {
    test('a crash leftover that is still ours is restored', () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      current = applied;

      await ProxyOwnership.reconcileOnStart();

      expect(stops, 1);
      expect(await readState(), isNull);
    });

    test('a leftover that someone else changed is only dropped', () async {
      const applied = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
      await writeState(ownedState(applied: applied));
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:7891');

      await ProxyOwnership.reconcileOnStart();

      expect(stops, 0, reason: 'the newer value belongs to whoever set it');
      expect(await readState(), isNull);
    });
  });

  // ── T-P6 ───────────────────────────────────────────────────────────────────
  // P10-P0-B — the restore must reproduce what was there, not force direct.
  group('T-P6 — restore semantics (P10-P0-B)', () {
    const ours = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');

    Map<String, Object?> stateWith({Object? snapshot}) => {
      'schema': 1,
      'owned': true,
      'pending': false,
      'pid': 1,
      'snapshot': snapshot,
      'applied': ours.toJson(),
    };

    test('direct before takeover restores through the plugin', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 0,
            server: '',
            bypass: '<local>',
          ).toJson(),
        ),
      );
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(stops, 1, reason: 'stopProxy is the direct primitive');
      expect(starts, 0);
      expect(written, isEmpty, reason: 'the registry writer is not needed here');
      expect(await readState(), isNull);
    });

    test('a third-party loopback proxy keeps its own port', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:1080',
            bypass: '<local>;*.corp.example',
          ).toJson(),
        ),
      );
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(stops, 0, reason: 'going direct would destroy their proxy');
      expect(startPorts, [1080]);
      expect(
        startBypass.single,
        ['*.corp.example'],
        reason: 'startProxy prepends <local> itself; it must not be doubled',
      );
      expect(written, isEmpty);
    });

    test('a remote HTTP proxy is written back verbatim', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
            bypass: '*.internal;<local>',
          ).toJson(),
        ),
      );
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(stops, 0);
      expect(starts, 0, reason: 'the plugin cannot express a remote server');
      expect(written, hasLength(1));
      expect(written.single.enable, 1);
      expect(written.single.server, 'proxy.corp.example:8080');
      expect(written.single.bypass, '*.internal;<local>');
      expect(await readState(), isNull);
    });

    test('a PAC url is written back instead of being dropped', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 0,
            server: '',
            autoConfigUrl: 'http://wpad.example/wpad.dat',
          ).toJson(),
        ),
      );
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoredPartial,
        reason: 'the PAC url is restored, but the flags that enable it are not '
            'part of the snapshot — that must not be reported as a full restore',
      );
      expect(
        stops,
        0,
        reason: 'stopProxy only flips the flags and would lose the PAC url',
      );
      expect(written, hasLength(1));
      expect(written.single.autoConfigUrl, 'http://wpad.example/wpad.dat');
    });

    test('an external change during a remote-proxy session wins', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
          ).toJson(),
        ),
      );
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:9999');

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.externalChange,
      );
      expect(written, isEmpty, reason: 'never overwrite a newer third-party value');
      expect(stops, 0);
    });

    test('a failed write keeps the claim for the next launch', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
          ).toJson(),
        ),
      );
      current = ours;
      writeResult = false;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoreFailed,
      );
      expect(await readState(), isNotNull, reason: 'retry on the next launch');
    });

    test('a missing snapshot writes nothing at all', () async {
      await writeState(stateWith());
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.noSnapshot,
      );
      expect(stops, 0, reason: 'fail closed: no guessing at a configuration');
      expect(starts, 0);
      expect(written, isEmpty);
    });

    test('an unusable snapshot writes nothing at all', () async {
      await writeState(stateWith(snapshot: {'enable': 'not-an-int'}));
      current = ours;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.noSnapshot,
      );
      expect(stops, 0);
      expect(written, isEmpty);
    });

    test('crash recovery restores a recorded remote proxy', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
          ).toJson(),
        ),
      );
      current = ours;

      await ProxyOwnership.reconcileOnStart();

      expect(written, hasLength(1));
      expect(written.single.server, 'proxy.corp.example:8080');
      expect(await readState(), isNull);
    });

    test('crash recovery with a missing snapshot leaves the system alone',
        () async {
      await writeState(stateWith());
      current = ours;

      await ProxyOwnership.reconcileOnStart();

      expect(stops, 0);
      expect(written, isEmpty);
      expect(await readState(), isNull);
    });

    test('crash recovery never clears a proxy it does not own', () async {
      await writeState(
        stateWith(
          snapshot: const ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
          ).toJson(),
        ),
      );
      // The user reconfigured their proxy after the crash.
      current = const ProxySnapshot(enable: 0, server: '');

      await ProxyOwnership.reconcileOnStart();

      expect(stops, 0);
      expect(written, isEmpty);
      expect(await readState(), isNull, reason: 'the stale claim is dropped');
    });
  });

  // ── T-P7 ───────────────────────────────────────────────────────────────────
  // P10-P0-B round 2 — the write is not the proof, and a failed undo must not
  // erase the evidence.
  group('T-P7 — restore verification and failure safety', () {
    const ours = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');
    const remote = ProxySnapshot(
      enable: 1,
      server: 'proxy.corp.example:8080',
      bypass: '<local>;*.ours',
    );

    Map<String, Object?> stateWith(ProxySnapshot snapshot) => {
      'schema': 1,
      'owned': true,
      'pending': false,
      'pid': 1,
      'snapshot': snapshot.toJson(),
      'applied': ours.toJson(),
    };

    test('a registry write that fails keeps the claim', () async {
      await writeState(stateWith(remote));
      current = ours;
      writeResult = false;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoreFailed,
      );
      expect(await readState(), isNotNull, reason: 'retry on the next launch');
    });

    test('a partial registry write is caught by the read-back', () async {
      await writeState(stateWith(remote));
      current = ours;
      // The API reports success but only ProxyEnable actually changed.
      ProxyOwnership.writeSnapshotForTest = (s) async {
        written.add(s);
        current = ProxySnapshot(enable: s.enable, server: '', bypass: s.bypass);
        return true;
      };

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoreFailed,
      );
      expect(await readState(), isNotNull);
    });

    test('a failed WinINET notification is not treated as restored', () async {
      await writeState(stateWith(remote));
      current = ours;
      refreshResult = false;

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoreFailed,
        reason: 'a value written but never announced has not taken effect',
      );
      expect(await readState(), isNotNull);
    });

    test('a local restore that does not land is caught', () async {
      await writeState(
        stateWith(
          const ProxySnapshot(enable: 1, server: '127.0.0.1:1080'),
        ),
      );
      current = ours;
      startLands = false; // startProxy says yes, the system says no

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restoreFailed,
      );
      expect(await readState(), isNotNull);
    });

    test('a third-party ProxyOverride rewrite survives our restore', () async {
      await writeState(stateWith(remote));
      // Same routing as ours, but someone edited the exclusion list.
      current = const ProxySnapshot(
        enable: 1,
        server: '127.0.0.1:7890',
        bypass: '<local>;*.theirs',
      );

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(written, hasLength(1));
      expect(
        written.single.bypass,
        '<local>;*.theirs',
        reason: 'their exclusion rules must not be replaced by ours',
      );
      expect(written.single.server, 'proxy.corp.example:8080');
    });

    test('no ownership record means no proxy write at all', () async {
      // A file where the state directory should be makes persistence fail.
      final blocker = File('${tmp.path}${Platform.pathSeparator}blocker');
      await blocker.writeAsString('x');
      ProxyOwnership.statePathForTest =
          '${blocker.path}${Platform.pathSeparator}state.json';
      current = const ProxySnapshot(enable: 0, server: '');

      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isFalse);
      expect(
        starts,
        0,
        reason: 'a proxy we cannot undo must never be written',
      );
      expect(stops, 0);
    });

    test('a failed rollback keeps the record instead of clearing it', () async {
      // The plugin writes and then reports failure, so the system really does
      // hold our value — and the rollback that follows cannot undo it.
      ProxyOwnership.startForTest = (port, bypass) async {
        starts++;
        current = ProxySnapshot(
          enable: 1,
          server: '127.0.0.1:$port',
          bypass: '<local>',
        );
        return false;
      };
      current = const ProxySnapshot(enable: 0, server: '');
      stopResult = false;

      final ok = await ProxyOwnership.apply(port: 7890, bypass: const []);

      expect(ok, isFalse);
      expect(stops, 1, reason: 'the rollback really tried');
      expect(
        await readState(),
        isNotNull,
        reason: 'the snapshot is the only way back; never clear it on failure',
      );
      expect(current?.enable, 1, reason: 'our value is still on the system');
    });
  });

  // ── T-P8 ───────────────────────────────────────────────────────────────────
  // P10-P0-A2 — a `pending` record used to be ignored by reconcileOnStart, so a
  // failed rollback left a file that nothing ever acted on. These assert the
  // resulting system state, not merely that the file was written.
  group('T-P8 — interrupted apply recovery', () {
    const direct = ProxySnapshot(enable: 0, server: '', bypass: '<local>');
    const intended = ProxySnapshot(enable: 1, server: '127.0.0.1:7890');

    Map<String, Object?> pendingState({
      Object? snapshot = direct,
      Object? target = intended,
    }) => {
      'schema': 2,
      'owned': false,
      'pending': true,
      'pid': 1,
      'snapshot': snapshot is ProxySnapshot ? snapshot.toJson() : snapshot,
      'applied': null,
      'intended': target is ProxySnapshot ? target.toJson() : target,
    };

    test('an interrupted apply is recovered on the next launch', () async {
      await writeState(pendingState());
      current = intended; // the write landed, then the process died

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.restored);
      expect(current?.enable, 0, reason: 'the system must be back on direct');
      expect(stops, 1);
      expect(await readState(), isNull, reason: 'the record is resolved');
    });

    test('a pending record whose write never landed is just cleared', () async {
      await writeState(pendingState());
      current = direct; // nothing of ours is on the system

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.nothingToDo);
      expect(stops, 0, reason: 'nothing to undo, so nothing is called');
      expect(starts, 0);
      expect(await readState(), isNull);
    });

    test('a pending record overridden by a third party is left alone', () async {
      await writeState(pendingState());
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:9999');

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.externalChange);
      expect(stops, 0, reason: 'their value wins');
      expect(starts, 0);
      expect(written, isEmpty);
      expect(current?.server, '127.0.0.1:9999');
      expect(await readState(), isNull);
    });

    test('a pending record with no intended target fails closed', () async {
      await writeState(pendingState(target: null));
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:7890');

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.ownershipUnknown);
      expect(stops, 0, reason: 'cannot prove it is ours, so do not touch it');
      expect(starts, 0);
      expect(written, isEmpty);
      expect(current?.enable, 1, reason: 'system left exactly as found');
    });

    test('a pending record with no snapshot writes nothing', () async {
      await writeState(pendingState(snapshot: null));
      current = intended;

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.noSnapshot);
      expect(stops, 0);
      expect(written, isEmpty);
      expect(current?.enable, 1);
    });

    test('a failed rollback is resolved on the next launch', () async {
      // The write lands, the plugin reports failure, and the rollback cannot
      // undo it — so the pending record survives with the system still holding
      // our value.
      ProxyOwnership.startForTest = (port, bypass) async {
        starts++;
        current = ProxySnapshot(
          enable: 1,
          server: '127.0.0.1:$port',
          bypass: '<local>',
        );
        return false;
      };
      current = direct;
      stopResult = false;

      expect(
        await ProxyOwnership.apply(port: 7890, bypass: const []),
        isFalse,
      );
      final kept = await readState();
      expect(kept, isNotNull, reason: 'the record is the only way back');
      expect(kept?['intended'], isNotNull, reason: 'target recorded up front');

      // Next launch: the system still holds our value, so it is recoverable.
      stopResult = true;
      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.restored);
      expect(current?.enable, 0, reason: 'back to the pre-takeover value');
      expect(await readState(), isNull);
    });

    test('a corrupt state file is never read as ownership', () async {
      await File(statePath).writeAsString('{"owned": true, "pend');
      current = intended;

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.notOwned);
      expect(stops, 0);
      expect(current?.enable, 1, reason: 'unreadable state is not a claim');
    });

    test('a state file that is not an object is ignored', () async {
      await File(statePath).writeAsString('[]');
      current = intended;

      expect(
        await ProxyOwnership.reconcileOnStart(),
        ProxyReleaseOutcome.notOwned,
      );
      expect(stops, 0);
    });

    test('a successful apply leaves no staging file behind', () async {
      current = direct;

      expect(await ProxyOwnership.apply(port: 7890, bypass: const []), isTrue);

      final staging = File('$statePath.tmp');
      expect(await staging.exists(), isFalse);
      expect(await File(statePath).exists(), isTrue);
    });
  });

  // ── T-P9 ───────────────────────────────────────────────────────────────────
  // P10-P0-A3 — repeat takeovers, rollback ownership, bypass normalisation.
  group('T-P9 — repeat apply, rollback ownership, bypass consistency', () {
    Map<String, Object?> record({
      bool owned = false,
      bool pending = false,
      ProxySnapshot? snapshot,
      ProxySnapshot? applied,
      ProxySnapshot? intended,
    }) => {
      'schema': 2,
      'owned': owned,
      'pending': pending,
      'pid': 1,
      'snapshot': snapshot?.toJson(),
      'applied': applied?.toJson(),
      'intended': intended?.toJson(),
    };

    test('applying the same port twice is idempotent', () async {
      current = const ProxySnapshot(
        enable: 1,
        server: 'proxy.corp.example:8080',
        bypass: '<local>',
      );

      expect(await ProxyOwnership.apply(port: 7890, bypass: const []), isTrue);
      final afterFirst = await readState();
      expect(starts, 1);

      expect(await ProxyOwnership.apply(port: 7890, bypass: const []), isTrue);

      expect(starts, 1, reason: 'the second call must not write again');
      expect(stops, 0);
      final afterSecond = await readState();
      expect(
        afterSecond?['snapshot'],
        afterFirst?['snapshot'],
        reason: 'the original third-party value must survive a repeat apply',
      );
    });

    test('changing the port keeps the first snapshot', () async {
      current = const ProxySnapshot(
        enable: 1,
        server: 'proxy.corp.example:8080',
        bypass: '<local>',
      );

      expect(await ProxyOwnership.apply(port: 7890, bypass: const []), isTrue);
      expect(await ProxyOwnership.apply(port: 7891, bypass: const []), isTrue);

      expect(starts, 2, reason: 'the retarget really writes');
      final state = await readState();
      expect(
        (state?['snapshot'] as Map)['server'],
        'proxy.corp.example:8080',
        reason: 'nothing third-party happened, so the first snapshot stays',
      );
      expect((state?['applied'] as Map)['server'], '127.0.0.1:7891');
    });

    test('a third-party change during apply is not overwritten by the rollback',
        () async {
      current = const ProxySnapshot(enable: 0, server: '');
      // The plugin writes, reports failure, and by rollback time someone else
      // owns the proxy.
      ProxyOwnership.startForTest = (port, bypass) async {
        starts++;
        current = const ProxySnapshot(enable: 1, server: '127.0.0.1:9999');
        return false;
      };

      expect(await ProxyOwnership.apply(port: 7890, bypass: const []), isFalse);

      expect(stops, 0, reason: 'the rollback must not overwrite a third party');
      expect(current?.server, '127.0.0.1:9999');
      expect(await readState(), isNull, reason: 'the claim is dropped, not used');
    });

    test('an owned record without applied fails closed', () async {
      await writeState(
        record(
          owned: true,
          snapshot: ProxySnapshot(
            enable: 1,
            server: 'proxy.corp.example:8080',
          ),
        ),
      );
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:7890');

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.ownershipUnknown,
      );
      expect(stops, 0);
      expect(starts, 0);
      expect(written, isEmpty);
      expect(current?.server, '127.0.0.1:7890');
      expect(await readState(), isNotNull, reason: 'the evidence is kept');
    });

    test('pending recovery restores the third-party proxy and its bypass',
        () async {
      await writeState(
        record(
          pending: true,
          snapshot: ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:1080',
            bypass: '<local>;*.corp',
          ),
          intended: ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:7890',
            bypass: '<local>',
          ),
        ),
      );
      current = const ProxySnapshot(
        enable: 1,
        server: '127.0.0.1:7890',
        bypass: '<local>',
      );

      final outcome = await ProxyOwnership.reconcileOnStart();

      expect(outcome, ProxyReleaseOutcome.restored);
      expect(startPorts, [1080], reason: 'their proxy comes back');
      expect(
        startBypass.single,
        ['*.corp'],
        reason: 'their exclusions come back too, without a doubled <local>',
      );
      expect(current?.server, '127.0.0.1:1080');
    });

    test('a third party that only changed the bypass keeps it', () async {
      await writeState(
        record(
          owned: true,
          snapshot: ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:1080',
            bypass: '<local>;*.ours',
          ),
          applied: ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:7890',
            bypass: '<local>',
          ),
        ),
      );
      current = const ProxySnapshot(
        enable: 1,
        server: '127.0.0.1:7890',
        bypass: '<local>;*.theirs',
      );

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );
      expect(startPorts, [1080]);
      expect(
        startBypass.single,
        ['*.theirs'],
        reason: 'their exclusion list wins over the one we recorded',
      );
    });
  });

  // ── T-P10 ──────────────────────────────────────────────────────────────────
  // P10-P0-A4 — a port switch is a transaction. Failing it must not lose the
  // ownership we already had, and must not read our own previous port as a
  // third-party takeover.
  group('T-P10 — retarget recovery', () {
    final thirdParty = ProxySnapshot(
      enable: 1,
      server: 'proxy.corp.example:8080',
      bypass: '<local>;*.corp',
    );
    final ours7890 = ProxySnapshot(
      enable: 1,
      server: '127.0.0.1:7890',
      bypass: '<local>',
    );
    final target7891 = ProxySnapshot(
      enable: 1,
      server: '127.0.0.1:7891',
      bypass: '<local>',
    );

    Map<String, Object?> pendingSwitch() => {
      'schema': 2,
      'owned': false,
      'pending': true,
      'pid': 1,
      'snapshot': thirdParty.toJson(),
      'applied': ours7890.toJson(),
      'intended': target7891.toJson(),
    };

    /// Takes the proxy over at 7890, starting from the third-party value.
    Future<void> takeOver() async {
      current = thirdParty;
      expect(
        await ProxyOwnership.apply(port: 7890, bypass: const []),
        isTrue,
      );
      expect(current?.server, '127.0.0.1:7890');
    }

    test('7890 -> 7891 succeeds and keeps the original snapshot', () async {
      await takeOver();
      expect(starts, 1);

      expect(await ProxyOwnership.apply(port: 7891, bypass: const []), isTrue);

      expect(starts, 2);
      expect(current?.server, '127.0.0.1:7891');
      expect(stops, 0, reason: 'a successful switch never rolls back');
      final state = await readState();
      expect(state?['owned'], isTrue);
      expect((state?['snapshot'] as Map)['server'], 'proxy.corp.example:8080');
      expect((state?['applied'] as Map)['server'], '127.0.0.1:7891');
    });

    test('7890 -> 7891 that fails keeps ownership of 7890', () async {
      var call = 0;
      ProxyOwnership.startForTest = (port, bypass) async {
        starts++;
        call++;
        if (call == 1) {
          current = ProxySnapshot(
            enable: 1,
            server: '127.0.0.1:$port',
            bypass: '<local>',
          );
          return true;
        }
        return false; // the switch never lands
      };

      await takeOver();

      expect(
        await ProxyOwnership.apply(port: 7891, bypass: const []),
        isFalse,
      );

      expect(current?.server, '127.0.0.1:7890', reason: 'the system never moved');
      expect(stops, 0, reason: 'no proxy write during the rollback');
      final state = await readState();
      expect(state?['owned'], isTrue, reason: 'ownership of 7890 is restored');
      expect((state?['applied'] as Map)['server'], '127.0.0.1:7890');
      expect((state?['snapshot'] as Map)['server'], 'proxy.corp.example:8080');
    });

    test('a crash right after saving pending keeps ownership and snapshot',
        () async {
      await writeState(pendingSwitch());
      current = ours7890;

      expect(
        await ProxyOwnership.reconcileOnStart(),
        ProxyReleaseOutcome.nothingToDo,
      );

      expect(stops, 0, reason: 'nothing to undo');
      expect(starts, 0);
      expect(current?.server, '127.0.0.1:7890');
      final state = await readState();
      expect(state?['owned'], isTrue);
      expect((state?['applied'] as Map)['server'], '127.0.0.1:7890');
      expect((state?['snapshot'] as Map)['server'], 'proxy.corp.example:8080');
    });

    test('a partially applied switch keeps the record instead of guessing',
        () async {
      await writeState(pendingSwitch());
      // The flags were flipped but the proxy is off, on the new port.
      current = const ProxySnapshot(enable: 0, server: '127.0.0.1:7891');

      expect(
        await ProxyOwnership.reconcileOnStart(),
        ProxyReleaseOutcome.ownershipUnknown,
      );

      expect(stops, 0);
      expect(written, isEmpty);
      expect(current?.enable, 0, reason: 'the system is left exactly as found');
      expect(await readState(), isNotNull, reason: 'the evidence is kept');
    });

    test('a third party taking over during the switch wins', () async {
      await writeState(pendingSwitch());
      current = const ProxySnapshot(enable: 1, server: '127.0.0.1:9999');

      expect(
        await ProxyOwnership.reconcileOnStart(),
        ProxyReleaseOutcome.externalChange,
      );

      expect(stops, 0);
      expect(starts, 0);
      expect(written, isEmpty);
      expect(current?.server, '127.0.0.1:9999');
      expect(await readState(), isNull);
    });

    test('release after a successful switch restores the original proxy',
        () async {
      await takeOver();
      expect(await ProxyOwnership.apply(port: 7891, bypass: const []), isTrue);

      expect(
        await ProxyOwnership.release(reason: 'exit'),
        ProxyReleaseOutcome.restored,
      );

      expect(written, hasLength(1), reason: 'exactly one restore write');
      expect(written.single.server, 'proxy.corp.example:8080');
      expect(current?.server, 'proxy.corp.example:8080');
      expect(await readState(), isNull);
    });

    test('the same port with a different bypass is not a no-op', () async {
      await takeOver();
      expect(starts, 1);
      final before = await readState();

      expect(
        await ProxyOwnership.apply(port: 7890, bypass: const ['*.new']),
        isTrue,
      );

      expect(starts, 2, reason: 'a different exclusion list has to be written');
      final after = await readState();
      expect((after?['applied'] as Map)['bypass'], '<local>;*.new');
      expect(
        after?['snapshot'],
        before?['snapshot'],
        reason: 'the original third-party value is untouched',
      );
      expect(current?.bypass, '<local>;*.new');
    });
  });
}
