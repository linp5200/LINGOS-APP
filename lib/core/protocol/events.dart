/// WS 事件协议（协议 v3——2939 双向 JSON 事件流）
library;

import 'dart:convert';

class LingEvent {
  final String type;
  final Map<String, dynamic> data;

  const LingEvent(this.type, this.data);

  static LingEvent? parse(String line) {
    try {
      final map = jsonDecode(line);
      if (map is! Map<String, dynamic>) return null;
      final t = map['type'];
      if (t is! String) return null;
      return LingEvent(t, map);
    } catch (_) {
      return null;
    }
  }
}

/// 事件类型常量（App 渲染依据——协议 v3）
class EvtType {
  static const String content = 'content'; // 最终回复流式块
  static const String thinking = 'thinking'; // 步骤标题
  static const String thinkingDelta = 'thinking_delta'; // 思考逐字
  static const String thinkingHide = 'thinking_hide'; // 思考结束
  static const String toolCall = 'tool_call'; // 工具调用
  static const String toolResult = 'tool_result'; // 工具结果
  static const String subAgent = 'sub_agent'; // 子 AI
  static const String guiAsk = 'gui_ask'; // 提问弹窗
  static const String guiNotify = 'gui_notify'; // 通知
  static const String guiOpenUrl = 'gui_open_url'; // 打开链接
  static const String guiShare = 'gui_share'; // 分享
  static const String guiLocation = 'gui_location'; // 定位请求
  static const String guiClipboard = 'gui_clipboard'; // 剪贴板
  static const String image = 'image'; // 图片透传
  static const String error = 'error'; // 错误
  static const String done = 'done'; // 结束
  static const String authRequest = 'auth_request'; // 授权请求
  static const String authRespOk = 'auth_resp_ok';
  // 【0.1.9】chat 包装层与中断
  static const String chatEvent = 'chat_event'; // 服务端 AI 事件包装（data 内再解析）
  static const String chatDone = 'chat_done'; // 转发结束
  static const String chatInterrupted = 'chat_interrupted'; // 已被中断
  static const String chatError = 'chat_error'; // 转发错误
  static const String interruptAck = 'interrupt_ack'; // 中断已确认
  // 连接层事件（ConnectionManager 发出）
  static const String connectionOk = 'connection_ok';
  static const String connError = 'conn_error';
  static const String disconnected = 'disconnected';
}
