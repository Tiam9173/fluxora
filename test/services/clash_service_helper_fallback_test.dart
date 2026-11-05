import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/common.dart';
// Test-only: both are transitive dependencies of `path_provider`. `AppPath`
// resolves its temp/download dirs through it, and the platform interface throws
// before any channel mock can answer in a VM test.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P7-D2-R2 — the Windows helper → core fallback inside `ClashService`.
///
/// The production chain is
///
/// ```
/// ClashService._initTransport()            service.dart
///   → reStart() → _doRestart()
///     → if (system.isWindows) {
///          windows?.registerService()      ← probe
///          helperClient.startCore(...)     ← helper
///          if (!started) log('… falling back to normal mode')
///        }
///     → Process.start(corePath, [arg])    ← fallback
/// ```
///
/// Three collaborators sit outside the socket and none can be reached from a
/// test: the `windows` probe and `helperClient` are library globals, and
/// `Process.start` is not interceptable through `IOOverrides`. They are
/// replaced through [ClashServiceStartHooks], which production leaves `null`.
///
/// **This file runs on a real Windows host.** It drives `system.isWindows`,
/// which reads the real `dart:io Platform` — no `System.platformOverride` is
/// used, and each test asserts the host really is Windows so a non-Windows run
/// fails loudly instead of passing vacuously.
/// Reason attached to the five Windows-branch tests when the host is not
/// Windows.
///
/// `test.yaml` runs on `ubuntu-latest`. Each test below drives
/// `system.isWindows` and asserts the host really is Windows, so without this
/// guard the whole job would go red on Linux instead of skipping the five tests
/// that can only run on Windows. The `expect` stays: on Windows it still proves
/// the branch is real, and a skip never reaches it elsewhere.
const _windowsOnly = 'Windows-only: requires Windows platform';

void main() {
  // `_initServer`'s error handler reaches `globalState.showNotifier`, which
  // needs `WidgetsBinding.instance`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  ClashService? service;

  setUpAll(() async {
    sandbox = Directory.systemTemp.createTempSync('fluxora_p7d2r2_path_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() async {
    try {
      await sandbox.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    ClashService.resetForTest();
    ClashService.skipTransportForTest = false;
    // The constructor kicks off its own `reStart()`. Keep it at the guard until
    // the test has installed its hooks, so no real helper is ever probed.
    ClashService.skipCoreSpawnForTest = true;
    ClashService.startHooksForTest = null;
  });

  tearDown(() async {
    final s = service;
    service = null;
    if (s != null) {
      try {
        await s.destroy();
      } catch (_) {}
    }
    ClashService.startHooksForTest = null;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.skipTransportForTest = true;
    ClashService.resetForTest();
  });

  /// Binds the socket, settles the constructor's own restart at the guard, and
  /// then opens the guard so the next `reStart()` runs the real flow exactly
  /// once.
  Future<ClashService> startService() async {
    final s = ClashService();
    service = s;
    await s.preload();

    // Queue behind the constructor's restart. Both stop at
    // `skipCoreSpawnForTest`, so neither touches the helper or the launcher.
    await s.reStart();

    ClashService.skipCoreSpawnForTest = false;
    return s;
  }

  /// Unblocks `_waitForCoreReady` so the flow finishes instead of sitting on the
  /// 5 s timeout. Nothing in these tests touches the socket itself.
  void markReady(ClashService s) {
    if (!s.socketCompleter.isCompleted) {
      s.socketCompleter.complete(_ReadySocket());
    }
  }

  group('helper → core fallback', () {
    test('a helper start failure falls back to launching the core', () async {
      expect(Platform.isWindows, isTrue, reason: 'drives the Windows branch');

      final helperCalls = <({String corePath, String arg, String homeDir})>[];
      final launches = <({String corePath, String arg, String? safePaths})>[];
      late ClashService s;

      ClashService.startHooksForTest = ClashServiceStartHooks(
        registerService: () async => true,
        startCore: ({required corePath, required arg, required homeDir}) async {
          helperCalls.add((corePath: corePath, arg: arg, homeDir: homeDir));
          return false;
        },
        launchCore: (corePath, arg, environment) async {
          launches.add((
            corePath: corePath,
            arg: arg,
            safePaths: environment['SAFE_PATHS'],
          ));
          markReady(s);
        },
      );

      s = await startService();
      await s.reStart();

      final homeDir = await appPath.homeDirPath;

      expect(helperCalls, hasLength(1), reason: 'asked once');
      expect(launches, hasLength(1), reason: 'launched once');

      // SEC-P0-01 — the helper is handed the **protected** copy. The bundle
      // copy lives in a user-writable directory, and the helper refuses any
      // core outside its own directory, so sending that one would be a
      // guaranteed rejection (and an attempt to have SYSTEM run it).
      final protectedCore = appPath.protectedCorePath;
      expect(
        protectedCore,
        isNotNull,
        reason: '%ProgramFiles% resolves on a real Windows host',
      );
      expect(helperCalls.single.corePath, protectedCore);
      expect(
        helperCalls.single.corePath,
        isNot(appPath.corePath),
        reason: 'the user-writable bundle core must never reach the helper',
      );
      expect(helperCalls.single.homeDir, homeDir);
      expect(
        helperCalls.single.arg,
        launches.single.arg,
        reason: 'helper and core get the same transport argument',
      );

      expect(launches.single.corePath, appPath.corePath);
      expect(launches.single.safePaths, homeDir);
      expect(
        launches.single.arg,
        anyOf(endsWith('.sock'), matches(RegExp(r'^\d+$'))),
        reason: 'the core is handed the socket path or the TCP port',
      );

      expect(
        s.process,
        isNull,
        reason: 'the launcher was a stand-in — no real core was spawned',
      );
    }, skip: Platform.isWindows ? false : _windowsOnly);

    test('a failed service registration skips the helper entirely', () async {
      expect(Platform.isWindows, isTrue, reason: 'drives the Windows branch');

      var helperCalls = 0;
      final launches = <String>[];
      late ClashService s;

      ClashService.startHooksForTest = ClashServiceStartHooks(
        registerService: () async => false,
        startCore: ({required corePath, required arg, required homeDir}) async {
          helperCalls++;
          return true;
        },
        launchCore: (corePath, arg, environment) async {
          launches.add(corePath);
          markReady(s);
        },
      );

      s = await startService();
      await s.reStart();

      expect(
        helperCalls,
        0,
        reason: 'no service means there is nothing to ask the helper for',
      );
      expect(launches, [appPath.corePath], reason: 'launched exactly once');
    }, skip: Platform.isWindows ? false : _windowsOnly);

    test('a successful helper start never launches a second core', () async {
      expect(Platform.isWindows, isTrue, reason: 'drives the Windows branch');

      var helperCalls = 0;
      var launches = 0;
      late ClashService s;

      ClashService.startHooksForTest = ClashServiceStartHooks(
        registerService: () async => true,
        startCore: ({required corePath, required arg, required homeDir}) async {
          helperCalls++;
          markReady(s);
          return true;
        },
        launchCore: (corePath, arg, environment) async {
          launches++;
        },
      );

      s = await startService();
      await s.reStart();

      expect(helperCalls, 1, reason: 'the helper started the core');
      expect(launches, 0, reason: 'no fallback when the helper succeeded');
      expect(s.process, isNull);
      expect(
        s.isStarting,
        isFalse,
        reason: 'the helper path settles the starting flag',
      );
    }, skip: Platform.isWindows ? false : _windowsOnly);

    test(
      'a failing core launch propagates and leaves no started state',
      () async {
        expect(Platform.isWindows, isTrue, reason: 'drives the Windows branch');

        ClashService.startHooksForTest = ClashServiceStartHooks(
          registerService: () async => false,
          launchCore: (corePath, arg, environment) async {
            throw const FileSystemException('core binary is missing');
          },
        );

        final s = await startService();

        await expectLater(
          s.reStart(),
          throwsA(isA<FileSystemException>()),
          reason: '`reStart()` has no catch, so the launcher error reaches it',
        );

        expect(
          s.process,
          isNull,
          reason: 'a failed launch must not leave a process behind',
        );
        expect(
          s.hasLiveProcess,
          isFalse,
          reason: 'no false "core is running" state',
        );
        // P7-D2-R3: `reStart()`'s `finally` clears the flag on every exit,
        // including this throw. Before the fix it stayed `true` forever, which
        // made `checkCoreHealth()` report "still starting" for the rest of the
        // instance's life.
        expect(
          s.isStarting,
          isFalse,
          reason: 'a failed launch must not leave the service "starting"',
        );
      },
      skip: Platform.isWindows ? false : _windowsOnly,
    );

    test('a throwing helper also restores the starting state', () async {
      expect(Platform.isWindows, isTrue, reason: 'drives the Windows branch');

      ClashService.startHooksForTest = ClashServiceStartHooks(
        registerService: () async => true,
        startCore: ({required corePath, required arg, required homeDir}) async {
          throw const FileSystemException('helper pipe vanished');
        },
      );

      final s = await startService();

      await expectLater(
        s.reStart(),
        throwsA(isA<FileSystemException>()),
        reason: 'the helper error must reach the caller unchanged',
      );

      expect(s.isStarting, isFalse, reason: 'the flag must not stay set');
      expect(s.process, isNull);
    }, skip: Platform.isWindows ? false : _windowsOnly);
  });
}

/// A `Socket` that exists only to complete `socketCompleter`.
final class _ReadySocket implements Socket {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Same shape as the fake in `external_control_ownership_test.dart`; duplicated
/// so this file stays independent of that one.
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
  Future<String?> getExternalStoragePath() async => dir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [dir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [dir.path];

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}
