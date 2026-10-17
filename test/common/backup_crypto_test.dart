import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/dav_client.dart';

/// P1 ② — WebDAV backup encryption. The cipher and KDF are the `cryptography`
/// package's (covered by its own suites); what is *ours* is the container
/// format, the failure behaviour, and how encrypted names behave inside the
/// versioned-backup grammar — so that is what is pinned here.
void main() {
  final plaintext = Uint8List.fromList(
    utf8.encode('label: my-config\nproxies: []\n'),
  );

  group('BackupCrypto round trip', () {
    test('decrypt(encrypt(x)) == x', () async {
      final sealed = await BackupCrypto.encrypt(plaintext, 'correct horse');

      expect(await BackupCrypto.decrypt(sealed, 'correct horse'), plaintext);
    });

    test('a wrong password fails loudly, never partial', () async {
      final sealed = await BackupCrypto.encrypt(plaintext, 'right');

      await expectLater(
        BackupCrypto.decrypt(sealed, 'wrong'),
        throwsA(anything),
      );
    });

    test('a single flipped byte fails the authentication tag', () async {
      final sealed = await BackupCrypto.encrypt(plaintext, 'pw');
      final tampered = Uint8List.fromList(sealed)
        ..[sealed.length - 1] ^= 0x01;

      await expectLater(
        BackupCrypto.decrypt(tampered, 'pw'),
        throwsA(anything),
      );
    });

    test('non-backup bytes are rejected by the magic, not the cipher',
        () async {
      await expectLater(
        BackupCrypto.decrypt(
          Uint8List.fromList(utf8.encode('PK\x03\x04not-a-backup')),
          'pw',
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('an empty password is refused before any crypto happens', () async {
      await expectLater(
        BackupCrypto.encrypt(plaintext, ''),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        BackupCrypto.decrypt(plaintext, ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('every encrypt uses a fresh salt and nonce', () async {
      final a = await BackupCrypto.encrypt(plaintext, 'same');
      final b = await BackupCrypto.encrypt(plaintext, 'same');

      expect(a, isNot(equals(b)));
      // Both still open under the same password.
      expect(await BackupCrypto.decrypt(a, 'same'), plaintext);
      expect(await BackupCrypto.decrypt(b, 'same'), plaintext);
    });

    test('header layout: magic ‖ salt(16) ‖ nonce(12) ‖ mac(16) ‖ body',
        () async {
      final sealed = await BackupCrypto.encrypt(plaintext, 'pw');
      const header = 8 + 16 + 12 + 16;

      expect(sealed.length, header + plaintext.length);
      expect(String.fromCharCodes(sealed.sublist(0, 8)), kBackupCryptoMagic);
    });

    test('an all-UTF-16 password round-trips too', () async {
      // `codeUnits` on a non-ASCII password: the same units are used for
      // encryption and decryption, so this guards the encoding contract
      // rather than any particular character.
      const pw = '密码🔑';
      final sealed = await BackupCrypto.encrypt(plaintext, pw);

      expect(await BackupCrypto.decrypt(sealed, pw), plaintext);
    });
  });

  group('isEncryptedName', () {
    test('recognises the suffix case-insensitively', () {
      expect(BackupCrypto.isEncryptedName('fluxora_20261017T101112Z.zip.enc'), isTrue);
      expect(BackupCrypto.isEncryptedName('fluxora_20261017T101112Z.ZIP.ENC'), isTrue);
      expect(BackupCrypto.isEncryptedName('fluxora_20261017T101112Z.zip'), isFalse);
      expect(BackupCrypto.isEncryptedName('fluxora.zip'), isFalse);
    });
  });

  group('versioned names with an encrypted payload', () {
    const baseName = 'fluxora';

    test('build → parse round trip keeps the encryption flag', () {
      final name = buildBackupName(
        DateTime.utc(2026, 10, 17, 10, 11, 12),
        0,
        baseName: baseName,
        encrypted: true,
      );
      expect(name, 'fluxora_20261017T101112Z.zip.enc');

      final parsed = parseVersionedBackupName(name, baseName: baseName);
      expect(parsed, isNotNull);
      expect(parsed!.timestamp, DateTime.utc(2026, 10, 17, 10, 11, 12));
      expect(parsed.sequence, 0);
    });

    test('sequence suffixes still parse when encrypted', () {
      final name = 'fluxora_20261017T101112Z_03.zip.enc';
      final parsed = parseVersionedBackupName(name, baseName: baseName);

      expect(parsed?.sequence, 3);
    });

    test('classify flags encrypted entries, plain and legacy alike', () {
      final versioned = classifyBackupName(
        'fluxora_20261017T101112Z.zip.enc',
        baseName: baseName,
      );
      expect(versioned?.isVersioned, isTrue);
      expect(versioned?.isEncrypted, isTrue);

      final plain = classifyBackupName(
        'fluxora_20261017T101112Z.zip',
        baseName: baseName,
      );
      expect(plain?.isEncrypted, isFalse);

      final legacy = classifyBackupName(
        'fluxora.zip.enc',
        baseName: baseName,
      );
      expect(legacy?.kind, BackupKind.legacy);
      expect(legacy?.isEncrypted, isTrue);
    });

    test('encrypted backups prune exactly like plain ones', () {
      // Newest-first list: 11 versioned entries, alternating encryption, plus a
      // legacy one. The retention policy must not exempt either kind.
      final entries = <BackupEntry>[
        for (var i = 11; i >= 1; i--)
          classifyBackupName(
            'fluxora_20261017T1011${i.toString().padLeft(2, '0')}Z'
            '${i.isEven ? '.zip.enc' : '.zip'}',
            baseName: baseName,
          )!,
        classifyBackupName('fluxora.zip', baseName: baseName)!,
      ];
      sortBackupEntriesDesc(entries);

      final prunable = selectPrunableBackups(entries);

      expect(prunable.length, 1);
      // The oldest versioned entry (second 01, odd ⇒ plain) goes — encryption
      // neither exempts a backup from pruning nor gets one deleted "extra".
      expect(prunable.single.name, 'fluxora_20261017T101101Z.zip');
      // Legacy is never a candidate even though it sorts last.
      expect(prunable.every((e) => e.isVersioned), isTrue);
    });
  });
}
