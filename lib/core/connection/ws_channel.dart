/// WS 通道（协议 v3——Web/App 对话通道——token 直连）
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'channel.dart';
import '../logging/app_logger.dart';

class WsChannel implements ConnectChannel {
  final String url; // ws://host:2939
  final String token;
  final int heartbeatIntervalSeconds;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  ChannelListener? _listener;
  bool _connected = false;
  String? lastError;
  Timer? _handshakeTimeout;

  final String deviceId;

  WsChannel({
    required this.url,
    required this.token,
    this.deviceId = '',
    this.heartbeatIntervalSeconds = 30,
  });

  @override
  bool get isConnected => _connected;

  @override
  void setListener(ChannelListener listener) => _listener = listener;

  @override
  Future<bool> connect() async {
    lastError = null;
    try {
      final showTok = token.length > 8 ? '${token.substring(0, 8)}...' : token;
      appLog('WsChannel', '连接 $url（token: $showTok device: $deviceId）');
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _sub = channel.stream.listen(
        (data) {
          confirmHandshake();
          if (data is String) {
            final showData = data.length > 150 ? '${data.substring(0, 150)}...' : data;
            appLog('WsChannel', '收到: $showData');
            // 认证状态检测（auth_ok/auth_error）
            if (data.contains('auth_ok')) authenticated = true;
            if (data.contains('auth_error')) {
              authenticated = false;
              lastError = data;
            }
            _listener?.onData(data);
          }
        },
        onError: (e) {
          lastError = 'WS 连接错误: $e';
          appLog('WsChannel', '错误: $e');
          _listener?.onError(lastError!);
          _connected = false;
        },
        onDone: () {
          if (_connected) {
            _listener?.onDisconnected('WS 连接关闭');
          }
          _connected = false;
        },
        cancelOnError: true,
      );
      // 首帧 token 认证（协议 v3——带 device_id 设备绑定）
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token, 'device_id': deviceId}));
      _connected = true;
      // 【诊断】握手超时检测（5s——失败则报错——不再静默）
      _handshakeTimeout?.cancel();
      _handshakeTimeout = Timer(const Duration(seconds: 5), () {
        if (_connected && _channel != null) {
          lastError = 'WS 握手超时（5s 无确认——服务端未响应/地址错误）';
          appLog('WsChannel', '握手超时——服务端未响应');
          _listener?.onError(lastError!);
          _connected = false;
        }
      });
      _startHeartbeat();
      return true;
    } catch (e) {
      lastError = 'WS 连接异常: $e';
      _listener?.onError(lastError!);
      return false;
    }
  }

  /// 确认握手完成（收到任意服务端帧——取消超时）
  void confirmHandshake() {
    _handshakeTimeout?.cancel();
    _handshakeTimeout = null;
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(Duration(seconds: heartbeatIntervalSeconds), (_) {
      if (_connected) {
        _channel?.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch}));
      }
    });
  }

  /// 认证状态（收到 auth_ok 置 true——App 判断 WS 可用）
  bool authenticated = false;

  @override
  Future<void> send(String data) async {
    try {
      _channel?.sink.add(data);
    } catch (e) {
      _listener?.onError('WS 发送失败: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _connected = false;
    try {
      await _sub?.cancel();
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
  }
}
