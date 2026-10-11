import 'dart:convert';
import 'dart:io';

/// Atomic Config Storage for chain_proxies.json
///
/// Write flow:
///   1. Write JSON to a unique `.tmp` file
///   2. Validate the tmp content is parseable JSON
///   3. Copy current target → `.bak` (best-effort)
///   4. Rename/replace `.tmp` → target (atomic where supported)
///
/// Recovery flow on [load]:
///   1. Try target file
///   2. Try `.bak` backup
///   3. Try newest `.tmp` orphan (crash during save)
class AtomicConfigStorage {
  AtomicConfigStorage(this.filePath);

  final String filePath;
  int _tmpCounter = 0;

  Future<void> save(Map<String, dynamic> data) async {
    final targetFile = File(filePath);
    final backupFile = File('$filePath.bak');
    // Unique suffix per call to avoid concurrent-write collisions.
    final suffix = '${DateTime.now().microsecondsSinceEpoch}.${_tmpCounter++}';
    final tmpFile = File('$filePath.$suffix.tmp');

    try {
      // Ensure directory exists.
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      // Step 1: Write to tmp.
      await tmpFile.writeAsString(jsonStr, flush: true);

      // Step 2: Validate tmp content.
      final content = await tmpFile.readAsString();
      jsonDecode(content); // Throws FormatException if invalid.

      // Step 3: Best-effort backup of the current file.
      if (await targetFile.exists()) {
        try {
          await targetFile.copy(backupFile.path);
        } catch (_) {
          // Backup failure is non-fatal.
        }
      }

      // Step 4: Atomic rename.
      try {
        await tmpFile.rename(targetFile.path);
      } catch (_) {
        // On Windows, rename fails if the target already exists (no POSIX
        // atomic replace), and `File.copy` also fails with `ALREADY_EXISTS` in
        // that case. Fallback: copy then delete.
        //
        // P2.4-A: distinguish the two failure kinds instead of swallowing all:
        //  * the target is already a valid *file* (a concurrent save won the
        //    race) → nothing to do, this save's data is not needed;
        //  * the target is not a file at all (e.g. a directory, or an
        //    unwritable path) → the data did NOT land, so report the failure
        //    rather than letting `save()` claim success.
        if (await tmpFile.exists()) {
          try {
            await tmpFile.copy(targetFile.path);
          } catch (_) {
            // Decide synchronously and by the ONE deterministic failure shape:
            // a target that is a *directory* (or otherwise not a file path) can
            // never be written, so the failure must propagate. Every other
            // outcome — including a target that is momentarily absent while a
            // concurrent save replaces it — means another writer owns the
            // path, which is not an error.
            if (FileSystemEntity.isDirectorySync(targetFile.path)) {
              rethrow;
            }
          }
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      // Clean up orphaned tmp on failure.
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Loads the newest usable payload.
  ///
  /// [accept] (P2.5-C) is an optional predicate applied to **every** recovery
  /// candidate (target → `.bak` → orphan `.tmp`). A candidate it rejects is
  /// skipped exactly like a corrupt one, so an unsupported/invalid schema
  /// version in the primary does not prevent recovery from a valid `.bak`.
  /// When omitted, behaviour is byte-for-byte the pre-P2.5-C contract.
  Future<Map<String, dynamic>?> load({
    bool Function(Map<String, dynamic> data)? accept,
  }) async {
    final targetFile = File(filePath);
    final backupFile = File('$filePath.bak');

    // 1. Try the main target file.
    Map<String, dynamic>? data = await _tryLoad(targetFile, accept);
    if (data != null) return data;

    // P2.5-C: if the target is a well-formed JSON object that the schema
    // predicate rejected (e.g. a NEWER version written by a future build),
    // promoting a fallback over it would destroy that newer data. In that one
    // case the recovered payload is returned WITHOUT overwriting the target.
    // Missing / unparseable targets keep the P2.5-A promote behaviour.
    final preserveTarget = await _isWellFormedButRejected(targetFile, accept);

    // 2. Try the backup file.
    data = await _tryLoad(backupFile, accept);
    if (data != null) {
      // Restore backup to main location (P2.5-A).
      if (!preserveTarget) {
        try {
          await backupFile.copy(targetFile.path);
        } catch (_) {}
      }
      return data;
    }

    // 3. Try the newest valid orphan .tmp file (crash recovery).
    try {
      if (await targetFile.parent.exists()) {
        final baseName = targetFile.uri.pathSegments.last;
        final tmpFiles = targetFile.parent.listSync().whereType<File>().where((
          f,
        ) {
          final name = f.uri.pathSegments.last;
          return name.startsWith('$baseName.') && name.endsWith('.tmp');
        }).toList();

        // Sort newest first by modification time.
        tmpFiles.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );

        for (final tmp in tmpFiles) {
          data = await _tryLoad(tmp, accept);
          if (data != null) {
            // Promote orphan to main file (P2.5-A).
            if (!preserveTarget) {
              try {
                await tmp.copy(targetFile.path);
              } catch (_) {}
            }
            return data;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// True only when [file] exists, is a valid JSON **object**, and [accept]
  /// rejects it. Unparseable / missing / empty files are NOT "well-formed but
  /// rejected" — they keep the existing promote-on-recover behaviour.
  Future<bool> _isWellFormedButRejected(
    File file,
    bool Function(Map<String, dynamic> data)? accept,
  ) async {
    if (accept == null) return false;
    if (!await file.exists()) return false;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return false;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return !accept(decoded);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _tryLoad(
    File file, [
    bool Function(Map<String, dynamic> data)? accept,
  ]) async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      if (accept != null && !accept(decoded)) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }
}
