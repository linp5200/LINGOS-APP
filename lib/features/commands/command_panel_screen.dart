/// LING OS 命令面板（【0.7.0 P3】——"~130 命令无入口"的总出口）
///
/// 设计（方案三 1.4 B+C）：
///   · 数据源：服务端 command_list（ext 82 项 + 技能 + 核心——含来源/风险/描述）
///   · 搜索 + 分组过滤 + 参数表单 + 执行结果
///   · 三端同构（App 本屏 / Web 命令页 / 后续 Qt）
library;

import 'dart:convert';
import '../../core/i18n/app_i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class CommandPanelScreen extends ConsumerStatefulWidget {
  const CommandPanelScreen({super.key});

  @override
  ConsumerState<CommandPanelScreen> createState() => _CommandPanelScreenState();
}

class _CommandPanelScreenState extends ConsumerState<CommandPanelScreen> {
  List<Map<String, dynamic>> _commands = [];
  bool _loading = true;
  String _filter = '';
  String _sourceFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ref
          .read(connectionProvider)
          .requestJson({'cmd': 'command_list'}, timeout: const Duration(seconds: 10));
      final data = resp?['data'];
      List items = [];
      if (data is Map && data['data'] is Map && (data['data'] as Map)['commands'] is List) {
        items = (data['data'] as Map)['commands'] as List;
      } else if (data is Map && data['commands'] is List) {
        items = data['commands'] as List;
      }
      setState(() {
        _commands = items.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _shown {
    var list = _commands;
    if (_sourceFilter != 'all') {
      list = list.where((c) => c['source'] == _sourceFilter).toList();
    }
    if (_filter.trim().isNotEmpty) {
      final k = _filter.trim().toLowerCase();
      list = list
          .where((c) =>
              (c['name']?.toString().toLowerCase().contains(k) ?? false) ||
              (c['desc']?.toString().toLowerCase().contains(k) ?? false))
          .toList();
    }
    return list;
  }

  Future<void> _run(Map<String, dynamic> c) async {
    final name = c['name']?.toString() ?? '';
    final paramsCtrl = TextEditingController(text: '{}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(name, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((c['desc']?.toString() ?? '').isNotEmpty)
                Text(c['desc'].toString(),
                    style:  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(trp('cmd_source_risk', {'p0': c['source'] ?? '-', 'p1': c['risk'] ?? '-'}),
                  style:  TextStyle(fontSize: 11, color: AppColors.dim)),
              const SizedBox(height: 12),
              TextField(
                controller: paramsCtrl,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: tr('cmd_arguments_json_allowed'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('cmd_run'))),
        ],
      ),
    );
    if (ok != true) return;

    Map<String, dynamic> params = {};
    try {
      final parsed = jsonDecode(paramsCtrl.text.trim().isEmpty ? '{}' : paramsCtrl.text.trim());
      if (parsed is Map) params = Map<String, dynamic>.from(parsed);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('cmd_arguments_are_not_valid_json'))));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(trp('cmd_running', {'p0': name}))));
    }
    final resp = await ref
        .read(connectionProvider)
        .requestJson({'cmd': name, ...params}, timeout: const Duration(seconds: 20));

    if (!mounted) return;
    final pretty = _pretty(resp);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
               Divider(color: AppColors.divider),
              SelectableText(pretty,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  String _pretty(dynamic resp) {
    try {
      if (resp == null) return tr('cmd_timeout_or_no_response');
      final data = (resp is Map) ? resp['data'] : resp;
      return const JsonEncoder.withIndent('  ').convert(data ?? resp);
    } catch (_) {
      return resp?.toString() ?? tr('cmd_empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(tr('cmd_command_panel')),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: tr('cmd_search_commands_name_description'),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['all', 'ext', 'skill', 'core'].map((s) {
                final sel = _sourceFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      {'all': tr('skill_all'), 'ext': tr('cmd_extension'), 'skill': tr('cfg_skills'), 'core': tr('cmd_core')}[s] ?? s,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => _sourceFilter = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(trp('cmd_commands', {'p0': '${shown.length}'}),
                  style:  TextStyle(fontSize: 11, color: AppColors.dim)),
            ),
          ),
          Expanded(
            child: _loading
                ?  Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? Center(
                        child: Text(tr('cmd_no_matching_commands_or_host_not_connected'),
                            style:  TextStyle(color: AppColors.dim, fontSize: 12)))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (ctx, i) {
                          final c = shown[i];
                          final risk = c['risk']?.toString() ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(c['name']?.toString() ?? '',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              [
                                if ((c['source']?.toString() ?? '').isNotEmpty)
                                  trp('cmd_source', {'p0': c['source']}),
                                if ((c['module']?.toString() ?? '').isNotEmpty)
                                  trp('cmd_module', {'p0': c['module']}),
                                if (risk.isNotEmpty && risk != 'low') trp('cmd_risk', {'p0': risk}),
                                if ((c['desc']?.toString() ?? '').isNotEmpty)
                                  c['desc'].toString(),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:  TextStyle(fontSize: 10, color: AppColors.dim),
                            ),
                            trailing: const Icon(Icons.play_arrow, size: 18),
                            onTap: () => _run(c),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
