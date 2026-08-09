/// 本地存储（shared_preferences——token/主机/设置持久化——协议 v3）
/// 说明：小数据用 SP（无需 codegen）；会话历史/缓存后续用 Isar
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppStore {
  static const _kToken = 'token';
  static const _kHost = 'host';
  static const _kPort = 'port';
  static const _kSessionId = 'session_id';

  Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
  }

  Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

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

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }
}
