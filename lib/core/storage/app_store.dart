/// 本地存储（安全分层——先生决策：token 加密 + 设备绑定）
/// token → flutter_secure_storage（Android Keystore 加密）
/// host/port/sessionId → shared_preferences（非敏感）
/// deviceId → 持久 UUID（设备绑定——服务端 token↔device）
library;

import 'dart:math';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStore {
  static const _secToken = 'lingos_token';
  static const _kHost = 'host';
  static const _kPort = 'port';
  static const _kSessionId = 'session_id';
  static const _kDeviceId = 'device_id';
  static const _kAllowPlaintext = 'allow_plaintext';
  static const _kConnectionMode = 'connection_mode';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------- token（加密存储） ----------
  Future<void> saveToken(String token) async {
    await _secure.write(key: _secToken, value: token);
  }

  Future<String?> getToken() async {
    try {
      return await _secure.read(key: _secToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    await _secure.delete(key: _secToken);
  }

  // ---------- 主机/端口（非敏感——SP） ----------
  Future<void> saveHost(String host, int port) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kHost, host);
    await sp.setInt(_kPort, port);
  }

  Future<String?> getHost() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kHost);
  }

  Future<int?> getPort() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kPort);
  }

  Future<void> saveSessionId(String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSessionId, id);
  }

  Future<String?> getSessionId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kSessionId);
  }

  // ---------- 明文传输开关（先生决策：默认加密——明文关） ----------
  Future<void> saveAllowPlaintext(bool allow) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAllowPlaintext, allow);
  }

  Future<bool> getAllowPlaintext() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAllowPlaintext) ?? false; // 默认 false = 加密（不允许明文）
  }

  // ---------- 连接方式（先生要求：选项形式——默认原生 WebSocket） ----------
  Future<void> saveConnectionMode(String modeId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kConnectionMode, modeId);
  }

  Future<String> getConnectionModeId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kConnectionMode) ?? 'native'; // 默认原生
  }

  // ---------- 【0.1.9】AI 提供商配置（本地加密存储） ----------
  static const _kProviders = 'ai_providers_json';
  static const _kProviderKeys = 'ai_provider_keys_json'; // 密钥单独存（展示不泄露）
  static const _kVoiceProxy = 'voice_proxy_enabled'; // 【0.2.0】音频提供商使用服务端代理开关
  static const _kAutoRead = 'voice_auto_read'; // 【0.2.0】自动朗读开关（默认关）
  static const _kContinuousChat = 'voice_continuous_chat'; // 【0.2.0】连续对话开关

  /// 【0.2.0】音频提供商使用服务端代理（先生决策：本地直连/服务端代理可选）
  Future<void> saveVoiceProxy(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kVoiceProxy, enabled);
  }

  Future<bool> getVoiceProxy() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kVoiceProxy) ?? true; // 默认服务端代理（密钥在主机——隐私第一）
  }

  /// 【0.2.0】自动朗读（默认关——先生决策）
  Future<void> saveAutoRead(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoRead, enabled);
  }

  Future<bool> getAutoRead() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAutoRead) ?? false;
  }

  /// 【0.2.0】连续对话（家居等情景默认开——先生决策）
  Future<void> saveContinuousChat(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kContinuousChat, enabled);
  }

  Future<bool> getContinuousChat() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kContinuousChat) ?? false;
  }

  Future<void> saveProviders(List<Map<String, dynamic>> providers) async {
    final sp = await SharedPreferences.getInstance();
    final public = providers.map((p) {
      final m = Map<String, dynamic>.from(p);
      m.remove('apiKey'); // 密钥不落公开 JSON
      return m;
    }).toList();
    await sp.setString(_kProviders, jsonEncode(public));
    final keys = <String, String>{};
    for (final p in providers) {
      if (p['apiKey'] != null && p['id'] != null) {
        keys[p['id'].toString()] = p['apiKey'].toString();
      }
    }
    await sp.setString(_kProviderKeys, jsonEncode(keys));
  }

  Future<List<Map<String, dynamic>>> getProviders() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProviders);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getProviderKey(String id) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProviderKeys);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      return map is Map ? map[id]?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  // ---------- 【0.1.9】外观与偏好 ----------
  static const _kThemeMode = 'ui_theme_mode'; // system/light/dark
  static const _kAccentDynamic = 'ui_accent_dynamic'; // bool
  static const _kLanguage = 'ui_language'; // system/zh/en
  static const _kMsgPrefs = 'ui_msg_prefs_json';
  static const _kAnalytics = 'privacy_analytics';

  Future<void> saveThemeMode(String mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kThemeMode, mode);
  }

  Future<String> getThemeMode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kThemeMode) ?? 'system';
  }

  Future<void> saveAccentDynamic(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAccentDynamic, v);
  }

  Future<bool> getAccentDynamic() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAccentDynamic) ?? true; // 默认动态取色
  }

  Future<void> saveLanguage(String lang) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLanguage, lang);
  }

  Future<String> getLanguage() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLanguage) ?? 'system';
  }

  Future<void> saveMsgPrefs(Map<String, bool> prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMsgPrefs, jsonEncode(prefs));
  }

  Future<Map<String, bool>> getMsgPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMsgPrefs);
    // 【0.2.1 #5】流式思考展开思考链 + 工具块展开（默认：思考收缩、工具收缩——防长内容占屏）
    const defaults = {
      'thinking': true, 'tool': true, 'streaming': true, 'codeHighlight': true,
      'thinkExpand': false, 'toolExpand': false,
    };
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return defaults;
      return {
        for (final k in defaults.keys) k: map[k] as bool? ?? defaults[k]!,
      };
    } catch (_) {
      return defaults;
    }
  }

  // ---------- 【0.2.1 #7】开局显示设置（上一次的会话 / 会话列表 / 仪表盘） ----------
  static const _kStartScreen = 'ui_start_screen';

  Future<void> saveStartScreen(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStartScreen, v);
  }

  Future<String> getStartScreen() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kStartScreen) ?? 'sessions'; // 默认会话列表（9.2 裁决）
  }

  // ---------- 【0.2.2 同步】last_sync 时间戳（增量同步基线） ----------
  static const _kLastSync = 'sync_last_sync_ts';

  Future<void> saveLastSync(double ts) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kLastSync, ts);
  }

  Future<double> getLastSync() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_kLastSync) ?? 0;
  }

  Future<void> saveAnalytics(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAnalytics, v);
  }

  Future<bool> getAnalytics() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAnalytics) ?? false; // 默认关（隐私第一）
  }

  // ---------- 【0.1.9】记忆自动写入开关 ----------
  static const _kAutoMemoryWrite = 'ai_auto_memory_write';

  Future<void> saveAutoMemoryWrite(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoMemoryWrite, v);
  }

  Future<bool> getAutoMemoryWrite() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAutoMemoryWrite) ?? false;
  }

  // ---------- 【0.1.9】通用偏好（通知/后台等） ----------
  Future<bool> getPrefBool(String key, bool def) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('pref_$key') ?? def;
  }

  Future<void> savePrefBool(String key, bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('pref_$key', v);
  }

  Future<String> getPrefString(String key, String def) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('pref_$key') ?? def;
  }

  Future<void> savePrefString(String key, String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('pref_$key', v);
  }

  // ---------- 【0.1.9】挂载配置（持久化） ----------
  static const _kMounts = 'sandbox_mounts_json';

  Future<void> saveMounts(List<Map<String, dynamic>> mounts) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMounts, jsonEncode(mounts));
  }

  Future<List<Map<String, dynamic>>> getMounts() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- 【0.1.9】Rootfs 沙箱配置 ----------
  static const _kRootfs = 'sandbox_rootfs_json';

  Future<void> saveRootfs(Map<String, dynamic>? rootfs) async {
    final sp = await SharedPreferences.getInstance();
    if (rootfs == null) {
      await sp.remove(_kRootfs);
    } else {
      await sp.setString(_kRootfs, jsonEncode(rootfs));
    }
  }

  Future<Map<String, dynamic>?> getRootfs() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRootfs);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : null;
    } catch (_) {
      return null;
    }
  }

  // ---------- 【0.1.9】日志开关 ----------
  static const _kLogging = 'logging_enabled';
  static const _kLogSave = 'log_save_to_file'; // 【2026-08-22】保存到文件开关

  Future<void> saveLoggingEnabled(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLogging, v);
  }

  Future<bool> getLoggingEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLogging) ?? true; // 默认开启
  }

  Future<void> saveLogSaveToFile(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLogSave, v);
  }

  Future<bool> getLogSaveToFile() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLogSave) ?? false; // 定稿：默认不保存文件
  }

  // ---------- 设备绑定（UUID 持久） ----------
  Future<String> getDeviceId() async {
    final sp = await SharedPreferences.getInstance();
    var id = sp.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = _generateUuid();
      await sp.setString(_kDeviceId, id);
    }
    return id;
  }

  String _generateUuid() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ---------- 注销（完整清除） ----------
  Future<void> logout() async {
    await _secure.deleteAll();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kHost);
    await sp.remove(_kPort);
    await sp.remove(_kSessionId);
  }

  Future<void> clear() async {
    await logout();
  }
}
