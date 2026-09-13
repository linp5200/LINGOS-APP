/// BLAKE2b-256 keyed（RFC 7693）——纯 Dart 实现
///
/// 【0.6.0 S1】与服务端 C 端 monocypher crypto_blake2b_keyed 逐字节一致。
/// 构建方式（已交叉验证）：
///   session_key = BLAKE2b-256(message = salt || info, key = shared_secret)
/// 验证链：镜像逻辑 → hashlib 标准一致（7 组测试+边界）→ C 实现一致（2 向量）。
library;

import 'dart:typed_data';

class Blake2b {
  Blake2b._();

  static const int blockBytes = 128;

  static const List<int> _iv = [
    0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
    0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
  ];

  static const List<List<int>> _sigma = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
    [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
    [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
    [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
    [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
    [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
    [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
    [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
    [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
  ];

  static int _rotr(int x, int n) => (x >>> n) | (x << (64 - n));

  static void _g(List<int> v, int a, int b, int c, int d, int x, int y) {
    v[a] = v[a] + v[b] + x;
    v[d] = _rotr(v[d] ^ v[a], 32);
    v[c] = v[c] + v[d];
    v[b] = _rotr(v[b] ^ v[c], 24);
    v[a] = v[a] + v[b] + y;
    v[d] = _rotr(v[d] ^ v[a], 16);
    v[c] = v[c] + v[d];
    v[b] = _rotr(v[b] ^ v[c], 63);
  }

  static void _compress(List<int> h, List<int> m, int t, bool finalBlock) {
    final v = List<int>.filled(16, 0);
    for (int i = 0; i < 8; i++) {
      v[i] = h[i];
    }
    for (int i = 0; i < 8; i++) {
      v[8 + i] = _iv[i];
    }
    v[12] ^= t;
    // v[13] ^= t_high（消息 < 2^64——忽略高位）
    if (finalBlock) v[14] ^= -1; // 0xFFFFFFFFFFFFFFFF
    for (int r = 0; r < 12; r++) {
      final s = _sigma[r];
      _g(v, 0, 4, 8, 12, m[s[0]], m[s[1]]);
      _g(v, 1, 5, 9, 13, m[s[2]], m[s[3]]);
      _g(v, 2, 6, 10, 14, m[s[4]], m[s[5]]);
      _g(v, 3, 7, 11, 15, m[s[6]], m[s[7]]);
      _g(v, 0, 5, 10, 15, m[s[8]], m[s[9]]);
      _g(v, 1, 6, 11, 12, m[s[10]], m[s[11]]);
      _g(v, 2, 7, 8, 13, m[s[12]], m[s[13]]);
      _g(v, 3, 4, 9, 14, m[s[14]], m[s[15]]);
    }
    for (int i = 0; i < 8; i++) {
      h[i] ^= v[i] ^ v[8 + i];
    }
  }

  static int _leU64(List<int> b, int o) {
    int v = 0;
    for (int i = 7; i >= 0; i--) {
      v = (v << 8) | (b[o + i] & 0xFF);
    }
    return v;
  }

  static void _putLeU64(Uint8List b, int o, int v) {
    for (int i = 0; i < 8; i++) {
      b[o + i] = (v >> (8 * i)) & 0xFF;
    }
  }

  /// BLAKE2b-256（输出 32 字节）
  /// [message] 待哈希数据；[key] 密钥（null/空 = 无密钥模式）
  static Uint8List blake2b256(Uint8List message, {Uint8List? key}) {
    final keyLen = (key == null) ? 0 : key.length;

    final h = List<int>.of(_iv);
    // 参数块：digest(1)=32 || key_len(1) || fanout(1)=1 || depth(1)=1 → 0x01010000
    h[0] ^= 0x01010000 ^ (keyLen << 8) ^ 32;

    // data = key_block(128) + message
    final builder = BytesBuilder();
    if (keyLen > 0) {
      final kb = Uint8List(blockBytes);
      kb.setRange(0, keyLen, key!);
      builder.add(kb);
    }
    builder.add(message);
    final data = builder.toBytes();

    final m = List<int>.filled(16, 0);
    if (data.isEmpty) {
      _compress(h, m, 0, true);
    } else {
      int t = 0;
      int off = 0;
      while (off < data.length) {
        final n = (data.length - off) < blockBytes ? (data.length - off) : blockBytes;
        final block = Uint8List(blockBytes);
        block.setRange(0, n, data, off);
        for (int i = 0; i < 16; i++) {
          m[i] = _leU64(block, i * 8);
        }
        t += n;
        final last = (off + n) >= data.length;
        _compress(h, m, t, last);
        off += n;
      }
    }

    final out = Uint8List(32);
    for (int i = 0; i < 4; i++) {
      _putLeU64(out, i * 8, h[i]);
    }
    return out;
  }
}
