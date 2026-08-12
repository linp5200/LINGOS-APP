/// Chat 页面（协议 v3——流式对话渲染）
/// 【0.1.9】发送键↔中断键 + 已终止（继续）交互
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'chat_controller.dart';
import 'voice_helper.dart';

class ChatScreen extends ConsumerStatefulWidget {
  // 【A1修复】三横按钮回调（HomeShell 打开 Drawer）
  final VoidCallback? onOpenDrawer;
  const ChatScreen({super.key, this.onOpenDrawer});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  // 【0.2.0】语音（录音→STT / TTS→播放）
  final VoiceHelper _voice = VoiceHelper();
  bool _recording = false;

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
        // 【0.1.9】左上角三横——打开 Drawer（经回调——修复 Scaffold.of 跨层失效）
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          onPressed: widget.onOpenDrawer,
        ),
        title: const Text('Nook'),
        actions: [
        IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => ref.read(chatControllerProvider.notifier).clear()),
      ]),
      body: Column(
        children: [
          // 【0.2.0】状态行：model + token 上传/下载 + 缓存命中 + AI 输出 + 压缩标记
          _buildStatusBar(chat),
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

  /// 【0.2.0】状态行（先生决策：model/token 上传下载/缓存命中/AI 输出/压缩标记）
  Widget _buildStatusBar(ChatState chat) {
    final aiOut = chat.messages.lastWhere(
      (m) => m.type == ChatMsgType.ai,
      orElse: () => const ChatMsg(ChatMsgType.ai, ''),
    ).content.length;
    final parts = <String>[
      chat.model ?? '未连接模型',
      '↑ ${chat.promptTokens}',
      '↓ ${chat.completionTokens}',
      if (chat.cacheHit > 0) '缓存 ${chat.cacheHit}',
      if (aiOut > 0) '输出 $aiOut 字',
      if (chat.contextCompressed) '📋已压缩',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: AppColors.surface.withValues(alpha: 0.6),
      child: Text(
        parts.join('  ·  '),
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
            // 【0.2.0】朗读按钮（服务端代理 TTS——音频走 HTTP 8088）
            if (!msg.streaming && msg.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 10),
                child: GestureDetector(
                  onTap: () => _speakAi(msg),
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
                        Icon(Icons.volume_up_outlined, size: 14, color: AppColors.brandCyan),
                        SizedBox(width: 4),
                        Text('朗读', style: TextStyle(fontSize: 12, color: AppColors.brandCyan)),
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
          child: Text('▸ ${msg.toolName ?? msg.content}',
              style: const TextStyle(color: AppColors.brandCyan, fontSize: 12, fontFamily: 'monospace')),
        );
      // 【0.2.0】工具错误卡片（红色——17 类详细说明 + 建议）
      case ChatMsgType.toolError:
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brandRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppColors.brandRed),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${msg.toolName ?? '工具'} [${msg.errorType ?? 'Error'}]',
                        style: const TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg.content,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              if (msg.errorAction != null && msg.errorAction!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('💡 ${msg.errorAction}',
                    style: const TextStyle(color: AppColors.brandCyan, fontSize: 11)),
              ],
            ],
          ),
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
          // 【0.2.0】语音输入（录音→STT→发送）
          IconButton(
            icon: Icon(_recording ? Icons.mic : Icons.mic_none,
                size: 22, color: _recording ? AppColors.brandRed : AppColors.textSecondary),
            tooltip: _recording ? '停止录音并识别' : '语音输入（点击录音）',
            onPressed: _toggleRecord,
          ),
          const SizedBox(width: 4),
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

  // ========== 【0.2.0】语音交互 ==========
  String _hostFromWs() {
    final cm = ref.read(connectionProvider);
    final u = cm.ws?.url ?? '';
    final cleaned = u.replaceFirst('wss://', '').replaceFirst('ws://', '').split(':').first;
    return cleaned.isEmpty ? '127.0.0.1' : cleaned;
  }

  /// 录音开关：点击开始录音 → 再点停止 → STT → 发送
  Future<void> _toggleRecord() async {
    final cm = ref.read(connectionProvider);
    _voice.configure(host: _hostFromWs(), token: cm.token);
    if (_recording) {
      final path = await _voice.stopRecording();
      setState(() => _recording = false);
      if (path != null) {
        final text = await _voice.transcribe(path);
        if (text != null && text.isNotEmpty) {
          _inputCtrl.text = text;
          _send();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音识别失败（服务端 STT 不可用）')),
          );
        }
      }
    } else {
      final ok = await _voice.ensureMicPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能语音输入')),
        );
        return;
      }
      final path = await _voice.startRecording();
      if (path != null) {
        setState(() => _recording = true);
      }
    }
  }

  /// 朗读最后一条 AI 回复（服务端代理 TTS → 下载播放）
  Future<void> _speakAi(ChatMsg msg) async {
    final cm = ref.read(connectionProvider);
    _voice.configure(host: _hostFromWs(), token: cm.token);
    final resp = await cm.requestJson({'cmd': 'voice_tts', 'text': msg.content});
    final data = resp?['data'];
    final file = data is Map ? data['file']?.toString() : null;
    if (file != null && file.isNotEmpty) {
      final ok = await _voice.speak('', remoteFile: file);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音播放失败（音频下载失败）')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音合成失败——服务端无 TTS 提供商/引擎，App 将不朗读')),
      );
    }
  }
}
