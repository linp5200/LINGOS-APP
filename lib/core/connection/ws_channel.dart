/// WS 通道（协议 v3——Web/App 对话通道——token 直连）
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'channel.dart';

class WsChannel implements ConnectChannel {
  final String url; // ws://host:2939
  final String token;
  final int heartbeatIntervalSeconds;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  ChannelListener? _listener;
  bool _connected = false;

  WsChannel({
    required this.url,
    required this.token,
    this.heartbeatIntervalSeconds = 30,
  });

  @override
  bool get isConnected => _connected;

  @override
  void setListener(ChannelListener listener) => _listener = listener;

  @override
  Future<bool> connect() async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _sub = channel.stream.listen(
        (data) {
          if (data is String) {
            _listener?.onData(data);
          }
        },
        onError: (e) {
          _listener?.onError('WS 错误: $e');
          _connected = false;
        },
        onDone: () {
          _listener?.onDisconnected('WS 连接关闭');
          _connected = false;
        },
        cancelOnError: true,
      );
      // 首帧 token 认证（协议 v3）
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _connected = true;
      _startHeartbeat();
      return true;
    } catch (e) {
      _listener?.onError('WS 连接失败: $e');
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(Duration(seconds: heartbeatIntervalSeconds), (_) {
      if (_connected) {
        _channel?.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch}));
      }
    });
  }

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
