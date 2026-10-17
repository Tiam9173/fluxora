import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// item 6 进程图标性能 — the queue, the cache, and the negative-cache
/// contract are asserted against an injected extractor; the real Windows FFI
/// extraction is asserted against a real executable (it runs on the developer
/// machine and Windows CI — everywhere else it skips).
void main() {
  Uint8List fakeBytes() => Uint8List.fromList(const [1, 2, 3, 4]);

  group('serial queue', () {
    test('extractions run one at a time, never concurrently', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final icon = ProcessIcon(
        extractor: (path) async {
          inFlight++;
          maxInFlight = max(maxInFlight, inFlight);
          await Future.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return fakeBytes();
        },
      );

      await Future.wait([
        for (var i = 0; i < 5; i++) icon.get('process-$i'),
      ]);

      expect(maxInFlight, 1);
    });

    test('a failing extraction does not stall the queue', () async {
      var calls = 0;
      final icon = ProcessIcon(extractor: (path) async {
        calls++;
        if (calls == 1) throw StateError('core not ready');
        return fakeBytes();
      });

      final results = await Future.wait([
        icon.get('a'),
        icon.get('b'),
      ]);

      expect(calls, 2);
      expect(results.first, isNull); // failure surfaces, the second still ran
      expect(results.last, isNotNull);
    });
  });

  group('LRU cache', () {
    test('holds 50 entries and evicts the oldest', () async {
      var calls = 0;
      final icon = ProcessIcon(
        extractor: (path) async {
          calls++;
          return fakeBytes();
        },
      );

      for (var i = 0; i < 50; i++) {
        await icon.get('p$i');
      }
      expect(calls, 50);
      expect(icon.cacheLength, 50);

      await icon.get('p49'); // hit — no new extraction
      expect(calls, 50);

      await icon.get('p50'); // evicts p0
      expect(calls, 51);
      expect(icon.cacheLength, 50);

      await icon.get('p0'); // was evicted, extracted again
      expect(calls, 52);
    });

    test('a cached path never re-extracts', () async {
      var calls = 0;
      final icon = ProcessIcon(
        extractor: (path) async {
          calls++;
          return fakeBytes();
        },
      );

      await icon.get('chrome');
      await icon.get('chrome');
      await icon.get('chrome');

      expect(calls, 1);
    });
  });

  group('edge inputs', () {
    test('an empty path short-circuits before the extractor', () async {
      var called = false;
      final icon = ProcessIcon(
        extractor: (path) async {
          called = true;
          return fakeBytes();
        },
      );

      expect(await icon.get(''), isNull);
      expect(called, isFalse);
    });

    test('a failed extraction is remembered as a miss', () async {
      // Without this, every scroll pass would re-extract the processes whose
      // icons cannot be resolved — the storm the queue exists for.
      var calls = 0;
      final icon = ProcessIcon(extractor: (path) async {
        calls++;
        return null;
      });

      expect(await icon.get('ghost'), isNull);
      expect(await icon.get('ghost'), isNull);
      expect(calls, 1);
    });
  });

  group('real Windows extraction', () {
    testWidgets('a real executable yields PNG bytes', (tester) async {
      final bytes = await tester.runAsync(
        () => processIcon.get(r'C:\Windows\System32\cmd.exe'),
      );

      expect(bytes, isNotNull);
      // PNG magic number.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    }, skip: !Platform.isWindows);
  });
}
