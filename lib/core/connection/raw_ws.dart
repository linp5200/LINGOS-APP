/// 【先生全权】原始 socket WebSocket 客户端（绕开 HttpClient 101 兼容问题）
/// 像 python 原始 socket 一样手动握手 + 帧收发——完全控制
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// 原始 WebSocket 客户端（RFC 6455 客户端实现）
class RawWebSocket {
  Socket? _socket;
  final _messages = StreamController<String>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  bool _closed = false;

  /// 连接 + 握手（raw socket——校验 Sec-WebSocket-Accept）
  static Future<RawWebSocket> connect(String url, {Duration timeout = const Duration(seconds: 5)}) async {
    final uri = Uri.parse(url);
    final ws = RawWebSocket();
    // 1. TCP 连接
    final socket = await Socket.connect(uri.host, uri.port, timeout: timeout);
    ws._socket = socket;
    // 2. 生成 Sec-WebSocket-Key（16 字节随机 → base64）
    final rand = Random.secure();
    final keyBytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final key = base64Encode(keyBytes);
    // 3. 发送握手请求
    final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    socket.write('GET ${uri.path.isEmpty ? '/' : uri.path} HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        '\r\n');
    // 4. 事件驱动读响应头（完整 \r\n\r\n）
    final respCompleter = Completer<Map<String, String>>();
    final acc = <int>[];
    late StreamSubscription<List<int>> hsub;
    hsub = socket.listen((data) {
      acc.addAll(data);
      final s = utf8.decode(acc, allowMalformed: true);
      final idx = s.indexOf('\r\n\r\n');
      if (idx >= 0) {
        hsub.cancel();
        final headStr = s.substring(0, idx);
        final lines = headStr.split('\r\n');
        final statusLine = lines.first;
        final headers = <String, String>{};
        for (final line in lines.skip(1)) {
          final c = line.indexOf(':');
          if (c > 0) {
            headers[line.substring(0, c).trim().toLowerCase()] = line.substring(c + 1).trim();
          }
        }
        if (!statusLine.contains('101')) {
          respCompleter.completeError(StateError('握手失败: $statusLine'));
          return;
        }
        // 校验 accept（RFC 6455）
        final expected = base64Encode(sha1.convert(utf8.encode('$key${'258EAFA5-E914-47DA-95CA-C5AB0DC85B11'}')).bytes);
        final actual = headers['sec-websocket-accept'] ?? '';
        if (expected != actual) {
          respCompleter.completeError(StateError('Sec-WebSocket-Accept 校验失败'));
          return;
        }
        // 剩余数据（可能含首帧）入缓冲
        final rest = acc.sublist(idx + 4);
        if (rest.isNotEmpty) {
          ws._frameBuffer.addAll(rest);
          ws._processFrames();
        }
        respCompleter.complete(headers);
      }
    }, onError: (e) {
      if (!respCompleter.isCompleted) respCompleter.completeError(e);
    }, onDone: () {
      if (!respCompleter.isCompleted) respCompleter.completeError(const SocketException('连接关闭'));
    });
    try {
      await respCompleter.future;
    } catch (e) {
      socket.destroy();
      rethrow;
    }
    // 5. 帧事件循环
    socket.listen((data) {
      ws._frameBuffer.addAll(data);
      ws._processFrames();
    }, onError: (e) {
      ws._errors.add(e);
      ws._closed = true;
    }, onDone: () {
      if (!ws._closed) {
        ws._messages.close();
        ws._errors.add(const SocketException('连接关闭'));
        ws._closed = true;
      }
    });
    return ws;
  }

  /// 帧缓冲
  final List<int> _frameBuffer = [];

  /// 解析并处理服务端帧（无掩码）
  void _processFrames() {
    while (true) {
      if (_frameBuffer.length < 2) return;
      final b0 = _frameBuffer[0];
      final b1 = _frameBuffer[1];
      final opcode = b0 & 0x0F;
      var len = b1 & 0x7F;
      var idx = 2;
      if (len == 126) {
        if (_frameBuffer.length < 4) return;
        len = (_frameBuffer[2] << 8) | _frameBuffer[3];
        idx = 4;
      } else if (len == 127) {
        if (_frameBuffer.length < 10) return;
        len = 0;
        for (var i = 0; i < 8; i++) {
          len = (len << 8) | _frameBuffer[2 + i];
        }
        idx = 10;
      }
      if (_frameBuffer.length < idx + len) return;
      final payload = _frameBuffer.sublist(idx, idx + len);
      _frameBuffer.removeRange(0, idx + len);
      switch (opcode) {
        case 0x1: // 文本
        case 0x2: // 二进制
          _messages.add(utf8.decode(payload, allowMalformed: true));
          break;
        case 0x8: // close
          _closed = true;
          _socket?.destroy();
          _messages.close();
          return;
        case 0x9: // ping → pong
          _sendFrame(0xA, payload);
          break;
        case 0xA: // pong
          break;
      }
    }
  }

  /// 发送文本消息（客户端帧——掩码）
  void send(String text) {
    final payload = utf8.encode(text);
    _sendFrame(0x1, payload);
  }

  void _sendFrame(int opcode, List<int> payload) {
    final rand = Random.secure();
    final mask = List<int>.generate(4, (_) => rand.nextInt(256));
    final out = <int>[];
    out.add(0x80 | opcode); // FIN + opcode
    final len = payload.length;
    if (len < 126) {
      out.add(0x80 | len); // MASK + len
    } else if (len < 65536) {
      out.add(0x80 | 126);
      out.add((len >> 8) & 0xFF);
      out.add(len & 0xFF);
    } else {
      out.add(0x80 | 127);
      for (var i = 7; i >= 0; i--) {
        out.add(((len >> (i * 8)) & 0xFF));
      }
    }
    out.addAll(mask);
    for (var i = 0; i < payload.length; i++) {
      out.add(payload[i] ^ mask[i % 4]);
    }
    _socket?.add(out);
  }

  /// 消息流
  Stream<String> get stream => _messages.stream;

  /// 错误流
  Stream<Object> get errors => _errors.stream;

  Future<void> close() async {
    _closed = true;
    try {
      _sendFrame(0x8, const []);
    } catch (_) {}
    _socket?.destroy();
    if (!_messages.isClosed) await _messages.close();
    await _errors.close();
  }
}
