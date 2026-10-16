import 'dart:async';
import 'dart:typed_data';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart';

/// item 6 (Bettbox 1.19.3) — what kind of backup a remote file is.
enum BackupKind {
  /// `fluxora_20261016T230500Z.zip` (optionally `_01`, `_02` on collision).
  /// These are the only files the retention policy may delete.
  versioned,

  /// `fluxora.zip` — the single-file backup written before versions existed.
  ///
  /// Kept exactly as-is: never renamed, never overwritten, never pruned, and not
  /// counted against the version limit, so upgrading does not cost an old user
  /// either their existing backup or one of the new slots.
  legacy,
}

/// A backup found on the server, with its name already decoded into fields.
///
/// Sorting reads [timestamp] and [sequence] rather than comparing file names as
/// strings: the name happens to sort correctly today, but that is a property of
/// the format, not something the sort should have to rely on.
class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.kind,
    this.timestamp,
    this.sequence = 0,
  });

  final String name;
  final BackupKind kind;

  /// The UTC instant encoded in the name. Null for [BackupKind.legacy], which
  /// carries no timestamp.
  final DateTime? timestamp;

  /// Collision suffix: `_01` is 1, no suffix is 0.
  final int sequence;

  bool get isVersioned => kind == BackupKind.versioned;
}

/// Parse `fluxora_20261016T230500Z[_NN].zip`.
///
/// Returns null unless the name matches **strictly** — an unrecognised name is
/// not a versioned backup, so it must never become eligible for pruning.
({DateTime timestamp, int sequence})? parseVersionedBackupName(
  String name, {
  required String baseName,
}) {
  final reg = RegExp(
    '^${RegExp.escape(baseName)}_(\\d{4})(\\d{2})(\\d{2})T(\\d{2})(\\d{2})(\\d{2})Z(?:_(\\d{2}))?\\.zip\$',
    caseSensitive: false,
  );
  final match = reg.firstMatch(name);
  if (match == null) return null;

  int at(int group) => int.parse(match.group(group)!);
  final timestamp = DateTime.utc(
    at(1),
    at(2),
    at(3),
    at(4),
    at(5),
    at(6),
  );
  // `DateTime.utc` silently rolls impossible dates over (month 13 → next year),
  // so a name like `20261301T...` would parse into a plausible-looking wrong
  // instant. Reject anything that does not round-trip.
  if (timestamp.year != at(1) ||
      timestamp.month != at(2) ||
      timestamp.day != at(3) ||
      timestamp.hour != at(4) ||
      timestamp.minute != at(5) ||
      timestamp.second != at(6)) {
    return null;
  }

  final seqGroup = match.group(7);
  return (
    timestamp: timestamp,
    sequence: seqGroup == null ? 0 : int.parse(seqGroup),
  );
}

/// Build the versioned name for [utc] and [sequence].
///
/// [utc] is converted to UTC first, so a caller passing a local `DateTime` still
/// gets a UTC-stamped name rather than a silently local one.
String buildBackupName(
  DateTime utc,
  int sequence, {
  required String baseName,
}) {
  final t = utc.toUtc();
  String p2(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year.toString().padLeft(4, '0')}${p2(t.month)}${p2(t.day)}'
      'T${p2(t.hour)}${p2(t.minute)}${p2(t.second)}Z';
  final suffix = sequence == 0 ? '' : '_${p2(sequence)}';
  return '${baseName}_$stamp$suffix.zip';
}

/// Classify a remote file name, or null when it is neither kind of backup.
///
/// Null means "not ours" — such a file is neither listed nor prunable.
BackupEntry? classifyBackupName(String name, {required String baseName}) {
  if (name.toLowerCase() == '${baseName.toLowerCase()}.zip') {
    return BackupEntry(name: name, kind: BackupKind.legacy);
  }
  final parsed = parseVersionedBackupName(name, baseName: baseName);
  if (parsed == null) return null;
  return BackupEntry(
    name: name,
    kind: BackupKind.versioned,
    timestamp: parsed.timestamp,
    sequence: parsed.sequence,
  );
}

/// Newest first: versioned backups by timestamp then collision sequence, with
/// legacy backups last (they predate versions and carry no instant).
void sortBackupEntriesDesc(List<BackupEntry> entries) {
  entries.sort((a, b) {
    if (a.isVersioned != b.isVersioned) return a.isVersioned ? -1 : 1;
    final at = a.timestamp;
    final bt = b.timestamp;
    if (at == null || bt == null) return 0;
    final byTime = bt.compareTo(at);
    if (byTime != 0) return byTime;
    return b.sequence.compareTo(a.sequence);
  });
}

/// Which backups the retention policy may delete, given the newest-first list.
///
/// Pure so the policy can be asserted without a server. Legacy backups are never
/// candidates — they are not counted against [maxVersions] and are never
/// removed, so upgrading cannot cost an old user their only backup.
List<BackupEntry> selectPrunableBackups(
  List<BackupEntry> entries, {
  int maxVersions = 10,
}) {
  final versioned = entries.where((e) => e.isVersioned).toList();
  if (versioned.length <= maxVersions) return const [];
  return versioned.sublist(maxVersions);
}

class DAVClient {
  late Client client;
  Completer<bool> pingCompleter = Completer();
  late String fileName;
  late final Uri _serverUri;

  DAVClient(DAV dav) {
    client = newClient(dav.uri, user: dav.user, password: dav.password);
    fileName = dav.fileName;
    _serverUri = Uri.parse(dav.uri);
    client.c.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!_hasSameOrigin(options.uri, _serverUri)) {
            options.headers.remove('authorization');
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final challenges = response.headers['www-authenticate'];
          if (response.statusCode == 401 &&
              challenges != null &&
              challenges.length > 1) {
            response.headers.set('www-authenticate', challenges.join(', '));
          }
          handler.next(response);
        },
      ),
    );
    client.setHeaders({'accept-charset': 'utf-8', 'Content-Type': 'text/xml'});
    client.setConnectTimeout(15000);
    client.setSendTimeout(120000);
    client.setReceiveTimeout(120000);
    pingCompleter.complete(_ping());
  }

  Future<bool> _ping() async {
    try {
      await client.ping();
      commonPrint.log('WebDAV ping successful');
      return true;
    } catch (e) {
      commonPrint.log('WebDAV ping failed: $e');
      return false;
    }
  }

  String get root => '/$appName';

  /// `fileName` without its `.zip`, used as the prefix of every versioned name.
  String get baseName =>
      fileName.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');

  /// The pre-version single-file backup. Still written by nothing, still
  /// restorable, never overwritten and never pruned.
  String get legacyFile => '$root/$fileName';

  /// Every backup on the server, newest first.
  ///
  /// Only strictly-recognised names are returned. A file that is neither the
  /// legacy backup nor a well-formed versioned name is left out entirely, which
  /// is what keeps it out of reach of the retention policy.
  Future<List<BackupEntry>> getBackupEntries() async {
    try {
      await client.mkdir(root);
    } catch (_) {}
    final rawFiles = await client.readDir(root);
    final entries = <BackupEntry>[];
    for (final file in rawFiles) {
      if (file.isDir == true) continue;
      final name = file.name;
      if (name == null || name.isEmpty) continue;
      final entry = classifyBackupName(name, baseName: baseName);
      if (entry != null) entries.add(entry);
    }
    sortBackupEntriesDesc(entries);
    return entries;
  }

  /// The name a new backup should use: the current UTC instant, with `_01`,
  /// `_02`, … appended while that name is already taken.
  ///
  /// This only picks a name. It cannot *claim* it — see [backup] for the check
  /// that runs after the upload.
  Future<String> getNextBackupFileName({DateTime? now}) async {
    final utc = (now ?? DateTime.now()).toUtc();
    final taken = <String>{};
    try {
      for (final entry in await getBackupEntries()) {
        taken.add(entry.name.toLowerCase());
      }
    } catch (_) {}

    for (var sequence = 0; sequence <= 99; sequence++) {
      final candidate = buildBackupName(utc, sequence, baseName: baseName);
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
    // 100 backups inside one second: fall back to the plain name rather than
    // looping forever. The post-upload check still refuses to clobber anything.
    return buildBackupName(utc, 0, baseName: baseName);
  }

  /// Delete versioned backups beyond the newest [maxVersions].
  ///
  /// Legacy backups are never candidates, and neither is anything whose name did
  /// not parse — the retention policy only ever removes files it can prove it
  /// wrote.
  Future<void> _pruneOldBackups({int maxVersions = 10}) async {
    final entries = await getBackupEntries();
    for (final entry in selectPrunableBackups(
      entries,
      maxVersions: maxVersions,
    )) {
      try {
        await client.remove('$root/${entry.name}');
      } catch (e) {
        // A failed prune must not fail the backup that just succeeded, but it
        // must not be silent either.
        commonPrint.log('Prune backup failed for ${entry.name}: $e');
      }
    }
  }

  Future<bool> backup(Uint8List data) async {
    return await _retryOperation(() async {
      try {
        await client.mkdir(root);
      } catch (e) {
        commonPrint.log('WebDAV mkdir warning (may already exist): $e');
      }

      // Pick a free name, upload, then confirm the file we find under that name
      // is the one we just wrote.
      //
      // `webdav_client`'s `write` is an unconditional PUT and its headers are set
      // globally, so there is no way to ask for `If-None-Match: *` without
      // mutating shared state for every other request. This is therefore
      // *detection*, not prevention: two clients writing the same second can
      // still race, and the loser notices here and retries under a new name
      // instead of having silently overwritten the winner.
      const maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        final targetName = await getNextBackupFileName();
        final targetPath = '$root/$targetName';
        commonPrint.log(
          'WebDAV backup: uploading ${data.length} bytes to $targetPath',
        );

        await client.write(targetPath, data);

        final landed = (await getBackupEntries()).where(
          (e) => e.name.toLowerCase() == targetName.toLowerCase(),
        );
        if (landed.isEmpty) {
          commonPrint.log('WebDAV backup: $targetName missing after upload');
          continue;
        }

        commonPrint.log('WebDAV backup successful: $targetName');

        // Only now that the new backup is confirmed on the server.
        try {
          await _pruneOldBackups();
        } catch (e) {
          commonPrint.log('Prune after backup failed: $e');
        }
        return true;
      }

      throw Exception('Could not store a new backup after $maxAttempts attempts');
    }, operationName: 'backup');
  }

  Future<List<int>> recovery([String? targetFileName]) async {
    return await _retryOperation(() async {
      final target = targetFileName ?? fileName;
      final targetPath = target.startsWith('/') ? target : '$root/$target';
      commonPrint.log('WebDAV recovery: downloading from $targetPath');

      try {
        await client.mkdir(root);
      } catch (e) {
        commonPrint.log('WebDAV mkdir warning: $e');
      }

      final data = await client.read(targetPath);
      commonPrint.log('WebDAV recovery successful: ${data.length} bytes');
      return data;
    }, operationName: 'recovery');
  }

  bool _hasSameOrigin(Uri left, Uri right) {
    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        left.port == right.port;
  }

  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    required String operationName,
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 2);

    while (attempt < maxAttempts) {
      attempt++;

      try {
        return await operation();
      } catch (e) {
        final isLastAttempt = attempt >= maxAttempts;

        if (isLastAttempt) {
          commonPrint.log(
            'WebDAV $operationName failed after $maxAttempts attempts: $e',
          );
          throw 'WebDAV $operationName failed: ${_formatError(e)}';
        }

        commonPrint.log(
          'WebDAV $operationName attempt $attempt failed: $e, retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);

        delay *= 2;
      }
    }

    throw 'WebDAV $operationName failed: unexpected error';
  }

  String _formatError(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection')) {
      return 'Network connection failed. Please check your internet connection and WebDAV server address.';
    }

    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'Authentication failed. Please check your username and password.';
    }

    if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return 'Access denied. Please check your account permissions.';
    }

    if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return 'Backup file not found on server.';
    }

    if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
      return 'Operation timed out. Please check your network connection or try again later.';
    }

    if (errorStr.contains('507') || errorStr.contains('Insufficient Storage')) {
      return 'Server storage is full. Please free up space on your WebDAV server.';
    }

    return errorStr;
  }
}
