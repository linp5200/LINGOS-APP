/// 记忆管理（协议 v3——memory_search/read/write/delete）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  final _store = AppStore();
  bool _autoWrite = false;
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _loadAutoWrite();
    _search('');
  }

  Future<void> _loadAutoWrite() async {
    final v = await _store.getAutoMemoryWrite();
    if (!mounted) return;
    setState(() => _autoWrite = v);
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

  /// 【0.1.9】点击记忆——展开全文详情
  void _showDetail(String content, String type, String time) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text([if (type.isNotEmpty) type, if (time.isNotEmpty) time].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        content: SingleChildScrollView(
          child: SelectableText(content,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  String _fmtMemTime(String t) {
    // 兼容数字时间戳（秒）与已格式化字符串
    final ts = int.tryParse(t);
    if (ts != null && ts > 1000000000) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return '${d.month}-${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记忆管理'), actions: [
        IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _write),
      ]),
      body: Column(
        children: [
          // 【0.1.9】AI 记忆自动写入开关（先生定案：显示状态）
          SwitchListTile(
            dense: true,
            value: _autoWrite,
            onChanged: (v) async {
              setState(() => _autoWrite = v);
              await _store.saveAutoMemoryWrite(v);
            },
            title: const Text('AI 记忆自动写入',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            subtitle: const Text('允许 AI 自主调用 memory_write 记录重要信息',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
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
                          final content = m['content']?.toString() ?? '';
                          final type = m['type']?.toString() ?? '';
                          final time = m['time']?.toString() ?? m['timestamp']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.psychology_outlined, size: 20, color: AppColors.brandCyan),
                              // 【0.1.9】列表显示摘要——点击展开全文
                              title: Text(content.length > 60 ? '${content.substring(0, 60)}...' : content,
                                  style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  [if (type.isNotEmpty) type, if (time.isNotEmpty) _fmtMemTime(time)].join(' · '),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              onTap: () => _showDetail(content, type, time),
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
