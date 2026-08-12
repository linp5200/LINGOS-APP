/// 会话管理（0.1.9——点击进入对话页继续对话 + 长按多选批量删除）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_screen.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = false;
  bool _selectMode = false;
  final Set<String> _selected = {};
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'command_response') {
        final data = evt['data'];
        Map<String, dynamic>? resp;
        if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map) resp = Map<String, dynamic>.from(decoded);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null || resp['status'] != 'ok') return;
        final list = resp['data'];
        if (list is List) {
          setState(() {
            _sessions = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  void _refresh() {
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'session_list'});
  }

  void _create() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建会话'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '会话标题')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(connectionProvider).sendCommand({'cmd': 'session_create', 'title': ctrl.text.trim()});
      _refresh();
    }
  }

  /// 【0.1.9】点击会话 → 进入对话页（载入该会话继续对话）
  void _openChat(String id) {
    ref.read(chatControllerProvider.notifier).setSession(id);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _rename(String id) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '新标题')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctrl.text.isNotEmpty) {
      ref.read(connectionProvider).sendCommand({'cmd': 'session_rename', 'id': id, 'title': ctrl.text});
      _refresh();
    }
  }

  void _delete(String id) {
    ref.read(connectionProvider).sendCommand({'cmd': 'session_delete', 'id': id});
    _refresh();
  }

  /// 【0.1.9】多选批量删除
  void _batchDelete() {
    if (_selected.isEmpty) return;
    for (final id in _selected) {
      ref.read(connectionProvider).sendCommand({'cmd': 'session_delete', 'id': id});
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    _refresh();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '已选 ${_selected.length}' : '会话管理'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }))
            : null,
        actions: [
          if (_selectMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.brandRed),
              onPressed: _batchDelete,
            )
          else ...[
            IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _create),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('暂无会话', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final id = s['id']?.toString() ?? '';
                    final sel = _selected.contains(id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: sel ? AppColors.surface.withValues(alpha: 0.8) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: sel ? const BorderSide(color: AppColors.brandCyan) : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(
                          sel ? Icons.check_circle : Icons.chat_bubble_outline,
                          size: 20,
                          color: sel ? AppColors.brandCyan : AppColors.brandCyan,
                        ),
                        title: Text(s['title']?.toString() ?? '未命名',
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                            '${s['message_count']?.toString() ?? '0'} 条消息 · ${s['updated'] != null ? _fmtTime(s['updated']) : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: _selectMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.drive_file_rename_outline, size: 18),
                                      onPressed: () => _rename(id)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => _delete(id)),
                                ],
                              ),
                        // 【0.1.9】点击进入对话页；长按进入多选
                        onTap: () => _selectMode ? _toggleSelect(id) : _openChat(id),
                        onLongPress: () => setState(() {
                          _selectMode = true;
                          _selected.add(id);
                        }),
                      ),
                    );
                  },
                ),
    );
  }

  String _fmtTime(dynamic ts) {
    if (ts is! num) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000);
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    if (d.inDays < 1) return '${d.inHours} 小时前';
    return '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
