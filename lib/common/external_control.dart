import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/utils/platform_check.dart';
import 'package:restart_app/restart_app.dart';

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

  static Future<void> _startTcpSocket() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _ownsControlChannel = true;
    final portFilePath = await appPath.controlPortFilePath;
    try {
      await File(portFilePath).writeAsString('${_server!.port}');
    } catch (_) {}
    _listen();
  }

  static void _listen() {
    _server!.listen(
      (socket) => socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleCommand),
      onError: (e) => commonPrint.log('ExternalControl server error: $e'),
    );
  }

  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    _transportType = null;

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

  static Future<void> sendCommand(String command) async {
    if (!system.isDesktop) return;

    // Prefer Unix Domain Socket when the socket file exists.
    final socketPath = await appPath.controlSocketPath;
    final socketType = FileSystemEntity.typeSync(socketPath);
    if (socketType != FileSystemEntityType.notFound) {
      try {
        await _sendUnixCommand(socketPath, command);
        return;
      } catch (_) {}
    }

    // Fall back to TCP loopback port file.
    final portFilePath = await appPath.controlPortFilePath;
    if (await File(portFilePath).exists()) {
      final content = await File(portFilePath).readAsString();
      final port = int.tryParse(content.trim());
      if (port != null) {
        try {
          await _sendTcpCommand(port, command);
          return;
        } catch (_) {}
      }
    }

    throw StateError('Fluxora is not running');
  }

  static Future<void> _sendUnixCommand(
    String socketPath,
    String command,
  ) async {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    final socket = await Socket.connect(
      address,
      0,
    ).timeout(const Duration(seconds: 1));
    try {
      socket.write('$command\n');
      await socket.flush();
    } on SocketException catch (e) {
      if (!_isConnectionReset(e)) rethrow;
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  static Future<void> _sendTcpCommand(int port, String command) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
    ).timeout(const Duration(seconds: 1));
    try {
      socket.write('$command\n');
      await socket.flush();
    } on SocketException catch (e) {
      if (!_isConnectionReset(e)) rethrow;
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  static bool _isConnectionReset(SocketException e) {
    final osError = e.osError;
    if (osError == null) return false;
    const resetMessages = [
      'Connection reset by peer',
      'Connection refused',
      '远程主机强迫关闭了一个现有的连接',
      'An existing connection was forcibly closed',
    ];
    return osError.errorCode == 10054 ||
        resetMessages.any((m) => osError.message.contains(m));
  }

  static void _handleCommand(String command) {
    switch (command.trim()) {
      case 'exit':
        globalState.appController.handleExit();
      case 'restart':
        Restart.restartApp();
      case 'show':
        window?.show();
      default:
        commonPrint.log('ExternalControl unknown command: $command');
    }
  }
}
