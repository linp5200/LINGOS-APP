// WS 握手测试（模拟 App——web_socket_channel）
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main() async {
  const url = 'ws://127.0.0.1:2939';
  stdout.writeln('连接 $url...');
  try {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    // 等握手结果（成功=收到服务端帧/关闭；失败=抛异常）
    final done = Completer<String>();
    channel.stream.listen(
      (data) {
        stdout.writeln('收到: $data');
        if (!done.isCompleted) done.complete('data');
      },
      onError: (e) {
        stdout.writeln('ERROR: $e');
        if (!done.isCompleted) done.complete('error');
      },
      onDone: () {
        stdout.writeln('连接关闭');
        if (!done.isCompleted) done.complete('closed');
      },
      cancelOnError: true,
    );
    // 发 auth 帧（模拟 App）
    channel.sink.add('{"type":"auth","token":"dummy-test","device_id":"dart-test"}');
    // 等 3 秒（握手 + 响应）
    final r = await done.future.timeout(const Duration(seconds: 5), onTimeout: () => 'timeout');
    stdout.writeln('结果: $r');
    await channel.sink.close();
  } catch (e) {
    stdout.writeln('连接异常: $e');
    stdout.writeln('结果: exception');
  }
  exit(0);
}
