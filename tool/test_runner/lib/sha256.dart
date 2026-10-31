// Dependency-free SHA-256 (FIPS 180-4).
//
// R7-1..R7-4 must not add pub dependencies and must not shell out to external
// programs, so the manifest fingerprint is computed here with `dart:typed_data`
// only. The digest is used for V10 (manifest drift) and for evidence checksums.
class Sha256 {
  const Sha256._();

  /// 64 round constants, FIPS 180-4 §4.2.2.
  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const int _mask32 = 0xFFFFFFFF;

  /// Lower-case hex digest of [input].
  static String hexOfBytes(List<int> input) {
    final List<int> digest = _digest(input);
    final StringBuffer buffer = StringBuffer();
    for (final int byte in digest) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static int _rotr(int value, int bits) =>
      ((value >> bits) | (value << (32 - bits))) & _mask32;

  static List<int> _digest(List<int> input) {
    final int bitLength = input.length * 8;
    final int paddedLength = ((input.length + 8) ~/ 64 + 1) * 64;
    final List<int> message = List<int>.filled(paddedLength, 0);
    message.setRange(0, input.length, input);
    message[input.length] = 0x80;

    final int highBits = bitLength ~/ 0x100000000;
    final int lowBits = bitLength & _mask32;
    message[paddedLength - 8] = (highBits >> 24) & 0xFF;
    message[paddedLength - 7] = (highBits >> 16) & 0xFF;
    message[paddedLength - 6] = (highBits >> 8) & 0xFF;
    message[paddedLength - 5] = highBits & 0xFF;
    message[paddedLength - 4] = (lowBits >> 24) & 0xFF;
    message[paddedLength - 3] = (lowBits >> 16) & 0xFF;
    message[paddedLength - 2] = (lowBits >> 8) & 0xFF;
    message[paddedLength - 1] = lowBits & 0xFF;

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final List<int> w = List<int>.filled(64, 0);

    for (int offset = 0; offset < paddedLength; offset += 64) {
      for (int t = 0; t < 16; t++) {
        final int base = offset + t * 4;
        w[t] = (message[base] << 24) |
            (message[base + 1] << 16) |
            (message[base + 2] << 8) |
            message[base + 3];
      }
      for (int t = 16; t < 64; t++) {
        final int s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
        final int s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mask32;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int t = 0; t < 64; t++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ (~e & _mask32 & g);
        final int temp1 = (h + s1 + ch + _k[t] + w[t]) & _mask32;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (s0 + maj) & _mask32;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }

      h0 = (h0 + a) & _mask32;
      h1 = (h1 + b) & _mask32;
      h2 = (h2 + c) & _mask32;
      h3 = (h3 + d) & _mask32;
      h4 = (h4 + e) & _mask32;
      h5 = (h5 + f) & _mask32;
      h6 = (h6 + g) & _mask32;
      h7 = (h7 + h) & _mask32;
    }

    final List<int> out = <int>[];
    for (final int word in <int>[h0, h1, h2, h3, h4, h5, h6, h7]) {
      out
        ..add((word >> 24) & 0xFF)
        ..add((word >> 16) & 0xFF)
        ..add((word >> 8) & 0xFF)
        ..add(word & 0xFF);
    }
    return out;
  }
}
