/// Token 完整用量（0.1.9——汇总卡片 + 时间过滤 + 按模型分组 + 可展开明细）
/// 服务端：token_usage_query 命令（/LINGOS/state/token_usage.jsonl）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class TokenUsageScreen extends ConsumerStatefulWidget {
  const TokenUsageScreen({super.key});

  @override
  ConsumerState<TokenUsageScreen> createState() => _TokenUsageScreenState();
}

class _TokenUsageScreenState extends ConsumerState<TokenUsageScreen> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  String _range = 'all'; // all/7d/30d/today
  StreamSubscription? _sub;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen((line) {
      try {
        final evt = jsonDecode(line);
        if (evt is Map && evt['type'] == 'command_response') {
          final data = evt['data'];
          Map<String, dynamic>? resp;
          if (data is String) {
            final d = jsonDecode(data);
            if (d is Map) resp = Map<String, dynamic>.from(d);
          } else if (data is Map) {
            resp = Map<String, dynamic>.from(data);
          }
          if (resp == null) return;
          if (resp['status'] != 'ok') {
            setState(() {
              _loading = false;
              _error = '查询失败：${resp['msg'] ?? '未知错误'}';
            });
            return;
          }
          final info = resp['data'];
          if (info is Map) {
            setState(() {
              _data = Map<String, dynamic>.from(info);
              _loading = false;
              _error = null;
            });
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

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    // 时间范围 → 秒级时间戳
    String start = '';
    if (_range != 'all') {
      final now = DateTime.now();
      DateTime s;
      switch (_range) {
        case 'today':
          s = DateTime(now.year, now.month, now.day);
          break;
        case '7d':
          s = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          s = now.subtract(const Duration(days: 30));
          break;
        default:
          s = now;
      }
      start = (s.millisecondsSinceEpoch / 1000).floor().toString();
    }
    ref.read(connectionProvider).sendCommand({'cmd': 'token_usage_query', 'start_time': start});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Token 完整用量'), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
      ]),
      body: Column(
        children: [
          // 时间过滤
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _chip('全部', 'all'),
                      _chip('今天', 'today'),
                      _chip('近7天', '7d'),
                      _chip('近30天', '30d'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.brandRed)))
                    : _data == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.data_usage, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                const Text('暂无用量数据——对话后生成',
                                    style: TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _load, child: const Text('刷新')),
                              ],
                            ),
                          )
                        : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _range == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: sel,
      onSelected: (_) {
        setState(() => _range = value);
        _load();
      },
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final total = (d['total_tokens'] as num?)?.toInt() ?? 0;
    final prompt = (d['prompt_tokens'] as num?)?.toInt() ?? 0;
    final completion = (d['completion_tokens'] as num?)?.toInt() ?? 0;
    final count = (d['count'] as num?)?.toInt() ?? 0;
    final byModel = d['by_model'] is Map ? Map<String, dynamic>.from(d['by_model'] as Map) : {};
    final records = d['records'] is List ? (d['records'] as List).cast<Map>() : <Map>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 汇总卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Text('总用量 ${_fmtTokens(total)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('请求次数', '$count'),
                  _stat('输入', _fmtTokens(prompt)),
                  _stat('输出', _fmtTokens(completion)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('按模型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        // 按模型分组
        for (final e in byModel.entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.memory, size: 20, color: AppColors.brandCyan),
              title: Text(e.key, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                  '${e.value['count'] ?? 0} 次 · 输入 ${_fmtTokens((e.value['prompt_tokens'] as num?)?.toInt() ?? 0)} · 输出 ${_fmtTokens((e.value['completion_tokens'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              trailing: e.value['model'] == 'unknown'
                  ? const Text('未知', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
                  : null,
            ),
          ),
        const SizedBox(height: 12),
        // 明细（可展开）
        const Text('明细（最近 ${records.length} 条）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        for (final r in records)
          _recordTile(r),
      ],
    );
  }

  Widget _recordTile(Map r) {
    final ts = (r['ts'] as num?)?.toDouble() ?? 0;
    final time = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).round())
            .toString()
            .substring(5, 16)
        : '--';
    final model = r['model']?.toString() ?? 'unknown';
    final p = (r['prompt_tokens'] as num?)?.toInt() ?? 0;
    final c = (r['completion_tokens'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(model == 'unknown' ? Icons.help_outline : Icons.chat_bubble_outline,
            size: 16, color: AppColors.textSecondary),
        title: Text('$time · $model', style: const TextStyle(fontSize: 12)),
        trailing: Text('${_fmtTokens(p)} / ${_fmtTokens(c)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  String _fmtTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
