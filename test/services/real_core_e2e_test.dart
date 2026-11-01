import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:path/path.dart' as p;
// Test-only: both are transitive dependencies of `path_provider`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P7-D3 — the real Mihomo core, end to end.
///
/// **Opt-in only.** The default `flutter test` run skips every test in this file;
/// nothing here runs unless `FLUXORA_REAL_CORE_TEST=1` is set:
///
/// ```
/// FLUXORA_REAL_CORE_TEST=1 flutter test test/services/real_core_e2e_test.dart
/// ```
///
/// What is real: the production `ClashService` start path, `Process.start` on the
/// repo's built core, the AF_UNIX socket the core dials back on, and every RPC
/// reply. Nothing is mocked — the only injection is
/// `AppPath.corePathOverrideForTest`, which points `corePath` at the repo build
/// because a VM test runs from the Flutter SDK's `flutter_tester` directory.
///
/// Isolation: the data/home directory is a throwaway temp dir, the socket is
/// per-process unique, the core never loads a user profile, and nothing touches
/// the system proxy, DNS, routes or firewall. Every test kills its core in
/// `tearDown` even when it fails.
final bool _enabled =
    Platform.environment['FLUXORA_REAL_CORE_TEST'] == '1';

final String _corePath = p.join(
  Directory.current.path,
  'libclash',
  'windows',
  'FluxoraDevCore.exe',
);

String _skipReason() {
  if (!_enabled) {
    return 'real-core E2E is opt-in: set FLUXORA_REAL_CORE_TEST=1';
  }
  if (!File(_corePath).existsSync()) {
    return 'core binary not found at $_corePath';
  }
  if (!Platform.isWindows) {
    return 'this file drives the Windows core build';
  }
  return '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final skip = _skipReason();

  late Directory sandbox;
  ClashService? service;

  setUpAll(() async {
    sandbox = Directory.systemTemp.createTempSync('fluxora_p7d3_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() async {
    try {
      await sandbox.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    AppPath.corePathOverrideForTest = _corePath;
    ClashService.resetForTest();
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    // Never touch the Windows service: `registerService()` runs `sc query` and,
    // when the helper looks unhealthy, an elevated `sc create` through `runas`.
    // Reporting "no service" sends `_doRestart` straight to the real
    // `Process.start` fallback, which is the path this file is about.
    ClashService.startHooksForTest = ClashServiceStartHooks(
      registerService: () async => false,
    );
  });

  tearDown(() async {
    final s = service;
    service = null;
    if (s != null) {
      try {
        await Future<void>.value(s.destroy()).timeout(
          const Duration(seconds: 10),
        );
      } catch (_) {}
      // Last resort: never leave a core behind, even if destroy() failed.
      try {
        s.process?.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    AppPath.corePathOverrideForTest = null;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.skipTransportForTest = true;
    ClashService.resetForTest();
  });

  /// The core's control sockets that **this process** created.
  ///
  /// `_initTransport` puts them in `Directory.systemTemp` (not `appPath`), and
  /// `flutter test` runs files in parallel, so the set is scoped to this pid.
  Set<String> coreSockets() => Directory.systemTemp
      .listSync(followLinks: false)
      .map((e) => e.path)
      .where(
        (path) =>
            path.endsWith('.sock') &&
            path.split(Platform.pathSeparator).last.startsWith('Fluxora_${pid}_'),
      )
      .toSet();

  /// Binds, lets the constructor's own `reStart()` spawn the core, and waits for
  /// the core to dial back — which is the production "core is reachable" signal.
  Future<ClashService> bootCore({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final s = ClashService();
    service = s;
    await s.preload();
    await s.socketCompleter.future.timeout(timeout);
    return s;
  }

  /// Sends one real RPC. `onTimeout` throws, so a returned value is always a
  /// genuine reply rather than `invoke`'s default.
  Future<T> rpc<T>(
    ClashService s,
    ActionMethod method, {
    Object? data,
  }) {
    return s.invoke<T>(
      method: method,
      data: data,
      timeout: const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('no reply for ${method.name}'),
    );
  }

  test(
    'T1 — the real core starts, stays alive, and its channel comes up',
    () async {
      final s = await bootCore();

      final process = s.process;
      expect(process, isNotNull, reason: 'the OS must have a core process');
      expect(process!.pid, greaterThan(0));
      expect(
        s.socketCompleter.isCompleted,
        isTrue,
        reason: 'the core dialled back on the control socket',
      );

      // A core that dies immediately would still have produced a pid.
      var exited = false;
      unawaited(process.exitCode.then((_) => exited = true));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(
        exited,
        isFalse,
        reason: 'the core must still be running 800 ms after start',
      );
      // ignore: avoid_print
      print('P7D3 T1 pid=${process.pid}');
    },
    skip: skip.isEmpty ? false : skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'T2 — real RPC round trips and observes a state change',
    () async {
      final s = await bootCore();

      // `getIsInit` returns the `bool` default (`false`) on timeout, so the
      // timeout callback above throws — a returned value is a real reply.
      expect(
        await rpc<bool>(s, ActionMethod.getIsInit),
        isFalse,
        reason: 'a fresh core has no config loaded yet',
      );

      expect(
        await rpc<bool>(
          s,
          ActionMethod.initClash,
          data: jsonEncodeInit(sandbox.path),
        ),
        isTrue,
        reason: 'initClash must be acknowledged by the core',
      );

      expect(
        await rpc<bool>(s, ActionMethod.getIsInit),
        isTrue,
        reason: 'the same call must now report the new state',
      );

      final proxies = await rpc<Map>(s, ActionMethod.getProxies);
      expect(proxies, isA<Map>());
      // ignore: avoid_print
      print('P7D3 T2 getIsInit=false→true, getProxies keys=${proxies.length}');
    },
    skip: skip.isEmpty ? false : skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'T3 — reStart replaces the core process',
    () async {
      final s = await bootCore();
      final first = s.process!;
      final firstPid = first.pid;

      await s.reStart().timeout(const Duration(seconds: 60));

      final second = s.process;
      expect(second, isNotNull, reason: 'a new core must be running');
      expect(
        second!.pid,
        isNot(firstPid),
        reason: 'the restart must produce a different OS process',
      );
      expect(
        await first.exitCode.timeout(const Duration(seconds: 10)),
        isNotNull,
        reason: 'the old core must have exited',
      );
      expect(
        s.socketCompleter.isCompleted,
        isTrue,
        reason: 'the new core dialled back',
      );
      // The new process really answers.
      expect(await rpc<bool>(s, ActionMethod.getIsInit), isFalse);
      // ignore: avoid_print
      print('P7D3 T3 $firstPid → ${second.pid}');
    },
    skip: skip.isEmpty ? false : skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'T4 — shutdown stops the core and releases the control socket',
    () async {
      final before = coreSockets();
      final s = await bootCore();
      final process = s.process!;

      expect(
        coreSockets().difference(before),
        hasLength(1),
        reason: 'precondition: the control socket exists while running',
      );

      await s.shutdown().timeout(const Duration(seconds: 30));

      expect(
        await process.exitCode.timeout(const Duration(seconds: 15)),
        isNotNull,
        reason: 'the core process must exit',
      );
      expect(s.process, isNull);
      expect(
        coreSockets().difference(before),
        isEmpty,
        reason: 'the control socket must be released, not left behind',
      );
      // ignore: avoid_print
      print('P7D3 T4 pid=${process.pid} exited, socket released');
    },
    skip: skip.isEmpty ? false : skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'T5 — a failed launch leaks nothing and the next start still works',
    () async {
      // A path that cannot exist: `Process.start` throws before any child is
      // created, which is the production failure this test is about.
      AppPath.corePathOverrideForTest = p.join(
        sandbox.path,
        'no-such-core.exe',
      );

      final s = ClashService();
      service = s;
      await s.preload();

      await expectLater(
        s.reStart().timeout(const Duration(seconds: 30)),
        throwsA(isA<ProcessException>()),
        reason: 'the launcher error must reach the caller',
      );
      expect(s.process, isNull, reason: 'no half-started core');
      expect(
        s.isStarting,
        isFalse,
        reason: 'P7-D2-R3: the flag must not stay set after a throw',
      );

      // Same instance, real binary: the channel must recover.
      AppPath.corePathOverrideForTest = _corePath;
      await s.reStart().timeout(const Duration(seconds: 60));
      await s.socketCompleter.future.timeout(const Duration(seconds: 30));

      expect(s.process, isNotNull, reason: 'the retry must bring a core up');
      expect(await rpc<bool>(s, ActionMethod.getIsInit), isFalse);
      // ignore: avoid_print
      print('P7D3 T5 recovered on pid=${s.process!.pid}');
    },
    skip: skip.isEmpty ? false : skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// `initClash` only needs the home dir and a protocol version (`core/hub.go:97`).
String jsonEncodeInit(String homeDir) =>
    '{"home-dir":${_jsonString(homeDir)},"version":1}';

String _jsonString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"');
  return '"$escaped"';
}

/// Same shape as the fake in `external_control_ownership_test.dart`.
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
