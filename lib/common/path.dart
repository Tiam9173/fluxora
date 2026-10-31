import 'dart:async';
import 'dart:io';

import 'package:fluxora/common/common.dart';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 解析内核二进制的位置。
///
/// 纯函数：所有输入都显式传入，不读全局状态也不碰 Platform。这样测试可以用
/// 同一套规则判断"这台机器上到底有没有内核"，而不是各自拼一份路径猜。
String resolveCorePath({
  required String? devWorkspacePath,
  required String executableDir,
  required bool isWindows,
}) {
  final extension = isWindows ? '.exe' : '';
  if (devWorkspacePath != null) {
    final devPath = join(
      devWorkspacePath,
      'libclash',
      'windows',
      '${AppIdentity.coreExecutableName}$extension',
    );
    if (File(devPath).existsSync()) {
      return devPath;
    }
  }
  return join(executableDir, '${AppIdentity.coreExecutableName}$extension');
}

class AppPath {
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  late String appDirPath;

  /// Whether this run resolved its data directory from a portable marker.
  ///
  /// Synchronous on purpose: `PortablePrefsStore` has to be installed before
  /// the first `SharedPreferences.getInstance()`, and that point is reached
  /// long before [dataDir] completes on a non-portable run (it awaits
  /// `path_provider`). Deciding from the marker alone makes the decision
  /// available immediately.
  late final bool isPortable;

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    final portable = _resolvePortableDir();
    isPortable = portable != null;

    final testDataDir = _testDataDir();
    if (testDataDir != null) {
      // `flutter test`: never resolve against the developer's real profile.
      dataDir.complete(testDataDir);
    } else if (portable != null) {
      dataDir.complete(portable);
    } else {
      getApplicationSupportDirectory().then((value) {
        if (system.isWindows) {
          final roamingAppData = Platform.environment['APPDATA'];
          if (roamingAppData != null && roamingAppData.isNotEmpty) {
            dataDir.complete(
              Directory(join(roamingAppData, AppIdentity.dataDirName)),
            );
          } else {
            dataDir.complete(
              Directory(join(value.parent.parent.path, AppIdentity.dataDirName)),
            );
          }
        } else {
          dataDir.complete(value);
        }
      });
    }
    getTemporaryDirectory().then((value) {
      tempDir.complete(value);
    });
    getDownloadsDirectory().then((value) {
      downloadDir.complete(value);
    });
  }

  /// `<exeDir>/userData` when this is a portable build, else `null`.
  ///
  /// Same rules as before, just extracted so [isPortable] can answer without
  /// waiting on `path_provider`: a `.portable` marker or an existing `userData`
  /// directory next to the executable wins; a directory that cannot be created
  /// falls through to the roaming profile.
  Directory? _resolvePortableDir() {
    if (!system.isWindows) return null;
    final portableMarker = File(join(appDirPath, '.portable'));
    final portableUserData = Directory(join(appDirPath, 'userData'));
    if (!portableMarker.existsSync() && !portableUserData.existsSync()) {
      return null;
    }
    try {
      if (!portableUserData.existsSync()) {
        portableUserData.createSync(recursive: true);
      }
      return portableUserData;
    } catch (_) {
      // If local directory is not writable, fall back to APPDATA
      return null;
    }
  }

  /// A per-process sandbox for `flutter test`, or `null` when not under test.
  ///
  /// [AppPath] is the app's single source of user-writable paths: `config.yaml`,
  /// `chain_proxies.json` (+ `.bak`), the fallback pool, the reliability stats,
  /// `profiles/`, `scripts/`, and the control socket. Under `flutter test` there
  /// is no user to own that data, and the Windows branch above deliberately
  /// reads `Platform.environment['APPDATA']` — the *developer's* real profile,
  /// which no `PathProviderPlatform` fake can redirect.
  ///
  /// That combination was not theoretical: before this guard,
  /// `test/services/android_runtime_validation_test.dart` called
  /// `ChainProxyManager.updateConfig()` without setting
  /// `ChainProxyManager.configFilePathOverride`, so every full `flutter test`
  /// rewrote the real `%APPDATA%\Fluxora\chain_proxies.json`.
  /// `test/services/runtime_lifecycle_hardening_test.dart` documents the same
  /// hazard for the other three persistence files.
  ///
  /// Guarding here — instead of asking each test to opt in — means tests written
  /// later are sandboxed by construction. The `pid` suffix keeps concurrently
  /// running test isolates from sharing one directory.
  static Directory? _testDataDir() {
    if (Platform.environment['FLUTTER_TEST'] != 'true') return null;
    final dir = Directory(
      join(Directory.systemTemp.path, 'fluxora_test_data_$pid'),
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  String get executableExtension {
    return system.isWindows ? '.exe' : '';
  }

  String get executableDirPath {
    final currentExecutablePath = Platform.resolvedExecutable;
    return dirname(currentExecutablePath);
  }

  String get corePath => resolveCorePath(
    devWorkspacePath: _devWorkspacePath,
    executableDir: executableDirPath,
    isWindows: system.isWindows,
  );

  String get helperPath {
    final devWorkspacePath = _devWorkspacePath;
    if (devWorkspacePath != null) {
      final helperPath = join(
        devWorkspacePath,
        'libclash',
        'windows',
        '$appHelperService$executableExtension',
      );
      if (File(helperPath).existsSync()) {
        return helperPath;
      }
    }

    final targetHelper =
        join(executableDirPath, '$appHelperService$executableExtension');
    if (File(targetHelper).existsSync()) {
      return targetHelper;
    }
    // NOTE: this used to fall back to a hardcoded `FluxoraHelperService`, which
    // was provably the same path as `targetHelper` (and is now wrong for debug
    // builds, where the helper is `FluxoraDevHelperService`). Removed instead of
    // left as dead code — `targetHelper` is the correct answer either way.
    return targetHelper;
  }

  String? get _devWorkspacePath {
    if (!system.isWindows || !AppIdentity.isDev) return null;
    var directory = Directory(executableDirPath);
    for (var depth = 0; depth < 8; depth++) {
      final pubspecPath = join(directory.path, 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) return directory.path;

      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }

    return null;
  }

  Future<String> get downloadDirPath async {
    final directory = await downloadDir.future;
    return directory.path;
  }

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get configFilePath async {
    return join(await homeDirPath, 'config.yaml');
  }

  Future<String> get lockFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, '${AppIdentity.dataDirName}.lock');
  }

  Future<String> get controlSocketPath async {
    final directory = await dataDir.future;
    return join(directory.path, '${AppIdentity.dataDirName}.control.sock');
  }

  Future<String> get controlPortFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, '${AppIdentity.dataDirName}.control.port');
  }

  /// Sidecar file used as the cross-process ownership token for the control
  /// channel.
  ///
  /// It must **never be deleted**. Unlinking a lock file lets the next process
  /// create a fresh inode and lock *that* one, so two processes would each
  /// believe they own the channel. One stable inode is what makes the lock mean
  /// anything.
  Future<String> get controlLockFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, '${AppIdentity.dataDirName}.control.lock');
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory.path, 'shared_preferences.json');
  }

  Future<String> get helperAuthKeyPath async {
    final directory = await dataDir.future;
    return join(directory.path, 'helper_auth.key');
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, profilesDirectoryName);
  }

  Future<String> getProfilePath(String id) async {
    final directory = await profilesPath;
    return join(directory, '$id.yaml');
  }

  Future<String> getScriptPath(String id) async {
    final directory = await dataDir.future;
    // `basename` keeps a crafted id (e.g. `../../x`) inside the directory.
    return join(directory.path, 'scripts', '${basename(id)}.js');
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id);
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(directory, 'providers', id, type, url.toMd5());
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }

  Future<String> get uiPath async {
    final directory = await dataDir.future;
    return join(directory.path, 'ui');
  }
}

final appPath = AppPath();
