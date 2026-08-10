// native 连接方式测试（connectByMode——连 3940 分片服务）
import 'dart:async';
import 'dart:io';
import '../lib/core/connection/connection_mode.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main() async {
  const url = 'ws://127.0.0.1:3940';
  stdout.writeln('测试 native 连接: $url');
  try {
    final channel = await connectByMode(Uri.parse(url), mode: ConnectionMode.native);
    stdout.writeln('✅ native 握手成功（IOWebSocketChannel——dart:io WebSocket）');
    // 发 auth 测试帧
    channel.sink.add('{"type":"auth","token":"dart-native-test","device_id":"dart-native"}');
    final done = Completer<String>();
    channel.stream.listen((d) {
      stdout.writeln('收到: $d');
      if (!done.isCompleted) done.complete('data');
    }, onError: (e) {
      stdout.writeln('流错误: $e');
      if (!done.isCompleted) done.complete('err');
    }, onDone: () {
      if (!done.isCompleted) done.complete('done');
    });
    final r = await done.future.timeout(const Duration(seconds: 4), onTimeout: () => 'timeout');
    stdout.writeln('结果: $r');
    await channel.sink.close();
  } catch (e) {
    stdout.writeln('❌ native 失败: $e');
  }
  exit(0);
}
