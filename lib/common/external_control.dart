import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/utils/platform_check.dart';
import 'package:flutter/foundation.dart';

/// What a control-channel line routes to.
///
/// Split out from the side effects so the routing decision can be asserted
/// without exiting the app, relaunching it, or driving a platform channel.
enum ExternalControlCommand { exit, restart, show, unknown }

/// Why a control command did not get through.
///
/// N5: the probe used to see one opaque `StateError` for all three cases, so
/// "nothing is running" (a cold start — retrying only adds latency) was
/// indistinguishable from "a channel exists but did not answer yet" (worth a
/// bounded retry). They are separate outcomes now.
enum ExternalControlFailure {
  /// No control channel exists at all. Definitively nothing is running.
  notRunning,

  /// A channel exists but the attempt did not complete — connect refused or
  /// reset, or the write failed. Transient by nature; retrying is meaningful.
  unreachable,

  /// The peer answered, but not with the acknowledgement we require.
  rejected,
}

class ExternalControlException implements Exception {
  const ExternalControlException(this.failure, [this.detail = '']);

  final ExternalControlFailure failure;
  final String detail;

  @override
  String toString() => detail.isEmpty
      ? 'ExternalControlException(${failure.name})'
      : 'ExternalControlException(${failure.name}): $detail';
}

class ExternalControl {
  static ServerSocket? _server;
  static TransportType? _transportType;

  /// Held for as long as this process owns the control channel.
  ///
  /// `null` means "not the owner": nothing may be deleted and no socket may be
  /// bound. The lock is an OS-level exclusive lock (`LockFileEx` on Windows,
  /// `fcntl` on POSIX), so it is enforced **across processes** - the only level
  /// that matters here, because two Fluxora instances share one fixed path.
  static RandomAccessFile? _lockFile;

  /// Set only after a bind succeeded, i.e. this process actually has a channel
  /// behind the files it may delete.
  static bool _ownsControlChannel = false;

  static Future<void> start() async {
    if (!system.isDesktop || _server != null) return;

    // Take ownership *before* touching the fixed path. Deleting or binding it
    // without the lock is what let a second instance cut the first one's control
    // channel.
    if (!await _acquireOwnership()) {
      commonPrint.log(
        'ExternalControl: control channel is owned by another instance, skipping',
      );
      return;
    }

    // Everything past the lock lives inside this `try`. `getRecommendedTransport`
    // is not side-effect free — on Windows it probes AF_UNIX support by binding a
    // throwaway socket — so it can throw, and leaking the lock there would lock
    // every later instance out for the rest of this process's life.
    try {
      _transportType = await PlatformChecker.getRecommendedTransport();

      if (_transportType == TransportType.unixSocket) {
        try {
          await _startUnixSocket();
          return;
        } catch (e) {
          commonPrint.log(
            'ExternalControl UDS bind failed, falling back to TCP: $e',
          );
          // The UDS attempt may have bound a listener before it failed. Close it
          // here, otherwise the TCP fallback would overwrite `_server` and leak
          // the listener - and its socket file - for the life of the process.
          await _discardBoundListener();
        }
      }
      await _startTcpSocket();
    } catch (e) {
      // Nothing is listening, so hand the ownership back instead of holding a
      // lock with no channel behind it.
      await _abortStart();
      rethrow;
    }
  }

  /// Closes a listener this start attempt bound and removes the files it created.
  ///
  /// Called both when the UDS attempt fails before the TCP fallback and when the
  /// whole start fails. Without it a listener bound before the failure stays
  /// open: `_server != null` then makes every later `start()` a silent no-op
  /// while the port (or the socket path) stays occupied.
  static Future<void> _discardBoundListener() async {
    // Delete while ownership is still recorded - `_deleteOwnedControlFiles`
    // requires both the lock and `_ownsControlChannel`.
    try {
      await _deleteOwnedControlFiles();
    } catch (_) {}

    final server = _server;
    _server = null;
    _ownsControlChannel = false;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  /// Unwinds a failed [start]: drop the half-bound listener, forget the transport
  /// and hand the lock back so the next attempt can take it.
  static Future<void> _abortStart() async {
    await _discardBoundListener();
    _transportType = null;
    await _releaseOwnership();
  }

  /// Opens the sidecar lock file and takes a non-blocking exclusive lock on it.
  ///
  /// Returns `false` when another process holds it. The lock *file* is never
  /// removed - see `AppPath.controlLockFilePath`.
  static Future<bool> _acquireOwnership() async {
    if (_lockFile != null) return true;

    final lockPath = await appPath.controlLockFilePath;
    RandomAccessFile? handle;
    try {
      await File(lockPath).create(recursive: true);
      handle = await File(lockPath).open(mode: FileMode.write);
      // `FileLock.exclusive` is the non-blocking variant: it throws instead of
      // waiting when the lock is already held.
      await handle.lock(FileLock.exclusive);
    } catch (e) {
      try {
        await handle?.close();
      } catch (_) {}
      commonPrint.log('ExternalControl: could not take the control lock: $e');
      return false;
    }
    _lockFile = handle;
    return true;
  }

  static Future<void> _releaseOwnership() async {
    final handle = _lockFile;
    _lockFile = null;
    _ownsControlChannel = false;
    if (handle == null) return;
    try {
      await handle.unlock();
    } catch (_) {}
    try {
      await handle.close();
    } catch (_) {}
  }

  static Future<void> _startUnixSocket() async {
    // Belt and braces: `getRecommendedTransport()` never returns unixSocket on
    // Windows, and binding one there is what bugchecks afunix.sys on exit.
    if (Platform.isWindows) {
      throw StateError('AF_UNIX control channel is disabled on Windows');
    }
    final socketPath = await appPath.controlSocketPath;
    // Safe to clear a stale file only here: ownership is already held, so no
    // other instance can be using this path.
    final type = FileSystemEntity.typeSync(socketPath);
    if (type != FileSystemEntityType.notFound) {
      try {
        await File(socketPath).delete();
      } catch (_) {}
    }
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    _server = await ServerSocket.bind(address, 0);
    _ownsControlChannel = true;
    _listen();
  }

  /// Per-session credential for the loopback TCP channel.
  ///
  /// A loopback port is reachable by every local process, so the port number is
  /// not a credential: without a secret, any local program could send `exit` or
  /// `restart`. The token is generated when this instance binds, written beside
  /// the port, and must be echoed as the first field of every command.
  static String? _sessionToken;

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<void> _startTcpSocket() async {
    // Loopback only — never 0.0.0.0.
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _ownsControlChannel = true;
    final token = _generateToken();
    _sessionToken = token;
    final portFilePath = await appPath.controlPortFilePath;
    try {
      await _publishTcpChannel(portFilePath, _server!.port, token);
    } catch (e) {
      // The listener is up but no client can learn the port or the token, so
      // `exit` / `restart` / second-instance wake-up are unreachable until the
      // next start. Never report that as success, and never fall back to
      // tokenless access — the channel stays fail-closed.
      //
      // Diagnosable, and deliberately free of secrets: error type, path, stage.
      commonPrint.log(
        'ExternalControl: publishing the control port file failed '
        '[stage=publish type=${e.runtimeType} path="$portFilePath"]: $e',
      );
    }
    _listen();
  }

  /// Publishes `<port>\n<token>\n` at [path] without ever leaving the target
  /// truncated, half-written, or briefly absent.
  ///
  /// The write goes to a unique temp file **in the same directory** — same
  /// volume, so the rename is a replace rather than a copy — and only then is it
  /// moved onto [path]. The existing target is never deleted first: a valid old
  /// file keeps working until the new one is complete.
  ///
  /// The temp file inherits the directory ACL exactly like the target does, so
  /// it is never more permissive. Only this process's own temp file is ever
  /// removed; the rename target belongs to this instance because the control
  /// lock is already held.
  static Future<void> _publishTcpChannel(
    String path,
    int port,
    String token,
  ) async {
    final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await temp.writeAsString('$port\n$token\n', flush: true);
      await temp.rename(path);
    } catch (_) {
      try {
        if (await temp.exists()) {
          await temp.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  static void _listen() {
    final requireToken = _transportType == TransportType.tcp;
    _server!.listen((socket) {
      void reply(String line) {
        try {
          socket.write('$line\n');
          socket.flush();
        } catch (_) {}
      }

      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) => _handleCommand(line, reply, requireToken: requireToken),
          );
    }, onError: (e) => commonPrint.log('ExternalControl server error: $e'));
  }

  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    _transportType = null;
    _sessionToken = null;

    // Delete **while the lock is still held**. Releasing first would let another
    // instance acquire ownership, bind its own socket, and then lose it to this
    // unlink.
    try {
      await _deleteOwnedControlFiles();
    } finally {
      await _releaseOwnership();
    }
  }

  /// Removes the control files, but only when this process both holds the lock
  /// and actually owns a bound channel.
  static Future<void> _deleteOwnedControlFiles() async {
    if (_lockFile == null || !_ownsControlChannel) return;

    final socketPath = await appPath.controlSocketPath;
    if (FileSystemEntity.typeSync(socketPath) !=
        FileSystemEntityType.notFound) {
      try {
        await File(socketPath).delete();
      } catch (_) {}
    }

    final portFilePath = await appPath.controlPortFilePath;
    if (await File(portFilePath).exists()) {
      try {
        await File(portFilePath).delete();
      } catch (_) {}
    }
  }

  /// The one line the server sends back when a command actually took effect.
  static const ackOk = 'ok';

  /// Sends [command] to the running instance.
  ///
  /// With [requireAck] the call does not return until the peer confirms it
  /// **executed** the command — the acknowledgement is the server's word that
  /// the action happened, not merely that the bytes arrived. Commands that do
  /// not ask for one (`exit`, `restart`) keep the original write-only protocol.
  static Future<void> sendCommand(
    String command, {
    bool requireAck = false,
  }) async {
    if (!system.isDesktop) return;

    // Prefer Unix Domain Socket when the socket file exists.
    //
    // Never on Windows: `afunix.sys` bugchecks when a Unix-domain socket handle
    // is torn down at process exit (0xD1 in AfUnixTlConnectEndpointDisconnect).
    // The whole point of the Windows transport change is that no AF_UNIX socket
    // is ever created there, so the client must not try one either.
    ExternalControlException? transient;
    if (!Platform.isWindows) {
      final socketPath = await appPath.controlSocketPath;
      if (FileSystemEntity.typeSync(socketPath) !=
          FileSystemEntityType.notFound) {
        try {
          await _sendUnixCommand(socketPath, command, requireAck: requireAck);
          return;
        } on ExternalControlException catch (e) {
          // A peer that answered wrongly is a definitive outcome — falling back
          // to the TCP channel would just ask a different listener the same
          // question and could double-execute the command.
          if (e.failure != ExternalControlFailure.unreachable) rethrow;
          transient = e;
        }
      }
    }

    // Fall back to TCP loopback port file. The file is `<port>\n<token>\n`; the
    // token is the credential that a loopback port cannot provide on its own.
    final portFilePath = await appPath.controlPortFilePath;
    if (await File(portFilePath).exists()) {
      final lines = const LineSplitter().convert(
        await File(portFilePath).readAsString(),
      );
      final port = lines.isEmpty ? null : int.tryParse(lines.first.trim());
      final token = lines.length > 1 ? lines[1].trim() : null;
      if (port != null) {
        try {
          await _sendTcpCommand(
            port,
            command,
            requireAck: requireAck,
            token: token,
          );
          return;
        } on ExternalControlException catch (e) {
          if (e.failure != ExternalControlFailure.unreachable) rethrow;
          transient = e;
        }
      }
    }

    // A channel file existed but every attempt failed: that is transient, and
    // the caller may retry. Nothing existing at all is definitive.
    if (transient != null) throw transient;
    throw const ExternalControlException(ExternalControlFailure.notRunning);
  }

  static Future<void> _sendUnixCommand(
    String socketPath,
    String command, {
    required bool requireAck,
  }) async {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    final Socket socket;
    try {
      socket = await Socket.connect(
        address,
        0,
      ).timeout(const Duration(seconds: 1));
    } catch (e) {
      throw ExternalControlException(ExternalControlFailure.unreachable, '$e');
    }
    await _exchange(socket, command, requireAck: requireAck);
  }

  static Future<void> _sendTcpCommand(
    int port,
    String command, {
    required bool requireAck,
    String? token,
  }) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
      ).timeout(const Duration(seconds: 1));
    } catch (e) {
      throw ExternalControlException(ExternalControlFailure.unreachable, '$e');
    }
    final line = token == null ? command : '$token $command';
    await _exchange(socket, line, requireAck: requireAck);
  }

  static Future<void> _exchange(
    Socket socket,
    String command, {
    required bool requireAck,
  }) async {
    try {
      socket.write('$command\n');
      await socket.flush();
      if (!requireAck) return;

      final String reply;
      try {
        reply = await socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        throw ExternalControlException(
          ExternalControlFailure.rejected,
          'no acknowledgement: $e',
        );
      }
      if (reply.trim() != ackOk) {
        throw ExternalControlException(
          ExternalControlFailure.rejected,
          reply.trim(),
        );
      }
    } on ExternalControlException {
      rethrow;
    } catch (e) {
      throw ExternalControlException(ExternalControlFailure.unreachable, '$e');
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  /// Routes one received line to the action it names.
  ///
  /// This is the whole routing rule: trimmed, exact-match, `unknown` otherwise.
  @visibleForTesting
  static ExternalControlCommand parseCommand(String raw) {
    switch (raw.trim()) {
      case 'exit':
        return ExternalControlCommand.exit;
      case 'restart':
        return ExternalControlCommand.restart;
      case 'show':
        return ExternalControlCommand.show;
      default:
        return ExternalControlCommand.unknown;
    }
  }

  /// Test-only probe for [_handleCommand]'s side effect.
  ///
  /// When set, a received command is reported here **instead of** being
  /// executed: `exit` tears down the tray and quits, `restart` relaunches, and
  /// `show` drives a platform channel — none of which a test may trigger.
  /// Production leaves it `null`, so the real handlers run unchanged.
  @visibleForTesting
  static void Function(ExternalControlCommand command)? onCommandRoutedForTest;

  static Future<void> _handleCommand(
    String rawLine,
    void Function(String line)? reply, {
    bool requireToken = false,
  }) async {
    var command = rawLine.trim();

    // Loopback TCP is reachable by any local process, so the port number alone
    // cannot authenticate a caller. Every TCP command must present the token
    // this instance wrote beside the port; anything else is refused before it
    // can reach `exit` / `restart`.
    if (requireToken) {
      final expected = _sessionToken;
      if (expected == null || expected.isEmpty) {
        commonPrint.log('ExternalControl: no session token, refusing command');
        reply?.call('error unauthorized');
        return;
      }
      final prefix = '$expected ';
      if (!command.startsWith(prefix)) {
        commonPrint.log('ExternalControl: rejected an unauthenticated request');
        reply?.call('error unauthorized');
        return;
      }
      command = command.substring(prefix.length).trim();
    }

    final routed = parseCommand(command);

    final probe = onCommandRoutedForTest;
    if (probe != null) {
      probe(routed);
      reply?.call(ackOk);
      return;
    }

    switch (routed) {
      case ExternalControlCommand.exit:
        globalState.appController.handleExit();
      case ExternalControlCommand.restart:
        // P9B-D3 — restart goes through the same teardown as exit. Calling
        // `Restart.restartApp()` here used to leave the core, the helper
        // service and the system proxy behind.
        globalState.appController.restartApp();
      case ExternalControlCommand.show:
        await _showWindow(reply);
      case ExternalControlCommand.unknown:
        commonPrint.log('ExternalControl unknown command: $command');
        reply?.call('error unknown-command');
    }
  }

  /// Brings the window up and acknowledges **only** when that actually happened.
  ///
  /// N5: the old handler was `window?.show()` — a null window (window manager
  /// not ready) or a throwing `show()` still left the client believing it had
  /// woken the app, so the second launch exited as if it had succeeded while
  /// nothing appeared. An acknowledgement is not visual proof — the window may
  /// still not end up in front — so the real result stays a runtime check.
  static Future<void> _showWindow(void Function(String line)? reply) async {
    final target = window;
    if (target == null) {
      reply?.call('error window-unavailable');
      return;
    }
    try {
      await target.show();
      reply?.call(ackOk);
    } catch (e) {
      commonPrint.log('ExternalControl show failed: $e');
      reply?.call('error show-failed');
    }
  }
}
