/// 连接通道抽象（协议 v3——双通道）
///
/// TCPChannel：Android/桌面——完整两步认证（验证码→连接码→token）
/// WSChannel：Web（浏览器无原生 TCP——token 直连）
/// 上层（认证状态机/心跳/事件解析）共用
library;

import 'dart:async';

/// 通道事件
enum ChannelEvent { connected, disconnected, data, error }

/// 通道监听
abstract class ChannelListener {
  void onData(String line);
  void onDisconnected(String reason);
  void onError(String message);
}

/// 通道接口
abstract class ConnectChannel {
  Future<bool> connect();
  Future<void> send(String data);
  Future<void> disconnect();
  bool get isConnected;
  void setListener(ChannelListener listener);
}
