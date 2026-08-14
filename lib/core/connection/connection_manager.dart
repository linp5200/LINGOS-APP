/// 连接管理器（协议 v3——认证状态机 + 双通道编排 + 会话管理）
library;

import 'dart:async';
import 'dart:convert';

import 'channel.dart';
import 'tcp_channel.dart';
import '../storage/app_store.dart';
import '../storage/offline_cache.dart';
import 'ws_channel.dart';
import 'connection_mode.dart';
import '../logging/app_logger.dart';
import '../services/notification_service.dart';

enum ConnState { idle, connecting, waitingAuth, waitingConnCode, authenticated, error, disconnected }

class ConnectionManager implements ChannelListener {
  TcpChannel? tcp;
  WsChannel? ws;

  ConnState state = ConnState.idle;
  String? lastError;
  String token = '';

  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  /// 连接 + 等待验证码（TCP 主通道——认证流程）
  String? _tcpHost;
  int? _tcpPort;

  Future<bool> connectTcp(String host, int port) async {
    _tcpHost = host;
    _tcpPort = port;
    state = ConnState.connecting;
    tcp = TcpChannel(host: host, port: port);
    tcp!.setListener(this);
    final ok = await tcp!.connect();
    if (ok) {
      state = ConnState.waitingAuth;
    } else {
      state = ConnState.error;
      lastError = tcp!.lastError ?? '未知错误';
      _eventController.add('{"type":"conn_error","message":"$lastError"}');
    }
    return ok;
  }

  /// 发送验证码（两步认证第一步）
  Future<bool> sendAuthCode(String code) async {
    if (tcp == null || !tcp!.isConnected) {
      lastError = '未连接——请先建立 TCP 连接';
      state = ConnState.error;
      return false;
    }
    return tcp!.sendFrame(0x0001, code);
  }

  /// 发送连接码（两步认证第二步——服务端签发 token）
  Future<bool> sendConnectionCode(String code) async {
    if (tcp == null || !tcp!.isConnected) return false;
    return tcp!.sendFrame(0x0003, code);
  }

  /// 建立 WS 对话通道（token 直连——协议 v3）
  Future<bool> connectWs(String host, int port, String wsToken) async {
    token = wsToken;
    ws = WsChannel(url: 'ws://$host:$port', token: wsToken);
    ws!.setListener(this);
    return ws!.connect();
  }

  /// 发送命令（先生决策：走 WS 命令事件 → Python 直通——Web/App 统一）
  /// 【0.2.2 同步协议】连接成功自动同步（sync_full 首次 / sync_delta 增量——先生裁决 B：自动+手动）
  void _autoSync() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      appLog('ConnectionManager', '自动同步核心数据（同步协议——sync_full/sync_delta）');
      await _syncAll();
    });
  }

  /// 【0.2.2】同步入口：首次（last_sync=0）全量 sync_full；之后 sync_delta 增量
  Future<void> _syncAll() async {
    try {
      final store = AppStore();
      final lastSync = await store.getLastSync();
      final deviceId = await store.getDeviceId();
      if (lastSync <= 0) {
        // 首次连接：完整同步包（全量快照）
        final resp = await requestJson({
          'cmd': 'sync_full',
          'device_id': deviceId,
        }, timeout: const Duration(seconds: 30));
        if (resp == null) return;
        final data = resp['data'];
        if (data is Map && data['sessions'] is List) {
          final sessions = (data['sessions'] as List).whereType<Map<String, dynamic>>().toList();
          await OfflineCache.instance.saveSnapshot(sessions: sessions);
          await store.saveLastSync(DateTime.now().millisecondsSinceEpoch / 1000);
          appLog('ConnectionManager', '首次全量同步完成（${sessions.length} 会话）');
        }
      } else {
        // 非首次：增量（A 时间戳消息 + B 哈希列表）
        final resp = await requestJson({
          'cmd': 'sync_delta',
          'last_sync': lastSync,
          'device_id': deviceId,
        }, timeout: const Duration(seconds: 30));
        if (resp == null) return;
        final data = resp['data'];
        if (data is Map) {
          if (data['sessions'] is List) {
            final sessions = (data['sessions'] as List).whereType<Map<String, dynamic>>().toList();
            // 合并增量消息
            final dm = data['delta_messages'];
            final msgsBySession = <String, List<Map<String, dynamic>>>{};
            if (dm is Map) {
              for (final e in dm.entries) {
                final sid = e.key.toString();
                final list = e.value;
                if (list is List) {
                  msgsBySession[sid] = list.whereType<Map<String, dynamic>>().toList();
                }
              }
            }
            await OfflineCache.instance.saveSnapshot(
              sessions: sessions,
              sessionMessages: msgsBySession,
            );
            await store.saveLastSync(DateTime.now().millisecondsSinceEpoch / 1000);
            appLog('ConnectionManager', '增量同步完成（${sessions.length} 会话, ${msgsBySession.length} 个增量）');
          }
        }
      }
    } catch (e) {
      appLog('ConnectionManager', '同步失败: $e');
    }
  }

  /// 【0.2.2】手动刷新（先生裁决 B：连接成功自动 + 手动刷新按钮）
  Future<void> refreshSync() => _syncAll();

  Future<bool> sendCommand(Map<String, dynamic> cmd) async {
    // WS 优先（认证后 App 连 WS——token 直连——命令走 WS）
    if (ws != null && ws!.isConnected) {
      await ws!.send(jsonEncode({'type': 'command', 'cmd': cmd['cmd'], 'params': cmd}));
      return true;
    }
    // 兜底：TCP COMMAND 帧（C 端仅支持 ping/system_status 等）
    if (tcp != null && tcp!.isConnected) {
      return tcp!.sendFrame(0x0005, jsonEncode({'command': cmd['cmd'], ...cmd}));
    }
    return false;
  }

  /// 【0.2.1 9.4 修复】请求-响应配对：按 cmd 匹配响应（不再"先到先得"）
  /// 服务端命令响应已带 cmd 字段（_reply 统一出口）——requestJson 只认对应 cmd 的响应，
  /// 与自动同步（system_info/session_list 广播）不再冲突
  Future<Map<String, dynamic>?> requestJson(
      Map<String, dynamic> cmd, {Duration timeout = const Duration(seconds: 8)}) async {
    final cmdName = cmd['cmd']?.toString() ?? '';
    final comp = Completer<Map<String, dynamic>>();
    late StreamSubscription sub;
    sub = _eventController.stream.listen((line) {
      try {
        final m = jsonDecode(line);
        if (m is Map && !comp.isCompleted) {
          if (m['type'] == 'command_response') {
            final data = m['data'];
            // 服务端已注入 cmd 标识：优先按 data.cmd 匹配
            if (data is Map && data['cmd'] == cmdName) {
              comp.complete(m.cast<String, dynamic>());
            }
          }
        }
      } catch (_) {}
    });
    await sendCommand(cmd);
    try {
      return await comp.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      await sub.cancel();
    }
  }

  /// 建立 WS 对话通道（token 直连——协议 v3）并保存 token
  /// 【修复】WS 端口 = TCP 端口 + 2（2937→2939——协议约定——曾用错端口导致 WS 未连）
  Future<bool> connectWsAndSave(String host, int port, String wsToken) async {
    token = wsToken;
    final showTok = wsToken.isEmpty ? '【空！】' : '${wsToken.substring(0, wsToken.length > 8 ? 8 : wsToken.length)}...';
    final store = AppStore();
    final deviceId = await store.getDeviceId();
    final wsPort = port + 2;
    // 【先生决策】明文开关：默认加密（wss）——用户开明文才用 ws://
    final allowPlain = await store.getAllowPlaintext();
    final modeId = await store.getConnectionModeId();
    final mode = ConnectionMode.fromId(modeId);
    final scheme = allowPlain ? 'ws' : 'wss';
    appLog('ConnectionManager', 'connectWsAndSave: host=$host wsPort=$wsPort 协议=${allowPlain ? "明文(ws)" : "加密(wss)"} 连接方式=${mode.label} token=$showTok');
    ws = WsChannel(url: '$scheme://$host:$wsPort', token: wsToken, deviceId: deviceId, connectionMode: mode);
    ws!.setListener(this);
    final ok = await ws!.connect();
    appLog('ConnectionManager', 'WS 连接结果: ${ok ? "成功" : "失败(${ws!.lastError})"}');
    if (ok && wsToken.isNotEmpty) {
      await store.saveToken(wsToken);
      await store.saveHost(host, port);
    } else if (!ok) {
      lastError = ws!.lastError ?? 'WS 连接失败';
    }
    return ok;
  }

  /// 注销（清除本地 + 通知服务端吊销——先生决策安全）
  Future<void> logout() async {
    try {
      if (ws != null && ws!.isConnected) {
        final store = AppStore();
        final deviceId = await store.getDeviceId();
        await ws!.send(jsonEncode({'type': 'logout', 'device_id': deviceId}));
      }
    } catch (_) {}
    await ws?.disconnect();
    await tcp?.disconnect();
    final store = AppStore();
    await store.logout();
    state = ConnState.disconnected;
  }

  /// 发送对话（WS 通道——chat 事件）
  /// 【0.1.9】字段适配：content → prompt（服务端 websocket_server.c 以 prompt 解析）
  Future<void> sendChat(String content, {String sessionId = 'default'}) async {
    // 【0.2.2】带上 device_id——服务端归属校验（_session_append_msg 强制）
    final store = AppStore();
    final deviceId = await store.getDeviceId();
    if (ws != null && ws!.isConnected) {
      await ws!.send(jsonEncode({
        'type': 'chat',
        'prompt': content,
        'session_id': sessionId,
        'device_id': deviceId,
      }));
    } else if (tcp != null && tcp!.isConnected) {
      await sendCommand({'cmd': 'nook_ask', 'prompt': content, 'session_id': sessionId, 'device_id': deviceId});
    }
  }

  /// 【0.1.9】发送中断帧（终止当前 AI 回复）
  Future<bool> sendInterrupt() async {
    if (ws != null && ws!.isConnected) {
      await ws!.send(jsonEncode({'type': 'interrupt'}));
      return true;
    }
    return false;
  }

  /// 【0.2.0】切换模型（主机端配置的模型列表——先生决策：可切换）
  Future<bool> switchModel(String modelId) async {
    return sendCommand({'cmd': 'model_switch', 'model_id': modelId});
  }

  /// 【0.2.0】查询当前上下文状态（会话页入口）
  Future<bool> queryContextStatus({String sessionId = 'default'}) async {
    return sendCommand({'cmd': 'context_status', 'session_id': sessionId});
  }

  /// 【0.2.0】TTS 合成（服务端代理——音频落盘主机，返回 file 路径）
  Future<bool> voiceTts(String text, {String provider = '', String voice = ''}) async {
    return sendCommand({'cmd': 'voice_tts', 'text': text, 'provider': provider, 'voice': voice});
  }

  /// 【0.2.0】STT 识别（服务端代理——上传录音文件路径）
  Future<bool> voiceStt(String file, {String provider = ''}) async {
    return sendCommand({'cmd': 'voice_stt', 'file': file, 'provider': provider});
  }

  void startHeartbeat() {
    tcp?.startHeartbeat(30);
  }

  @override
  void onData(String line) {
    // 【先生要求】连接状态通知（连接成功/失败——通知栏）
    if (line.contains('"type":"connection_ok"')) {
      NotificationService.instance.show('LING OS', '已连接——认证成功');
    } else if (line.contains('"type":"conn_error"')) {
      NotificationService.instance.show('LING OS', '连接失败：${lastError ?? '未知'}');
    } else if (line.contains('"type":"disconnected"')) {
      NotificationService.instance.show('LING OS', '连接已断开');
    }
    // 【先生要求】同步：WS 认证成功（auth_ok）→ 自动拉取核心数据（完善服务端数据请求）
    if (line.contains('auth_ok')) {
      _autoSync();
    }
    // 【先生设计】token 无效（auth_error invalid token）→ 弹窗事件（手动重新验证）
    if (line.contains('auth_error') && line.contains('invalid token')) {
      appLog('ConnectionManager', 'token 无效——触发重新验证弹窗');
      _eventController.add('{"type":"token_invalid","message":"当前令牌无法使用"}');
    }
    // 【方案B】token 事件驱动：connection_ok（token 已到）→ 自动连 WS
    if (line.contains('"type":"connection_ok"')) {
      // 【修复】token 在 TcpChannel（tcp.token）——Manager.token 未同步
      final t = tcp?.token ?? '';
      final host = _tcpHost;
      final port = _tcpPort;
      if (t.isNotEmpty && host != null && port != null &&
          (ws == null || !ws!.isConnected)) {
        appLog('ConnectionManager', 'token 已到（tcp.token）——自动连 WS（$host:${port + 2}）');
        connectWsAndSave(host, port, t);
      } else {
        appLog('ConnectionManager', '自动连 WS 条件不满足: token=${t.isEmpty ? "空" : "有"} host=$host port=$port ws已连=${ws?.isConnected ?? false}');
      }
    }
    _eventController.add(line);
  }

  @override
  void onDisconnected(String reason) {
    lastError = reason;
    state = ConnState.disconnected;
    // 【0.2.1 #1】断连 → 离线只读事件（UI 切缓存显示 + 操作拦截）
    _eventController.add('{"type":"disconnected","reason":"$reason"}');
    _eventController.add('{"type":"offline","reason":"$reason"}');
  }

  @override
  void onError(String message) {
    lastError = message;
    state = ConnState.error;
    _eventController.add('{"type":"conn_error","message":"$message"}');
  }

  Future<void> disconnect() async {
    await ws?.disconnect();
    await tcp?.disconnect();
    state = ConnState.disconnected;
  }

  void dispose() {
    _eventController.close();
  }
}
