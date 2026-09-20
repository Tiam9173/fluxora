import 'dart:convert';
import 'dart:typed_data';
import 'package:bett_box/common/curve25519.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hexToBytes(String hex) {
  final clean = hex.replaceAll(' ', '').trim();
  final result = Uint8List(clean.length ~/ 2);
  for (int i = 0; i < result.length; i++) {
    result[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

BigInt _decodeLittleEndian(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (int i = bytes.length - 1; i >= 0; i--) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

void main() {
  group('Curve25519 RFC 7748 规范测试', () {
    test('RFC 7748 Section 5.2 官方测试向量', () {
      final scalar = _hexToBytes(
        'a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4',
      );
      final uBytes = _hexToBytes(
        'e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c',
      );
      final expected = 'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552';

      final uBigInt = _decodeLittleEndian(uBytes);
      final result = Curve25519.x25519(scalar, uBigInt);

      expect(_bytesToHex(result), expected);
    });

    test('随机生成密钥对与公钥推导测试', () {
      final keyPair = Curve25519.generateKeyPair();
      expect(keyPair.privateKey.isNotEmpty, isTrue);
      expect(keyPair.publicKey.isNotEmpty, isTrue);

      final derivedPub = Curve25519.calculatePublicKey(keyPair.privateKey);
      expect(derivedPub, keyPair.publicKey);

      final privBytes = base64Decode(keyPair.privateKey);
      expect(privBytes.length, 32);
      final pubBytes = base64Decode(keyPair.publicKey);
      expect(pubBytes.length, 32);
    });
  });
}
