import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Pure Dart implementation of Curve25519 / X25519 (RFC 7748).
/// Used for generating WireGuard client private and public key pairs.
class Curve25519 {
  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
  static final BigInt _a24 = BigInt.from(121665);

  /// Generates a random 32-byte WireGuard private key (unclamped raw bytes).
  static Uint8List generatePrivateKeyBytes() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Clamps private key bytes according to RFC 7748 / WireGuard specification.
  static Uint8List clampPrivateKey(Uint8List keyBytes) {
    final clamped = Uint8List.fromList(keyBytes);
    clamped[0] &= 248;
    clamped[31] &= 127;
    clamped[31] |= 64;
    return clamped;
  }

  /// RFC 7748 X25519 function: clamps scalar then performs scalar multiplication.
  static Uint8List x25519(Uint8List scalarBytes, BigInt u) {
    final clamped = clampPrivateKey(scalarBytes);
    return scalarMult(clamped, u);
  }

  /// Derives the 32-byte public key from a private key.
  static Uint8List derivePublicKeyBytes(Uint8List privateKeyBytes) {
    return x25519(privateKeyBytes, BigInt.from(9));
  }

  /// RFC 7748 X25519 scalar multiplication.
  /// [scalarBytes]: 32 bytes little-endian.
  /// [u]: base coordinate as BigInt.
  static Uint8List scalarMult(Uint8List scalarBytes, BigInt u) {
    BigInt x1 = u % _p;
    BigInt x2 = BigInt.one;
    BigInt z2 = BigInt.zero;
    BigInt x3 = u % _p;
    BigInt z3 = BigInt.one;
    int swap = 0;

    for (int t = 254; t >= 0; t--) {
      final byteIndex = t ~/ 8;
      final bitIndex = t % 8;
      final kt = (scalarBytes[byteIndex] >> bitIndex) & 1;

      swap ^= kt;
      if (swap != 0) {
        final tx = x2; x2 = x3; x3 = tx;
        final tz = z2; z2 = z3; z3 = tz;
      }
      swap = kt;

      final a = (x2 + z2) % _p;
      final aa = (a * a) % _p;
      final b = (x2 - z2 + _p) % _p;
      final bb = (b * b) % _p;
      final e = (aa - bb + _p) % _p;
      final c = (x3 + z3) % _p;
      final d = (x3 - z3 + _p) % _p;
      final da = (d * a) % _p;
      final cb = (c * b) % _p;

      final daPlusCb = (da + cb) % _p;
      x3 = (daPlusCb * daPlusCb) % _p;

      final daMinusCb = (da - cb + _p) % _p;
      z3 = (x1 * ((daMinusCb * daMinusCb) % _p)) % _p;

      x2 = (aa * bb) % _p;
      final a24TimesE = (_a24 * e) % _p;
      z2 = (e * ((aa + a24TimesE) % _p)) % _p;
    }

    if (swap != 0) {
      final tx = x2; x2 = x3; x3 = tx;
      final tz = z2; z2 = z3; z3 = tz;
    }

    // result = x2 * (z2 ^ (p - 2)) mod p
    final z2Inv = z2.modPow(_p - BigInt.two, _p);
    final result = (x2 * z2Inv) % _p;

    return _encodeLittleEndian(result);
  }

  static Uint8List _encodeLittleEndian(BigInt n) {
    final bytes = Uint8List(32);
    var temp = n;
    for (int i = 0; i < 32; i++) {
      bytes[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }

  /// Generates a new random WireGuard KeyPair with base64 encoded private/public keys.
  static WireGuardKeyPair generateKeyPair() {
    final priv = generatePrivateKeyBytes();
    final clamped = clampPrivateKey(priv);
    final pub = derivePublicKeyBytes(clamped);

    return WireGuardKeyPair(
      privateKey: base64Encode(clamped),
      publicKey: base64Encode(pub),
    );
  }

  /// Calculates public key from a base64 private key.
  static String calculatePublicKey(String base64PrivateKey) {
    try {
      final privBytes = base64Decode(base64PrivateKey.trim());
      if (privBytes.length != 32) return '';
      final pubBytes = derivePublicKeyBytes(privBytes);
      return base64Encode(pubBytes);
    } catch (_) {
      return '';
    }
  }
}

class WireGuardKeyPair {
  final String privateKey;
  final String publicKey;

  const WireGuardKeyPair({
    required this.privateKey,
    required this.publicKey,
  });
}
