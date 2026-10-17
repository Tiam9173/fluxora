/// P1 ② — WebDAV backup encryption (user authorized the `cryptography`
/// dependency on 2026-10-17; pubspec is normally frozen).
///
/// Threat model, stated plainly: this protects the backup **at rest on the
/// DAV server**. A compromised server sees ciphertext only. It is not a
/// transport protection (that is HTTPS's job) and it is not a substitute for
/// the DAV credentials.
///
/// Format — self-describing header followed by the AES-256-GCM output:
///
/// ```text
/// magic(8) ‖ salt(16) ‖ nonce(12) ‖ mac(16) ‖ cipherText
/// ```
///
/// * `magic`   — `FLXENC01`, so a future format change is greppable.
/// * `salt`    — random per backup, fed to PBKDF2. Never reused.
/// * `nonce`   — random per backup, AES-GCM nonce. Never reused (96-bit
///               random nonces; the birthday bound is ~2^32 backups, which no
///               user will ever reach).
/// * `mac`     — GCM authentication tag. A wrong password or a tampered byte
///               fails here — decryption never yields partial plaintext.
///
/// The password is never persisted by this module; callers collect it per
/// operation (once to back up, once per restore).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const String kBackupCryptoMagic = 'FLXENC01';

const int _saltLength = 16;
const int _nonceLength = 12;
const int _macLength = 16;

/// OWASP's PBKDF2-HMAC-SHA256 recommendation (2023): 210k iterations for a
/// 256-bit key. Lower would be faster to brute-force; much higher makes phones
/// stutter on every restore.
const int _pbkdf2Iterations = 210000;

class BackupCrypto {
  const BackupCrypto._();

  static final _cipher = AesGcm.with256bits();

  /// Encrypts [plaintext] under [password]. Every call produces a fresh salt
  /// and nonce, so encrypting the same file twice yields different outputs.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    String password,
  ) async {
    if (password.isEmpty) {
      throw ArgumentError('Backup password must not be empty');
    }
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final secretKey = await _deriveKey(password, salt);
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    final builder = BytesBuilder(copy: false)
      ..add(_magicBytes)
      ..add(salt)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return builder.toBytes();
  }

  /// Reverses [encrypt]. Throws [BackupCryptoException] when the input is not
  /// an encrypted backup at all, and [SecretBoxAuthenticationError] (from the
  /// cipher) when the password is wrong or the bytes were tampered with.
  static Future<Uint8List> decrypt(
    Uint8List payload,
    String password,
  ) async {
    if (password.isEmpty) {
      throw ArgumentError('Backup password must not be empty');
    }
    final headerLength =
        kBackupCryptoMagic.length + _saltLength + _nonceLength + _macLength;
    if (payload.length < headerLength) {
      throw const BackupCryptoException('not an encrypted backup');
    }
    final magic = String.fromCharCodes(payload.sublist(0, 8));
    if (magic != kBackupCryptoMagic) {
      throw const BackupCryptoException('not an encrypted backup');
    }
    var offset = 8;
    final salt = Uint8List.sublistView(payload, offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = Uint8List.sublistView(payload, offset, offset + _nonceLength);
    offset += _nonceLength;
    final mac = Uint8List.sublistView(payload, offset, offset + _macLength);
    offset += _macLength;
    final cipherText = Uint8List.sublistView(payload, offset);

    final secretKey = await _deriveKey(password, salt);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    return Uint8List.fromList(await _cipher.decrypt(box, secretKey: secretKey));
  }

  /// Whether [name] addresses an encrypted backup entry (`…​.zip.enc`). The
  /// check is case-insensitive because DAV servers disagree about case.
  static bool isEncryptedName(String name) =>
      name.toLowerCase().endsWith('.zip.enc');

  static Future<SecretKey> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(password.codeUnits),
      nonce: salt,
    );
  }

  static List<int> get _magicBytes => kBackupCryptoMagic.codeUnits;

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class BackupCryptoException implements Exception {
  const BackupCryptoException(this.message);

  final String message;

  @override
  String toString() => 'BackupCryptoException: $message';
}
