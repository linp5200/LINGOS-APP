// 真正的原生测试：dart:io WebSocket.connect（不走 HttpClient）
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  const url = 'ws://127.0.0.1:3940';
  stdout.writeln('测试 dart:io WebSocket.connect: $url');
  try {
    final ws = await WebSocket.connect(url);
    stdout.writeln('✅ 原生握手成功（dart:io WebSocket——不走 HttpClient）');
    ws.add('{"type":"auth","token":"dart-native2","device_id":"dart2"}');
    final done = Completer<String>();
    ws.listen((d) {
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
    await ws.close();
  } catch (e) {
    stdout.writeln('❌ 失败: $e');
  }
  exit(0);
}
