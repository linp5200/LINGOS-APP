/// App 日志系统（2026-08-22 定稿——与服务端格式统一）
/// - 格式：time/id/level/txt（与服务端 /log JSON 四字段一致）
/// - 默认不保存文件：仅用户导出时落盘
/// - 直接显示：最近 100 行
/// - 开启保存到文件：保留全部
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  static final AppLogger instance = AppLogger._();
  AppLogger._();

  final List<Map<String, dynamic>> _logs = [];
  int _seq = 0;
  File? _logFile;
  bool enabled = true; // 日志记录开关
  bool _saveToFile = false; // 【定稿】默认不保存文件，导出才落盘
  int maxLines = 500; // 内存缓冲上限（显示取最近 100）

  /// 当前 App 版本（发版同步）
  static const appVersion = '0.4.3';

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/lingos_app.log');
    } catch (_) {}
    // 【先生要求】日志提供当前版本 + 环境
    log('App', 'App 版本: $appVersion | 平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  }

  /// 开启/关闭保存到文件（定稿：默认关=仅导出落盘；开=追加保留全部）
  void setSaveToFile(bool on) {
    _saveToFile = on;
  }

  void log(String tag, String message, {String level = 'INFO'}) {
    if (!enabled) return;
    _seq++;
    final now = DateTime.now();
    // time：ISO8601 毫秒（与服务端一致）
    String two(int v) => v.toString().padLeft(2, '0');
    final iso = '${now.year}-${two(now.month)}-${two(now.day)}T'
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.'
        '${now.millisecond.toString().padLeft(3, '0')}'
        '${now.timeZoneOffset.inHours >= 0 ? '+' : '-'}${two(now.timeZoneOffset.inHours.abs())}00';
    final entry = {
      'time': iso,
      'id': _seq,
      'level': level,
      'txt': '[$level][$tag] $message',
    };
    _logs.add(entry);
    if (_logs.length > maxLines) _logs.removeAt(0);
    // 定稿：默认不写文件；仅保存开关开启时追加
    if (_saveToFile) {
      try {
        _logFile?.writeAsStringSync('${_jsonLine(entry)}\n',
            mode: FileMode.append, flush: true);
      } catch (_) {}
    }
    // 控制台
    // ignore: avoid_print
    print('[${iso.substring(11, 23)}][$level][$tag] $message');
  }

  String _jsonLine(Map<String, dynamic> e) {
    final txt = (e['txt'] as String)
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
    return '{"time":"${e['time']}","id":${e['id']},"level":"${e['level']}","txt":"$txt"}';
  }

  /// 最近 100 行（定稿：直接显示=最近 100 行）
  List<Map<String, dynamic>> get recentLogs {
    final n = _logs.length;
    return n <= 100 ? List.unmodifiable(_logs) : List.unmodifiable(_logs.sublist(n - 100));
  }

  List<Map<String, dynamic>> get logs => List.unmodifiable(_logs);

  String get logText => _logs.map(_jsonLine).join('\n');

  /// 导出日志（定稿：导出时落盘 + 返回文本）
  String exportText() {
    final header = '=== LING OS App 日志 ===\n版本: $appVersion\n时间: ${DateTime.now()}\n';
    final body = logText;
    try {
      _logFile?.writeAsStringSync('$header\n$body\n', flush: true);
    } catch (_) {}
    return '$header\n$body';
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
    _seq = 0;
    try {
      _logFile?.writeAsStringSync('');
    } catch (_) {}
  }
}

/// 便捷函数
void appLog(String tag, String message) => AppLogger.instance.log(tag, message);
