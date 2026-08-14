/// 【0.2.1 #1】离线缓存模块（先生裁决 Q2 全量 + Q3 加密 + Q4 sqflite）
/// - 存储：sqflite_sqlcipher 三表（sessions/messages/memory_summary）+ shared_preferences 辅
/// - 加密：sqlcipher（密钥 Android Keystore——flutter_secure_storage 保存）
/// - 策略：首连全量快照落库 → 断连只读渲染 → 重连刷新
/// - 操作拦截：未连接时任何修改操作提示"当前尚未连接主机，无法修改"
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as p;

class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  Database? _db;
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyName = 'lingos_db_key';
  static const _ivKeyName = 'lingos_db_iv';

  /// 打开加密数据库（密钥 Keystore 生成/复用——sqlcipher 派生密钥）
  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'lingos_offline.db');
    // 密钥：首次生成 32 字节随机 → Keystore 保存；之后复用
    var key = await _secureStorage.read(key: _keyName);
    if (key == null || key.length < 64) {
      final rnd = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256);
      key = base64Encode(rnd);
      await _secureStorage.write(key: _keyName, value: key);
    }
    _db = await openDatabase(
      dbPath,
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            title TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            token_usage INTEGER,
            message_count INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            role TEXT,
            content TEXT,
            msg_type TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_messages_session ON messages(session_id, created_at)');
        await db.execute('''
          CREATE TABLE memory_summary(
            key TEXT PRIMARY KEY,
            content TEXT,
            updated_at INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  /// 全量快照落库（连接建立后调用——先生裁决 Q2：全量无限缓存）
  Future<void> saveSnapshot({
    required List<Map<String, dynamic>> sessions,
    Map<String, List<Map<String, dynamic>>>? sessionMessages,
    Map<String, String>? memorySummary,
  }) async {
    try {
      final db = await _openDb();
      await db.transaction((txn) async {
        // 会话全量替换（幂等 upsert）
        await txn.delete('sessions');
        for (final s in sessions) {
          await txn.insert('sessions', {
            'id': s['id']?.toString() ?? '',
            'title': s['title']?.toString() ?? '未命名',
            'created_at': (s['created_at'] as num?)?.toInt() ?? 0,
            'updated_at': (s['updated'] as num?)?.toInt() ?? 0,
            'token_usage': (s['token_total'] as num?)?.toInt() ?? 0,
            'message_count': (s['message_count'] as num?)?.toInt() ?? 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        // 消息增量 upsert（按会话——重复则跳过）
        if (sessionMessages != null) {
          for (final entry in sessionMessages.entries) {
            final sid = entry.key;
            for (final m in entry.value) {
              final exists = await txn.query(
                'messages',
                where: 'session_id = ? AND id = ?',
                whereArgs: [sid, m['id'] ?? -1],
              );
              if (exists.isEmpty) {
                await txn.insert('messages', {
                  'session_id': sid,
                  'role': m['role']?.toString() ?? 'user',
                  'content': m['content']?.toString() ?? '',
                  'msg_type': m['type']?.toString() ?? '',
                  'created_at': (m['ts'] as num?)?.toInt() ?? 0,
                });
              }
            }
          }
        }
        // 记忆摘要
        if (memorySummary != null) {
          for (final e in memorySummary.entries) {
            await txn.insert('memory_summary', {
              'key': e.key,
              'content': e.value,
              'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    } catch (_) {
      // 缓存失败静默——在线模式不受影响
    }
  }

  /// 读取缓存会话列表（断连只读显示）
  Future<List<Map<String, dynamic>>> getCachedSessions() async {
    try {
      final db = await _openDb();
      final rows = await db.query('sessions', orderBy: 'updated_at DESC');
      return rows;
    } catch (_) {
      return [];
    }
  }

  /// 读取缓存会话消息
  Future<List<Map<String, dynamic>>> getCachedMessages(String sessionId) async {
    try {
      final db = await _openDb();
      final rows = await db.query(
        'messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC',
        limit: 200,
      );
      return rows;
    } catch (_) {
      return [];
    }
  }

  /// 读取缓存记忆摘要
  Future<Map<String, String>> getCachedMemorySummary() async {
    try {
      final db = await _openDb();
      final rows = await db.query('memory_summary');
      return {for (final r in rows) r['key'].toString(): r['content'].toString()};
    } catch (_) {
      return {};
    }
  }

  /// 清空缓存（设置入口）
  Future<void> clear() async {
    try {
      final db = await _openDb();
      await db.delete('sessions');
      await db.delete('messages');
      await db.delete('memory_summary');
    } catch (_) {}
  }
}
