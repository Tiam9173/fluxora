import 'dart:async';
import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `AppPath` resolves temp/download dirs through path_provider, whose
// platform interface throws in a VM test before any channel mock can answer.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P9-S08 — an unconfirmed `core.stop` must **block** the next start.
///
/// S07 kept the ownership claim when the stop failed, but still started a new
/// core. That leaves two cores alive and only one of them tracked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() {
    sandbox = Directory.systemTemp.createTempSync('fluxora_p9s08_path_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() {
    try {
      sandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(milliseconds: 30);
    ClashService.startHooksForTest = null;
    ClashService.resetForTest();
  });

  tearDown(() {
    ClashService.startHooksForTest = null;
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(seconds: 5);
    ClashService.resetForTest();
  });

  Future<void> settleFirstStart(ClashService service) async {
    for (var i = 0; i < 200 && service.lastStartFailure == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(service.lastStartFailure, isNotNull);
    service.lastStartFailure = null;
  }

  // Windows-only: `_doRestart` only enters the helper branch under
  // `if (system.isWindows && _coreStartedViaHelper)` (service.dart:425). Off
  // Windows that branch is unreachable by design, so the claim this test sets up
  // is cleared immediately and the guard can never fire — the failure there is
  // "core did not become ready", not "not confirmed stopped". This is a platform
  // gate in production code, not a timing problem: the same 30 ms budget is used
  // on Windows where the test passes.
  test('an unconfirmed previous core stop blocks the new start', () async {
    var launches = 0;
    var stopResult = false;

    ClashService.startHooksForTest = ClashServiceStartHooks(
      registerService: () async => false,
      launchCore: (corePath, arg, environment) async {
        launches++;
      },
      stopCore: () async => stopResult,
    );

    final service = ClashService();
    await settleFirstStart(service);
    final launchesBefore = launches;

    // A previous start left a helper-owned core behind, and the helper refuses
    // to stop it.
    service.coreStartedViaHelperForTest = true;

    await expectLater(
      service.reStart(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not confirmed stopped'),
        ),
      ),
      reason:
          'starting a second core over an unconfirmed stop must fail loudly',
    );

    expect(
      launches,
      launchesBefore,
      reason:
          'no new core may be launched while the old one is unaccounted for',
    );
    expect(
      service.coreStartedViaHelperForTest,
      isTrue,
      reason: 'the claim is kept so the stop can be retried',
    );
    expect(service.isStarting, isFalse);
  }, skip: !Platform.isWindows);

  test(
    'a previous direct core that will not exit blocks the new start',
    () async {
      var launches = 0;
      ClashService.startHooksForTest = ClashServiceStartHooks(
        registerService: () async => false,
        launchCore: (corePath, arg, environment) async {
          launches++;
        },
        stopCore: () async => true,
        killProcess: (p, force) async {},
        awaitExit: (p) async => throw TimeoutException('still running'),
      );

      final service = ClashService();
      await settleFirstStart(service);
      final launchesBefore = launches;

      // A long-running child to reap. Portable on purpose: the "will not exit"
      // path (`_reapDirectCore`) is platform-neutral, so only the command differs.
      final child = Platform.isWindows
          ? await Process.start('cmd', ['/c', 'ping', '-n', '30', '127.0.0.1'])
          : await Process.start('sleep', ['30']);
      addTearDown(() {
        try {
          child.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
      service.process = child;

      await expectLater(
        service.reStart(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not confirmed exited'),
          ),
        ),
      );

      expect(
        launches,
        launchesBefore,
        reason: 'no second core may be launched',
      );
      expect(
        service.process,
        same(child),
        reason: 'the handle is kept so the reap can be retried',
      );
    },
  );

  test('the same start succeeds once the stop is confirmed', () async {
    var launches = 0;
    var stopResult = false;

    ClashService.startHooksForTest = ClashServiceStartHooks(
      registerService: () async => false,
      launchCore: (corePath, arg, environment) async {
        launches++;
      },
      stopCore: () async => stopResult,
    );

    final service = ClashService();
    await settleFirstStart(service);
    service.coreStartedViaHelperForTest = true;

    // Blocked the first time.
    await expectLater(service.reStart(), throwsA(isA<StateError>()));
    final launchesWhileBlocked = launches;

    // The helper recovers; the retry must go through.
    stopResult = true;
    await expectLater(service.reStart(), throwsA(isA<StateError>()));
    // The retry still fails at the readiness gate (no core in a test), but it
    // got past the ownership check and launched.
    expect(
      launches,
      greaterThan(launchesWhileBlocked),
      reason: 'a confirmed stop must unblock the next start',
    );
    expect(service.coreStartedViaHelperForTest, isFalse);
  });
}

/// Same shape as the fake in `clash_service_helper_fallback_test.dart`.
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
