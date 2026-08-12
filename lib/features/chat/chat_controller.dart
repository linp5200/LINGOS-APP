/// Chat 控制器（协议 v3——流式事件渲染）
/// 【0.1.9】解包 chat_event（服务端包装层）+ 中断/继续支持
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/protocol/events.dart';

/// 消息类型
enum ChatMsgType { user, ai, thinking, tool, system }

class ChatMsg {
  final ChatMsgType type;
  final String content;
  final String? toolName;
  final bool streaming;
  final bool interrupted; // 【0.1.9】该条 AI 回复是否被中断

  const ChatMsg(this.type, this.content,
      {this.toolName, this.streaming = false, this.interrupted = false});

  ChatMsg copyWith({String? content, bool? streaming, bool? interrupted}) =>
      ChatMsg(type, content ?? this.content,
          toolName: toolName,
          streaming: streaming ?? this.streaming,
          interrupted: interrupted ?? this.interrupted);
}

class ChatState {
  final List<ChatMsg> messages;
  final bool aiBusy;
  final String sessionId;
  final bool interrupted; // 【0.1.9】最近一轮是否被中断
  final String? lastUserText; // 【0.1.9】最近发送的用户原文（继续用）

  const ChatState(
      {this.messages = const [],
      this.aiBusy = false,
      this.sessionId = 'default',
      this.interrupted = false,
      this.lastUserText});

  ChatState copyWith(
          {List<ChatMsg>? messages,
          bool? aiBusy,
          String? sessionId,
          bool? interrupted,
          String? lastUserText}) =>
      ChatState(
          messages: messages ?? this.messages,
          aiBusy: aiBusy ?? this.aiBusy,
          sessionId: sessionId ?? this.sessionId,
          interrupted: interrupted ?? this.interrupted,
          lastUserText: lastUserText ?? this.lastUserText);
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
      case EvtType.done:
        _endAi(false);
      case EvtType.guiNotify:
        _appendSystem('📢 ${evt.data['title']}');
      case EvtType.error:
        _appendSystem('⚠️ ${evt.data['msg'] ?? evt.data['message'] ?? '错误'}');
      // 【0.1.9】chat_event 解包：服务端把 AI 事件包装为 {"type":"chat_event","data":{...}}
      case EvtType.chatEvent:
        final inner = evt.data['data'];
        if (inner is Map) {
          _onEvent(jsonEncode(inner));
        }
      case EvtType.chatDone:
        _endAi(false);
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

  void _appendTool(String name, String args) {
    _appendSystem('▸ $name $args');
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
