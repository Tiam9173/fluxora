import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/helper_auth.dart';
import 'package:fluxora/helper/helper.dart';
// Test-only: both are transitive dependencies of `path_provider`. `AppPath`
// resolves its temp/download dirs through it, and the platform interface throws
// before any channel mock can answer in a VM test.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P7-D2 — what `HelperClient.startCore` does when the helper fails.
///
/// The production chain is
///
/// ```
/// ClashService.start()                       service.dart:344-374
///   → windows.registerService()
///     → helperClient.startCore(...)          helper.dart:131
///       → _request('core.start', …)          helper.dart:195
///         → HelperTransport.send(...)
/// ```
///
/// `HelperClient` takes its transport through the constructor, so the whole
/// chain up to the transport can be driven with a fake — **no production seam
/// was added**.
///
/// What this file pins, and what it deliberately does not:
///   · `startCore` is `Future<bool>`. A transport error, a malformed reply and
///     a helper-side `ok: false` all reach the caller as **`false`**, and the
///     original error text reaches the log. The exception object is *not*
///     rethrown — `ClashService` uses that `false` to fall back to spawning the
///     core directly (`service.dart:370-378`). Changing it to throw would
///     remove the fallback, which is production behaviour this batch must not
///     alter.
///   · `getLogs` is the contrast case: it has no `catch`, so the very same
///     transport failure propagates. That proves the swallowing is per-method,
///     not a blanket policy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUpAll(() async {
    sandbox = Directory.systemTemp.createTempSync('fluxora_p7d2_path_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() async {
    try {
      await sandbox.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    // A fresh key per test keeps `ensureAuthKey()` deterministic and gives each
    // test its own key file inside the sandbox.
    await HelperAuthManager.clearAuthKey();

    // `commonPrint.log` ends in `debugPrint`, so replacing it captures exactly
    // what a user would see in the log pane.
    logs = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    await HelperAuthManager.clearAuthKey();
  });

  group('HelperClient.startCore — failure reaches the caller', () {
    test('a transport error comes back as false, never as a throw', () async {
      final transport = _RecordingTransport(error: StateError('pipe is gone'));
      final client = HelperClient(transport: transport);

      // The contract is `Future<bool>`: `false` is how the caller learns the
      // helper did not start the core.
      expect(
        await client.startCore(
          corePath: 'core.exe',
          arg: '1234',
          homeDir: 'home',
        ),
        isFalse,
      );
    });

    test('the original error text reaches the log, so it is not swallowed',
        () async {
      final transport = _RecordingTransport(error: StateError('pipe is gone'));
      final client = HelperClient(transport: transport);

      await client.startCore(corePath: 'core.exe', arg: '1', homeDir: 'h');

      expect(
        logs.where(
          (line) =>
              line.contains('[HelperClient] startCore failed') &&
              line.contains('pipe is gone'),
        ),
        isNotEmpty,
        reason: 'the failure must be observable, not silent',
      );
    });

    test('a helper-side rejection keeps the helper\'s own error text', () async {
      final transport = _RecordingTransport(
        response: json.encode({
          'id': 'reply',
          'ok': false,
          'error': {'code': 'CORE_START_FAILED', 'message': 'cannot bind 4711'},
        }),
      );
      final client = HelperClient(transport: transport);

      expect(
        await client.startCore(corePath: 'c', arg: 'a', homeDir: 'h'),
        isFalse,
      );
      expect(
        logs.where(
          (line) =>
              line.contains('CORE_START_FAILED') &&
              line.contains('cannot bind 4711'),
        ),
        isNotEmpty,
        reason: 'the helper\'s diagnosis must survive the conversion to false',
      );
    });

    test('an unparseable reply also lands on false instead of crashing',
        () async {
      final transport = _RecordingTransport(response: 'not json at all');
      final client = HelperClient(transport: transport);

      expect(
        await client.startCore(corePath: 'c', arg: 'a', homeDir: 'h'),
        isFalse,
      );
      expect(
        logs.where((line) => line.contains('[HelperClient] startCore failed')),
        isNotEmpty,
      );
    });
  });

  group('HelperClient.startCore — the call it makes', () {
    test('sends core.start with the path, arg and home dir it was given',
        () async {
      final transport = _RecordingTransport(response: _okResponse);
      final client = HelperClient(transport: transport);

      expect(
        await client.startCore(
          corePath: r'C:\app\core.exe',
          arg: '4711',
          homeDir: r'C:\app\home',
        ),
        isTrue,
      );

      expect(transport.payloads, hasLength(1));
      final request =
          json.decode(transport.payloads.single) as Map<String, dynamic>;
      expect(request['version'], helperProtocolVersion);
      expect(request['method'], 'core.start');
      expect(request['id'], isA<String>());
      expect(json.decode(request['body'] as String), {
        'path': r'C:\app\core.exe',
        'arg': '4711',
        'home_dir': r'C:\app\home',
      });
      expect(
        request['auth'],
        isA<Map<String, dynamic>>(),
        reason: 'the request must be signed, not sent bare',
      );
    });

    test('gives the helper the full five seconds to answer', () async {
      final transport = _RecordingTransport(response: _okResponse);
      final client = HelperClient(transport: transport);

      await client.startCore(corePath: 'c', arg: 'a', homeDir: 'h');

      expect(transport.timeouts.single, const Duration(seconds: 5));
    });

    test('a second call is a second request, not a cached answer', () async {
      final transport = _RecordingTransport(response: _okResponse);
      final client = HelperClient(transport: transport);

      await client.startCore(corePath: 'c', arg: 'a', homeDir: 'h');
      await client.startCore(corePath: 'c', arg: 'b', homeDir: 'h');

      expect(transport.payloads, hasLength(2));
    });
  });

  group('contrast — the swallowing is per-method, not a policy', () {
    test('getLogs has no catch, so the same failure propagates', () async {
      final transport = _RecordingTransport(error: StateError('pipe is gone'));
      final client = HelperClient(transport: transport);

      await expectLater(client.getLogs(), throwsA(isA<StateError>()));
      expect(
        logs.where((line) => line.contains('[HelperClient]')),
        isEmpty,
        reason: 'nothing caught it, so nothing logged it',
      );
    });

    test('ping also reports false and logs, like startCore', () async {
      final transport = _RecordingTransport(error: StateError('pipe is gone'));
      final client = HelperClient(transport: transport);

      expect(await client.ping('token'), isFalse);
      expect(
        logs.where((line) => line.contains('[HelperClient] ping failed')),
        isNotEmpty,
      );
    });
  });
}

const _okResponse = '{"id":"reply","ok":true}';

/// A transport that records what it was asked to send and answers with a fixed
/// reply or a fixed error.
final class _RecordingTransport implements HelperTransport {
  _RecordingTransport({this.response, this.error});

  final String? response;
  final Object? error;

  final List<String> payloads = <String>[];
  final List<Duration> timeouts = <Duration>[];

  @override
  Future<String> send(
    String payload, {
    Duration timeout = helperDefaultTimeout,
  }) async {
    payloads.add(payload);
    timeouts.add(timeout);
    final failure = error;
    if (failure != null) throw failure;
    return response ?? _okResponse;
  }
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
