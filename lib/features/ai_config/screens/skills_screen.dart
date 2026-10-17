/// 技能（0.1.9——分组 + 风险色标 + 启用开关；列表实时读 skill_list_full，不写死数量）
/// 启用 ≠ 权限：容器内=全权 / 主机/手机=必须用户授权
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

 final Map<String, Color> kRiskColors = {
  'low': Color(0xFF4CAF50),
  'medium': Color(0xFFFFB300),
  'high': Color(0xFFFF7043),
  'critical': AppColors.brandRed,
};

/// 【i18n】改为 getter：风险标签经 tr() 后需在每次访问时求值
Map<String, String> get kRiskLabels => {
  'low': tr('skill_low'),
  'medium': tr('skill_medium'),
  'high': tr('skill_high'),
  'critical': tr('skill_critical'),
};

// 技能分组（按功能前缀映射）
String skillGroup(String name) {
  if (name.startsWith('file_')) return tr('skill_files');
  if (name.startsWith('memory_')) return tr('skill_memory');
  if (name.startsWith('system_') || name.startsWith('process_') ||
      name.startsWith('package_') || name.startsWith('net_') ||
      name.startsWith('user_') || name.startsWith('cron_') ||
      name.startsWith('service_') || name == 'sys_command' ||
      name.startsWith('config_') || name.startsWith('script_') ||
      name.startsWith('read_log')) {
    return tr('skill_system');
  }
  if (name.startsWith('git_')) return 'Git';
  if (name.startsWith('web_')) return tr('dash_net');
  if (name.startsWith('ha_') || name.startsWith('agent_') || name.startsWith('sub_ai')) return tr('skill_ai_assistant');
  if (name.startsWith('gui_') || name == 'voice_command') return tr('skill_interaction');
  if (name.contains('alert') || name.contains('typhoon')) return tr('alert_generic');
  if (name.startsWith('vision')) return tr('skill_vision');
  return tr('grp_other');
}

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;
  String? _error;
  String _filter = tr('skill_all');
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _load();
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
          final d = jsonDecode(data);
          if (d is Map) resp = Map<String, dynamic>.from(d);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null || resp['status'] != 'ok') return;
        final list = resp['data'];
        if (list is List) {
          setState(() {
            _skills = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
            _error = null;
          });
        }
      }
    } catch (_) {}
  }

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'skill_list_full'});
  }

  void _toggle(Map<String, dynamic> s, bool v) {
    final name = s['name']?.toString() ?? '';
    setState(() => s['enabled'] = v);
    ref.read(connectionProvider)
        .sendCommand({'cmd': 'skill_enable', 'name': name, 'enabled': v});
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final s in _skills) {
      groups.putIfAbsent(skillGroup(s['name']?.toString() ?? ''), () => []).add(s);
    }
    final filters = [tr('skill_all'), ...groups.keys];

    return Scaffold(
      appBar: AppBar(title: Text(tr('cfg_skills')), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
      ]),
      body: _loading
          ?  Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style:  TextStyle(color: AppColors.brandRed)))
              : Column(
                  children: [
                    // 分组过滤
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: filters.map((f) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(f, style: const TextStyle(fontSize: 12)),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // 权限模型说明
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        tr('skill_enabled_permitted_inside_a_proot_rootfs'),
                        style:  TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: groups.entries
                            .where((e) => _filter == tr('skill_all') || e.key == _filter)
                            .map((e) => _groupSection(e.key, e.value))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _groupSection(String group, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(trp('skill_text', {'p0': group, 'p1': '${items.length}'}),
              style:  TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        for (final s in items) _skillTile(s),
      ],
    );
  }

  Widget _skillTile(Map<String, dynamic> s) {
    final name = s['name']?.toString() ?? '';
    final risk = s['risk']?.toString() ?? 'low';
    final riskColor = kRiskColors[risk] ?? AppColors.textSecondary;
    final enabled = s['enabled'] as bool? ?? true;
    final needConfirm = s['need_confirm'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(kRiskLabels[risk] ?? risk,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: riskColor)),
        ),
        title: Text(name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
            [s['description']?.toString() ?? '', if (needConfirm) tr('skill_needs_confirmation')].join(' · '),
            style:  TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Switch(
          value: enabled,
          onChanged: (v) => _toggle(s, v),
        ),
      ),
    );
  }
}
