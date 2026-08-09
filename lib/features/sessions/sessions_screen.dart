/// 会话管理（协议 v3——session_list/create/delete/rename/history）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = false;
  StreamSubscription? _sub;
  final _store = AppStore();

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
        if (data is String) {
          final resp = jsonDecode(data);
          if (resp is Map && resp['status'] == 'ok') {
            final list = resp['data'];
            if (list is List) {
              setState(() {
                _sessions = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
                _loading = false;
              });
            }
          }
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

  void _switchTo(String id) async {
    await _store.saveSessionId(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已切换到会话 $id')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会话管理'), actions: [
        IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _create),
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
      ]),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.brandCyan),
                        title: Text(s['title']?.toString() ?? '未命名', style: const TextStyle(fontSize: 14)),
                        subtitle: Text('${s['message_count']?.toString() ?? '0'} 条消息',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.drive_file_rename_outline, size: 18), onPressed: () => _rename(id)),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(id)),
                          ],
                        ),
                        onTap: () => _switchTo(id),
                      ),
                    );
                  },
                ),
    );
  }
}
