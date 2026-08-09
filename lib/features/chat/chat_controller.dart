/// Chat 控制器（协议 v3——流式事件渲染）
library;

import 'dart:async';

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

  const ChatMsg(this.type, this.content, {this.toolName, this.streaming = false});

  ChatMsg copyWith({String? content, bool? streaming}) =>
      ChatMsg(type, content ?? this.content, toolName: toolName, streaming: streaming ?? this.streaming);
}

class ChatState {
  final List<ChatMsg> messages;
  final bool aiBusy;
  final String sessionId;

  const ChatState({this.messages = const [], this.aiBusy = false, this.sessionId = 'default'});

  ChatState copyWith({List<ChatMsg>? messages, bool? aiBusy, String? sessionId}) =>
      ChatState(messages: messages ?? this.messages, aiBusy: aiBusy ?? this.aiBusy, sessionId: sessionId ?? this.sessionId);
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
        // 步骤标题（第 N/∞ 步）——显示为系统行
        _appendSystem(evt.data['content']?.toString() ?? evt.data['step']?.toString() ?? '');
      case EvtType.thinkingHide:
        _endThinking();
      case EvtType.toolCall:
        _appendTool(evt.data['name']?.toString() ?? '工具', evt.data['args']?.toString() ?? '');
      case EvtType.done:
        _endAi();
      case EvtType.guiNotify:
        _appendSystem('📢 ${evt.data['title']}');
      case EvtType.error:
        _appendSystem('⚠️ ${evt.data['msg'] ?? evt.data['message'] ?? '错误'}');
      case EvtType.connectionOk:
      case EvtType.connError:
      case EvtType.disconnected:
        // 连接状态（不混入对话）
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

  void _endAi() {
    if (_aiMsgIdx >= 0) {
      final msgs = [...state.messages];
      msgs[_aiMsgIdx] = msgs[_aiMsgIdx].copyWith(streaming: false);
      state = state.copyWith(messages: msgs, aiBusy: false);
      _aiMsgIdx = -1;
    }
  }

  void _appendTool(String name, String args) {
    _appendSystem('▸ $name $args');
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.aiBusy) return;
    final content = text.trim();
    state = state.copyWith(
      messages: [...state.messages, ChatMsg(ChatMsgType.user, content)],
      aiBusy: true,
    );
    await ref.read(connectionProvider).sendChat(content, sessionId: state.sessionId);
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
