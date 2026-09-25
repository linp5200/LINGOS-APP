/// Chat 控制器（协议 v3——流式事件渲染）
/// 【0.1.9】解包 chat_event（服务端包装层）+ 中断/继续支持
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/protocol/events.dart';

/// 消息类型
enum ChatMsgType { user, ai, thinking, tool, system, toolError }

class ChatMsg {
  final ChatMsgType type;
  final String content;
  final String? toolName;
  final bool streaming;
  final bool interrupted; // 【0.1.9】该条 AI 回复是否被中断
  // 【0.2.0】工具错误卡片
  final String? errorType;
  final String? errorAction;
  // 【0.2.1 #4】工具结果（tool_result 事件——点击展开查看）
  final String? toolResult;
  final bool? toolSuccess;

  const ChatMsg(this.type, this.content,
      {this.toolName, this.streaming = false, this.interrupted = false,
      this.errorType, this.errorAction, this.toolResult, this.toolSuccess});

  ChatMsg copyWith({String? content, bool? streaming, bool? interrupted, String? toolResult, bool? toolSuccess}) =>
      ChatMsg(type, content ?? this.content,
          toolName: toolName,
          streaming: streaming ?? this.streaming,
          interrupted: interrupted ?? this.interrupted,
          errorType: errorType, errorAction: errorAction,
          toolResult: toolResult ?? this.toolResult,
          toolSuccess: toolSuccess ?? this.toolSuccess);
}

class ChatState {
  final List<ChatMsg> messages;
  final bool aiBusy;
  final String sessionId;
  final bool interrupted; // 【0.1.9】最近一轮是否被中断
  final String? lastUserText; // 【0.1.9】最近发送的用户原文（继续用）
  // 【0.2.0】状态行数据（done.usage / meta 事件）
  final String? model;
  final String? provider;
  final int promptTokens;
  final int completionTokens;
  final int cacheHit;
  final bool contextCompressed;
  // 【0.6.0】待审批高风险管理操作（auth_request 事件——审批链修复）
  final Map<String, dynamic>? pendingAuth;
  // 【0.6.0】待回答的 GUI 提问（gui_ask 事件——GUI 链修复）
  final Map<String, dynamic>? pendingGuiAsk;

  const ChatState(
      {this.messages = const [],
      this.aiBusy = false,
      this.sessionId = 'default',
      this.interrupted = false,
      this.lastUserText,
      this.model,
      this.provider,
      this.promptTokens = 0,
      this.completionTokens = 0,
      this.cacheHit = 0,
      this.contextCompressed = false,
      this.pendingAuth,
      this.pendingGuiAsk});

  ChatState copyWith(
          {List<ChatMsg>? messages,
          bool? aiBusy,
          String? sessionId,
          bool? interrupted,
          String? lastUserText,
          String? model,
          String? provider,
          int? promptTokens,
          int? completionTokens,
          int? cacheHit,
          bool? contextCompressed,
          Map<String, dynamic>? pendingAuth,
          Map<String, dynamic>? pendingGuiAsk,
          bool? clearPendingAuth,
          bool? clearPendingGuiAsk}) =>
      ChatState(
          messages: messages ?? this.messages,
          aiBusy: aiBusy ?? this.aiBusy,
          sessionId: sessionId ?? this.sessionId,
          interrupted: interrupted ?? this.interrupted,
          lastUserText: lastUserText ?? this.lastUserText,
          model: model ?? this.model,
          provider: provider ?? this.provider,
          promptTokens: promptTokens ?? this.promptTokens,
          completionTokens: completionTokens ?? this.completionTokens,
          cacheHit: cacheHit ?? this.cacheHit,
          contextCompressed: contextCompressed ?? this.contextCompressed,
          pendingAuth: (clearPendingAuth ?? false) ? null : (pendingAuth ?? this.pendingAuth),
          pendingGuiAsk: (clearPendingGuiAsk ?? false) ? null : (pendingGuiAsk ?? this.pendingGuiAsk));
}

class ChatController extends StateNotifier<ChatState> {
  final Ref ref;
  StreamSubscription? _sub;
  int _aiMsgIdx = -1;
  int _thinkMsgIdx = -1;

  ChatController(this.ref) : super(const ChatState()) {
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
  }

  void _onEvent(String line) {
    final evt = LingEvent.parse(line);
    if (evt == null) return;
    switch (evt.type) {
      case EvtType.content:
        _appendAi(evt.data['delta']?.toString() ?? '');
      case EvtType.thinkingDelta:
        _appendThinking(evt.data['delta']?.toString() ?? '');
      case EvtType.thinking:
        _appendSystem(evt.data['content']?.toString() ?? evt.data['step']?.toString() ?? '');
      case EvtType.thinkingHide:
        _endThinking();
      case EvtType.toolCall:
        _appendTool(evt.data['name']?.toString() ?? '工具', evt.data['args']?.toString() ?? '');
      case EvtType.toolResult:
        _appendToolResult(
          evt.data['name']?.toString() ?? '',
          evt.data['content']?.toString() ?? '',
          (evt.data['success'] as num?)?.toInt() == 1,
        );
      case EvtType.done:
        // 【0.2.1 #3】强制收尾（防工具轮后残留流式标记）
        _finalizeAll(false);
        // 【0.2.0】状态行数据（真实 token 用量 + 模型）
        final u = evt.data['usage'];
        if (u is Map) {
          state = state.copyWith(
            promptTokens: (u['prompt_tokens'] as num?)?.toInt() ?? 0,
            completionTokens: (u['completion_tokens'] as num?)?.toInt() ?? 0,
            cacheHit: (u['cache_hit'] as num?)?.toInt() ?? 0,
          );
        }
        if (evt.data['model'] != null) {
          state = state.copyWith(model: evt.data['model']?.toString());
        }
      case EvtType.guiNotify:
        _appendSystem('📢 ${evt.data['title']}');
      // 【0.6.0】GUI 交互链修复——6 事件全处理（此前仅 notify 有处理）
      case EvtType.guiAsk:
        state = state.copyWith(pendingGuiAsk: {
          'question': evt.data['question']?.toString() ?? '',
          'options': (evt.data['options'] is List)
              ? (evt.data['options'] as List).map((e) => e.toString()).toList()
              : <String>[],
          'req_id': evt.data['req_id']?.toString() ?? '',
        });
        _appendSystem('❓ AI 提问：${evt.data['question'] ?? ''}');
      case EvtType.guiOpenUrl:
        _appendSystem('🔗 请求打开链接：${evt.data['url'] ?? ''}');
      case EvtType.guiShare:
        _appendSystem('📤 分享内容：${evt.data['text'] ?? ''}');
      case EvtType.guiLocation:
        _appendSystem('📍 收到定位请求（请在系统设置中授权定位后由 App 上传）');
      case EvtType.guiClipboard:
        _appendSystem('📋 剪贴板请求：${evt.data['action'] ?? 'read'}');
      // 【0.6.0】审批链修复——高风险操作审批卡片（此前静默丢弃 → 必超时）
      case EvtType.authRequest:
        state = state.copyWith(pendingAuth: {
          'req_id': evt.data['req_id']?.toString() ?? '',
          'tool': evt.data['tool']?.toString() ?? '',
          'args': evt.data['args']?.toString() ?? '',
          'reason': evt.data['reason']?.toString() ?? '',
          'timeout': evt.data['timeout'] ?? 60,
        });
        _appendSystem('🔐 高风险操作待审批：${evt.data['tool'] ?? ''}');
      case EvtType.error:
        _appendSystem('⚠️ ${evt.data['msg'] ?? evt.data['message'] ?? '错误'}');
      // 【0.2.0】上下文压缩通知（先生决策：App 显示提示条）
      case EvtType.context:
        if ((evt.data['action']?.toString() ?? '') == 'summarized') {
          final removed = evt.data['removed']?.toString() ?? '?';
          _appendSystem('📋 上下文已压缩（移除 $removed 条旧消息——历史已存档可回溯）');
          state = state.copyWith(contextCompressed: true);
        }
      // 【0.2.0】工具错误卡片（先生决策：17 类详细说明）
      case EvtType.toolError:
        _appendToolError(
          evt.data['name']?.toString() ?? '工具',
          evt.data['error_type']?.toString() ?? 'Unknown',
          evt.data['error']?.toString() ?? '',
          evt.data['action']?.toString() ?? '',
        );
      // 【0.2.0】会话头部（model/上下文 token）
      case EvtType.meta:
        state = state.copyWith(
          model: evt.data['model']?.toString(),
          provider: evt.data['provider']?.toString(),
        );
      // 【0.2.0】语音事件
      case EvtType.ttsResult:
        _appendSystem('🔊 语音合成完成：${evt.data['file']}');
      case EvtType.ttsError:
        _appendSystem('⚠️ 语音合成失败：${evt.data['msg'] ?? evt.data['error'] ?? '未知'}');
      case EvtType.sttResult:
        _appendSystem('🎤 识别结果：${evt.data['text']}');
      case EvtType.sttError:
        _appendSystem('⚠️ 语音识别失败：${evt.data['msg'] ?? evt.data['error'] ?? '未知'}');
      // 【0.1.9】chat_event 解包：服务端把 AI 事件包装为 {"type":"chat_event","data":{...}}
      case EvtType.chatEvent:
        final inner = evt.data['data'];
        if (inner is Map) {
          _onEvent(jsonEncode(inner));
        }
      case EvtType.chatDone:
        _finalizeAll(false);
      case EvtType.chatInterrupted:
        _endAi(true);
      case EvtType.chatError:
        _appendSystem('⚠️ ${evt.data['message'] ?? evt.data['msg'] ?? '对话错误'}');
        _endAi(false);
      case EvtType.interruptAck:
        // 服务端确认中断——等待 chat_interrupted 事件
        break;
      case EvtType.connectionOk:
      case EvtType.connError:
      case EvtType.disconnected:
        break;
    }
  }

  void _appendSystem(String text) {
    state = state.copyWith(messages: [...state.messages, ChatMsg(ChatMsgType.system, text)]);
  }

  void _appendThinking(String delta) {
    if (_thinkMsgIdx < 0) {
      state = state.copyWith(messages: [...state.messages, ChatMsg(ChatMsgType.thinking, delta, streaming: true)]);
      _thinkMsgIdx = state.messages.length - 1;
    } else {
      final msgs = [...state.messages];
      msgs[_thinkMsgIdx] = msgs[_thinkMsgIdx].copyWith(content: msgs[_thinkMsgIdx].content + delta);
      state = state.copyWith(messages: msgs);
    }
  }

  void _endThinking() {
    if (_thinkMsgIdx >= 0) {
      final msgs = [...state.messages];
      msgs[_thinkMsgIdx] = msgs[_thinkMsgIdx].copyWith(streaming: false);
      state = state.copyWith(messages: msgs);
      _thinkMsgIdx = -1;
    }
  }

  void _appendAi(String delta) {
    if (_aiMsgIdx < 0) {
      state = state.copyWith(
        messages: [...state.messages, ChatMsg(ChatMsgType.ai, delta, streaming: true)],
        aiBusy: true,
      );
      _aiMsgIdx = state.messages.length - 1;
    } else {
      final msgs = [...state.messages];
      msgs[_aiMsgIdx] = msgs[_aiMsgIdx].copyWith(content: msgs[_aiMsgIdx].content + delta);
      state = state.copyWith(messages: msgs);
    }
  }

  void _endAi(bool interrupted) {
    if (_aiMsgIdx >= 0) {
      final msgs = [...state.messages];
      msgs[_aiMsgIdx] = msgs[_aiMsgIdx].copyWith(streaming: false, interrupted: interrupted);
      state = state.copyWith(messages: msgs, aiBusy: false, interrupted: interrupted);
      _aiMsgIdx = -1;
      _thinkMsgIdx = -1;
    } else {
      state = state.copyWith(aiBusy: false, interrupted: interrupted);
    }
  }

  /// 【0.2.1 #3 防御】done 到达时：强制收尾所有残留流式消息
  /// 工具调用轮后若模型直接 done（无 content 事件），残留的 thinking/ai 流式标记
  /// 会导致界面停在"流式中"——强制全部收尾 + aiBusy 复位
  void _finalizeAll(bool interrupted) {
    if (_aiMsgIdx >= 0 || _thinkMsgIdx >= 0) {
      final msgs = [...state.messages];
      if (_aiMsgIdx >= 0 && _aiMsgIdx < msgs.length) {
        msgs[_aiMsgIdx] = msgs[_aiMsgIdx].copyWith(streaming: false, interrupted: interrupted);
      }
      if (_thinkMsgIdx >= 0 && _thinkMsgIdx < msgs.length) {
        msgs[_thinkMsgIdx] = msgs[_thinkMsgIdx].copyWith(streaming: false);
      }
      _aiMsgIdx = -1;
      _thinkMsgIdx = -1;
      state = state.copyWith(messages: msgs, aiBusy: false, interrupted: interrupted);
    } else {
      state = state.copyWith(aiBusy: false, interrupted: interrupted);
    }
  }

  void _appendTool(String name, String args) {
    // 【0.2.1 #4】保留完整 args（渲染层负责截断/折叠——点击展开看全文）
    state = state.copyWith(messages: [
      ...state.messages,
      ChatMsg(ChatMsgType.tool, args, toolName: name)
    ]);
  }

  /// 【0.2.1 #4】工具结果（tool_result 事件——挂到最近一条 tool 消息，可展开查看）
  void _appendToolResult(String name, String content, bool success) {
    final msgs = [...state.messages];
    // 找最近的 tool 消息（同名优先）
    int idx = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].type == ChatMsgType.tool && (name.isEmpty || msgs[i].toolName == name)) {
        idx = i;
        break;
      }
    }
    if (idx >= 0) {
      msgs[idx] = msgs[idx].copyWith(toolResult: content, toolSuccess: success);
      state = state.copyWith(messages: msgs);
    } else {
      // 无对应 tool 消息——独立展示
      state = state.copyWith(messages: [
        ...msgs,
        ChatMsg(ChatMsgType.tool, '', toolName: name, toolResult: content, toolSuccess: success),
      ]);
    }
  }

  /// 【0.2.0】工具错误卡片（错误类型 + 建议动作）
  void _appendToolError(String name, String type, String error, String action) {
    state = state.copyWith(messages: [
      ...state.messages,
      ChatMsg(ChatMsgType.toolError, error,
          toolName: name, errorType: type, errorAction: action)
    ]);
  }

  /// 发送消息（记录原文——继续用）
  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.aiBusy) return;
    final content = text.trim();
    state = state.copyWith(
      messages: [...state.messages, ChatMsg(ChatMsgType.user, content)],
      aiBusy: true,
      interrupted: false,
      lastUserText: content,
    );
    await ref.read(connectionProvider).sendChat(content, sessionId: state.sessionId);
  }

  /// 【0.1.9】中断当前 AI 回复
  Future<void> interrupt() async {
    await ref.read(connectionProvider).sendInterrupt();
  }

  /// 【0.6.0】审批回执（auth_request → 用户决策 → 发送 auth_respond 命令）
  /// 【0.7.0-hf2】三态：approve（一次）/ always（始终允许——写服务端记忆表）/ reject
  Future<void> respondAuth(bool approve, {bool always = false}) async {
    final p = state.pendingAuth;
    if (p == null) return;
    final reqId = p['req_id']?.toString() ?? '';
    final tool = p['tool']?.toString() ?? '';
    state = state.copyWith(clearPendingAuth: true);
    try {
      await ref.read(connectionProvider).sendCommand({
        'cmd': 'auth_respond',
        'req_id': reqId,
        'decision': always ? 'always' : (approve ? 'approve' : 'reject'),
        'tool': tool,
      });
      _appendSystem(
          always
              ? '✅ 已设为始终允许：$tool（后续同类操作自动批准）'
              : (approve ? '✅ 已批准：$tool' : '⛔ 已拒绝：$tool'));
    } catch (e) {
      _appendSystem('⚠️ 审批回执发送失败：$e');
    }
  }

  /// 【0.6.0】回答 GUI 提问（gui_ask → 用户选择/输入 → 作为消息回传 AI）
  Future<void> respondGuiAsk(String answer) async {
    final q = state.pendingGuiAsk;
    if (q == null) return;
    state = state.copyWith(clearPendingGuiAsk: true);
    final text = answer.trim();
    if (text.isEmpty) return;
    // AI 繁忙时等待本轮结束再发送（最多 30 秒——防消息丢失）
    for (int i = 0; i < 60 && state.aiBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await send(text);
  }

  /// 【0.1.9】继续：重发原文（同会话续接上下文）
  Future<void> resume() async {
    final text = state.lastUserText;
    if (text == null || text.isEmpty) return;
    await send(text);
  }

  /// 【0.1.9】切换会话（点击会话进入对话页——载入该会话继续对话）
  void setSession(String sessionId) {
    state = state.copyWith(sessionId: sessionId);
  }

  void clear() {
    _aiMsgIdx = -1;
    _thinkMsgIdx = -1;
    state = const ChatState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});
