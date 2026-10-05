import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/services/atomic_config_storage.dart';

void main() {
  group('Phase 5.0-D Atomic Config Storage', () {
    late Directory tempDir;
    late String filePath;
    late AtomicConfigStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atomic_config_test');
      filePath = '${tempDir.path}/chain_proxies.json';
      storage = AtomicConfigStorage(filePath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Normal save & atomic replace', () async {
      final data = {'hello': 'world'};
      await storage.save(data);

      final file = File(filePath);
      expect(await file.exists(), isTrue);

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['hello'], equals('world'));
    });

    test('2. Backup creation & recovery', () async {
      final data1 = {'version': 1};
      await storage.save(data1);

      final data2 = {'version': 2};
      await storage.save(data2);

      // Verify backup exists
      final backup = File('$filePath.bak');
      expect(await backup.exists(), isTrue);

      // Destroy original file
      final file = File(filePath);
      await file.delete();

      // Load should recover from backup (which contains version 1)
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['version'], equals(1));
    });

    test('3. Corrupted json recovery', () async {
      await storage.save({'version': 0});
      await storage.save({'version': 1});

      // Save a corrupt JSON directly to the target file
      final file = File(filePath);
      await file.writeAsString('invalid { json', flush: true);

      // Load should fallback to backup which has version 0
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['version'], equals(0));
    });

    test('4. Tmp recovery (Crash Simulation)', () async {
      // Create a fake tmp file as if a crash happened before rename
      final tmpFile = File('$filePath.123456.123.tmp');
      await tmpFile.writeAsString('{"tmpVersion": 99}', flush: true);

      // Load should pick up the tmp file when main is missing
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['tmpVersion'], equals(99));
    });

    test('5. Concurrent save protection (isolated files)', () async {
      final futures = <Future>[];
      for (int i = 0; i < 50; i++) {
        futures.add(storage.save({'id': i}));
      }
      await Future.wait(futures);

      // Verify the file contains one of the valid ids and is not corrupted
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['id'], isA<int>());
    });

    test('6. Empty file recovery', () async {
      await storage.save({'version': 0});
      await storage.save({'version': 1});

      // Empty the main file
      final file = File(filePath);
      await file.writeAsString('', flush: true);

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['version'], equals(0));
    });
  });
}
