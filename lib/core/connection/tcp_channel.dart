/// TCP 通道（协议 v3——两步认证 + 心跳）
/// Android/桌面使用（dart:io Socket——浏览器不可用）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/tlv.dart';
import 'channel.dart';

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

  TcpChannel({
    required this.host,
    required this.port,
    this.connectTimeoutMs = 8000,
  });

  @override
  bool get isConnected => _socket != null && !_disposed;

  @override
  void setListener(ChannelListener listener) => _listener = listener;

  @override
  Future<bool> connect() async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: Duration(milliseconds: connectTimeoutMs));
      _socket = socket;
      _disposed = false;

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

  /// 发送 TLV 帧
  Future<bool> sendFrame(int type, String payload) async {
    if (!isConnected) return false;
    try {
      final frame = TlvFrame(type, Uint8List.fromList(utf8.encode(payload)));
      _socket!.add(frame.encode());
      await _socket!.flush();
      return true;
    } catch (e) {
      _listener?.onError('发送失败: $e');
      return false;
    }
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
    while (offset < data.lengthInBytes) {
      final frame = TlvFrame.decode(data, offset);
      if (frame == null) break;
      _handleFrame(frame);
      offset += TlvFrame.headerLen + frame.payload.length;
    }
    if (offset < data.lengthInBytes) {
      _pending = ByteData.sublistView(bytes, offset, data.lengthInBytes);
    }
  }

  void _handleFrame(TlvFrame frame) {
    switch (frame.type) {
      case MsgType.authResponse:
        _listener?.onData('{"type":"auth_response","data":${frame.payloadString()}}');
      case MsgType.connectionResponse:
        _handleConnectionResponse(frame.payloadString());
      case MsgType.commandResponse:
        _listener?.onData('{"type":"command_response","data":${frame.payloadString()}}');
      case MsgType.heartbeatAck:
        _listener?.onData('{"type":"heartbeat_ack"}');
      case MsgType.error:
        _listener?.onData('{"type":"error","data":${frame.payloadString()}}');
      default:
        _listener?.onData('{"type":"frame_0x${frame.type.toRadixString(16).padLeft(4, '0')}","data":${frame.payloadString()}}');
    }
  }

  void _handleConnectionResponse(String payload) {
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic> && map['status'] == 'ok') {
        token = map['token']?.toString() ?? '';
        authenticated = token.isNotEmpty;
        _listener?.onData('{"type":"connection_ok","token":"$token"}');
      } else {
        _listener?.onData('{"type":"connection_error","data":"$payload"}');
      }
    } catch (_) {
      _listener?.onData('{"type":"connection_error","data":"$payload"}');
    }
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_socket != null) {
      try {
        _socket!.destroy();
      } catch (_) {}
      _socket = null;
    }
    authenticated = false;
  }

  @override
  Future<void> disconnect() async {
    _disposed = true;
    _cleanup();
  }
}
