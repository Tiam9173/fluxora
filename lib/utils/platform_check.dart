import 'dart:io';

enum TransportType { unixSocket, tcp }

class PlatformChecker {
  static bool? _udsSupport;

  /// Whether this platform may use AF_UNIX sockets.
  ///
  /// **Windows always answers `false`, and never probes.**
  ///
  /// `afunix.sys` 10.0.26100.9818 bugchecks when a Unix-domain socket handle is
  /// torn down: three minidumps (`0xD1`, args `0,2,0,0`) all resolve to
  /// `AV_afunix!AfUnixTlConnectEndpointDisconnect+0x3e`, reached through
  /// `nt!ExSweepHandleTable` → `nt!ObKillProcess` — i.e. plain **process exit**.
  /// The old implementation bound a throwaway socket here just to prove AF_UNIX
  /// worked, creating exactly the handle that crashes the machine.
  ///
  /// Loopback TCP is the supported Windows transport and is already implemented
  /// end to end (see `ExternalControl` and `ClashService`).
  static Future<bool> checkUnixSocketSupport() async {
    final cached = _udsSupport;
    if (cached != null) return cached;

    if (Platform.isWindows) {
      _udsSupport = false;
      return false;
    }

    _udsSupport = true;
    return true;
  }

  static Future<TransportType> getRecommendedTransport() async {
    // Spelled out rather than inferred from the probe: on Windows this is a
    // correctness requirement, not a capability question.
    if (Platform.isWindows) return TransportType.tcp;

    if (await checkUnixSocketSupport()) {
      return TransportType.unixSocket;
    }
    return TransportType.tcp;
  }
}
