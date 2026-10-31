import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
// `shared_preferences_platform_interface` is a direct dependency of
// `shared_preferences` and pinned by the lock file; it is imported here to
// implement a store, which is exactly what the plugin documents. Declaring it
// in `pubspec.yaml` is the cleaner fix, but pubspec is on the do-not-touch list
// and adding a dependency needs its own approval.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

import 'path.dart';
import 'print.dart';

/// File name the plugin itself uses. Kept identical on purpose: a data
/// directory written by portable mode stays readable if the store is ever
/// swapped back, and the migration is a straight copy of the same JSON shape.
const portablePrefsFileName = 'shared_preferences.json';

/// The plugin prefixes every key it stores with this. The store sees the
/// prefixed form, and `getAll` / `clear` must filter on it — mirroring
/// `shared_preferences_windows`.
const _defaultPrefix = 'flutter.';

/// A `SharedPreferencesStorePlatform` that keeps the plugin's JSON file inside
/// the app's own data directory.
///
/// ## Why this exists
///
/// On Windows the plugin resolves its file through
/// `path_provider_windows.getApplicationSupportPath()`, i.e. the Windows Known
/// Folder API. That ignores both the `.portable` marker and the `APPDATA`
/// environment variable, so a portable build still wrote the *developer's*
/// `%APPDATA%\Fluxora\Fluxora\shared_preferences.json`. `AppPath` cannot fix
/// this: the plugin owns that resolution, not us.
///
/// Replacing the store is the only seam. It is installed **only** in portable
/// mode (see [installPortablePrefsStore]) — a normal install keeps the plugin's
/// own store and its existing file untouched.
///
/// The on-disk format is the plugin's: one JSON object mapping
/// `flutter.<key>` to a JSON-encodable value.
class PortablePrefsStore extends SharedPreferencesStorePlatform {
  PortablePrefsStore(this.file, {this.onError});

  /// Where the settings live. Callers pass `<dataDir>/shared_preferences.json`.
  final File file;

  /// Diagnostics sink. Write and parse failures must be visible rather than
  /// silent — a settings file that never lands must not look like success.
  final void Function(Object error, StackTrace stack)? onError;

  Map<String, Object>? _cache;

  /// Serialises writes so two overlapping saves cannot interleave their
  /// tmp-file + rename pairs.
  Future<void> _queue = Future<void>.value();

  Future<Map<String, Object>> _read() async {
    final cached = _cache;
    if (cached != null) return cached;

    final data = <String, Object>{};
    try {
      if (file.existsSync()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value != null) {
              data[key] = value as Object;
            }
          });
        }
      }
    } catch (error, stack) {
      // A corrupt file must not take the app down; start empty and report.
      onError?.call(error, stack);
    }
    return _cache = data;
  }

  /// Atomically replaces the file: tmp → rename. Returns `false` (and reports)
  /// on failure instead of throwing, because `SharedPreferences` treats the
  /// bool as the result of the write.
  Future<bool> _persist() {
    final next = _queue.then((_) async {
      final data = _cache ?? const <String, Object>{};
      final tmp = File('${file.path}.tmp');
      await tmp.parent.create(recursive: true);
      await tmp.writeAsString(json.encode(data), flush: true);
      await tmp.rename(file.path);
    });
    // Keep the chain alive even when one write fails.
    _queue = next.then((_) {}, onError: (Object _, StackTrace _) {});

    return next.then((_) => true, onError: (Object error, StackTrace stack) {
      onError?.call(error, stack);
      return false;
    });
  }

  /// Writes [values] as the initial content. Used by the one-time migration;
  /// returns the same bool contract as [setValue].
  Future<bool> importAll(Map<String, Object> values) async {
    final data = await _read();
    data.addAll(values);
    return _persist();
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
  );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    final data = await _read();
    return <String, Object>{
      for (final entry in data.entries)
        if (entry.key.startsWith(filter.prefix) &&
            (filter.allowList?.contains(entry.key) ?? true))
          entry.key: entry.value,
    };
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final data = await _read();
    data[key] = value;
    return _persist();
  }

  @override
  Future<bool> remove(String key) async {
    final data = await _read();
    data.remove(key);
    return _persist();
  }

  @override
  Future<bool> clear() => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    final data = await _read();
    data.removeWhere(
      (key, _) =>
          key.startsWith(filter.prefix) &&
          (filter.allowList?.contains(key) ?? true),
    );
    return _persist();
  }
}

/// What [installPortablePrefsStore] did.
enum PortablePrefsOutcome {
  /// Not a portable build — the plugin's own store is left in place.
  notPortable,

  /// Portable, and the settings file already existed: nothing was imported.
  reused,

  /// Portable, fresh file, and the legacy settings were imported.
  migrated,

  /// Portable, fresh file, and there was nothing to import.
  created,

  /// Portable, but the legacy settings could not be read. The store is still
  /// installed (so nothing falls back to `%APPDATA%`); the file is left absent
  /// so the next start retries the import.
  legacyReadFailed,
}

/// Installs [PortablePrefsStore] when the app is running from a portable
/// directory, importing the plugin's old settings exactly once.
///
/// Must run **before** the first `SharedPreferences.getInstance()`:
/// `SharedPreferences` caches the store's contents on first read, so a store
/// installed afterwards is ignored for the rest of the process.
///
/// Migration rules:
///
/// * The legacy store is only ever **read**. Nothing writes, deletes or
///   rewrites the old file, so a failed or partial migration can never damage
///   the user's existing settings.
/// * If the portable file already exists it is authoritative — the legacy
///   settings are not merged into it, so a stale import cannot resurrect
///   settings the user has since changed.
/// * If the legacy read fails, the file is not created. The next start retries
///   instead of freezing an empty store in place.
///
/// [dataDir] and [legacyStore] exist for tests and for callers that already
/// resolved a directory; production passes neither.
Future<PortablePrefsOutcome> installPortablePrefsStore({
  Directory? dataDir,
  SharedPreferencesStorePlatform? legacyStore,
}) async {
  final target = dataDir ?? (appPath.isPortable ? await appPath.dataDir.future : null);
  if (target == null) return PortablePrefsOutcome.notPortable;

  final file = File(p.join(target.path, portablePrefsFileName));
  final store = PortablePrefsStore(
    file,
    onError: (error, stack) =>
        commonPrint.log('PortablePrefsStore: $error\n$stack'),
  );

  if (file.existsSync()) {
    SharedPreferencesStorePlatform.instance = store;
    return PortablePrefsOutcome.reused;
  }

  var legacy = const <String, Object>{};
  try {
    legacy = await (legacyStore ?? SharedPreferencesStorePlatform.instance)
        .getAll();
  } catch (error, stack) {
    commonPrint.log(
      'PortablePrefsStore: could not read the legacy settings, starting empty '
      '(the old file is left untouched): $error\n$stack',
    );
    // Install anyway: falling back to the plugin's store here would write
    // %APPDATA%, which is the exact thing portable mode must avoid.
    SharedPreferencesStorePlatform.instance = store;
    return PortablePrefsOutcome.legacyReadFailed;
  }

  final wrote = await store.importAll(legacy);
  SharedPreferencesStorePlatform.instance = store;
  if (!wrote) return PortablePrefsOutcome.legacyReadFailed;
  return legacy.isEmpty
      ? PortablePrefsOutcome.created
      : PortablePrefsOutcome.migrated;
}
