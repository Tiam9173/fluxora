import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/external_control.dart';
// Test-only: both are transitive dependencies of `path_provider`. `AppPath`
// resolves its temp/download dirs through it, and the platform interface throws
// before any channel mock can answer in a VM test.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// P7-D1 — where a control-channel line ends up.
///
/// The chain under test is the production one, not a copy:
///
/// ```
/// ExternalControl.sendCommand(cmd)
///   → _sendUnixCommand / _sendTcpCommand   (writes "<cmd>\n" to the listener)
///     → _listen()                          (utf8 + LineSplitter)
///       → _handleCommand(line)
///         → parseCommand(line)             ← the routing rule
///           → the side effect
/// ```
///
/// `exit` tears down the tray and quits, `restart` relaunches the app and `show`
/// drives a platform channel, so the side effects themselves are never executed
/// here: `onCommandRoutedForTest` reports the routed action instead. What that
/// proves is the **routing**, which is the part that had no coverage.
///
/// `parseCommand` is asserted separately because it is the rule itself — the
/// same function `_handleCommand` calls, not a re-implementation.
void main() {
  // `AppPath`'s constructor starts `getTemporaryDirectory()` eagerly, which
  // needs a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  late String socketPath;
  late String portPath;
  late Directory sandbox;

  setUpAll(() async {
    // Must precede the first `appPath` read: `getDownloadsDirectory()` throws on
    // any non-macOS platform unless a fake provider answers it.
    sandbox = Directory.systemTemp.createTempSync('fluxora_p7d1_path_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(sandbox);
  });

  tearDownAll(() async {
    try {
      await sandbox.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    System.platformOverride = 'linux';
    socketPath = await appPath.controlSocketPath;
    portPath = await appPath.controlPortFilePath;
    for (final path in [socketPath, portPath]) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    ExternalControl.onCommandRoutedForTest = null;
  });

  tearDown(() async {
    ExternalControl.onCommandRoutedForTest = null;
    try {
      await ExternalControl.stop();
    } catch (_) {}
    System.platformOverride = null;
  });

  /// Sends [line] over the real control channel and returns what the handler
  /// routed it to.
  Future<ExternalControlCommand> routeThroughChannel(String line) async {
    final received = <ExternalControlCommand>[];
    ExternalControl.onCommandRoutedForTest = received.add;

    await ExternalControl.start();
    // Transport-agnostic on purpose: POSIX publishes a socket file, Windows
    // publishes a port file. Both mean "the channel is up".
    final socketReady =
        FileSystemEntity.typeSync(socketPath) != FileSystemEntityType.notFound;
    final portReady = File(portPath).existsSync();
    expect(
      socketReady || portReady,
      isTrue,
      reason: 'the channel must be up before a command can be routed',
    );

    await ExternalControl.sendCommand(line);

    // The listener handles the line on its own event-loop turn, so poll instead
    // of guessing a fixed delay.
    for (var i = 0; i < 200 && received.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(received, hasLength(1), reason: 'the line must be handled once');
    return received.single;
  }

  group('parseCommand — the routing rule itself', () {
    test('the three known verbs each map to their own action', () {
      expect(ExternalControl.parseCommand('exit'), ExternalControlCommand.exit);
      expect(
        ExternalControl.parseCommand('restart'),
        ExternalControlCommand.restart,
      );
      expect(ExternalControl.parseCommand('show'), ExternalControlCommand.show);
    });

    test('every other line is unknown', () {
      // Case matters, and the match is on the whole line, not a prefix.
      for (final raw in ['', 'quit', 'EXIT', 'Exit', 'exit now', 'show me']) {
        expect(
          ExternalControl.parseCommand(raw),
          ExternalControlCommand.unknown,
          reason: 'raw="$raw"',
        );
      }
    });

    test('surrounding whitespace is trimmed before matching', () {
      expect(
        ExternalControl.parseCommand('  exit  '),
        ExternalControlCommand.exit,
      );
      expect(
        ExternalControl.parseCommand('\trestart\r\n'),
        ExternalControlCommand.restart,
      );
    });
  });

  group('routing through the real control channel', () {
    test('exit routes to the exit action', () async {
      // If the probe did not stand in for the handler, this test process would
      // have been torn down by `handleExit()`.
      expect(await routeThroughChannel('exit'), ExternalControlCommand.exit);
    });

    test('restart routes to the restart action', () async {
      expect(
        await routeThroughChannel('restart'),
        ExternalControlCommand.restart,
      );
    });

    test('show routes to the show action', () async {
      expect(await routeThroughChannel('show'), ExternalControlCommand.show);
    });

    test('an unrecognised line takes the default branch', () async {
      expect(
        await routeThroughChannel('definitely-not-a-command'),
        ExternalControlCommand.unknown,
      );
    });

    test('a line that only looks like a verb is still unknown', () async {
      // Guards the exact-match rule against a `startsWith` style regression.
      expect(
        await routeThroughChannel('exitnow'),
        ExternalControlCommand.unknown,
      );
    });
  });

  group('sendCommand', () {
    test('without a live channel it throws instead of hanging', () async {
      // Nothing started, no socket and no port file. N5 split the old opaque
      // `StateError` into three outcomes; "no channel at all" is the one that
      // must never be retried.
      await expectLater(
        ExternalControl.sendCommand('exit'),
        throwsA(
          isA<ExternalControlException>().having(
            (e) => e.failure,
            'failure',
            ExternalControlFailure.notRunning,
          ),
        ),
      );
    });

    test('a command sent twice is handled twice', () async {
      final received = <ExternalControlCommand>[];
      ExternalControl.onCommandRoutedForTest = received.add;

      await ExternalControl.start();
      await ExternalControl.sendCommand('show');
      await ExternalControl.sendCommand('show');

      for (var i = 0; i < 200 && received.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(received, [
        ExternalControlCommand.show,
        ExternalControlCommand.show,
      ]);
    });
  });
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
