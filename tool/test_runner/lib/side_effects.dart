// R7-5 side-effect snapshot collector.
//
// The E-2 audit could not see `%TEMP%\Fluxora_*.sock` because its baseline was
// captured with a case-sensitive `grep fluxora_` filter. This module therefore
// captures a *complete* case-insensitive inventory of every configured root,
// with no prefix filtering at all, and records why anything could not be read
// or hashed instead of dropping it silently.
//
// Design constraints (R7-5):
//  * no pub dependencies, no external processes, no network;
//  * symlinks and junctions are recorded but never followed;
//  * `.sock` entries are never opened — a unix domain socket cannot be hashed
//    and reading one can block forever;
//  * one unreadable object never aborts the scan;
//  * a scan timeout is recorded as truncation, never as "nothing else existed".

import 'dart:convert';
import 'dart:io';

import 'sha256.dart';

/// Bumped whenever the JSONL field set changes in an incompatible way.
const int kSideEffectSchemaVersion = 1;

/// Default per-file hashing ceiling (64 MiB).
const int kDefaultMaxHashBytes = 64 * 1024 * 1024;

/// Default whole-scan wall-clock budget.
const int kDefaultScanTimeoutSeconds = 120;

/// Thrown for every expected failure so the CLI can map it to exit code 2.
class SideEffectException implements Exception {
  SideEffectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Coarse classification of a filesystem object.
///
/// [socketCandidate] is deliberately *not* called `socket`: on Windows a
/// `.sock` name is only a naming convention, and confirming the real object
/// type would require opening it, which this tool must never do.
enum SideEffectType { file, directory, link, socketCandidate, other, vanished }

/// Outcome of the hashing attempt for one entry.
enum HashStatus {
  hashed,
  skippedSocket,
  skippedTooLarge,
  skippedNoHash,
  unreadable,
  notApplicable,
}

/// Comparison outcome for one path identity.
enum DiffStatus { added, deleted, modified, unchanged, unverifiable }

String _typeWire(SideEffectType type) {
  switch (type) {
    case SideEffectType.file:
      return 'file';
    case SideEffectType.directory:
      return 'directory';
    case SideEffectType.link:
      return 'link';
    case SideEffectType.socketCandidate:
      return 'socket_candidate';
    case SideEffectType.other:
      return 'other';
    case SideEffectType.vanished:
      return 'vanished';
  }
}

String _hashWire(HashStatus status) {
  switch (status) {
    case HashStatus.hashed:
      return 'hashed';
    case HashStatus.skippedSocket:
      return 'skipped_socket';
    case HashStatus.skippedTooLarge:
      return 'skipped_too_large';
    case HashStatus.skippedNoHash:
      return 'skipped_no_hash';
    case HashStatus.unreadable:
      return 'unreadable';
    case HashStatus.notApplicable:
      return 'not_applicable';
  }
}

String _diffWire(DiffStatus status) {
  switch (status) {
    case DiffStatus.added:
      return 'new';
    case DiffStatus.deleted:
      return 'deleted';
    case DiffStatus.modified:
      return 'modified';
    case DiffStatus.unchanged:
      return 'unchanged';
    case DiffStatus.unverifiable:
      return 'unverifiable';
  }
}

/// Windows path comparison is case-insensitive; POSIX is not.
bool get isCaseInsensitiveFilesystem => Platform.isWindows;

String _unify(String path) => path.replaceAll('\\', '/');

/// Comparison key for a path: separators unified, case folded on Windows.
String pathIdentity(String path) {
  final String unified = _unify(path);
  return isCaseInsensitiveFilesystem ? unified.toLowerCase() : unified;
}

String _trimTrailingSeparators(String path) {
  String value = path;
  while (value.length > 1 &&
      (value.endsWith('/') || value.endsWith('\\')) &&
      !RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(value)) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

String _leafOf(String path) {
  final String trimmed = _trimTrailingSeparators(path);
  final int slash = trimmed.lastIndexOf('/');
  final int backslash = trimmed.lastIndexOf('\\');
  final int cut = slash > backslash ? slash : backslash;
  return cut < 0 ? trimmed : trimmed.substring(cut + 1);
}

/// Real path when the object exists, otherwise a normalised absolute guess.
String _realPathOrGuess(String path) {
  try {
    return _unify(Directory(path).resolveSymbolicLinksSync());
  } on FileSystemException {
    try {
      return _unify(File(path).resolveSymbolicLinksSync());
    } on FileSystemException {
      final String absolute = File(path).absolute.path;
      return _unify(_trimTrailingSeparators(absolute));
    }
  }
}

/// One scan root, with every label that resolved to the same real directory.
class ScanRoot {
  ScanRoot({
    required this.label,
    required this.path,
    required this.realPath,
    required this.exists,
    required List<String> aliases,
  }) : aliases = List<String>.unmodifiable(aliases);

  /// Primary label, e.g. `TEMP`.
  final String label;

  /// Path exactly as configured (may be relative for `--repo`).
  final String path;

  /// Canonical path used for deduplication and containment checks.
  final String realPath;

  final bool exists;

  /// Other labels that resolved to the same [realPath] (e.g. `LOCALAPPDATA_TEMP`).
  final List<String> aliases;

  /// Every label this root answers to, primary first.
  List<String> get allLabels => <String>[label, ...aliases];

  Map<String, Object?> toJson() => <String, Object?>{
        'label': label,
        'path': path,
        'real_path': realPath,
        'exists': exists,
        'aliases': aliases,
      };
}

/// Builds the four roots and folds duplicates by real path.
///
/// `%TEMP%` and `%LOCALAPPDATA%\Temp` are normally the *same* directory, so the
/// merged root keeps both labels and is scanned exactly once.
List<ScanRoot> resolveScanRoots({required String repoRoot}) {
  final Map<String, String> env = Platform.environment;
  final List<List<String>> candidates = <List<String>>[];

  final String? appData = env['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    candidates.add(<String>['APPDATA_FLUXORA', '$appData\\Fluxora']);
  }

  final String temp = env['TEMP'] ?? env['TMP'] ?? Directory.systemTemp.path;
  candidates.add(<String>['TEMP', temp]);

  final String? localAppData = env['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    candidates.add(<String>['LOCALAPPDATA_TEMP', '$localAppData\\Temp']);
  }

  candidates.add(<String>['REPO', repoRoot]);

  final List<ScanRoot> roots = <ScanRoot>[];
  final Map<String, int> byIdentity = <String, int>{};

  for (final List<String> candidate in candidates) {
    final String label = candidate[0];
    final String rawPath = candidate[1];
    final bool exists =
        Directory(rawPath).existsSync() || File(rawPath).existsSync();
    final String realPath =
        exists ? _realPathOrGuess(rawPath) : _unify(File(rawPath).absolute.path);
    final String identity = pathIdentity(realPath);

    final int? existing = byIdentity[identity];
    if (existing != null) {
      final ScanRoot previous = roots[existing];
      roots[existing] = ScanRoot(
        label: previous.label,
        path: previous.path,
        realPath: previous.realPath,
        exists: previous.exists,
        aliases: <String>[...previous.aliases, label],
      );
      continue;
    }
    byIdentity[identity] = roots.length;
    roots.add(ScanRoot(
      label: label,
      path: rawPath,
      realPath: realPath,
      exists: exists,
      aliases: const <String>[],
    ));
  }
  return roots;
}

/// A traversal problem that is not itself a filesystem entry.
class ScanIssue {
  ScanIssue({required this.path, required this.kind, required this.reason});

  final String path;
  final String kind;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'issue',
        'path': path,
        'issue_kind': kind,
        'reason': reason,
      };
}

/// One captured filesystem object.
class SideEffectEntry {
  SideEffectEntry({
    required this.path,
    required this.rootLabels,
    required this.type,
    required this.size,
    required this.mtime,
    required this.ctime,
    required this.sha256,
    required this.hashStatus,
    required this.hashReason,
  });

  final String path;
  final List<String> rootLabels;
  final SideEffectType type;
  final int? size;
  final String? mtime;
  final String? ctime;
  final String? sha256;
  final HashStatus hashStatus;
  final String? hashReason;

  String get identity => pathIdentity(path);

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'entry',
        'path': path,
        'roots': rootLabels,
        'type': _typeWire(type),
        'size': size,
        'mtime': mtime,
        'ctime': ctime,
        'sha256': sha256,
        'hash_status': _hashWire(hashStatus),
        'hash_reason': hashReason,
      };

  Map<String, Object?> toSummaryJson() => <String, Object?>{
        'type': _typeWire(type),
        'size': size,
        'sha256': sha256,
        'hash_status': _hashWire(hashStatus),
      };

  static SideEffectEntry fromJson(Map<String, Object?> json) {
    final Object? roots = json['roots'];
    return SideEffectEntry(
      path: json['path']! as String,
      rootLabels: roots is List
          ? roots.map((Object? value) => value! as String).toList()
          : const <String>[],
      type: _parseType(json['type'] as String?),
      size: json['size'] is int ? json['size']! as int : null,
      mtime: json['mtime'] as String?,
      ctime: json['ctime'] as String?,
      sha256: json['sha256'] as String?,
      hashStatus: _parseHashStatus(json['hash_status'] as String?),
      hashReason: json['hash_reason'] as String?,
    );
  }

  static SideEffectType _parseType(String? wire) {
    switch (wire) {
      case 'file':
        return SideEffectType.file;
      case 'directory':
        return SideEffectType.directory;
      case 'link':
        return SideEffectType.link;
      case 'socket_candidate':
        return SideEffectType.socketCandidate;
      case 'other':
        return SideEffectType.other;
      case 'vanished':
        return SideEffectType.vanished;
      default:
        throw SideEffectException('unknown entry type "$wire"');
    }
  }

  static HashStatus _parseHashStatus(String? wire) {
    switch (wire) {
      case 'hashed':
        return HashStatus.hashed;
      case 'skipped_socket':
        return HashStatus.skippedSocket;
      case 'skipped_too_large':
        return HashStatus.skippedTooLarge;
      case 'skipped_no_hash':
        return HashStatus.skippedNoHash;
      case 'unreadable':
        return HashStatus.unreadable;
      case 'not_applicable':
        return HashStatus.notApplicable;
      default:
        throw SideEffectException('unknown hash_status "$wire"');
    }
  }
}

/// Result of a full capture.
class CaptureResult {
  CaptureResult({
    required this.roots,
    required this.entries,
    required this.issues,
    required this.truncated,
    required this.truncationReason,
    required this.unvisitedDirectories,
    required this.elapsed,
    required this.options,
    required this.snapshotTime,
  });

  final List<ScanRoot> roots;
  final List<SideEffectEntry> entries;
  final List<ScanIssue> issues;
  final bool truncated;
  final String? truncationReason;
  final int unvisitedDirectories;
  final Duration elapsed;
  final Map<String, Object?> options;
  final DateTime snapshotTime;

  Map<String, int> countByType() {
    final Map<String, int> counts = <String, int>{};
    for (final SideEffectEntry entry in entries) {
      final String key = _typeWire(entry.type);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> countByHashStatus() {
    final Map<String, int> counts = <String, int>{};
    for (final SideEffectEntry entry in entries) {
      final String key = _hashWire(entry.hashStatus);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}

bool _looksLikeSocket(String path) {
  final String leaf = _leafOf(path).toLowerCase();
  return leaf.endsWith('.sock');
}

/// Walks every root and captures one record per filesystem object.
CaptureResult captureSideEffects({
  required String repoRoot,
  int maxHashBytes = kDefaultMaxHashBytes,
  int timeoutSeconds = kDefaultScanTimeoutSeconds,
  bool hashFiles = true,
  void Function(String message)? progress,
}) {
  final DateTime startedAt = DateTime.now().toUtc();
  final Stopwatch stopwatch = Stopwatch()..start();
  final Duration budget = Duration(seconds: timeoutSeconds);

  final List<ScanRoot> roots = resolveScanRoots(repoRoot: repoRoot);
  final List<SideEffectEntry> entries = <SideEffectEntry>[];
  final List<ScanIssue> issues = <ScanIssue>[];

  bool truncated = false;
  String? truncationReason;
  int unvisited = 0;

  for (final ScanRoot root in roots) {
    if (!root.exists) {
      issues.add(ScanIssue(
        path: root.path,
        kind: 'root_missing',
        reason: 'root does not exist; nothing was captured for this label',
      ));
      continue;
    }
    if (truncated) {
      unvisited++;
      continue;
    }

    final List<String> stack = <String>[root.realPath];
    while (stack.isNotEmpty) {
      if (stopwatch.elapsed > budget) {
        truncated = true;
        truncationReason = 'scan timeout after ${timeoutSeconds}s';
        break;
      }
      final String directory = stack.removeLast();
      List<FileSystemEntity> children;
      try {
        children = Directory(directory).listSync(followLinks: false);
      } on FileSystemException catch (error) {
        issues.add(ScanIssue(
          path: directory,
          kind: 'list_failed',
          reason: error.toString(),
        ));
        continue;
      }
      children.sort((FileSystemEntity a, FileSystemEntity b) =>
          a.path.compareTo(b.path));

      for (int index = 0; index < children.length; index++) {
        if (stopwatch.elapsed > budget) {
          truncated = true;
          truncationReason = 'scan timeout after ${timeoutSeconds}s';
          // R7-5.1: the child at `index` and every child after it were never
          // visited. The directories among them are pending work that must be
          // counted, otherwise a timeout silently under-reports the omission.
          // Children before `index` were already handled: the directories among
          // them sit on `stack` and are counted there, so nothing is counted
          // twice.
          unvisited += _countPendingDirectories(children, index);
          break;
        }
        final FileSystemEntity child = children[index];
        final String childPath = _trimTrailingSeparators(child.path);

        FileSystemEntityType entityType;
        try {
          entityType =
              FileSystemEntity.typeSync(childPath, followLinks: false);
        } on FileSystemException catch (error) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.vanished,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.unreadable,
            hashReason: 'type lookup failed: $error',
          ));
          continue;
        }

        if (entityType == FileSystemEntityType.notFound) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.vanished,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.unreadable,
            hashReason: 'disappeared between directory listing and stat',
          ));
          continue;
        }

        if (entityType == FileSystemEntityType.link) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.link,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.notApplicable,
            hashReason: 'symlink or junction; recorded but never followed',
          ));
          continue;
        }

        if (entityType == FileSystemEntityType.directory) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.directory,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.notApplicable,
            hashReason: null,
          ));
          stack.add(childPath);
          continue;
        }

        // Dart reports a real unix domain socket as its own entity type. That is
        // an OS-level confirmation, unlike the `.sock` name check below, and the
        // object must never be opened either way.
        if (entityType == FileSystemEntityType.unixDomainSock) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.socketCandidate,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.skippedSocket,
            hashReason: 'OS-confirmed unix domain socket; never opened or hashed',
          ));
          continue;
        }

        if (entityType != FileSystemEntityType.file) {
          entries.add(SideEffectEntry(
            path: _unify(childPath),
            rootLabels: root.allLabels,
            type: SideEffectType.other,
            size: null,
            mtime: null,
            ctime: null,
            sha256: null,
            hashStatus: HashStatus.notApplicable,
            hashReason: 'unsupported entity type: $entityType',
          ));
          continue;
        }

        entries.add(_captureFile(
          path: _unify(childPath),
          rootLabels: root.allLabels,
          maxHashBytes: maxHashBytes,
          hashFiles: hashFiles,
        ));

        if (progress != null && entries.length % 250 == 0) {
          progress('scanned ${entries.length} entries '
              '(${stopwatch.elapsed.inSeconds}s)');
        }
      }
      if (truncated) {
        break;
      }
    }
    if (truncated) {
      unvisited += stack.length;
    }
  }

  stopwatch.stop();
  return CaptureResult(
    roots: roots,
    entries: entries,
    issues: issues,
    truncated: truncated,
    truncationReason: truncationReason,
    unvisitedDirectories: unvisited,
    elapsed: stopwatch.elapsed,
    options: <String, Object?>{
      'max_hash_bytes': maxHashBytes,
      'timeout_seconds': timeoutSeconds,
      'hash_files': hashFiles,
    },
    snapshotTime: startedAt,
  );
}

/// Counts the directories in [children] from [from] onwards.
///
/// R7-5.1: used only after the scan deadline has already passed, so it must not
/// touch the filesystem. It relies on the entity type `listSync` already
/// resolved: with `followLinks: false` a directory arrives as [Directory] and a
/// symlink or junction arrives as [Link], so neither costs an extra syscall and
/// junctions are never mistaken for pending directories.
///
/// Known race: if a listed directory vanished before the main loop could stat
/// it, it is recorded as `vanished` but still counted here as pending. The two
/// records are consistent in intent — the directory was known and not visited.
int _countPendingDirectories(List<FileSystemEntity> children, int from) {
  int pending = 0;
  for (int index = from; index < children.length; index++) {
    if (children[index] is Directory) {
      pending++;
    }
  }
  return pending;
}

SideEffectEntry _captureFile({
  required String path,
  required List<String> rootLabels,
  required int maxHashBytes,
  required bool hashFiles,
}) {
  FileStat stat;
  try {
    stat = File(path).statSync();
  } on FileSystemException catch (error) {
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.file,
      size: null,
      mtime: null,
      ctime: null,
      sha256: null,
      hashStatus: HashStatus.unreadable,
      hashReason: 'stat failed: $error',
    );
  }

  final String mtime = stat.modified.toUtc().toIso8601String();
  final String ctime = stat.changed.toUtc().toIso8601String();

  // A `.sock` name is never opened: reading a unix domain socket blocks, and the
  // object type cannot be confirmed without opening it.
  if (_looksLikeSocket(path)) {
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.socketCandidate,
      size: stat.size,
      mtime: mtime,
      ctime: ctime,
      sha256: null,
      hashStatus: HashStatus.skippedSocket,
      hashReason: 'socket candidate by name; never opened or hashed',
    );
  }

  if (!hashFiles) {
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.file,
      size: stat.size,
      mtime: mtime,
      ctime: ctime,
      sha256: null,
      hashStatus: HashStatus.skippedNoHash,
      hashReason: 'hashing disabled by --no-hash',
    );
  }

  if (stat.size > maxHashBytes) {
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.file,
      size: stat.size,
      mtime: mtime,
      ctime: ctime,
      sha256: null,
      hashStatus: HashStatus.skippedTooLarge,
      hashReason: 'size ${stat.size} exceeds max_hash_bytes $maxHashBytes',
    );
  }

  try {
    final List<int> bytes = File(path).readAsBytesSync();
    if (bytes.length > maxHashBytes) {
      return SideEffectEntry(
        path: path,
        rootLabels: rootLabels,
        type: SideEffectType.file,
        size: stat.size,
        mtime: mtime,
        ctime: ctime,
        sha256: null,
        hashStatus: HashStatus.skippedTooLarge,
        hashReason: 'read ${bytes.length} bytes, exceeds max_hash_bytes '
            '$maxHashBytes',
      );
    }
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.file,
      size: stat.size,
      mtime: mtime,
      ctime: ctime,
      sha256: Sha256.hexOfBytes(bytes),
      hashStatus: HashStatus.hashed,
      hashReason: null,
    );
  } on FileSystemException catch (error) {
    return SideEffectEntry(
      path: path,
      rootLabels: rootLabels,
      type: SideEffectType.file,
      size: stat.size,
      mtime: mtime,
      ctime: ctime,
      sha256: null,
      hashStatus: HashStatus.unreadable,
      hashReason: 'read failed (locked, permission, or vanished): $error',
    );
  }
}

/// Serialises a capture as JSONL: header, entries, issues, footer.
///
/// Every line is independently parseable and carries a `kind` discriminator, so
/// a reader never needs the previous line to interpret the current one.
String encodeCapture(CaptureResult result) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(jsonEncode(<String, Object?>{
    'kind': 'header',
    'schema_version': kSideEffectSchemaVersion,
    'record': 'capture',
    'snapshot_time': result.snapshotTime.toIso8601String(),
    'platform': Platform.operatingSystem,
    'case_insensitive_paths': isCaseInsensitiveFilesystem,
    'ctime_semantics': Platform.isWindows
        ? 'file creation time (Windows FileStat.changed)'
        : 'inode change time (POSIX FileStat.changed)',
    'roots': result.roots.map((ScanRoot root) => root.toJson()).toList(),
    'options': result.options,
  }));
  for (final SideEffectEntry entry in result.entries) {
    buffer.writeln(jsonEncode(entry.toJson()));
  }
  for (final ScanIssue issue in result.issues) {
    buffer.writeln(jsonEncode(issue.toJson()));
  }
  buffer.writeln(jsonEncode(<String, Object?>{
    'kind': 'footer',
    'entry_count': result.entries.length,
    'issue_count': result.issues.length,
    'type_counts': result.countByType(),
    'hash_status_counts': result.countByHashStatus(),
    'truncated': result.truncated,
    'truncation_reason': result.truncationReason,
    'unvisited_directory_count': result.unvisitedDirectories,
    'elapsed_seconds': result.elapsed.inMilliseconds / 1000,
  }));
  return buffer.toString();
}

/// A parsed snapshot file.
class SnapshotFile {
  SnapshotFile({
    required this.sourcePath,
    required this.header,
    required this.entries,
    required this.issues,
    required this.footer,
  });

  final String sourcePath;
  final Map<String, Object?> header;
  final List<SideEffectEntry> entries;
  final List<ScanIssue> issues;
  final Map<String, Object?> footer;

  List<ScanRoot> get roots {
    final Object? raw = header['roots'];
    if (raw is! List) {
      return const <ScanRoot>[];
    }
    return raw.map((Object? item) {
      final Map<String, Object?> json = (item! as Map<Object?, Object?>)
          .map((Object? k, Object? v) => MapEntry<String, Object?>(k! as String, v));
      final Object? aliases = json['aliases'];
      return ScanRoot(
        label: json['label']! as String,
        path: json['path']! as String,
        realPath: json['real_path']! as String,
        exists: json['exists'] == true,
        aliases: aliases is List
            ? aliases.map((Object? value) => value! as String).toList()
            : const <String>[],
      );
    }).toList();
  }
}

/// Reads a JSONL snapshot, failing closed on structural damage.
SnapshotFile readSnapshot(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw SideEffectException('snapshot not found: "$path"');
  }
  final List<String> lines = file.readAsLinesSync();
  final List<SideEffectEntry> entries = <SideEffectEntry>[];
  final List<ScanIssue> issues = <ScanIssue>[];
  Map<String, Object?>? header;
  Map<String, Object?>? footer;

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i].trim();
    if (line.isEmpty) {
      continue;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      throw SideEffectException(
          'invalid JSON on line ${i + 1} of "$path": $error');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw SideEffectException(
          'line ${i + 1} of "$path" is not a JSON object');
    }
    final Map<String, Object?> record =
        decoded.map((Object? k, Object? v) => MapEntry<String, Object?>(k! as String, v));
    switch (record['kind']) {
      case 'header':
        header ??= record;
        break;
      case 'entry':
        entries.add(SideEffectEntry.fromJson(record));
        break;
      case 'issue':
        issues.add(ScanIssue(
          path: record['path'] as String? ?? '',
          kind: record['issue_kind'] as String? ?? 'unknown',
          reason: record['reason'] as String? ?? '',
        ));
        break;
      case 'footer':
        footer = record;
        break;
      default:
        throw SideEffectException(
            'line ${i + 1} of "$path" has unknown kind "${record['kind']}"');
    }
  }

  if (header == null) {
    throw SideEffectException('snapshot "$path" has no header record');
  }
  return SnapshotFile(
    sourcePath: path,
    header: header,
    entries: entries,
    issues: issues,
    footer: footer ?? const <String, Object?>{},
  );
}

/// One path compared across two snapshots.
class DiffRecord {
  DiffRecord({
    required this.path,
    required this.status,
    required this.before,
    required this.after,
  });

  final String path;
  final DiffStatus status;
  final SideEffectEntry? before;
  final SideEffectEntry? after;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'diff',
        'status': _diffWire(status),
        'path': path,
        'before': before?.toSummaryJson(),
        'after': after?.toSummaryJson(),
      };
}

/// Result of a snapshot comparison.
class DiffResult {
  DiffResult({
    required this.records,
    required this.beforePath,
    required this.afterPath,
    required this.compareTime,
    required this.beforeHeader,
    required this.afterHeader,
  });

  final List<DiffRecord> records;
  final String beforePath;
  final String afterPath;
  final DateTime compareTime;
  final Map<String, Object?> beforeHeader;
  final Map<String, Object?> afterHeader;

  Map<String, int> counts() {
    final Map<String, int> result = <String, int>{};
    for (final DiffRecord record in records) {
      final String key = _diffWire(record.status);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }
}

Map<String, SideEffectEntry> _indexByIdentity(
    List<SideEffectEntry> entries, String sourcePath) {
  final Map<String, SideEffectEntry> index = <String, SideEffectEntry>{};
  for (final SideEffectEntry entry in entries) {
    final String identity = entry.identity;
    final SideEffectEntry? existing = index[identity];
    if (existing != null) {
      throw SideEffectException(
          'duplicate path identity in "$sourcePath":\n'
          '  "${existing.path}"\n  "${entry.path}"\n'
          'Two records map to the same case-insensitive path; refusing to '
          'silently keep one of them.');
    }
    index[identity] = entry;
  }
  return index;
}

DiffStatus _classify(SideEffectEntry before, SideEffectEntry after) {
  if (before.type != after.type) {
    return DiffStatus.modified;
  }
  if (before.hashStatus == HashStatus.hashed &&
      after.hashStatus == HashStatus.hashed) {
    if (before.sha256 == after.sha256) {
      return DiffStatus.unchanged;
    }
    return DiffStatus.modified;
  }
  if (before.size != null && after.size != null && before.size != after.size) {
    return DiffStatus.modified;
  }
  // Type and size agree but at least one side was never hashed: content
  // equality cannot be proven, so the pair stays unverifiable rather than being
  // reported as unchanged.
  return DiffStatus.unverifiable;
}

DiffResult compareSnapshots({
  required SnapshotFile before,
  required SnapshotFile after,
}) {
  final Map<String, SideEffectEntry> beforeIndex =
      _indexByIdentity(before.entries, before.sourcePath);
  final Map<String, SideEffectEntry> afterIndex =
      _indexByIdentity(after.entries, after.sourcePath);

  final Set<String> identities = <String>{...beforeIndex.keys, ...afterIndex.keys};
  final List<String> sorted = identities.toList()..sort();

  final List<DiffRecord> records = <DiffRecord>[];
  for (final String identity in sorted) {
    final SideEffectEntry? lhs = beforeIndex[identity];
    final SideEffectEntry? rhs = afterIndex[identity];
    if (lhs == null && rhs != null) {
      records.add(DiffRecord(
        path: rhs.path,
        status: DiffStatus.added,
        before: null,
        after: rhs,
      ));
      continue;
    }
    if (lhs != null && rhs == null) {
      records.add(DiffRecord(
        path: lhs.path,
        status: DiffStatus.deleted,
        before: lhs,
        after: null,
      ));
      continue;
    }
    records.add(DiffRecord(
      path: rhs!.path,
      status: _classify(lhs!, rhs),
      before: lhs,
      after: rhs,
    ));
  }

  return DiffResult(
    records: records,
    beforePath: before.sourcePath,
    afterPath: after.sourcePath,
    compareTime: DateTime.now().toUtc(),
    beforeHeader: before.header,
    afterHeader: after.header,
  );
}

/// Serialises a diff as JSONL.
String encodeDiff(DiffResult result) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(jsonEncode(<String, Object?>{
    'kind': 'header',
    'schema_version': kSideEffectSchemaVersion,
    'record': 'compare',
    'compare_time': result.compareTime.toIso8601String(),
    'before': result.beforePath,
    'after': result.afterPath,
    'before_snapshot_time': result.beforeHeader['snapshot_time'],
    'after_snapshot_time': result.afterHeader['snapshot_time'],
    'case_insensitive_paths': isCaseInsensitiveFilesystem,
  }));
  for (final DiffRecord record in result.records) {
    buffer.writeln(jsonEncode(record.toJson()));
  }
  buffer.writeln(jsonEncode(<String, Object?>{
    'kind': 'footer',
    'record_count': result.records.length,
    'status_counts': result.counts(),
  }));
  return buffer.toString();
}

/// Validates an output path and returns its canonical form.
///
/// Refuses to overwrite, refuses traversal, and refuses to write inside any scan
/// root or inside the git worktree — a snapshot written into `%TEMP%` would be
/// picked up by its own scan and poison the next comparison.
String validateOutputPath({
  required String outPath,
  required List<ScanRoot> roots,
  required String repoRoot,
}) {
  final String raw = outPath.trim();
  if (raw.isEmpty) {
    throw SideEffectException('empty --out path');
  }
  final String unified = _unify(raw);
  if (unified.endsWith('/')) {
    throw SideEffectException('trailing slash is not allowed in --out: "$raw"');
  }
  for (final String segment in unified.split('/')) {
    if (segment == '..') {
      throw SideEffectException('path traversal is not allowed in --out: "$raw"');
    }
  }
  if (Platform.isWindows &&
      RegExp(r'^[A-Za-z]:').hasMatch(unified) &&
      unified.length > 2 &&
      unified[2] != '/') {
    throw SideEffectException(
        'drive-relative --out is ambiguous: "$raw" (use C:/... or C:\\...)');
  }

  final File file = File(raw);
  if (file.existsSync()) {
    throw SideEffectException(
        'output already exists: "$raw" (overwriting is not supported)');
  }
  if (Directory(raw).existsSync()) {
    throw SideEffectException('output path is a directory: "$raw"');
  }
  final Directory parent = file.parent;
  if (!parent.existsSync()) {
    throw SideEffectException('output parent does not exist: "${parent.path}"');
  }

  String canonicalParent;
  try {
    canonicalParent = _unify(parent.resolveSymbolicLinksSync());
  } on FileSystemException catch (error) {
    throw SideEffectException(
        'cannot resolve output parent "${parent.path}": $error');
  }
  final String target = '$canonicalParent/${_leafOf(raw)}';
  final String targetId = pathIdentity(target);

  for (final ScanRoot root in roots) {
    if (!root.exists) {
      continue;
    }
    final String rootId = pathIdentity(root.realPath);
    if (targetId == rootId || targetId.startsWith('$rootId/')) {
      throw SideEffectException(
          'output must live outside every scan root: "$target" is inside '
          '"${root.label}" (${root.realPath})');
    }
  }

  final String repoId = pathIdentity(_realPathOrGuess(repoRoot));
  if (targetId == repoId || targetId.startsWith('$repoId/')) {
    throw SideEffectException(
        'output must live outside the git worktree: "$target" is inside '
        '"$repoId"');
  }
  return target;
}

/// Writes [content] to a validated, previously non-existent path.
void writeSnapshot({required String outPath, required String content}) {
  final File file = File(outPath);
  if (file.existsSync()) {
    throw SideEffectException('output already exists: "$outPath"');
  }
  file.writeAsStringSync(content, flush: true);
}
