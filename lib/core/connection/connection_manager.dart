/// 连接管理器（协议 v3——认证状态机 + 双通道编排 + 会话管理）
library;

import 'dart:async';
import 'dart:convert';

import 'channel.dart';
import 'tcp_channel.dart';
import '../storage/app_store.dart';
import 'ws_channel.dart';

enum ConnState { idle, connecting, waitingAuth, waitingConnCode, authenticated, error, disconnected }

class ConnectionManager implements ChannelListener {
  TcpChannel? tcp;
  WsChannel? ws;

  ConnState state = ConnState.idle;
  String? lastError;
  String token = '';

  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  /// 连接 + 等待验证码（TCP 主通道——认证流程）
  Future<bool> connectTcp(String host, int port) async {
    state = ConnState.connecting;
    tcp = TcpChannel(host: host, port: port);
    tcp!.setListener(this);
    final ok = await tcp!.connect();
    if (ok) {
      state = ConnState.waitingAuth;
    } else {
      state = ConnState.error;
      lastError = tcp!.lastError ?? '未知错误';
      _eventController.add('{"type":"conn_error","message":"$lastError"}');
    }
    return ok;
  }

  /// 发送验证码（两步认证第一步）
  Future<bool> sendAuthCode(String code) async {
    if (tcp == null || !tcp!.isConnected) {
      lastError = '未连接——请先建立 TCP 连接';
      state = ConnState.error;
      return false;
    }
    return tcp!.sendFrame(0x0001, code);
  }

  /// 发送连接码（两步认证第二步——服务端签发 token）
  Future<bool> sendConnectionCode(String code) async {
    if (tcp == null || !tcp!.isConnected) return false;
    return tcp!.sendFrame(0x0003, code);
  }

  /// 建立 WS 对话通道（token 直连——协议 v3）
  Future<bool> connectWs(String host, int port, String wsToken) async {
    token = wsToken;
    ws = WsChannel(url: 'ws://$host:$port', token: wsToken);
    ws!.setListener(this);
    return ws!.connect();
  }

  /// 发送命令（先生决策：走 WS 命令事件 → Python 直通——Web/App 统一）
  Future<bool> sendCommand(Map<String, dynamic> cmd) async {
    // WS 优先（认证后 App 连 WS——token 直连——命令走 WS）
    if (ws != null && ws!.isConnected) {
      await ws!.send(jsonEncode({'type': 'command', 'cmd': cmd['cmd'], 'params': cmd}));
      return true;
    }
    // 兜底：TCP COMMAND 帧（C 端仅支持 ping/system_status 等）
    if (tcp != null && tcp!.isConnected) {
      return tcp!.sendFrame(0x0005, jsonEncode({'command': cmd['cmd'], ...cmd}));
    }
    return false;
  }

  /// 建立 WS 对话通道（token 直连——协议 v3）并保存 token
  /// 【修复】WS 端口 = TCP 端口 + 2（2937→2939——协议约定——曾用错端口导致 WS 未连）
  Future<bool> connectWsAndSave(String host, int port, String wsToken) async {
    token = wsToken;
    final store = AppStore();
    final deviceId = await store.getDeviceId();
    final wsPort = port + 2;
    ws = WsChannel(url: 'ws://$host:$wsPort', token: wsToken, deviceId: deviceId);
    ws!.setListener(this);
    final ok = await ws!.connect();
    if (ok && wsToken.isNotEmpty) {
      await store.saveToken(wsToken);
      await store.saveHost(host, port);
    }
    return ok;
  }

  /// 注销（清除本地 + 通知服务端吊销——先生决策安全）
  Future<void> logout() async {
    try {
      if (ws != null && ws!.isConnected) {
        final store = AppStore();
        final deviceId = await store.getDeviceId();
        await ws!.send(jsonEncode({'type': 'logout', 'device_id': deviceId}));
      }
    } catch (_) {}
    await ws?.disconnect();
    await tcp?.disconnect();
    final store = AppStore();
    await store.logout();
    state = ConnState.disconnected;
  }

  /// 发送对话（WS 通道——chat 事件）
  Future<void> sendChat(String content, {String sessionId = 'default'}) async {
    if (ws != null && ws!.isConnected) {
      await ws!.send(jsonEncode({
        'type': 'chat',
        'content': content,
        'session_id': sessionId,
      }));
    } else if (tcp != null && tcp!.isConnected) {
      await sendCommand({'cmd': 'nook_ask', 'prompt': content, 'session_id': sessionId});
    }
  }

  void startHeartbeat() {
    tcp?.startHeartbeat(30);
  }

  @override
  void onData(String line) {
    _eventController.add(line);
  }

  @override
  void onDisconnected(String reason) {
    lastError = reason;
    state = ConnState.disconnected;
    _eventController.add('{"type":"disconnected","reason":"$reason"}');
  }

  @override
  void onError(String message) {
    lastError = message;
    state = ConnState.error;
    _eventController.add('{"type":"conn_error","message":"$message"}');
  }

  Future<void> disconnect() async {
    await ws?.disconnect();
    await tcp?.disconnect();
    state = ConnState.disconnected;
  }

  void dispose() {
    _eventController.close();
  }
}
