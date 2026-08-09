/// 本地存储（安全分层——先生决策：token 加密 + 设备绑定）
/// token → flutter_secure_storage（Android Keystore 加密）
/// host/port/sessionId → shared_preferences（非敏感）
/// deviceId → 持久 UUID（设备绑定——服务端 token↔device）
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStore {
  static const _secToken = 'lingos_token';
  static const _kHost = 'host';
  static const _kPort = 'port';
  static const _kSessionId = 'session_id';
  static const _kDeviceId = 'device_id';
  static const _kAllowPlaintext = 'allow_plaintext';

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
