/// Home Assistant 控制面板（AI-AGENT#10 定稿——0.2.1 实施）
/// - 配置入口 C2：设置主页独立入口（不藏 AI 配置里）
/// - B REST 控制：ha_config_set/ha_status/ha_states/ha_control
/// - C WS 实时事件：ha_event（state_changed → 事件流显示）
/// - 权限 A2：ha_control 默认直接执行，高风险（开锁/断电/燃气）强制确认弹窗
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class HaControlScreen extends ConsumerStatefulWidget {
  const HaControlScreen({super.key});

  @override
  ConsumerState<HaControlScreen> createState() => _HaControlScreenState();
}

class _HaControlScreenState extends ConsumerState<HaControlScreen> {
  bool _configured = false;
  String _statusText = '';
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _events = [];
  StreamSubscription? _sub;
  bool _loading = false;

  // 配置表单
  final _hostCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _loadConfig();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hostCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'ha_event') {
        if (!mounted) return;
        setState(() {
          _events.insert(0, Map<String, dynamic>.from(evt));
          if (_events.length > 50) _events.removeRange(50, _events.length);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConfig() async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({'cmd': 'ha_config_get'});
    if (!mounted || resp == null) return;
    final data = resp['data'];
    if (data is Map) {
      final configured = data['configured'] == true;
      setState(() {
        _configured = configured;
        if (configured) {
          _hostCtrl.text = data['host']?.toString() ?? '';
        }
      });
      if (configured) _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    final cm = ref.read(connectionProvider);
    final st = await cm.requestJson({'cmd': 'ha_status'});
    final es = await cm.requestJson({'cmd': 'ha_states'});
    if (!mounted) return;
    setState(() {
      _loading = false;
      final sd = st?['data'];
      if (sd is Map) {
        _statusText = 'HA ${sd['version'] ?? '?'} · ${sd['location_name'] ?? ''}';
      } else {
        _statusText = st?['msg']?.toString() ?? '状态获取失败';
      }
      final ed = es?['data'];
      if (ed is List) {
        _entities = ed.whereType<Map<String, dynamic>>().take(100).toList();
      }
    });
  }

  Future<void> _saveConfig() async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({
      'cmd': 'ha_config_set',
      'host': _hostCtrl.text.trim(),
      'token': _tokenCtrl.text.trim(),
      'port': 8123,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resp?['msg']?.toString() ?? '已保存'),
      duration: const Duration(seconds: 2),
    ));
    setState(() => _configured = _hostCtrl.text.trim().isNotEmpty);
    if (_configured) _refreshStatus();
  }

  /// 控制实体（高风险强制确认——先生裁决 A2）
  Future<void> _control(String domain, String service, String entityId) async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({
      'cmd': 'ha_control',
      'domain': domain,
      'service': service,
      'entity_id': entityId,
    });
    if (!mounted) return;
    final st = resp?['status']?.toString();
    if (st == 'need_confirm') {
      // 高风险操作——确认后带 confirm=true 重发
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('高风险操作确认'),
          content: Text(resp?['msg']?.toString() ?? '确认执行该操作？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认执行')),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        final r2 = await cm.requestJson({
          'cmd': 'ha_control',
          'domain': domain,
          'service': service,
          'entity_id': entityId,
          'confirm': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r2?['status']?.toString() == 'ok' ? '执行成功' : (r2?['msg'] ?? '执行失败')),
            duration: const Duration(seconds: 2),
          ));
        }
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(st == 'ok' ? '执行成功' : (resp?['msg'] ?? '执行失败')),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Assistant 控制')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 配置卡片
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('连接配置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'HA 主机地址（IP 或域名）',
                      hintText: '192.168.1.10',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '长期访问令牌（Long-Lived Token）',
                      hintText: 'HA 个人资料页生成',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saveConfig,
                        child: const Text('保存并连接'),
                      ),
                      const SizedBox(width: 8),
                      if (_configured)
                        OutlinedButton(
                          onPressed: _loading ? null : _refreshStatus,
                          child: const Text('刷新状态'),
                        ),
                    ],
                  ),
                  if (_statusText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_statusText,
                        style: const TextStyle(fontSize: 12, color: AppColors.brandCyan)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 实体列表
          if (_entities.isNotEmpty) ...[
            const Text('设备实体（前 100）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._entities.map((e) {
              final entityId = e['entity_id']?.toString() ?? '';
              final state = e['state']?.toString() ?? '';
              final attrs = e['attributes'];
              final friendly = attrs is Map ? attrs['friendly_name']?.toString() : null;
              final domain = entityId.split('.').first;
              final controllable = ['light', 'switch', 'cover', 'climate', 'lock', 'fan'].contains(domain);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    domain == 'light' ? Icons.lightbulb_outline :
                    domain == 'switch' ? Icons.power_settings_new :
                    domain == 'lock' ? Icons.lock_outline :
                    domain == 'cover' ? Icons.blinds :
                    domain == 'climate' ? Icons.thermostat :
                    Icons.devices_other,
                    size: 18,
                    color: state == 'on' || state == 'open' || state == 'unlocked'
                        ? AppColors.brandCyan : AppColors.textSecondary,
                  ),
                  title: Text(friendly ?? entityId,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('$entityId · $state',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: controllable
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.power_settings_new, size: 18),
                              onPressed: () => _control(domain, 'toggle', entityId),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }),
          ] else if (!_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('未配置或无可控实体',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
          // 实时事件流
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('实时事件（state_changed）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ..._events.take(20).map((evt) {
              final friendly = evt['friendly']?.toString() ?? evt['entity']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$friendly: ${evt['old_state'] ?? '?'} → ${evt['state'] ?? '?'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
