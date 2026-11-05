import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `AppPath` resolves temp/download dirs through path_provider, whose
// platform interface throws in a VM test before any channel mock can answer.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P9-S07 — helper→direct transition and failed `core.stop` handling.
///
/// These are the two holes S06 left open:
///  * A: a helper-owned core has no `Process` handle, so `_doRestart`'s kill
///    cannot reach it. Dropping the claim first leaks it forever.
///  * B: a failed `core.stop` cleared the claim anyway, so the orphan could
///    never be retried.
///
/// No FluxoraCore is started: the helper is the `stopCore` hook, and the direct
/// branch fails at the readiness gate.
void main() {
  // `_doRestart` reads `appPath.homeDirPath`, which needs `path_provider`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;
  late Directory sandbox;

  setUpAll(() {
    sandbox = Directory.systemTemp.createTempSync('fluxora_p9s07_path_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() {
    try {
      sandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    log = <String>[];
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

  /// The constructor starts the transport on its own; wait for that first
  /// attempt to settle so the assertions only cover the call under test.
  Future<void> settleFirstStart(ClashService service) async {
    for (var i = 0; i < 200 && service.lastStartFailure == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      service.lastStartFailure,
      isNotNull,
      reason: 'the constructor start was expected to fail at the ready gate',
    );
    service.lastStartFailure = null;
  }

  test('A — helper→direct must not leak the previous helper core', () async {
    var stops = 0;
    ClashService.startHooksForTest = ClashServiceStartHooks(
      // No helper this time: the probe fails and the direct branch runs.
      registerService: () async => false,
      // Never completes `socketCompleter`, so the ready gate times out.
      launchCore: (corePath, arg, environment) async {},
      stopCore: () async {
        stops++;
        log.add('stopCore');
        return true;
      },
    );

    final service = ClashService();
    await settleFirstStart(service);

    // A previous start left a helper-owned core behind.
    service.coreStartedViaHelperForTest = true;

    await expectLater(service.reStart(), throwsA(isA<StateError>()));

    expect(
      stops,
      1,
      reason:
          'the old helper core has no Process handle; it must be stopped '
          'through the helper before the claim is dropped',
    );
    expect(
      service.coreStartedViaHelperForTest,
      isFalse,
      reason: 'the stop succeeded, so the claim is settled',
    );
  }, skip: !Platform.isWindows);

  test('B — a failed core.stop must keep the claim', () async {
    var stops = 0;
    ClashService.startHooksForTest = ClashServiceStartHooks(
      registerService: () async => true,
      startCore:
          ({
            required String corePath,
            required String arg,
            required String homeDir,
          }) async => true,
      // The helper refuses to stop it.
      stopCore: () async {
        stops++;
        return false;
      },
    );

    final service = ClashService();
    await settleFirstStart(service);

    await expectLater(service.reStart(), throwsA(isA<StateError>()));

    expect(stops, greaterThanOrEqualTo(1), reason: 'a stop was attempted');
    expect(
      service.coreStartedViaHelperForTest,
      isTrue,
      reason: 'an unconfirmed stop must not be recorded as cleaned up',
    );
  }, skip: !Platform.isWindows);
}

/// Same shape as the fake in `clash_service_helper_fallback_test.dart`;
/// duplicated so this file stays independent of that one.
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
