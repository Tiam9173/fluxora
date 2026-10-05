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
        // On Windows, rename fails if target exists (no POSIX atomic replace).
        // Fallback: copy then delete.
        if (await tmpFile.exists()) {
          try {
            await tmpFile.copy(targetFile.path);
          } catch (_) {
            // If target already exists from a concurrent write, that is OK.
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

  Future<Map<String, dynamic>?> load() async {
    final targetFile = File(filePath);
    final backupFile = File('$filePath.bak');

    // 1. Try the main target file.
    Map<String, dynamic>? data = await _tryLoad(targetFile);
    if (data != null) return data;

    // 2. Try the backup file.
    data = await _tryLoad(backupFile);
    if (data != null) {
      // Restore backup to main location.
      try {
        await backupFile.copy(targetFile.path);
      } catch (_) {}
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
          data = await _tryLoad(tmp);
          if (data != null) {
            // Promote orphan to main file.
            try {
              await tmp.copy(targetFile.path);
            } catch (_) {}
            return data;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>?> _tryLoad(File file) async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
