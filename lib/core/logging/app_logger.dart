/// App 日志系统（全链路——文件存储 + 导出）
/// 先生要求：不只显示错误——显示内容——设置可导出日志
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  static final AppLogger instance = AppLogger._();
  AppLogger._();

  final List<String> _logs = [];
  final int maxLines = 500;
  File? _logFile;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/lingos_app.log');
    } catch (_) {}
  }

  void log(String tag, String message) {
    final ts = DateTime.now().toString().substring(0, 19);
    final line = '[$ts][$tag] $message';
    _logs.add(line);
    if (_logs.length > maxLines) _logs.removeAt(0);
    // 写入文件（异步）
    try {
      _logFile?.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    // 控制台
    // ignore: avoid_print
    print(line);
  }

  List<String> get logs => List.unmodifiable(_logs);

  String get logText => _logs.join('\n');

  /// 导出日志（复制到剪贴板/分享——由 UI 调用）
  String exportText() {
    final header = '=== LING OS App 日志 ===\n版本: 2.0.1.0_rc\n时间: ${DateTime.now()}\n\n';
    return header + logText;
  }

  Future<String?> logFilePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/lingos_app.log');
      return f.existsSync() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _logs.clear();
    try {
      _logFile?.writeAsStringSync('');
    } catch (_) {}
  }
}

/// 便捷函数
void appLog(String tag, String message) => AppLogger.instance.log(tag, message);
