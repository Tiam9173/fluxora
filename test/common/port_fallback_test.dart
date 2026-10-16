import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// Port-fallback search, ported from clash-verge-rev's `utils/port.rs`.
///
/// The search is pure (`isAvailable` is injected), so the cases below pin the
/// semantics without touching a socket. `isPortAvailable` is covered separately
/// at the end, where a real bind is the only meaningful test.
void main() {
  group('nextPortCandidate', () {
    test('steps up by one', () {
      expect(nextPortCandidate(7890), 7891);
    });

    test('wraps to the floor when below the range', () {
      expect(nextPortCandidate(80), minFallbackPort);
      expect(nextPortCandidate(0), minFallbackPort);
    });

    test('wraps to the floor at the top of the range', () {
      // u16::MAX cannot advance without leaving the range.
      expect(nextPortCandidate(65535), minFallbackPort);
    });
  });

  group('findNextAvailablePort', () {
    test('takes the very next port when it is free', () async {
      expect(
        await findNextAvailablePort(7890, isAvailable: (_) async => true),
        7891,
      );
    });

    test('skips ports the probe rejects', () async {
      final taken = {7891, 7892, 7893};
      expect(
        await findNextAvailablePort(
          7890,
          isAvailable: (port) async => !taken.contains(port),
        ),
        7894,
      );
    });

    test('skips reserved ports even when they probe free', () async {
      // Reserved is checked *before* availability, so a port the caller has
      // earmarked is never handed back even if nothing is bound to it.
      expect(
        await findNextAvailablePort(
          7890,
          reserved: {7891, 7892},
          isAvailable: (_) async => true,
        ),
        7893,
      );
    });

    test('never returns the current port, even when it is the only free one', () async {
      // The whole point of the call: the current port is the broken one, so
      // handing it back would put the caller in a loop. When it is the *only*
      // port the probe accepts, the correct answer is "nothing found".
      expect(
        await findNextAvailablePort(20_000, isAvailable: (port) async => port == 20_000),
        isNull,
      );
    });

    test('wraps around and finds a free port below the start', () async {
      // Everything from 60_000 upward is taken, so the scan must wrap past the
      // top rather than give up. The first thing it meets after wrapping is the
      // floor.
      expect(
        await findNextAvailablePort(60_000, isAvailable: (port) async => port < 60_000),
        minFallbackPort,
      );
    });

    test('returns null when nothing in the range is free', () async {
      expect(
        await findNextAvailablePort(7890, isAvailable: (_) async => false),
        isNull,
      );
    });

    test('a null result is not the current port', () async {
      // Guards the caller's failure mode: null must mean "do not guess", not
      // "keep using the port we know is taken".
      final result = await findNextAvailablePort(
        7890,
        isAvailable: (_) async => false,
      );
      expect(result, isNot(7890));
      expect(result, isNull);
    });
  });

  group('isPortAvailable', () {
    test('reports false for a port this test is holding', () async {
      final held = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        expect(await isPortAvailable(held.port), isFalse);
      } finally {
        await held.close();
      }
    });

    test('reports true for a port just released', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final free = probe.port;
      await probe.close();
      // A listening socket we opened ourselves closes cleanly (no TIME_WAIT),
      // so this is reliable rather than timing-dependent.
      expect(await isPortAvailable(free), isTrue);
    });
  });
}
