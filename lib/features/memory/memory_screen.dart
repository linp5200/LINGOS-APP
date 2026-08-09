/// 记忆管理（协议 v3——memory_search/read/write/delete）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _search('');
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
                _items = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
                _loading = false;
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  void _search(String keyword) {
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'memory_search', 'keyword': keyword});
  }

  void _write() async {
    final contentCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'medium');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('写入记忆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: contentCtrl, decoration: const InputDecoration(hintText: '记忆内容'), maxLines: 3),
            const SizedBox(height: 8),
            TextField(controller: typeCtrl, decoration: const InputDecoration(hintText: '类型: short/medium/long')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && contentCtrl.text.isNotEmpty) {
      ref.read(connectionProvider).sendCommand({
        'cmd': 'memory_write',
        'content': contentCtrl.text,
        'type': typeCtrl.text.trim().isEmpty ? 'medium' : typeCtrl.text.trim(),
      });
      _search(_searchCtrl.text.trim());
    }
  }

  void _delete(String id) {
    ref.read(connectionProvider).sendCommand({'cmd': 'memory_delete', 'id': id});
    _search(_searchCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记忆管理'), actions: [
        IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _write),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: _search,
                    decoration: const InputDecoration(hintText: '搜索记忆（关键词）'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _search(_searchCtrl.text.trim()),
                  icon: const Icon(Icons.search, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('暂无记忆', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final m = _items[i];
                          final id = m['id']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.psychology_outlined, size: 20, color: AppColors.brandCyan),
                              title: Text(m['content']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${m['type']?.toString() ?? ''}  ${m['time']?.toString() ?? ''}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              trailing: id.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => _delete(id),
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
