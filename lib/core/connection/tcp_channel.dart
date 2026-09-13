/// TCP 通道（协议 v3——两步认证 + 心跳 + 【0.6.0 S1】应用层加密）
/// Android/桌面使用（dart:io Socket——浏览器不可用）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../crypto/secure_channel.dart';
import '../protocol/tlv.dart';
import 'channel.dart';
import '../logging/app_logger.dart';

class TcpChannel implements ConnectChannel {
  final String host;
  final int port;
  final int connectTimeoutMs;

  Socket? _socket;
  ByteData? _pending;
  bool _disposed = false;
  Timer? _heartbeatTimer;
  ChannelListener? _listener;

  /// 认证状态
  bool authenticated = false;
  String token = '';
  String? lastError;

  // ===== 【0.6.0 S1】应用层加密（X25519 + XChaCha20-Poly1305）=====
  DartSecureChannel? _sc;
  bool _encActive = false;
  bool _kexStarted = false;
  Uint8List? _kexClientSalt;
  Timer? _kexTimer;
  /// 帧处理串行链（异步解密防乱序）
  Future<void> _procChain = Future.value();

  TcpChannel({
    required this.host,
    required this.port,
    this.connectTimeoutMs = 8000,
  });

  @override
  bool get isConnected => _socket != null && !_disposed;

  /// 【0.6.0】当前会话是否已启用应用层加密（诚实状态——UI 可显示）
  bool get encActive => _encActive;

  @override
  void setListener(ChannelListener listener) => _listener = listener;

  @override
  Future<bool> connect() async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: Duration(milliseconds: connectTimeoutMs));
      _socket = socket;
      _disposed = false;
      appLog('TcpChannel', '已连接 $host:$port');

      socket.listen(
        _onRawData,
        onError: (e) {
          _listener?.onError('连接错误: $e');
          _cleanup();
        },
        onDone: () {
          _listener?.onDisconnected('连接已断开');
          _cleanup();
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      lastError = _errDetail(e);
      appLog('TcpChannel', '连接失败 $host:$port → ${_errDetail(e)}');
      _listener?.onError('连接失败: $lastError');
      return false;
    }
  }

  /// 错误详情提取（SocketException 等）
  String _errDetail(Object e) {
    if (e is SocketException) {
      final msg = e.message;
      final osErr = e.osError?.message ?? '';
      final detail = [msg, osErr].where((s) => s.isNotEmpty).join(' | ');
      return 'Socket异常: $detail';
    }
    if (e is TimeoutException) {
      return '连接超时（${connectTimeoutMs}ms 无响应）';
    }
    return '连接失败: $e';
  }

  /// 发送 TLV 帧（【0.6.0 S1】加密会话自动 AEAD 加密）
  Future<bool> sendFrame(int type, String payload) async {
    if (!isConnected) return false;
    try {
      var payloadBytes = Uint8List.fromList(utf8.encode(payload));
      if (_encActive && _sc != null && type != MsgType.keyExchange && payloadBytes.isNotEmpty) {
        if (payloadBytes.length > DartSecureChannel.maxPayload) {
          appLog('TcpChannel', '帧过大（${payloadBytes.length}B）超加密上限——发送中止（诚实）');
          _listener?.onError('帧过大未发送（加密模式上限 ${DartSecureChannel.maxPayload}B）');
          return false;
        }
        final enc = await _sc!.encrypt(payloadBytes);
        if (enc == null) {
          appLog('TcpChannel', '加密失败——发送中止');
          return false;
        }
        payloadBytes = enc;
      }
      return await _sendRawFrame(type, payloadBytes);
    } catch (e) {
      appLog('TcpChannel', '发送失败: $e');
      _listener?.onError('发送失败: $e');
      return false;
    }
  }

  /// 原始帧发送（不经加密——密钥交换与已加密帧走此通道）
  Future<bool> _sendRawFrame(int type, Uint8List payloadBytes) async {
    if (!isConnected) return false;
    final frame = TlvFrame(type, payloadBytes);
    _socket!.add(frame.encode());
    await _socket!.flush();
    final showLen = payloadBytes.length > 60 ? 60 : payloadBytes.length;
    appLog('TcpChannel', '发送帧 0x${type.toRadixString(16).padLeft(4, '0')} len=${payloadBytes.length}'
        '${_encActive && type != MsgType.keyExchange ? ' [encrypted]' : ''}');
    return true;
  }

  /// 【0.6.0 S1】发起应用层加密密钥交换（连接建立后调用）
  Future<void> _startKeyExchange() async {
    if (_kexStarted) return;
    _kexStarted = true;
    try {
      _sc = await DartSecureChannel.create();
      if (_sc == null) {
        appLog('TcpChannel', '加密通道创建失败（保持明文）');
        return;
      }
      final salt = _randomBytes(16);
      _kexClientSalt = salt;
      final payload = Uint8List(52);
      payload[3] = 0x01; // caps = SC_CAP_ENCRYPT（大端）
      payload.setRange(4, 36, _sc!.localPublic);
      payload.setRange(36, 52, salt);
      await _sendRawFrame(MsgType.keyExchange, payload);
      appLog('TcpChannel', '密钥交换已发起（X25519）');
      _kexTimer = Timer(const Duration(seconds: 4), () {
        if (!_encActive) {
          appLog('TcpChannel', '密钥交换超时——保持明文（诚实上报）');
          _listener?.onData('{"type":"e2e_status","encrypted":false,"reason":"timeout"}');
        }
      });
    } catch (e) {
      appLog('TcpChannel', '密钥交换发起失败（保持明文）: $e');
    }
  }

  /// 【0.6.0 S1】处理密钥交换响应（caps + 服务端公钥 + 服务端 salt）
  Future<void> _handleKeyExchangeResponse(Uint8List payload) async {
    try {
      if (payload.length < 52 || _sc == null || _kexClientSalt == null) {
        appLog('TcpChannel', '密钥交换响应异常（len=${payload.length}）');
        return;
      }
      final srvCaps = (payload[0] << 24) | (payload[1] << 16) | (payload[2] << 8) | payload[3];
      final srvPub = Uint8List.sublistView(payload, 4, 36);
      final srvSalt = Uint8List.sublistView(payload, 36, 52);
      final salt = Uint8List(32)
        ..setRange(0, 16, _kexClientSalt!)
        ..setRange(16, 32, srvSalt);
      final ok = await _sc!.handshake(Uint8List.fromList(srvPub), salt);
      if (!ok) {
        appLog('TcpChannel', 'X25519 握手失败（保持明文）');
        return;
      }
      _sc!.setDirection(1, 2); // 客户端发送=1；接收服务端帧=2
      _kexTimer?.cancel();
      if ((srvCaps & 0x01) != 0) {
        _encActive = true;
        appLog('TcpChannel', '✓ 应用层加密已启用（X25519+XChaCha20-Poly1305）');
        _listener?.onData('{"type":"e2e_status","encrypted":true}');
      } else {
        appLog('TcpChannel', '服务端未启用加密——保持明文（诚实上报）');
        _listener?.onData('{"type":"e2e_status","encrypted":false,"reason":"server_caps"}');
      }
    } catch (e) {
      appLog('TcpChannel', '密钥交换响应处理失败（保持明文）: $e');
    }
  }

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    final b = Uint8List(n);
    for (int i = 0; i < n; i++) {
      b[i] = r.nextInt(256);
    }
    return b;
  }

  /// 发送原始文本（WS 风格统一接口）
  @override
  Future<void> send(String data) async {
    await sendFrame(MsgType.command, data);
  }

  /// 心跳（认证后启动——30s 间隔）
  void startHeartbeat(int intervalSeconds) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      if (isConnected && authenticated) {
        sendFrame(MsgType.heartbeat, '{"ping":${DateTime.now().millisecondsSinceEpoch}}');
      }
    });
  }

  void _onRawData(List<int> raw) {
    var bytes = Uint8List.fromList(raw);
    if (_pending != null) {
      final merged = Uint8List(_pending!.lengthInBytes + bytes.length)
        ..setRange(0, _pending!.lengthInBytes, _pending!.buffer.asUint8List())
        ..setRange(_pending!.lengthInBytes, _pending!.lengthInBytes + bytes.length, bytes);
      bytes = merged;
      _pending = null;
    }
    final data = ByteData.sublistView(bytes);
    int offset = 0;
    final frames = <TlvFrame>[];
    while (offset < data.lengthInBytes) {
      final frame = TlvFrame.decode(data, offset);
      if (frame == null) break;
      frames.add(frame);
      offset += TlvFrame.headerLen + frame.payload.length;
    }
    if (offset < data.lengthInBytes) {
      _pending = ByteData.sublistView(bytes, offset, data.lengthInBytes);
    }
    // 【0.6.0 S1】串行处理（异步解密保证顺序）
    for (final f in frames) {
      _procChain = _procChain.then((_) => _processFrame(f));
    }
  }

  /// 【0.6.0 S1】帧处理（加密会话先解密——AEAD 失败即丢弃）
  Future<void> _processFrame(TlvFrame frame) async {
    var payload = frame.payload;
    if (_encActive && _sc != null && frame.type != MsgType.keyExchange && payload.isNotEmpty) {
      final dec = await _sc!.decrypt(payload);
      if (dec == null) {
        appLog('TcpChannel', '加密帧解密失败（篡改/重放）——丢弃 type=0x${frame.type.toRadixString(16)}');
        _listener?.onError('消息认证失败（加密帧被丢弃）');
        return;
      }
      payload = dec;
    }
    _handleFrame(frame.type, payload);
  }

  void _handleFrame(int type, Uint8List payload) {
    switch (type) {
      case MsgType.authResponse:
        _listener?.onData('{"type":"auth_response","data":${_jsonSafe(payload)}}');
      case MsgType.connectionResponse:
        _handleConnectionResponse(_jsonSafe(payload));
      case MsgType.commandResponse:
        _listener?.onData('{"type":"command_response","data":${_jsonSafe(payload)}}');
      case MsgType.heartbeatAck:
        _listener?.onData('{"type":"heartbeat_ack"}');
      case MsgType.error:
        _listener?.onData('{"type":"error","data":${_jsonSafe(payload)}}');
      // 【0.6.0 S1】密钥交换响应
      case MsgType.keyExchange:
        _handleKeyExchangeResponse(payload);
      default:
        _listener?.onData('{"type":"frame_0x${type.toRadixString(16).padLeft(4, '0')}","data":${_jsonSafe(payload)}}');
    }
  }

  /// 载荷 → UTF-8 文本（trim NUL；JSON 嵌入用）
  String _jsonSafe(Uint8List payload) {
    try {
      var s = utf8.decode(payload, allowMalformed: true);
      final i = s.indexOf('\u0000');
      if (i >= 0) s = s.substring(0, i);
      return s;
    } catch (_) {
      return '';
    }
  }

  void _handleConnectionResponse(String payload) {
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic> && map['status'] == 'ok') {
        token = map['token']?.toString() ?? '';
        authenticated = token.isNotEmpty;
        appLog('TcpChannel', '连接响应 OK——token 收到: ${token.substring(0, token.length > 8 ? 8 : token.length)}... expires_in=${map['expires_in']}');
        _listener?.onData('{"type":"connection_ok","token":"$token"}');
        // 【0.6.0 S1】连接建立后发起应用层加密密钥交换
        _startKeyExchange();
      } else {
        appLog('TcpChannel', '连接响应失败: $payload');
        _listener?.onData('{"type":"connection_error","data":"$payload"}');
      }
    } catch (_) {
      appLog('TcpChannel', '连接响应解析失败: $payload');
      _listener?.onData('{"type":"connection_error","data":"$payload"}');
    }
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _kexTimer?.cancel();
    _kexTimer = null;
    if (_socket != null) {
      try {
        _socket!.destroy();
      } catch (_) {}
      _socket = null;
    }
    authenticated = false;
    _encActive = false;
    _sc = null;
    _kexStarted = false;
  }

  @override
  Future<void> disconnect() async {
    _disposed = true;
    _cleanup();
  }
}
