import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:path/path.dart' as p;
// Test-only: both are transitive dependencies of `path_provider`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// Test-only: a direct transitive of `shared_preferences`. The store under test
// implements this interface, so the test has to see it too.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A legacy store that can be read but never written.
///
/// Portable mode imports the settings the plugin wrote to the Windows Known
/// Folder. That file belongs to the user, so the migration must be read-only —
/// this store makes any write throw instead of trusting a comment.
class _ReadOnlyLegacyStore extends InMemorySharedPreferencesStore {
  _ReadOnlyLegacyStore(super.data) : super.withData();

  int reads = 0;

  @override
  Future<Map<String, Object>> getAll() {
    reads++;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw StateError('the legacy store must never be written');

  @override
  Future<bool> remove(String key) =>
      throw StateError('the legacy store must never be written');

  @override
  Future<bool> clear() =>
      throw StateError('the legacy store must never be written');

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      throw StateError('the legacy store must never be written');
}

/// A legacy store whose read fails, standing in for an unreadable or corrupt
/// `%APPDATA%` file.
class _UnreadableLegacyStore extends InMemorySharedPreferencesStore {
  _UnreadableLegacyStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async =>
      throw const FileSystemException('legacy settings unreadable');
}

/// `AppPath` calls `getDownloadsDirectory()` the first time it is touched, and
/// the test host has no platform implementation for it — the same hazard
/// `test/models/script_test.dart` documents. A fake keeps the singleton's
/// init from raising an unhandled async error.
class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory hostSupport;
  late SharedPreferencesStorePlatform originalStore;

  setUpAll(() async {
    originalStore = SharedPreferencesStorePlatform.instance;
    hostSupport = await Directory.systemTemp.createTemp('fluxora_host_support_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(hostSupport);
  });

  tearDownAll(() async {
    if (hostSupport.existsSync()) {
      await hostSupport.delete(recursive: true);
    }
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('fluxora_portable_prefs_');
  });

  tearDown(() async {
    SharedPreferencesStorePlatform.instance = originalStore;
    SharedPreferences.resetStatic();
    if (sandbox.existsSync()) {
      await sandbox.delete(recursive: true);
    }
  });

  File prefsFile(Directory dir) => File(p.join(dir.path, portablePrefsFileName));

  Map<String, dynamic> readJson(File file) =>
      json.decode(file.readAsStringSync()) as Map<String, dynamic>;

  test('a non-portable install leaves the plugin store alone', () async {
    // No `dataDir` and no `.portable` marker next to the test host, so this is
    // the "normal installation" branch: nothing is installed, nothing is read.
    final before = SharedPreferencesStorePlatform.instance;

    final outcome = await installPortablePrefsStore();

    expect(outcome, PortablePrefsOutcome.notPortable);
    expect(
      identical(SharedPreferencesStorePlatform.instance, before),
      isTrue,
      reason: 'a normal install must keep the plugin store and its file',
    );
    expect(sandbox.listSync(), isEmpty);
  });

  test('portable mode installs a store that writes into the data dir', () async {
    final outcome = await installPortablePrefsStore(
      dataDir: sandbox,
      // Nothing to import on a first portable start with no prior settings.
      legacyStore: InMemorySharedPreferencesStore.empty(),
    );

    expect(outcome, PortablePrefsOutcome.created);
    final store = SharedPreferencesStorePlatform.instance;
    expect(store, isA<PortablePrefsStore>());

    // Real write + real read through the store, not just a path assertion.
    await store.setValue('String', 'flutter.theme', 'aurora');
    final file = prefsFile(sandbox);
    expect(file.existsSync(), isTrue);
    expect(readJson(file)['flutter.theme'], 'aurora');

    final all = await store.getAll();
    expect(all['flutter.theme'], 'aurora');

    expect(
      sandbox.listSync().map((e) => p.basename(e.path)),
      contains(portablePrefsFileName),
      reason: 'the only file created must be the settings file',
    );
  });

  test('an existing portable file is authoritative, not overwritten', () async {
    prefsFile(sandbox).writeAsStringSync(
      json.encode(<String, Object>{'flutter.theme': 'portable-current'}),
    );
    final legacy = _ReadOnlyLegacyStore(<String, Object>{
      'flutter.theme': 'legacy-stale',
      'flutter.extra': 'should-not-be-imported',
    });

    final outcome = await installPortablePrefsStore(
      dataDir: sandbox,
      legacyStore: legacy,
    );

    expect(outcome, PortablePrefsOutcome.reused);
    expect(legacy.reads, 0, reason: 'a stale import must not even be read');
    final stored = readJson(prefsFile(sandbox));
    expect(stored['flutter.theme'], 'portable-current');
    expect(stored.containsKey('flutter.extra'), isFalse);
  });

  test('first portable start imports the legacy settings', () async {
    final legacy = _ReadOnlyLegacyStore(<String, Object>{
      'flutter.theme': 'dark',
      'flutter.windowWidth': 1200,
      'flutter.mode': 'system',
    });

    final outcome = await installPortablePrefsStore(
      dataDir: sandbox,
      legacyStore: legacy,
    );

    expect(outcome, PortablePrefsOutcome.migrated);
    final stored = readJson(prefsFile(sandbox));
    expect(stored['flutter.theme'], 'dark');
    expect(stored['flutter.windowWidth'], 1200);
    expect(stored['flutter.mode'], 'system');

    // Read-only contract: every write path on the legacy store throws, and the
    // migration completed, so nothing tried.
    expect(legacy.reads, 1);
    expect(
      (await legacy.getAll())['flutter.theme'],
      'dark',
      reason: 'the legacy store must still hold its data after the import',
    );
  });

  test('an unreadable legacy store leaves no file behind to retry', () async {
    final outcome = await installPortablePrefsStore(
      dataDir: sandbox,
      legacyStore: _UnreadableLegacyStore(),
    );

    expect(outcome, PortablePrefsOutcome.legacyReadFailed);
    expect(
      prefsFile(sandbox).existsSync(),
      isFalse,
      reason:
          'creating an empty file here would freeze the failed import: the next '
          'start would see `reused` and never try again',
    );
    // The store is still installed so nothing can fall back to %APPDATA%.
    expect(
      SharedPreferencesStorePlatform.instance,
      isA<PortablePrefsStore>(),
    );
  });

  test('installing twice reuses the file instead of re-importing', () async {
    final legacy = _ReadOnlyLegacyStore(<String, Object>{
      'flutter.theme': 'dark',
    });

    expect(
      await installPortablePrefsStore(dataDir: sandbox, legacyStore: legacy),
      PortablePrefsOutcome.migrated,
    );
    final afterFirst = readJson(prefsFile(sandbox));

    // Second start, same data dir, legacy now reports different values — they
    // must be ignored.
    final secondLegacy = _ReadOnlyLegacyStore(<String, Object>{
      'flutter.theme': 'light',
      'flutter.injected': true,
    });
    expect(
      await installPortablePrefsStore(
        dataDir: sandbox,
        legacyStore: secondLegacy,
      ),
      PortablePrefsOutcome.reused,
    );

    expect(readJson(prefsFile(sandbox)), afterFirst);
    expect(secondLegacy.reads, 0);
  });

  test('SharedPreferences round-trips through the portable file', () async {
    await installPortablePrefsStore(
      dataDir: sandbox,
      legacyStore: InMemorySharedPreferencesStore.empty(),
    );
    // The plugin caches the store's contents on first read, so the store has to
    // be in place before this call — which is exactly what `main()` guarantees.
    SharedPreferences.resetStatic();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('__isolation_probe__', 'portable');
    await prefs.setInt('__isolation_count__', 7);

    final stored = readJson(prefsFile(sandbox));
    expect(stored['flutter.__isolation_probe__'], 'portable');
    expect(stored['flutter.__isolation_count__'], 7);

    // And the developer's real settings file is not involved at all.
    final roaming = Platform.environment['APPDATA'];
    if (roaming != null && roaming.isNotEmpty) {
      final real = File(
        p.join(roaming, 'Fluxora', 'Fluxora', 'shared_preferences.json'),
      );
      if (real.existsSync()) {
        expect(
          p.isWithin(sandbox.path, real.path),
          isFalse,
          reason: 'sanity: the real file is not inside the sandbox',
        );
        expect(
          readJson(real).containsKey('flutter.__isolation_probe__'),
          isFalse,
          reason: 'the probe key must never reach the real settings file',
        );
      }
    }
  });

  test('a store registered explicitly is the one the plugin uses', () async {
    // Requirement: tests may register a fake store instead of relying on a real
    // platform implementation.
    final fake = InMemorySharedPreferencesStore.withData(<String, Object>{
      'flutter.seeded': 'yes',
    });
    SharedPreferencesStorePlatform.instance = fake;
    SharedPreferences.resetStatic();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seeded'), 'yes');

    await prefs.setString('written', 'in-memory');
    expect(
      await fake.getAll(),
      containsPair('flutter.written', 'in-memory'),
    );
    expect(prefsFile(sandbox).existsSync(), isFalse);
  });

  // ── Storage-contract checks (audit of the round-20 store) ─────────────────

  test('every value type survives a restart through the file', () async {
    // Migration compatibility is only proven if the file round-trips with the
    // plugin's own type semantics — a fresh store reading the same bytes must
    // hand back the same typed values.
    await installPortablePrefsStore(
      dataDir: sandbox,
      legacyStore: InMemorySharedPreferencesStore.empty(),
    );
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flag', true);
    await prefs.setInt('count', 42);
    await prefs.setDouble('ratio', 1.5);
    await prefs.setString('name', 'aurora');
    await prefs.setStringList('list', <String>['a', 'b']);

    // "Restart": brand-new store over the same file, fresh plugin cache.
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = PortablePrefsStore(
      prefsFile(sandbox),
    );
    final reopened = await SharedPreferences.getInstance();

    expect(reopened.getBool('flag'), isTrue);
    expect(reopened.getInt('count'), 42);
    expect(reopened.getDouble('ratio'), 1.5);
    expect(reopened.getString('name'), 'aurora');
    expect(reopened.getStringList('list'), <String>['a', 'b']);
  });

  test('a failed write does not poison later writes', () async {
    final file = prefsFile(sandbox);
    final errors = <Object>[];
    final store = PortablePrefsStore(file, onError: (e, _) => errors.add(e));

    // A directory where the tmp file should go makes the write fail.
    final blocker = Directory('${file.path}.tmp')
      ..createSync(recursive: true);

    expect(await store.setValue('String', 'flutter.a', 'one'), isFalse);
    expect(errors, isNotEmpty, reason: 'a failed write must be reported');

    blocker.deleteSync();
    expect(
      await store.setValue('String', 'flutter.b', 'two'),
      isTrue,
      reason: 'the write queue must recover after a failure',
    );
    expect(readJson(file)['flutter.b'], 'two');
  });

  test('overlapping writes are serialised, not interleaved', () async {
    final file = prefsFile(sandbox);
    final store = PortablePrefsStore(file);

    // All three share the same tmp path; without the queue they would clobber
    // each other's rename.
    final results = await Future.wait(<Future<bool>>[
      store.setValue('String', 'flutter.k1', 'v1'),
      store.setValue('String', 'flutter.k2', 'v2'),
      store.setValue('String', 'flutter.k3', 'v3'),
    ]);

    expect(results, everyElement(isTrue));
    final stored = readJson(file);
    expect(stored['flutter.k1'], 'v1');
    expect(stored['flutter.k2'], 'v2');
    expect(stored['flutter.k3'], 'v3');
  });
}
