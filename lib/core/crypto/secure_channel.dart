/// 安全通道（Dart 端——S1 应用层加密）
///
/// 与 C 端 src/security/secure_channel.c 逐字节对齐：
///   1. X25519 ECDH 前向保密（临时密钥对）
///   2. session_key = BLAKE2b-256(message = salt || "LINGOS-SC-v1", key = shared)
///   3. XChaCha20-Poly1305 逐帧 AEAD（nonce = dir(4B LE) || seq(8B BE) || 零填充）
///   4. 方向约定：客户端发送=1 / 服务端发送=2（防 nonce 撞车）
///   5. 序列号：首帧 seq=0，此后严格递增（防重放）
///
/// 交叉验证依据（构建时）：
///   · KDF 与 Python hashlib 标准一致（7 组测试含边界）→ 与 C 实现一致（2 向量）
///   · AEAD = 标准 XChaCha20-Poly1305（空 AD），与 monocypher crypto_aead_lock 同构
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'blake2b.dart';

class DartSecureChannel {
  static const int tagSize = 16;
  static const int maxPayload = 16128; // 明文上限（16KB 帧预算内）

  final SimpleKeyPair _keyPair;
  final Uint8List _localPublic;

  Uint8List? _sessionKey;
  bool _ready = false;

  int _sendSeq = 0;
  int _recvSeq = 0;
  bool _recvSeqInit = false;

  int _sendDir = 0;
  int _recvDir = 0;

  DartSecureChannel._(this._keyPair, this._localPublic);

  /// 创建通道（生成临时 X25519 密钥对；失败返回 null）
  static Future<DartSecureChannel?> create() async {
    try {
      final algo = X25519();
      final kp = await algo.newKeyPair();
      final pub = await kp.extractPublicKey();
      return DartSecureChannel._(kp, Uint8List.fromList(pub.bytes));
    } catch (_) {
      return null;
    }
  }

  Uint8List get localPublic => _localPublic;
  bool get isReady => _ready;

  /// 握手：载入对端公钥 + 组合 salt → 派生会话密钥
  Future<bool> handshake(Uint8List peerPublic, Uint8List salt) async {
    try {
      final algo = X25519();
      final remote = SimplePublicKey(peerPublic, type: KeyPairType.x25519);
      final shared = await algo.sharedSecretKey(keyPair: _keyPair, remotePublicKey: remote);
      final sharedBytes = await shared.extractBytes();

      // 弱公钥检查（全零共享密钥 → 拒绝——与 C 端一致）
      bool allZero = true;
      for (final b in sharedBytes) {
        if (b != 0) {
          allZero = false;
          break;
        }
      }
      if (allZero) return false;

      final info = Uint8List.fromList('LINGOS-SC-v1'.codeUnits);
      final msg = Uint8List(salt.length + info.length)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + info.length, info);
      _sessionKey = Blake2b.blake2b256(msg, key: Uint8List.fromList(sharedBytes));
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 方向约定（客户端：send=1, recv=2）
  void setDirection(int sendDir, int recvDir) {
    _sendDir = sendDir;
    _recvDir = recvDir;
  }

  Uint8List _buildNonce(int dir, int seq) {
    final nonce = Uint8List(24);
    nonce[0] = dir & 0xFF;
    nonce[1] = (dir >> 8) & 0xFF;
    nonce[2] = (dir >> 16) & 0xFF;
    nonce[3] = (dir >> 24) & 0xFF;
    for (int i = 0; i < 8; i++) {
      nonce[4 + i] = (seq >> (56 - i * 8)) & 0xFF;
    }
    return nonce;
  }

  /// 加密一帧 → ciphertext || tag（失败返回 null）
  Future<Uint8List?> encrypt(Uint8List plain) async {
    if (!_ready || _sessionKey == null) return null;
    if (plain.length > maxPayload) return null;
    try {
      final aead = Xchacha20.poly1305Aead();
      final nonce = _buildNonce(_sendDir, _sendSeq);
      final box = await aead.encrypt(plain, secretKey: SecretKey(_sessionKey!), nonce: nonce);
      final mac = box.mac.bytes;
      final out = Uint8List(box.cipherText.length + mac.length);
      out.setRange(0, box.cipherText.length, box.cipherText);
      out.setRange(box.cipherText.length, out.length, mac);
      _sendSeq++;
      return out;
    } catch (_) {
      return null;
    }
  }

  /// 解密一帧（ciphertext || tag；失败返回 null——防篡改/重放）
  Future<Uint8List?> decrypt(Uint8List cipherWithTag) async {
    if (!_ready || _sessionKey == null) return null;
    if (cipherWithTag.length < tagSize) return null;
    try {
      final ctLen = cipherWithTag.length - tagSize;
      final cipher = Uint8List.sublistView(cipherWithTag, 0, ctLen);
      final mac = Uint8List.sublistView(cipherWithTag, ctLen);
      final seq = _recvSeqInit ? (_recvSeq + 1) : 0;
      final nonce = _buildNonce(_recvDir, seq);
      final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
      final aead = Xchacha20.poly1305Aead();
      final clear = await aead.decrypt(box, secretKey: SecretKey(_sessionKey!));
      _recvSeq = seq;
      _recvSeqInit = true;
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }
}
