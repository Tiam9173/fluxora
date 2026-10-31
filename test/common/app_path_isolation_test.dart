import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Test-only: both are transitive dependencies of `path_provider`. A fake is
// installed on purpose here — see the note on the first test.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:path/path.dart' as p;

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

/// Every path the app can write must resolve inside the test sandbox.
///
/// `AppPath` is the single source of user-writable locations. On Windows the
/// resolution used to fall through to `Platform.environment['APPDATA']` — the
/// *developer's* real profile — because that branch never consults
/// `PathProviderPlatform`. A test that faked `path_provider` therefore still
/// wrote the real `%APPDATA%\Fluxora\chain_proxies.json`;
/// `test/services/android_runtime_validation_test.dart` did exactly that on
/// every full run.
///
/// `AppPath._testDataDir()` now short-circuits the whole resolution under
/// `flutter test`. The fake installed below is deliberately **not** the sandbox:
/// it proves the guard wins regardless of what the plugin reports.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeSupport;

  setUpAll(() async {
    fakeSupport = await Directory.systemTemp.createTemp(
      'fluxora_fake_support_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(fakeSupport);
  });

  tearDownAll(() async {
    if (fakeSupport.existsSync()) {
      await fakeSupport.delete(recursive: true);
    }
  });

  test('the data dir is a per-process sandbox, not the faked support dir', () async {
    final dataDir = await appPath.homeDirPath;

    expect(
      p.isWithin(Directory.systemTemp.path, dataDir),
      isTrue,
      reason: 'the test data dir must live under the temp root, was: $dataDir',
    );
    expect(
      p.basename(dataDir),
      startsWith('fluxora_test_data_'),
      reason: 'one directory per test process keeps parallel files apart',
    );
    expect(
      p.isWithin(fakeSupport.path, dataDir),
      isFalse,
      reason:
          'the guard must win over the plugin — otherwise faking path_provider '
          'would still let the Windows APPDATA branch through',
    );
    expect(
      Directory(dataDir).existsSync(),
      isTrue,
      reason: 'the sandbox has to exist before anything writes into it',
    );
  });

  test('every writable path getter resolves inside the sandbox', () async {
    final sandbox = await appPath.homeDirPath;
    final paths = <String, String>{
      'config.yaml': await appPath.configFilePath,
      'profiles/': await appPath.profilesPath,
      'scripts/': await appPath.getScriptPath('example'),
      'ui/': await appPath.uiPath,
      'shared_preferences.json': await appPath.sharedPreferencesPath,
      'helper_auth.key': await appPath.helperAuthKeyPath,
      'lock': await appPath.lockFilePath,
      'control socket': await appPath.controlSocketPath,
    };

    for (final entry in paths.entries) {
      expect(
        p.isWithin(sandbox, entry.value),
        isTrue,
        reason: '${entry.key} resolved outside the sandbox: ${entry.value}',
      );
    }
  });

  test(
    'a chain config write lands in the sandbox, never the real profile',
    () async {
      // The exact call the leak came from: `updateConfig` → `_saveConfig`
      // → `_getConfigFilePath` → `appPath.homeDirPath`.
      ChainProxyManager.coreRunningOverride = true;
      addTearDown(() => ChainProxyManager.coreRunningOverride = null);

      final manager = ChainProxyManager();
      await manager.updateConfig(
        (config) => config.copyWith(enable: false),
        reloadCore: false,
      );

      final written = File(
        p.join(await appPath.homeDirPath, 'chain_proxies.json'),
      );
      expect(
        written.existsSync(),
        isTrue,
        reason: 'the persisted chain config must land in the sandbox',
      );

      final roaming = Platform.environment['APPDATA'];
      if (roaming != null && roaming.isNotEmpty) {
        expect(
          p.isWithin(p.join(roaming, 'Fluxora'), written.path),
          isFalse,
          reason: 'nothing may be written into the developer profile',
        );
      }
    },
  );
}
