/// LING OS App 信息中心（唯一版本来源）
///
/// 【0.4.4 修复】先生反馈：
///   1. 关于页版本写死（未连接也显示 server 版本号）
///   2. app_logger / drawer / about 各自维护版本字符串，易不同步
/// 修法：全 App 只在此处定义版本；CI 可通过 --dart-define=APP_VERSION=x.y.z+N 注入。
library;

import 'dart:convert';

class AppInfo {
  AppInfo._();

  /// 语义版本（不含构建号）—— CI 注入优先，回退到默认值
  /// 【0.5.2 修复】CI 此前从未注入 → 永远显示旧默认值（先生报告）。
  ///   构建注入：--dart-define=APP_VERSION=$VERSION（build.yml 已加）
  /// 【0.6.0】默认值升级 0.6.0
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.6.2');

  /// 构建号
  static const String build =
      String.fromEnvironment('APP_BUILD', defaultValue: '30');

  /// 显示用完整版本
  static String get full => '$version+$build';

  /// 版本标签（带 v 前缀）
  static String get tag => 'v$full';

  /// 服务端版本 —— **仅在真实连接后由服务端返回填充**
  /// 未连接时为 null（UI 显示「未连接」，不再假装知道）
  static String? serverVersion;
  static String? serverInternalVersion;

  /// 记录服务端上报的版本（由 system_info 响应调用）
  static void setServerVersion(String? v, {String? internal}) {
    serverVersion = (v == null || v.isEmpty) ? null : v;
    serverInternalVersion = (internal == null || internal.isEmpty) ? null : internal;
  }

  /// 清空（断开连接时调用）
  static void clearServerVersion() {
    serverVersion = null;
    serverInternalVersion = null;
  }

  /// 从 WS/TCP 事件行中提取服务端版本（system_info / meta 响应）
  /// 【0.4.4】集中式解析 —— 避免各页各自 grep JSON
  static void updateFromEvent(String line) {
    if (line.isEmpty) return;
    // 快速预筛，避免全量 jsonDecode
    if (!line.contains('system_info') && !line.contains('"version"')) return;
    try {
      final d = jsonDecode(line);
      if (d is! Map) return;
      Map<String, dynamic>? resp;
      final data = d['data'];
      if (data is Map) {
        resp = Map<String, dynamic>.from(data);
      } else if (data is String && data.isNotEmpty) {
        final dec = jsonDecode(data);
        if (dec is Map) resp = Map<String, dynamic>.from(dec);
      }
      if (resp == null) return;
      // 形如 {status:ok, data:{version:"0.4.3", internal_version:"LN-0.4.3"}}
      Map<String, dynamic>? info;
      final inner = resp['data'];
      if (inner is Map) {
        info = Map<String, dynamic>.from(inner);
      } else {
        info = resp;
      }
      final v = info['version']?.toString();
      final iv = info['internal_version']?.toString() ?? info['internal']?.toString();
      if (v != null && v.isNotEmpty) {
        setServerVersion(v, internal: iv);
      }
    } catch (_) {
      // 解析失败静默（事件流里大量非版本消息）
    }
  }

  /// 服务端版本展示文本（未连接 → 明确指出，不臆造）
  static String get serverDisplay {
    final v = serverVersion;
    if (v == null || v.isEmpty) return '未连接（无法获知）';
    final i = serverInternalVersion;
    return (i == null || i.isEmpty) ? v : '$v · $i';
  }

  static const String repo = 'github.com/linp5200/LINGOS-APP';
  static const String dataRoot = '/LINGOS';
}
