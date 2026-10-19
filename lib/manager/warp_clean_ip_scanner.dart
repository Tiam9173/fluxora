import 'dart:async';
import 'dart:io';

/// One candidate endpoint and what the probe measured.
class CleanIpResult {
  final String ip;
  final int? latencyMs;
  final String? error;

  const CleanIpResult({required this.ip, this.latencyMs, this.error});

  bool get ok => latencyMs != null;
}

/// Probes Cloudflare WARP endpoint candidates and ranks them by latency.
///
/// WARP itself speaks WireGuard over UDP, which needs a handshake this app does
/// not implement in Dart. The endpoints are also ordinary Cloudflare edge IPs,
/// so a TCP connect to 443 measures the same thing that actually matters here —
/// how close the candidate is — without inventing a second crypto stack.
///
/// Caveat: when the tunnel is up, these probes travel through it. The ranking is
/// still useful (it compares candidates against each other under the same
/// conditions), but run it with the tunnel off for the cleanest numbers.
class WarpCleanIpScanner {
  static const int _probePort = 443;
  static const Duration _timeout = Duration(milliseconds: 1500);
  static const int _concurrency = 12;

  /// Cloudflare's published WARP endpoint ranges. Sampling every address would
  /// mean thousands of connects; these are the ranges the community actually
  /// uses, and one per /24 is enough to find a fast PoP.
  static List<String> defaultCandidates() {
    const prefixes = [
      '162.159.192',
      '162.159.193',
      '162.159.195',
      '188.114.96',
      '188.114.97',
      '188.114.98',
      '188.114.99',
    ];
    const hosts = [1, 2, 3, 10, 20, 30, 50, 80, 100, 120, 150, 180, 200, 220, 240, 254];
    return [
      for (final prefix in prefixes)
        for (final host in hosts) '$prefix.$host',
    ];
  }

  /// Runs the probes, reporting progress as results arrive.
  ///
  /// [onProgress] receives the finished count and the total, so the caller can
  /// show movement instead of a spinner that looks stuck for several seconds.
  Future<List<CleanIpResult>> scan(
    List<String> candidates, {
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <CleanIpResult>[];
    var done = 0;
    final total = candidates.length;

    for (var i = 0; i < candidates.length; i += _concurrency) {
      final batch = candidates.skip(i).take(_concurrency);
      final batchResults = await Future.wait(batch.map(_probe));
      results.addAll(batchResults);
      done += batchResults.length;
      onProgress?.call(done, total);
    }

    // Fastest first; unreachable entries keep their original order at the end.
    results.sort((a, b) {
      if (a.ok && b.ok) return a.latencyMs!.compareTo(b.latencyMs!);
      if (a.ok) return -1;
      if (b.ok) return 1;
      return 0;
    });
    return results;
  }

  Future<CleanIpResult> _probe(String ip) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(ip, _probePort, timeout: _timeout);
      stopwatch.stop();
      return CleanIpResult(ip: ip, latencyMs: stopwatch.elapsedMilliseconds);
    } catch (e) {
      return CleanIpResult(ip: ip, error: e.toString());
    } finally {
      socket?.destroy();
    }
  }
}

final warpCleanIpScanner = WarpCleanIpScanner();
