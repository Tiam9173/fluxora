import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/dav_client.dart';

/// item 6 (Bettbox 1.19.3) — WebDAV backup versions.
///
/// The naming, classification, ordering and retention rules are pure so they can
/// be asserted here. The parts that talk to a server — picking a free name from
/// a live listing, verifying a write landed, and the prune call itself — are not
/// covered by these tests; see the report for what remains unverified.
void main() {
  const base = 'fluxora';

  group('UTC naming', () {
    test('encodes the instant as compact ISO 8601 UTC', () {
      final name = buildBackupName(
        DateTime.utc(2026, 10, 16, 23, 5, 0),
        0,
        baseName: base,
      );
      expect(name, 'fluxora_20261016T230500Z.zip');
    });

    test('appends a zero-padded collision sequence', () {
      final name = buildBackupName(
        DateTime.utc(2026, 10, 16, 23, 5, 0),
        1,
        baseName: base,
      );
      expect(name, 'fluxora_20261016T230500Z_01.zip');
    });

    test('a local DateTime is converted to UTC, not stamped as-is', () {
      // The whole point of the format is that the stamp means one instant
      // everywhere. A caller passing local time must still get a UTC name.
      final local = DateTime(2026, 10, 16, 23, 5, 0);
      final name = buildBackupName(local, 0, baseName: base);
      final expected = local.toUtc();
      expect(
        name,
        buildBackupName(expected, 0, baseName: base),
      );
    });

    test('names sort chronologically as plain strings', () {
      final older = buildBackupName(DateTime.utc(2026, 1, 9, 1, 2, 3), 0, baseName: base);
      final newer = buildBackupName(DateTime.utc(2026, 10, 16, 23, 5, 0), 0, baseName: base);
      // Zero-padding is what makes this true; if it ever breaks, sorting by
      // string would silently reorder history.
      expect(older.compareTo(newer) < 0, isTrue);
    });
  });

  group('parseVersionedBackupName', () {
    test('recovers the instant and sequence', () {
      final parsed = parseVersionedBackupName(
        'fluxora_20261016T230500Z_02.zip',
        baseName: base,
      );
      expect(parsed, isNotNull);
      expect(parsed!.timestamp, DateTime.utc(2026, 10, 16, 23, 5, 0));
      expect(parsed.sequence, 2);
    });

    test('treats a missing suffix as sequence 0', () {
      final parsed = parseVersionedBackupName(
        'fluxora_20261016T230500Z.zip',
        baseName: base,
      );
      expect(parsed!.sequence, 0);
    });

    test('round-trips through buildBackupName', () {
      final name = buildBackupName(
        DateTime.utc(2026, 3, 4, 5, 6, 7),
        9,
        baseName: base,
      );
      final parsed = parseVersionedBackupName(name, baseName: base)!;
      expect(parsed.timestamp, DateTime.utc(2026, 3, 4, 5, 6, 7));
      expect(parsed.sequence, 9);
    });

    test('rejects a name whose date does not exist', () {
      // `DateTime.utc(2026, 13, 1)` would roll over into 2027 rather than fail,
      // so a malformed name would otherwise become a plausible wrong instant.
      expect(
        parseVersionedBackupName('fluxora_20261301T000000Z.zip', baseName: base),
        isNull,
      );
      expect(
        parseVersionedBackupName('fluxora_20260230T000000Z.zip', baseName: base),
        isNull,
      );
    });

    test('rejects a name that is not strictly formed', () {
      for (final name in [
        'fluxora_2026-10-16T23:05:00Z.zip', // punctuation
        'fluxora_20261016T2305Z.zip', // missing seconds
        'fluxora_20261016T230500.zip', // missing Z
        'fluxora_20261016T230500Z.zip.bak', // extra suffix
        'other_20261016T230500Z.zip', // wrong base name
        'fluxora.zip', // legacy, not versioned
      ]) {
        expect(
          parseVersionedBackupName(name, baseName: base),
          isNull,
          reason: name,
        );
      }
    });
  });

  group('classifyBackupName', () {
    test('recognises a versioned backup', () {
      final entry = classifyBackupName(
        'fluxora_20261016T230500Z.zip',
        baseName: base,
      )!;
      expect(entry.kind, BackupKind.versioned);
      expect(entry.isVersioned, isTrue);
    });

    test('recognises the legacy backup, case-insensitively', () {
      for (final name in ['fluxora.zip', 'Fluxora.ZIP']) {
        final entry = classifyBackupName(name, baseName: base)!;
        expect(entry.kind, BackupKind.legacy, reason: name);
        expect(entry.isVersioned, isFalse);
        expect(entry.timestamp, isNull);
      }
    });

    test('returns null for anything unrecognised', () {
      // Null is what keeps a stray file out of both the list and the reach of
      // the retention policy.
      for (final name in [
        'notes.txt',
        'fluxora_old.zip',
        'fluxora_backup.zip',
        'fluxora_20261016T230500Z.tar',
      ]) {
        expect(classifyBackupName(name, baseName: base), isNull, reason: name);
      }
    });
  });

  group('sortBackupEntriesDesc', () {
    test('orders by timestamp, newest first', () {
      final entries = [
        classifyBackupName('fluxora_20260101T000000Z.zip', baseName: base)!,
        classifyBackupName('fluxora_20261016T230500Z.zip', baseName: base)!,
        classifyBackupName('fluxora_20260601T000000Z.zip', baseName: base)!,
      ]..shuffle();
      sortBackupEntriesDesc(entries);

      expect(entries.map((e) => e.name).toList(), [
        'fluxora_20261016T230500Z.zip',
        'fluxora_20260601T000000Z.zip',
        'fluxora_20260101T000000Z.zip',
      ]);
    });

    test('breaks ties within the same second by sequence, descending', () {
      // Same-second collision is the case the sequence exists for.
      final entries = [
        classifyBackupName('fluxora_20261016T230500Z.zip', baseName: base)!,
        classifyBackupName('fluxora_20261016T230500Z_02.zip', baseName: base)!,
        classifyBackupName('fluxora_20261016T230500Z_01.zip', baseName: base)!,
      ];
      sortBackupEntriesDesc(entries);

      expect(entries.map((e) => e.name).toList(), [
        'fluxora_20261016T230500Z_02.zip',
        'fluxora_20261016T230500Z_01.zip',
        'fluxora_20261016T230500Z.zip',
      ]);
    });

    test('puts the legacy backup last', () {
      final entries = [
        classifyBackupName('fluxora.zip', baseName: base)!,
        classifyBackupName('fluxora_20260101T000000Z.zip', baseName: base)!,
      ];
      sortBackupEntriesDesc(entries);
      expect(entries.last.kind, BackupKind.legacy);
    });
  });

  group('selectPrunableBackups', () {
    List<BackupEntry> versioned(int count) {
      final entries = <BackupEntry>[];
      for (var i = 0; i < count; i++) {
        entries.add(
          classifyBackupName(
            buildBackupName(DateTime.utc(2026, 1, 1).add(Duration(minutes: i)), 0, baseName: base),
            baseName: base,
          )!,
        );
      }
      sortBackupEntriesDesc(entries);
      return entries;
    }

    test('deletes nothing at or below the limit', () {
      expect(selectPrunableBackups(versioned(10)), isEmpty);
      expect(selectPrunableBackups(versioned(9)), isEmpty);
    });

    test('keeps the newest 10 and marks the rest', () {
      final entries = versioned(13);
      final prunable = selectPrunableBackups(entries);
      expect(prunable, hasLength(3));
      // Everything marked must be older than everything kept.
      final kept = entries.take(10).toList();
      for (final p in prunable) {
        expect(p.timestamp!.isBefore(kept.last.timestamp!), isTrue);
      }
    });

    test('never marks the legacy backup, even when versions are over the limit', () {
      final entries = versioned(12)
        ..add(classifyBackupName('fluxora.zip', baseName: base)!);
      sortBackupEntriesDesc(entries);

      final prunable = selectPrunableBackups(entries);
      expect(prunable.any((e) => !e.isVersioned), isFalse);
      expect(prunable, hasLength(2));
    });

    test('the legacy backup does not consume a version slot', () {
      // 10 versioned + 1 legacy must prune nothing: the legacy file is not one
      // of the 10.
      final entries = versioned(10)
        ..add(classifyBackupName('fluxora.zip', baseName: base)!);
      sortBackupEntriesDesc(entries);
      expect(selectPrunableBackups(entries), isEmpty);
    });
  });
}
