/// Chat 页面（协议 v3——流式对话渲染）
/// 【0.1.9】发送键↔中断键 + 已终止（继续）交互
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    _scrollToBottom();
    return Scaffold(
      appBar: AppBar(
        // 【0.1.9】左上角三横——打开 Drawer
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Nook'),
        actions: [
        IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => ref.read(chatControllerProvider.notifier).clear()),
      ]),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length,
              itemBuilder: (ctx, i) => _buildMsg(chat.messages[i]),
            ),
          ),
          _buildInput(chat.aiBusy),
        ],
      ),
    );
  }

  Widget _buildMsg(ChatMsg msg) {
    switch (msg.type) {
      case ChatMsgType.user:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandRed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        );
      case ChatMsgType.ai:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(msg.content + (msg.streaming ? '▍' : ''),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
              ),
            ),
            // 【0.1.9】已终止（继续）——点击重发原文续接
            if (msg.interrupted)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 10),
                child: GestureDetector(
                  onTap: () => ref.read(chatControllerProvider.notifier).resume(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('已终止（继续）',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      case ChatMsgType.thinking:
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text('╭ ${msg.content}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
        );
      case ChatMsgType.tool:
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Text(msg.content,
              style: const TextStyle(color: AppColors.brandCyan, fontSize: 12, fontFamily: 'monospace')),
        );
      case ChatMsgType.system:
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(msg.content,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
        );
    }
  }

  Widget _buildInput(bool busy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: '输入消息...', border: InputBorder.none, filled: false),
            ),
          ),
          const SizedBox(width: 8),
          // 【0.1.9】busy 时发送键 → 中断键
          busy
              ? IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    disabledBackgroundColor: AppColors.brandRed,
                  ),
                  onPressed: () => ref.read(chatControllerProvider.notifier).interrupt(),
                  icon: const Icon(Icons.stop_rounded, size: 22, color: Colors.white),
                  tooltip: '中断',
                )
              : IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
        ],
      ),
    );
  }

  void _send() {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    ref.read(chatControllerProvider.notifier).send(text);
  }
}
