import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:win32_registry/win32_registry.dart';

/// The WinINET values that decide where traffic actually goes.
///
/// [bypass] is carried for the snapshot but deliberately excluded from
/// [sameRouting]: `stopProxy()` rewrites the flags without touching the bypass
/// list, so comparing it would report a spurious "someone else changed this".
class ProxySnapshot {
  const ProxySnapshot({
    this.enable = 0,
    this.server = '',
    this.bypass = '',
    this.autoConfigUrl,
  });

  final int enable;
  final String server;
  final String bypass;
  final String? autoConfigUrl;

  bool get isOn => enable == 1;

  /// Same routing decision: on/off, target server, PAC url.
  bool sameRouting(ProxySnapshot other) =>
      enable == other.enable &&
      server == other.server &&
      (autoConfigUrl ?? '') == (other.autoConfigUrl ?? '');

  Map<String, Object?> toJson() => {
    'enable': enable,
    'server': server,
    'bypass': bypass,
    'autoConfigUrl': autoConfigUrl,
  };

  static ProxySnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final enable = raw['enable'];
    final server = raw['server'];
    if (enable is! int || server is! String) return null;
    final auto = raw['autoConfigUrl'];
    return ProxySnapshot(
      enable: enable,
      server: server,
      bypass: raw['bypass'] is String ? raw['bypass'] as String : '',
      autoConfigUrl: auto is String ? auto : null,
    );
  }
}

/// What the persisted file holds.
class ProxyOwnershipState {
  const ProxyOwnershipState({
    this.owned = false,
    this.pending = false,
    this.snapshot,
    this.applied,
    this.intended,
    this.pid = 0,
  });

  /// True only after a write was read back and confirmed.
  final bool owned;

  /// A write was started but never confirmed. Never treated as ownership.
  final bool pending;

  /// What the system looked like before we touched it.
  final ProxySnapshot? snapshot;

  /// What we confirmed we had applied.
  ///
  /// P10-P0-A4 — in an **owned** record this is the value the system holds now.
  /// In a **pending** record it is the value we owned *before* the switch
  /// started (null on a first takeover). Without it, a failed port change left a
  /// record that could not tell "the system still holds our previous port" from
  /// "a third party took over", and the only recovery evidence was discarded.
  final ProxySnapshot? applied;

  /// What we were **about to** write, recorded before the write happens.
  ///
  /// P10-P0-A2 — a `pending` record used to carry only the snapshot, so after a
  /// crash mid-apply there was no way to tell "the system still holds our value"
  /// from "someone else wrote something". Without that distinction the record
  /// could never be resolved safely, and `reconcileOnStart` ignored it entirely.
  final ProxySnapshot? intended;

  final int pid;

  Map<String, Object?> toJson() => {
    'schema': 2,
    'owned': owned,
    'pending': pending,
    'pid': pid,
    'snapshot': snapshot?.toJson(),
    'applied': applied?.toJson(),
    'intended': intended?.toJson(),
  };

  static ProxyOwnershipState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return ProxyOwnershipState(
      owned: raw['owned'] == true,
      pending: raw['pending'] == true,
      pid: raw['pid'] is int ? raw['pid'] as int : 0,
      snapshot: ProxySnapshot.fromJson(raw['snapshot']),
      applied: ProxySnapshot.fromJson(raw['applied']),
      // Absent in schema 1 records; a pending record without it stays
      // unresolvable on purpose (see reconcileOnStart).
      intended: ProxySnapshot.fromJson(raw['intended']),
    );
  }
}

enum ProxyReleaseOutcome {
  /// We owned it, the system still held our value, and it was restored.
  restored,

  /// We never owned it — nothing was called.
  notOwned,

  /// Someone else changed the proxy while we held it. Left untouched.
  externalChange,

  /// The current state could not be read. Nothing was called.
  readFailed,

  /// We owned it, but the recorded snapshot was missing or unusable. Fail
  /// closed: nothing was written, because a guessed configuration is worse than
  /// a wrong one the user can see and fix.
  noSnapshot,

  /// We owned it and tried to restore, but the write did not land. The claim is
  /// kept so the next launch can try again.
  restoreFailed,

  /// A `pending` record was resolved without touching anything: the system
  /// already held the pre-takeover value, so there was nothing to undo.
  nothingToDo,

  /// A `pending` record exists but carries no record of what we were about to
  /// write, so ownership cannot be established. Fail closed: the system is left
  /// alone and the record is dropped with a log entry.
  ownershipUnknown,

  /// The pre-existing value was restored, but not completely: a PAC url was
  /// written back while the WinINET connection flags that actually enable it
  /// (`PROXY_TYPE_AUTO_PROXY_URL` / `PROXY_TYPE_AUTO_DETECT`) could not be
  /// captured or restored. Reported separately so nothing claims a full restore.
  restoredPartial,
}

/// How a restore actually reached the system.
///
/// The three write paths are not interchangeable, and collapsing them is what
/// caused P10-P0-B: every restore used to take the [direct] path, so a user who
/// had a corporate proxy or a PAC file before Fluxora took over got silently
/// disconnected from it.
enum ProxyRestoreOutcome {
  /// The snapshot said "direct": the plugin flips the flags and sweeps RAS
  /// entries, which is the only path that covers dial-up/VPN connections.
  direct,

  /// The snapshot was a loopback proxy the plugin can reproduce. Restored
  /// through the plugin so WinINET is notified.
  local,

  /// The snapshot was a remote server or a PAC url — neither is expressible
  /// through the plugin's API — so the recorded values are written back to the
  /// registry verbatim.
  written,

  /// A PAC url was written back, but the rest of the PAC configuration could
  /// not be.
  ///
  /// P10-P0-C — the four fields this class snapshots (`ProxyEnable`,
  /// `ProxyServer`, `ProxyOverride`, `AutoConfigURL`) cannot describe the WinINET
  /// connection flags. `PROXY_TYPE_AUTO_PROXY_URL` (0x4) and
  /// `PROXY_TYPE_AUTO_DETECT` (0x8) live in the per-connection
  /// `Connections\DefaultConnectionSettings` binary blob, not in these values.
  /// So an `AutoConfigURL` written back may leave the PAC *configured but not
  /// enabled*, and "automatically detect settings" is never restored at all.
  ///
  /// Reported separately so a caller can say "partially restored" instead of
  /// claiming a full restore.
  writtenPartial,

  /// No usable snapshot. Nothing was written.
  noSnapshot,

  /// A write was attempted and failed.
  failed,
}

/// B3 — who owns the Windows system proxy.
///
/// Before this, `handleExit` called `stopProxy()` unconditionally and
/// `ProxyManager` did the same on the **first frame**, so merely launching
/// Fluxora forced WinINET to direct-connect and clobbered any proxy another
/// program had set. Ownership is now recorded, verified by read-back, and
/// released only when the system still holds exactly what we wrote.
class ProxyOwnership {
  ProxyOwnership._();

  /// Test seams. Production uses the registry and the real plugin.
  static ProxySnapshot? Function()? readForTest;
  static Future<bool?> Function(int port, List<String> bypass)? startForTest;
  static Future<bool?> Function()? stopForTest;

  /// Test seam for the verbatim registry writer (the remote-server / PAC path).
  static Future<bool> Function(ProxySnapshot snapshot)? writeSnapshotForTest;

  /// Test seam for the WinINET notification.
  static bool Function()? refreshWinInetForTest;

  static String? statePathForTest;

  /// How long the WinINET write is given to land before it is read back.
  /// Same value `controller.dart` already uses for proxy changes.
  @visibleForTesting
  static Duration settle = const Duration(milliseconds: 400);

  static ProxySnapshot? read() {
    final override = readForTest;
    if (override != null) return override();
    return _readRegistry();
  }

  static ProxySnapshot? _readRegistry() {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.currentUser,
        path: r'Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        desiredAccessRights: AccessRights.readOnly,
      );
      return ProxySnapshot(
        enable: key.getIntValue('ProxyEnable') ?? 0,
        server: key.getStringValue('ProxyServer') ?? '',
        bypass: key.getStringValue('ProxyOverride') ?? '',
        autoConfigUrl: key.getStringValue('AutoConfigURL'),
      );
    } catch (e) {
      // Fail closed: no snapshot means we must not write anything, because we
      // would have no way to tell our value apart from someone else's later.
      commonPrint.log('ProxyOwnership: failed to read system proxy: $e');
      return null;
    } finally {
      key?.close();
    }
  }

  static Future<String> _statePath() async =>
      statePathForTest ??
      '${await appPath.homeDirPath}${Platform.pathSeparator}proxy_ownership.json';

  static Future<ProxyOwnershipState> load() async {
    try {
      final file = File(await _statePath());
      if (!await file.exists()) return const ProxyOwnershipState();
      final decoded = json.decode(await file.readAsString());
      // A corrupt file must never be read as "we own it".
      return ProxyOwnershipState.fromJson(decoded) ??
          const ProxyOwnershipState();
    } catch (e) {
      commonPrint.log('ProxyOwnership: unreadable state, assuming not owned: $e');
      return const ProxyOwnershipState();
    }
  }

  /// Persists the ownership record. Returns `false` when it could not be
  /// written — P10-P0-B: a caller must not touch the system proxy without a
  /// record of how to undo it.
  ///
  /// P10-P0-A2 — written to a sibling `.tmp` and renamed into place. A plain
  /// `writeAsString` truncates first, so a crash or a full disk between the
  /// truncate and the flush leaves an empty file where the only recovery record
  /// used to be. The rename is atomic, so the previous record survives any
  /// failure of the new one.
  static Future<bool> _save(ProxyOwnershipState state) async {
    try {
      final path = await _statePath();
      final file = File(path);
      await file.parent.create(recursive: true);
      final staging = File('$path.tmp');
      await staging.writeAsString(json.encode(state.toJson()), flush: true);
      await staging.rename(path);
      return true;
    } catch (e) {
      commonPrint.log('ProxyOwnership: failed to persist state: $e');
      return false;
    }
  }

  static Future<void> _clear() async {
    try {
      final file = File(await _statePath());
      if (await file.exists()) await file.delete();
    } catch (e) {
      commonPrint.log('ProxyOwnership: failed to clear state: $e');
    }
  }

  /// Announces a registry-level proxy change to WinINET.
  ///
  /// P10-P0-B — the plugin does this itself through `InternetSetOption`, but the
  /// verbatim writer bypasses the plugin entirely, so a remote server or a PAC
  /// url written back by us would sit in the registry unread by anything that
  /// had already cached its LAN settings.
  ///
  /// Returns `false` when the notification could not be delivered; the caller
  /// treats that as "the restore did not take effect" rather than success.
  static bool _refreshWinInet() {
    final override = refreshWinInetForTest;
    if (override != null) return override();
    if (!Platform.isWindows) return false;

    try {
      final wininet = DynamicLibrary.open('wininet.dll');
      final setOption = wininet.lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
          int Function(Pointer<Void>, int, Pointer<Void>, int)>(
        'InternetSetOptionW',
      );
      const settingsChanged = 39; // INTERNET_OPTION_SETTINGS_CHANGED
      const refresh = 37; // INTERNET_OPTION_REFRESH
      final changed = setOption(nullptr, settingsChanged, nullptr, 0);
      final refreshed = setOption(nullptr, refresh, nullptr, 0);
      return changed != 0 && refreshed != 0;
    } catch (e) {
      commonPrint.log('ProxyOwnership: WinINET refresh failed: $e');
      return false;
    }
  }

  static Future<bool?> _start(int port, List<String> bypass) {
    final override = startForTest;
    if (override != null) return override(port, bypass);
    final plugin = proxy;
    if (plugin == null) return Future<bool?>.value(null);
    return plugin.startProxy(port, bypass);
  }

  static Future<bool?> _stop() {
    final override = stopForTest;
    if (override != null) return override();
    final plugin = proxy;
    if (plugin == null) return Future<bool?>.value(null);
    return plugin.stopProxy();
  }

  /// Writes a recorded snapshot back verbatim, then announces it to WinINET.
  ///
  /// P10-P0-B: the plugin can only express `127.0.0.1:<port>` or direct, so a
  /// remote HTTP proxy (`proxy.corp.example:8080`) and an `AutoConfigURL` (PAC)
  /// have no plugin representation at all. Before this, both were "restored" by
  /// going direct — silently discarding the user's proxy.
  ///
  /// Returns `false` when either the registry write or the WinINET notification
  /// failed: a value that was written but never announced has not taken effect.
  static Future<bool> _writeSnapshot(ProxySnapshot snapshot) async {
    final write = writeSnapshotForTest ?? _writeSnapshotToRegistry;
    if (!await write(snapshot)) return false;
    return _refreshWinInet();
  }

  static Future<bool> _writeSnapshotToRegistry(ProxySnapshot s) async {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.currentUser,
        path: r'Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        desiredAccessRights: AccessRights.allAccess,
      );

      key.createValue(RegistryValue.int32('ProxyEnable', s.enable));

      if (s.server.isEmpty) {
        key.deleteValue('ProxyServer');
      } else {
        key.createValue(RegistryValue.string('ProxyServer', s.server));
      }

      if (s.bypass.isEmpty) {
        key.deleteValue('ProxyOverride');
      } else {
        key.createValue(RegistryValue.string('ProxyOverride', s.bypass));
      }

      final pac = s.autoConfigUrl;
      if (pac == null || pac.isEmpty) {
        key.deleteValue('AutoConfigURL');
      } else {
        key.createValue(RegistryValue.string('AutoConfigURL', pac));
      }

      return true;
    } catch (e) {
      commonPrint.log('ProxyOwnership: failed to write the snapshot back: $e');
      return false;
    } finally {
      key?.close();
    }
  }

  /// Points the system proxy at `127.0.0.1:<port>`, recording enough state to
  /// undo it — but only after a read-back proves the write landed.
  ///
  /// P10-P0-A3 — a repeat call is no longer treated as a fresh takeover.
  /// Before this, calling `apply` twice overwrote `snapshot` with whatever was
  /// current at that moment — which is *our own proxy* — so the third-party
  /// value we were supposed to restore was destroyed on the second call.
  static Future<bool> apply({
    required int port,
    required List<String> bypass,
    bool allowRetakeover = false,
  }) async {
    final before = read();
    if (before == null) return false; // cannot undo what we cannot measure

    // An unresolved `pending` record means a previous write is in an unknown
    // state. Overwriting it would replace the only snapshot of what the system
    // looked like before we ever touched it, so this is a fail-closed no-op
    // until `reconcileOnStart` resolves it on the next launch.
    final existing = await load();
    if (existing.pending) {
      commonPrint.log(
        'ProxyOwnership: unresolved pending record; refusing to write again '
        'until the next reconcile',
      );
      return false;
    }

    final cleanBypass = _cleanBypassParts(bypass);
    final target = '127.0.0.1:$port';

    // Recorded **before** the write so a crash mid-apply still leaves enough
    // evidence to tell "ours" from "someone else's" on the next launch.
    final intended = ProxySnapshot(
      enable: 1,
      server: target,
      bypass: _normalizedBypass(cleanBypass),
    );

    // Which value a later restore has to bring back.
    var snapshotForRecord = before;

    // The value we owned before this call, when the call is a port switch. It
    // goes into the pending record so a failed switch can be told apart from a
    // third-party takeover.
    ProxySnapshot? previousApplied;

    if (existing.owned) {
      final applied = existing.applied;
      if (applied == null) {
        // On record as owning it, but the record does not say what we wrote.
        // Any write now could destroy a third party's value with no way back.
        commonPrint.log(
          'ProxyOwnership: owned record has no applied value; refusing to '
          're-apply',
        );
        return false;
      }

      final stillOurs = before.sameRouting(applied);

      if (!stillOurs) {
        // P10-P0-A4 — the system no longer holds our value. Taking over here
        // would silently replace whatever is there now, so an automatic apply
        // fails closed. Only a caller that has explicitly decided to take the
        // proxy back may re-snapshot.
        if (!allowRetakeover) {
          commonPrint.log(
            'ProxyOwnership: owned record, but the system now holds '
            '${before.enable}/${before.server}; refusing to take over without '
            'an explicit retake',
          );
          return false;
        }
        commonPrint.log(
          'ProxyOwnership: explicit retake; re-snapshotting '
          '${before.enable}/${before.server}',
        );
        snapshotForRecord = before;
      } else {
        // Same target *and* same bypass is the only truly idempotent case: a
        // different exclusion list still has to be written.
        final sameRequest =
            applied.server == target && applied.bypass == intended.bypass;
        if (sameRequest) {
          commonPrint.log(
            'ProxyOwnership: already applied to $target; leaving it as is',
          );
          return true;
        }

        // Port switch (or a bypass-only change) while we still hold the proxy.
        // The FIRST takeover snapshot stays authoritative, and the value we own
        // right now is recorded so a failed switch does not look like a
        // third-party takeover.
        snapshotForRecord = existing.snapshot ?? before;
        previousApplied = applied;
        commonPrint.log(
          'ProxyOwnership: retargeting ${applied.server} -> $target '
          '(bypass ${applied.bypass} -> ${intended.bypass}); keeping the '
          'original snapshot',
        );
      }
    }

    // P10-P0-B — no unprotected write. If the pending record cannot be
    // persisted, a crash would leave the system proxy pointing at us with no
    // note of what it used to be.
    final pendingSaved = await _save(
      ProxyOwnershipState(
        pending: true,
        snapshot: snapshotForRecord,
        applied: previousApplied,
        intended: intended,
        pid: pid,
      ),
    );
    if (!pendingSaved) {
      commonPrint.log(
        'ProxyOwnership: cannot persist the pending record; not touching the '
        'system proxy',
      );
      return false;
    }

    bool? ok;
    try {
      ok = await _start(port, cleanBypass);
    } catch (e) {
      commonPrint.log('ProxyOwnership: startProxy threw: $e');
      ok = false;
    }
    if (ok != true) {
      await _rollback(
        before,
        intended: intended,
        snapshotForRecord: snapshotForRecord,
        previousApplied: previousApplied,
      );
      return false;
    }

    await Future<void>.delayed(settle);

    final applied = read();
    if (applied == null || applied.enable != 1 || applied.server != target) {
      commonPrint.log(
        'ProxyOwnership: write did not land (read back ${applied?.enable}/'
        '${applied?.server}), rolling back',
      );
      await _rollback(
        before,
        intended: intended,
        snapshotForRecord: snapshotForRecord,
        previousApplied: previousApplied,
      );
      return false;
    }

    final ownedSaved = await _save(
      ProxyOwnershipState(
        owned: true,
        snapshot: snapshotForRecord,
        applied: applied,
        pid: pid,
      ),
    );
    if (!ownedSaved) {
      // We changed the system and cannot record that we own it. Undo now rather
      // than leave an unowned proxy behind.
      commonPrint.log(
        'ProxyOwnership: cannot persist the ownership record; rolling back',
      );
      await _rollback(
        before,
        intended: intended,
        snapshotForRecord: snapshotForRecord,
        previousApplied: previousApplied,
      );
      return false;
    }
    return true;
  }

  /// Undoes a failed `apply`.
  ///
  /// P10-P0-A3 — the rollback proves ownership before writing anything.
  /// P10-P0-A4 — it also has to tell a *failed port switch* from a third-party
  /// takeover. When the switch never landed, the system still holds the value we
  /// owned before it, so the right answer is to put the owned record back —
  /// not to restore the pre-takeover snapshot and not to drop the claim.
  ///
  /// The record is kept whenever the outcome is uncertain, because it is the
  /// only evidence of what the system looked like.
  static Future<void> _rollback(
    ProxySnapshot before, {
    required ProxySnapshot intended,
    required ProxySnapshot snapshotForRecord,
    ProxySnapshot? previousApplied,
  }) async {
    final current = read();
    if (current == null) {
      commonPrint.log(
        'ProxyOwnership: cannot read the proxy during rollback; keeping the '
        'record instead of guessing',
      );
      return;
    }

    // The switch never happened and we still own what we owned before it.
    if (previousApplied != null && current.sameRouting(previousApplied)) {
      final saved = await _save(
        ProxyOwnershipState(
          owned: true,
          snapshot: snapshotForRecord,
          applied: previousApplied,
          pid: pid,
        ),
      );
      if (!saved) {
        commonPrint.log(
          'ProxyOwnership: switch did not happen, but the ownership record '
          'could not be rewritten; keeping the pending record',
        );
        return;
      }
      commonPrint.log(
        'ProxyOwnership: switch to ${intended.server} did not land; still '
        'owning ${previousApplied.server}, original snapshot kept',
      );
      return;
    }

    if (current.sameRouting(before)) {
      // Already back where we started, and we owned nothing before — nothing to
      // write and nothing to claim.
      commonPrint.log(
        'ProxyOwnership: rollback not needed; the system already holds the '
        'pre-takeover value',
      );
      await _clear();
      return;
    }

    if (!current.sameRouting(intended)) {
      // Not ours any more. Someone else's value wins, and their bypass list is
      // preserved by _withPreservedBypass if only that part differs.
      commonPrint.log(
        'ProxyOwnership: rollback skipped; a third party changed the proxy '
        '(${current.enable}/${current.server})',
      );
      await _clear();
      return;
    }

    // The new target did land, but we could not confirm it. End the takeover and
    // give the original value back — only safe because the proxy is still ours.
    final restored = await _restoreSnapshot(
      snapshotForRecord,
      applied: intended,
      current: current,
    );
    if (restored == ProxyRestoreOutcome.failed ||
        restored == ProxyRestoreOutcome.noSnapshot) {
      commonPrint.log(
        'ProxyOwnership: rollback did not land ($restored); keeping the record '
        'so the next launch can retry',
      );
      return;
    }
    await _clear();
  }

  /// Releases the proxy **only** if we own it and the system still holds our
  /// value. Called from the exit path and from `ProxyManager`.
  static Future<ProxyReleaseOutcome> release({required String reason}) async {
    final state = await load();
    if (!state.owned) return ProxyReleaseOutcome.notOwned;

    final current = read();
    if (current == null) {
      // Keep the state: we still believe we own it, we just cannot check now.
      commonPrint.log('ProxyOwnership[$reason]: cannot read current state');
      return ProxyReleaseOutcome.readFailed;
    }

    final applied = state.applied;
    if (applied == null) {
      // P10-P0-A3 — owned but with no record of what we wrote. We cannot prove
      // the current value is ours, so restoring could overwrite a third party.
      // Fail closed and keep the record as evidence.
      commonPrint.log(
        'ProxyOwnership[$reason]: owned record has no applied value; cannot '
        'tell ours from theirs — leaving the proxy alone',
      );
      return ProxyReleaseOutcome.ownershipUnknown;
    }

    if (!current.sameRouting(applied)) {
      // Clash Verge (or anything else) changed it while we held it. Their
      // value wins — we drop our claim and touch nothing.
      commonPrint.log(
        'ProxyOwnership[$reason]: external change detected '
        '(ours ${applied.enable}/${applied.server}, '
        'now ${current.enable}/${current.server}) — leaving it alone',
      );
      await _clear();
      return ProxyReleaseOutcome.externalChange;
    }

    final restore = await _restoreSnapshot(
      state.snapshot,
      applied: state.applied,
      current: current,
    );
    switch (restore) {
      case ProxyRestoreOutcome.direct:
      case ProxyRestoreOutcome.local:
      case ProxyRestoreOutcome.written:
        commonPrint.log(
          'ProxyOwnership[$reason]: restored the pre-existing proxy '
          '(${state.snapshot?.enable}/${state.snapshot?.server}) via $restore',
        );
        await _clear();
        return ProxyReleaseOutcome.restored;
      case ProxyRestoreOutcome.writtenPartial:
        commonPrint.log(
          'ProxyOwnership[$reason]: restored the PAC url only — the WinINET '
          'auto-proxy / auto-detect flags are not part of the snapshot',
        );
        await _clear();
        return ProxyReleaseOutcome.restoredPartial;
      case ProxyRestoreOutcome.noSnapshot:
        // Fail closed: no recorded state means any write would be a guess. The
        // claim is dropped so this is reported once, not on every launch.
        await _clear();
        return ProxyReleaseOutcome.noSnapshot;
      case ProxyRestoreOutcome.failed:
        commonPrint.log(
          'ProxyOwnership[$reason]: restore did not land; keeping the claim',
        );
        return ProxyReleaseOutcome.restoreFailed;
    }
  }

  /// Startup reconciliation.
  ///
  /// P10-P0-A2 — this used to return early unless `owned` was true, which left a
  /// `pending` record from a failed rollback permanently unresolved: the file
  /// survived every launch, and nothing ever acted on it.
  ///
  /// Both states are now handled, and the outcome is returned so the decision is
  /// observable rather than only visible in a log.
  static Future<ProxyReleaseOutcome> reconcileOnStart() async {
    final state = await load();
    if (!state.owned && !state.pending) return ProxyReleaseOutcome.notOwned;

    final current = read();
    if (current == null) {
      commonPrint.log('ProxyOwnership: reconcile skipped, cannot read state');
      return ProxyReleaseOutcome.readFailed;
    }

    if (state.owned) {
      final applied = state.applied;
      if (applied == null) {
        // P10-P0-A3 — same fail-closed rule as release(): without a record of
        // what we wrote, restoring could overwrite someone else's value.
        commonPrint.log(
          'ProxyOwnership: owned record has no applied value; cannot tell ours '
          'from theirs — leaving the proxy alone',
        );
        return ProxyReleaseOutcome.ownershipUnknown;
      }

      if (!current.sameRouting(applied)) {
        commonPrint.log(
          'ProxyOwnership: leftover claim, but the proxy changed while we were '
          'down — dropping the claim without touching it',
        );
        await _clear();
        return ProxyReleaseOutcome.externalChange;
      }

      commonPrint.log(
        'ProxyOwnership: restoring a proxy left behind by a crash',
      );
      final restore = await _restoreSnapshot(
        state.snapshot,
        applied: state.applied,
        current: current,
      );
      if (restore == ProxyRestoreOutcome.failed) {
        commonPrint.log(
          'ProxyOwnership: crash recovery did not land; keeping the claim',
        );
        return ProxyReleaseOutcome.restoreFailed;
      }
      await _clear();
      switch (restore) {
        case ProxyRestoreOutcome.noSnapshot:
          return ProxyReleaseOutcome.noSnapshot;
        case ProxyRestoreOutcome.writtenPartial:
          return ProxyReleaseOutcome.restoredPartial;
        default:
          return ProxyReleaseOutcome.restored;
      }
    }

    // ── pending ──────────────────────────────────────────────────────────────
    // A write was started and never confirmed. Three questions, in order:
    // what did we mean to write, what is there now, and are they the same thing.
    final snapshot = state.snapshot;
    final intended = state.intended;

    if (snapshot == null) {
      // Without a snapshot there is nothing to go back to. Zero writes.
      commonPrint.log(
        'ProxyOwnership: pending record has no snapshot; leaving the system '
        'alone',
      );
      await _clear();
      return ProxyReleaseOutcome.noSnapshot;
    }

    if (intended == null) {
      // A schema-1 record from before `intended` existed. We cannot tell our
      // value from anyone else's, so touching it would be a guess.
      commonPrint.log(
        'ProxyOwnership: pending record does not say what we intended to write; '
        'ownership unknown, leaving the system alone',
      );
      await _clear();
      return ProxyReleaseOutcome.ownershipUnknown;
    }

    if (current.sameRouting(snapshot)) {
      // The write never landed, or it was already undone. Nothing to restore.
      commonPrint.log(
        'ProxyOwnership: pending record is stale — the system already holds the '
        'pre-takeover value',
      );
      await _clear();
      return ProxyReleaseOutcome.nothingToDo;
    }

    // P10-P0-A4 — an interrupted *port switch*. The system still holds the value
    // we owned before it, which is neither the snapshot nor the intended target.
    // Reading that as a third-party change would drop the claim and throw away
    // the only record of what to restore, so put the owned record back instead.
    final previousApplied = state.applied;
    if (previousApplied != null && current.sameRouting(previousApplied)) {
      final saved = await _save(
        ProxyOwnershipState(
          owned: true,
          snapshot: snapshot,
          applied: previousApplied,
          pid: pid,
        ),
      );
      if (!saved) {
        commonPrint.log(
          'ProxyOwnership: switch did not land, but the ownership record could '
          'not be rewritten; keeping the pending record',
        );
        return ProxyReleaseOutcome.restoreFailed;
      }
      commonPrint.log(
        'ProxyOwnership: switch did not land; still owning '
        '${previousApplied.server}, original snapshot kept',
      );
      return ProxyReleaseOutcome.nothingToDo;
    }

    if (!current.sameRouting(intended)) {
      // A half-applied write: the server is one of ours, but the flags/PAC do
      // not match any state we can name. Restoring would be a guess, and
      // clearing would throw away the only record of what to go back to, so the
      // record is kept and nothing is written.
      final onOurPort =
          current.server == intended.server ||
          (previousApplied != null &&
              current.server == previousApplied.server);
      if (onOurPort) {
        commonPrint.log(
          'ProxyOwnership: pending record, and the system holds a partially '
          'applied value on ${current.server} (${current.enable}) — keeping the '
          'record instead of guessing',
        );
        return ProxyReleaseOutcome.ownershipUnknown;
      }

      // Someone else wrote a value in the meantime. Theirs wins.
      commonPrint.log(
        'ProxyOwnership: pending record, but the proxy now belongs to someone '
        'else (${current.enable}/${current.server}) — leaving it alone',
      );
      await _clear();
      return ProxyReleaseOutcome.externalChange;
    }

    // Ours, and still ours. Restore the pre-takeover snapshot.
    commonPrint.log(
      'ProxyOwnership: recovering from an interrupted apply '
      '(still holding ${intended.server})',
    );
    final restore = await _restoreSnapshot(
      snapshot,
      applied: intended,
      current: current,
    );
    if (restore == ProxyRestoreOutcome.failed) {
      commonPrint.log(
        'ProxyOwnership: pending recovery did not land; keeping the record',
      );
      return ProxyReleaseOutcome.restoreFailed;
    }
    await _clear();
    return restore == ProxyRestoreOutcome.writtenPartial
        ? ProxyReleaseOutcome.restoredPartial
        : ProxyReleaseOutcome.restored;
  }

  /// Restores [snapshot] as faithfully as the available primitives allow.
  ///
  /// P10-P0-B — three distinct paths, chosen by what the snapshot actually was:
  ///
  /// | snapshot | path | why |
  /// |---|---|---|
  /// | direct, no PAC | `stopProxy()` | flips the flags and sweeps RAS entries |
  /// | `127.0.0.1:<port>`, no PAC | `startProxy(port, bypass)` | the plugin's own shape |
  /// | remote server, or any PAC | registry write | the plugin cannot express either |
  ///
  /// Every path is followed by a read-back: a primitive reporting success is not
  /// evidence that the system now holds the value.
  ///
  /// [applied] and [current] exist for one reason: if a third party rewrote
  /// `ProxyOverride` while we held the proxy, their bypass list must survive our
  /// restore. Restoring ours would silently overwrite their exclusion rules.
  ///
  /// A `null` snapshot is **not** a licence to guess: nothing is written and the
  /// caller reports [ProxyReleaseOutcome.noSnapshot].
  static Future<ProxyRestoreOutcome> _restoreSnapshot(
    ProxySnapshot? snapshot, {
    ProxySnapshot? applied,
    ProxySnapshot? current,
  }) async {
    if (snapshot == null) {
      commonPrint.log(
        'ProxyOwnership: no snapshot to restore — leaving the system alone',
      );
      return ProxyRestoreOutcome.noSnapshot;
    }

    final target = _withPreservedBypass(snapshot, applied, current);
    final pac = target.autoConfigUrl ?? '';
    final loopbackPort = _loopbackPortOf(target.server);

    // Direct: the plugin's stop path is the only one that also covers dial-up and
    // RAS connections, so it stays the primitive for "off".
    if (!target.isOn && pac.isEmpty) {
      final ok = await _stop();
      if (ok != true) return ProxyRestoreOutcome.failed;
      return _verifyRestored(target, directOnly: true)
          ? ProxyRestoreOutcome.direct
          : ProxyRestoreOutcome.failed;
    }

    // A loopback proxy the plugin can reproduce exactly. Restored through the
    // plugin so WinINET is notified instead of merely having its registry
    // rewritten underneath it.
    if (target.isOn && pac.isEmpty && loopbackPort != null) {
      final ok = await _start(loopbackPort, _bypassParts(target.bypass));
      if (ok != true) return ProxyRestoreOutcome.failed;
      return _verifyRestored(target)
          ? ProxyRestoreOutcome.local
          : ProxyRestoreOutcome.failed;
    }

    // Remote server, PAC, or an "on" snapshot with no parseable server: none of
    // these have a plugin representation, so write the recorded values back.
    final written = await _writeSnapshot(target);
    if (!written) return ProxyRestoreOutcome.failed;
    if (!_verifyRestored(target)) return ProxyRestoreOutcome.failed;

    // A PAC url is only half the story: the flags that actually enable it live
    // in the per-connection blob we never snapshot. Say so instead of reporting
    // a clean restore.
    if (pac.isNotEmpty) {
      commonPrint.log(
        'ProxyOwnership: PAC url restored, but PROXY_TYPE_AUTO_PROXY_URL and '
        'PROXY_TYPE_AUTO_DETECT are not part of the snapshot — the PAC may be '
        'configured without being enabled',
      );
      return ProxyRestoreOutcome.writtenPartial;
    }
    return ProxyRestoreOutcome.written;
  }

  /// Reads the system back and checks it now holds [target].
  ///
  /// A primitive that returns `true` only says "the call was accepted". The
  /// registry can still hold a different value, and a WinINET refresh can fail
  /// after a successful write, so `restored` is only reported when the value is
  /// actually there.
  ///
  /// Compares routing only (enable / server / PAC): the plugin's `startProxy`
  /// always prefixes `<local>` to the bypass list, so byte equality on
  /// `ProxyOverride` would fail on every legitimate local restore.
  static bool _verifyRestored(
    ProxySnapshot target, {
    bool directOnly = false,
  }) {
    final now = read();
    if (now == null) {
      commonPrint.log(
        'ProxyOwnership: restore could not be verified — system unreadable',
      );
      return false;
    }
    if (directOnly) {
      // `stopProxy` only flips the flags; the remembered server and bypass stay
      // in place by design, so only "is it off" is meaningful here.
      if (now.enable != 0) {
        commonPrint.log(
          'ProxyOwnership: restore did not land (still enabled: ${now.enable})',
        );
        return false;
      }
      return true;
    }
    if (!now.sameRouting(target)) {
      commonPrint.log(
        'ProxyOwnership: restore did not land (wanted '
        '${target.enable}/${target.server}/${target.autoConfigUrl ?? ''}, '
        'got ${now.enable}/${now.server}/${now.autoConfigUrl ?? ''})',
      );
      return false;
    }
    return true;
  }

  /// Keeps a third party's `ProxyOverride` rewrite instead of restoring ours.
  ///
  /// The bypass list is deliberately excluded from [ProxySnapshot.sameRouting],
  /// so a program that only changed exclusions still looks like "our value is
  /// untouched". Restoring the recorded bypass in that case would silently undo
  /// their exclusion rules — the exact class of clobbering this class exists to
  /// prevent.
  static ProxySnapshot _withPreservedBypass(
    ProxySnapshot snapshot,
    ProxySnapshot? applied,
    ProxySnapshot? current,
  ) {
    if (applied == null || current == null) return snapshot;
    if (current.bypass == applied.bypass) return snapshot;
    commonPrint.log(
      'ProxyOwnership: ProxyOverride changed by someone else '
      '("${current.bypass}"); keeping it instead of restoring '
      '"${snapshot.bypass}"',
    );
    return ProxySnapshot(
      enable: snapshot.enable,
      server: snapshot.server,
      bypass: current.bypass,
      autoConfigUrl: snapshot.autoConfigUrl,
    );
  }

  /// The port of a `127.0.0.1:<port>` server, or `null` for anything else.
  ///
  /// Deliberately narrow: a protocol-specific list (`http=…;https=…`) or a
  /// hostname is not something `startProxy` can reproduce, so those fall through
  /// to the verbatim writer rather than being approximated.
  static int? _loopbackPortOf(String server) {
    final match = RegExp(r'^127\.0\.0\.1:(\d{1,5})$').firstMatch(server.trim());
    if (match == null) return null;
    final port = int.tryParse(match.group(1)!);
    if (port == null || port <= 0 || port > 65535) return null;
    return port;
  }

  /// The snapshot's bypass list as the plugin wants it.
  ///
  /// `startProxy` prepends `<local>` itself, so a snapshot that already carries
  /// it must not end up with `<local>;<local>;…`.
  static List<String> _bypassParts(String bypass) {
    return _cleanBypassParts(bypass.split(';'));
  }

  static List<String> _cleanBypassParts(Iterable<String> parts) {
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != '<local>')
        .toList(growable: false);
  }

  /// The bypass list exactly as `startProxy` will write it.
  ///
  /// P10-P0-C — the plugin builds `<local>` and then appends `;<domain>` for
  /// each entry (`proxy_plugin.cpp`, `startProxy`). A record of "what we
  /// intended to write" has to use that same shape, otherwise pending recovery
  /// compares `''` against `'<local>;…'`, reads the difference as a third-party
  /// edit, and preserves a bypass list that was never touched.
  static String _normalizedBypass(List<String> parts) {
    final clean = _cleanBypassParts(parts);
    if (clean.isEmpty) return '<local>';
    return '<local>;${clean.join(';')}';
  }
}
