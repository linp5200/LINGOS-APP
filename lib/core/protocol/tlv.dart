/// TLV 帧编解码（协议 v3——TCP 2937 主通道）
///
/// 帧格式：MAGIC(4B "LNGS") + VERSION(2B 0x0001) + TYPE(2B) + LENGTH(4B) + PAYLOAD
/// 大端序 | PAYLOAD 上限 16KB
library;

import 'dart:typed_data';

/// 消息类型（与服务端 connection_msg_type_t 对齐）
class MsgType {
  static const int authCode = 0x0001;
  static const int authResponse = 0x0002;
  static const int connectionCode = 0x0003;
  static const int connectionResponse = 0x0004;
  static const int command = 0x0005;
  static const int commandResponse = 0x0006;
  static const int status = 0x0007;
  static const int heartbeat = 0x0008;
  static const int heartbeatAck = 0x0009;
  static const int error = 0x000A;
  // 备用（协议 v3——授权实际走 WS）
  static const int authRequest = 0x000B;
  static const int authResponseBackup = 0x000C;
}

/// 错误码
class ErrCode {
  static const int success = 0;
  static const int serverBusy = 0x4001;
  static const int authInvalid = 0x4002;
  static const int codeInvalid = 0x4003;
  static const int sessionExpired = 0x4004;
  static const int commandUnknown = 0x4005;
  static const int paramInvalid = 0x4006;
  static const int permissionDenied = 0x4007;
  static const int deviceNotFound = 0x4008;
  static const int timeout = 0x4009;
  static const int authRejected = 0x400A;
  static const int authTimeout = 0x400B;
}

class TlvFrame {
  static const int magic = 0x4C4E4753;
  static const int version = 0x0001;
  static const int headerLen = 12;
  static const int maxPayload = 16 * 1024;

  final int type;
  final Uint8List payload;

  const TlvFrame(this.type, this.payload);

  /// 编码为字节流（大端）
  Uint8List encode() {
    final b = ByteData(headerLen + payload.length);
    b.setUint32(0, magic);
    b.setUint16(4, version);
    b.setUint16(6, type);
    b.setUint32(8, payload.length);
    final out = Uint8List.view(b.buffer, 0, headerLen + payload.length);
    out.setRange(headerLen, headerLen + payload.length, payload);
    return out;
  }

  /// 从字节流解析（返回帧 + 消耗字节数；不足返回 null）
  static TlvFrame? decode(ByteData data, int offset) {
    if (data.lengthInBytes - offset < headerLen) return null;
    if (data.getUint32(offset) != magic) return null;
    final ver = data.getUint16(offset + 4);
    if (ver != version) return null;
    final type = data.getUint16(offset + 6);
    final len = data.getUint32(offset + 8);
    if (len > maxPayload) return null;
    if (data.lengthInBytes - offset - headerLen < len) return null;
    final payload = Uint8List(len);
    for (int i = 0; i < len; i++) {
      payload[i] = data.getUint8(offset + headerLen + i);
    }
    return TlvFrame(type, payload);
  }

  String payloadString() => String.fromCharCodes(payload);
}
