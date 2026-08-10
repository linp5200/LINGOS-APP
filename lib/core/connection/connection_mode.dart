/// 连接方式（先生要求：选项形式——非开关——预留自定义导入 API）
library;

import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// 连接方式枚举（选项形式——后续可扩展）
enum ConnectionMode {
  /// 原生 WebSocket（dart:io WebSocket.connect——默认——不走 HttpClient）
  native('native', '原生 WebSocket（推荐）',
      'dart:io 原生实现——独立握手——绕过 HttpClient 层问题'),

  /// HTTP 客户端（web_socket_channel IOClient——旧方式——兼容保留）
  httpClient('http_client', 'HTTP 客户端（兼容）',
      'web_socket_channel + HttpClient——旧连接方式'),

  /// HTTP 客户端直连（同 httpClient——DIRECT 绕过代理）
  httpClientDirect('http_client_direct', 'HTTP 客户端（直连）',
      'HttpClient + DIRECT（绕过系统代理）'),

  /// 自定义（用户导入指定连接方式——预留 API）
  custom('custom', '自定义连接方式（导入）',
      '通过 ConnectionModeRegistry 注册自定义适配器');

  final String id;
  final String label;
  final String description;

  const ConnectionMode(this.id, this.label, this.description);

  static ConnectionMode fromId(String? id) {
    for (final m in ConnectionMode.values) {
      if (m.id == id) return m;
    }
    return ConnectionMode.native; // 默认
  }
}

/// 【预留 API】自定义连接适配器（用户导入指定连接方式）
/// 通过 ConnectionModeRegistry.register 注册——选择"自定义"时调用
class ConnectionAdapter {
  final String id;
  final String label;
  final Future<WebSocketChannel> Function(Uri uri, Map<String, dynamic> options) connect;

  const ConnectionAdapter({required this.id, required this.label, required this.connect});
}

/// 【预留 API】连接方式注册表（自定义导入）
class ConnectionModeRegistry {
  static final Map<String, ConnectionAdapter> _adapters = {};

  /// 注册自定义连接方式（用户导入）
  static void register(ConnectionAdapter adapter) {
    _adapters[adapter.id] = adapter;
  }

  /// 获取自定义适配器
  static ConnectionAdapter? get(String id) => _adapters[id];

  /// 已注册的自定义方式列表
  static List<ConnectionAdapter> get adapters => _adapters.values.toList();
}

/// 按模式创建 WebSocket 通道（native 默认）
Future<WebSocketChannel> connectByMode(
  Uri uri, {
  required ConnectionMode mode,
  bool direct = false,
  Map<String, dynamic>? customOptions,
}) async {
  switch (mode) {
    case ConnectionMode.native:
      // 原生 WebSocket（IOWebSocketChannel 默认底层即 dart:io WebSocket.connect——不走 HttpClient）
      return IOWebSocketChannel.connect(uri);
    case ConnectionMode.httpClient:
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      return IOWebSocketChannel.connect(uri, customClient: client);
    case ConnectionMode.httpClientDirect:
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      client.findProxy = ((u) => 'DIRECT');
      return IOWebSocketChannel.connect(uri, customClient: client);
    case ConnectionMode.custom:
      final adapter = ConnectionModeRegistry.get(customOptions?['adapterId'] as String? ?? '');
      if (adapter == null) {
        throw StateError('自定义连接方式未注册: ${customOptions?['adapterId']}');
      }
      return adapter.connect(uri, customOptions ?? {});
  }
}
