import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// `shared_preferences` must never reach the developer's real profile under
/// `flutter test`.
///
/// Unlike `AppPath` — which resolves `%APPDATA%\Fluxora` from the environment
/// and needed the `_testDataDir()` guard — the prefs plugin resolves its file
/// through `path_provider_windows`, which is **not registered** in a test
/// process. There is no store at all: `SharedPreferences.getInstance()` throws
/// `MissingPluginException`, `Preferences` swallows it and completes with
/// `null`, and nothing is written anywhere.
///
/// That is a structural guarantee, not an accident of the current test list, so
/// it is pinned here. If a future change ever registers a real store in tests,
/// the first assertion fails and the author has to think about the write path
/// before landing it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The file the plugin writes in a real run. Metadata only — never read.
  File? realPrefsFile() {
    final roaming = Platform.environment['APPDATA'];
    if (roaming == null || roaming.isEmpty) return null;
    return File(p.join(roaming, 'Fluxora', 'Fluxora', 'shared_preferences.json'));
  }

  test('no preferences store exists in a test process', () async {
    Object? error;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      error = e;
    }

    expect(
      prefs,
      isNull,
      reason:
          'a live store in tests means the plugin found a writable location — '
          'check that it is sandboxed before allowing this',
    );
    expect(
      error,
      isNotNull,
      reason: 'no store and no error would mean a silent in-memory fallback',
    );
  });

  test('asking for preferences does not touch the real profile', () async {
    final file = realPrefsFile();
    if (file == null || !file.existsSync()) {
      // Nothing on disk to protect on this machine; the other assertions still
      // hold, so this is not a skip — there is simply no file to compare.
      return;
    }

    final before = file.statSync();

    try {
      await SharedPreferences.getInstance();
    } catch (_) {
      // Expected: no platform implementation.
    }

    final after = file.statSync();
    expect(after.modified, before.modified, reason: 'mtime changed');
    expect(after.size, before.size, reason: 'size changed');
  });

  test('a mocked store keeps writes in memory, not on disk', () async {
    // `setMockInitialValues` is the sanctioned way for a test to get a working
    // store. It installs an in-memory implementation, so even a test that
    // writes settings cannot create a file.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final file = realPrefsFile();
    final before = (file != null && file.existsSync()) ? file.statSync() : null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('__isolation_probe__', 'written');
    await prefs.reload();

    expect(prefs.getString('__isolation_probe__'), 'written');

    if (file != null && before != null && file.existsSync()) {
      final after = file.statSync();
      expect(after.modified, before.modified, reason: 'mtime changed');
      expect(after.size, before.size, reason: 'size changed');
    }
  });
}
