/// Chat 页面（协议 v3——流式对话渲染）
/// 【0.1.9】发送键↔中断键 + 已终止（继续）交互
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
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
  // 【0.2.1 #4/#5】工具块/思考块折叠状态（来自外观设置 msgPrefs——默认收缩）
  bool _toolExpanded = false;
  bool _thinkingExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadBlockPrefs();
    // 【0.2.1 #10】初始化设备本地 TTS/STT 降级引擎（服务端不可用时兜底）
    _voice.ensureLocalFallback();
    // 【0.2.2】余额显示（DeepSeek /user/balance——token 行）
    _loadBalance();
  }

  Future<void> _loadBlockPrefs() async {
    final prefs = await AppStore().getMsgPrefs();
    if (!mounted) return;
    setState(() {
      _toolExpanded = prefs['toolExpand'] ?? false;
      _thinkingExpanded = prefs['thinkExpand'] ?? false;
    });
    _loadServerModels();
  }

  // 【0.2.1 #6】会话内模型切换——主机端模型列表（复用 provider_list 同步）
  List<Map<String, dynamic>> _serverModels = [];
  String _activeModel = '';
  String? _sessionName;

  Future<void> _loadServerModels() async {
    final cm = ref.read(connectionProvider);
    if (cm.ws == null || !cm.ws!.isConnected) return;
    final resp = await cm.requestJson({'cmd': 'provider_list'});
    if (resp == null || !mounted) return;
    final data = resp['data'];
    if (data is Map && data['providers'] is List) {
      setState(() {
        _serverModels = (data['providers'] as List).whereType<Map<String, dynamic>>().toList();
        _activeModel = data['active']?.toString() ?? '';
      });
    }
    // 会话名（9.1：session_list 已带 title——查当前会话）
    final sl = await cm.requestJson({'cmd': 'session_list'});
    if (sl != null && mounted) {
      final sd = sl['data'];
      if (sd is List) {
        for (final s in sd.whereType<Map<String, dynamic>>()) {
          if (s['id'] == ref.read(chatControllerProvider).sessionId) {
            setState(() => _sessionName = s['title']?.toString());
            break;
          }
        }
      }
    }
  }

  String _sessionTitle(String sessionId) {
    if (_sessionName != null && _sessionName!.isNotEmpty) return _sessionName!;
    if (sessionId == 'default') return '默认会话';
    return sessionId.length > 12 ? '…${sessionId.substring(sessionId.length - 12)}' : sessionId;
  }

  /// 【0.2.1 #6】模型下拉切换（切换提示：命中缓存将被重置）
  Widget _buildModelSwitcher(ChatState chat) {
    if (_serverModels.isEmpty) {
      return Text(chat.model ?? '未连接',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }
    final current = _activeModel.isNotEmpty ? _activeModel : (chat.model ?? '');
    return GestureDetector(
      onTap: () => _showModelPicker(current),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(current,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.brandCyan)),
          ),
          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.brandCyan),
        ],
      ),
    );
  }

  Future<void> _showModelPicker(String current) async {
    if (_serverModels.isEmpty) return;
    final cm = ref.read(connectionProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _serverModels.map((m) {
            final id = m['id']?.toString() ?? m['model']?.toString() ?? '';
            final name = m['name']?.toString() ?? id;
            return ListTile(
              title: Text(name, style: const TextStyle(fontSize: 14)),
              subtitle: id.isNotEmpty && id != name ? Text(id, style: const TextStyle(fontSize: 11)) : null,
              trailing: id == current ? const Icon(Icons.check, color: AppColors.brandCyan) : null,
              onTap: () => Navigator.pop(ctx, id),
            );
          }).toList(),
        ),
      ),
    );
    if (selected == null || selected == current || !mounted) return;
    // 切换前提示：命中缓存将被重置
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换模型'),
        content: const Text('更改模型后命中缓存将被重置，确定切换？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('切换')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final resp = await cm.requestJson({'cmd': 'model_switch', 'model_id': selected});
    if (!mounted) return;
    if (resp?['status']?.toString() == 'ok') {
      setState(() => _activeModel = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换模型：$selected'), duration: const Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败：${resp?['msg'] ?? '未知'}')),
      );
    }
  }

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
        // 【0.2.1 #6】会话正上方显示会话名 + 下方可换模型（模型下拉）
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_sessionTitle(chat.sessionId),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            _buildModelSwitcher(chat),
          ],
        ),
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
      if (_balance != null) '💰$_balance',   // 【0.2.2】余额（DeepSeek /user/balance——先生指示）
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

  String? _balance;   // 【0.2.2】余额显示（token 上传/下行一行）

  Future<void> _loadBalance() async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({'cmd': 'balance_query'});
    if (!mounted || resp == null) return;
    final d = resp['data'];
    if (d is Map && resp['status']?.toString() == 'ok') {
      final infos = d['balance_infos'];
      if (infos is List && infos.isNotEmpty) {
        final total = (infos.first as Map)['total_balance']?.toString() ?? '';
        final cur = (infos.first as Map)['currency']?.toString() ?? '';
        if (total.isNotEmpty) {
          setState(() => _balance = '$total$cur');
        }
      } else if (d['is_available'] != null) {
        setState(() => _balance = '可用');
      }
    }
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
        return _CollapsibleBlock(
          title: '思考',
          content: msg.content,
          collapsed: !_thinkingExpanded,
          icon: Icons.psychology_outlined,
          color: AppColors.textSecondary,
        );
      case ChatMsgType.tool:
        // 【0.2.1 #4】工具块可折叠：显示工具名 + 状态，点击展开看 args/result
        final hasResult = msg.toolResult != null;
        final ok = msg.toolSuccess ?? true;
        return _CollapsibleBlock(
          title: '▸ ${msg.toolName ?? '工具'}${hasResult ? (ok ? ' ✓' : ' ✗') : ' …'}',
          content: [
            if (msg.content.isNotEmpty) '参数: ${msg.content}',
            if (hasResult) '结果: ${msg.toolResult}',
          ].join('\n\n'),
          collapsed: !_toolExpanded,
          icon: Icons.build_outlined,
          color: ok ? AppColors.brandCyan : AppColors.brandRed,
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
            const SnackBar(content: Text('语音识别失败（服务端 STT 与设备本地均不可用）')),
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

/// 【0.2.1 #4】可折叠块（工具/思考——点击标题展开/收缩）
class _CollapsibleBlock extends StatefulWidget {
  final String title;
  final String content;
  final bool collapsed;
  final IconData icon;
  final Color color;

  const _CollapsibleBlock({
    required this.title,
    required this.content,
    required this.collapsed,
    required this.icon,
    required this.color,
  });

  @override
  State<_CollapsibleBlock> createState() => _CollapsibleBlockState();
}

class _CollapsibleBlockState extends State<_CollapsibleBlock> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = !widget.collapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(widget.icon, size: 14, color: widget.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(color: widget.color, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (_open && widget.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              // 【0.2.1 #4】展开显示全文（不截断——args/result 完整可读）
              child: SelectableText(widget.content,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            ),
        ],
      ),
    );
  }
}
