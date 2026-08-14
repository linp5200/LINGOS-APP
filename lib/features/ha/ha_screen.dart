/// Help AI 面板（协议 v3——ha_search 查询 Help AI Data 帮助档案）
/// 【0.2.1 B1 改名】原"HA 面板"→"Help AI"（仅显示名；技能 ha_*/协议名不改）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class HaScreen extends ConsumerStatefulWidget {
  const HaScreen({super.key});

  @override
  ConsumerState<HaScreen> createState() => _HaScreenState();
}

class _HaScreenState extends ConsumerState<HaScreen> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen((line) {
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
                  _events = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
                  _loading = false;
                });
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _search() {
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'ha_search', 'query': _queryCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help AI')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(hintText: '搜索 HA 事件（如 温度/灯/设备）'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('无事件——输入关键词搜索', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _events.length,
                        itemBuilder: (ctx, i) {
                          final e = _events[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.home_work_outlined, size: 20, color: AppColors.brandCyan),
                              title: Text(e['title']?.toString() ?? e['type']?.toString() ?? '事件'),
                              subtitle: Text(e['content']?.toString() ?? e['summary']?.toString() ?? ''),
                              trailing: Text(e['time']?.toString() ?? e['ts']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
