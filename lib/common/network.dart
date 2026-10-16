import 'dart:io';

extension NetworkInterfaceExt on NetworkInterface {
  bool get isWifi {
    final nameLowCase = name.toLowerCase();
    if (nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase == 'en0' ||
        nameLowCase == 'eth0') {
      return true;
    }

    return false;
  }

  bool get includesIPv4 {
    return addresses.any((addr) => addr.isIPv4);
  }
}

extension InternetAddressExt on InternetAddress {
  bool get isIPv4 {
    return type == InternetAddressType.IPv4;
  }
}

/// Lowest port the fallback search will consider.
///
/// Ports below this are privileged/reserved on most systems, and the well-known
/// ones below 1025 are exactly where a *proxy* must never silently land.
const minFallbackPort = 1025;

/// The next candidate after [port], wrapping back to [minFallbackPort].
///
/// Kept separate so the wrap-around is testable on its own: an out-of-range or
/// exhausted value restarts the scan rather than overflowing.
int nextPortCandidate(int port) {
  if (port < minFallbackPort || port >= 65535) return minFallbackPort;
  return port + 1;
}

/// Find a port to fall back to when [current] is already taken.
///
/// Walks upward from `current + 1`, skipping [reserved] and anything
/// [isAvailable] rejects, wrapping at the top and giving up once the whole range
/// has been tried. **Never returns [current] itself** — the caller is here
/// precisely because that port is unusable, so handing it back would loop.
///
/// Returns null when nothing in the range is free; the caller must treat that as
/// "do not start with a guessed port", not as "keep the current one".
///
/// Ported from clash-verge-rev's `utils/port.rs` (`find_next_available_port`).
int? findNextAvailablePort(
  int current, {
  Set<int> reserved = const {},
  required bool Function(int port) isAvailable,
}) {
  var candidate = nextPortCandidate(current);
  // Bounded by the size of the range, so a pathological `isAvailable` can never
  // spin forever.
  for (var i = minFallbackPort; i <= 65535; i++) {
    if (candidate != current &&
        !reserved.contains(candidate) &&
        isAvailable(candidate)) {
      return candidate;
    }
    candidate = nextPortCandidate(candidate);
  }
  return null;
}

/// Whether [port] can be bound right now.
///
/// A bind is the only honest test — an OS-level "is it in use" query answers a
/// different question than "can *we* take it". The socket is released immediately
/// either way.
///
/// Two caveats the caller owns:
/// * This probes the given [address] only. A core that binds `0.0.0.0` or a v6
///   address is not detected by an IPv4 loopback probe, so a `true` here is not
///   proof the port is free for every bind scope.
/// * A port released moments ago can still be in `TIME_WAIT` and fail to bind
///   even though nothing is serving on it.
Future<bool> isPortAvailable(int port, {InternetAddress? address}) async {
  final target = address ?? InternetAddress.loopbackIPv4;
  try {
    final socket = await ServerSocket.bind(target, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
