/// 【0.2.2 同步协议】同步设置页（先生裁决 2026-08-14）
/// - "允许其他设备修改本设备会话"全局开关（服务端强制）
/// - 手动同步按钮（先生裁决 B：连接成功自动 + 手动刷新）
/// - 最近同步时间显示
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _allowCross = false;
  bool _syncing = false;
  double _lastSync = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({'cmd': 'sync_settings_get'});
    final store = AppStore();
    final last = await store.getLastSync();
    if (!mounted) return;
    setState(() {
      final d = resp?['data'];
      if (d is Map) _allowCross = d['allow_cross_device'] == true;
      _lastSync = last;
    });
  }

  Future<void> _toggleCross(bool v) async {
    setState(() => _allowCross = v);
    final cm = ref.read(connectionProvider);
    await cm.requestJson({'cmd': 'sync_settings_set', 'allow_cross_device': v});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(v ? tr('sync_other_devices_may_now_modify_sessions_of') : tr('sync_defaults_restored_only_the_creator_can')),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _manualSync() async {
    setState(() => _syncing = true);
    final cm = ref.read(connectionProvider);
    await cm.refreshSync();
    final store = AppStore();
    final last = await store.getLastSync();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastSync = last;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('sync_sync_complete')),
      duration: const Duration(seconds: 2),
    ));
  }

  String _fmtLastSync(double ts) {
    if (ts <= 0) return tr('sync_never_synced');
    final t = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('cfg_sync_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _allowCross,
            onChanged: _toggleCross,
            title: Text(tr('sync_allow_other_devices_to_modify_sessions_of'), style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              tr('sync_off_only_the_session_creator_can_modify'),
              style:  TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const Divider(),
          ListTile(
            leading:  Icon(Icons.sync, size: 20, color: AppColors.brandCyan),
            title: Text(_syncing ? tr('sync_syncing') : tr('sync_sync_now'), style: const TextStyle(fontSize: 14)),
            subtitle: Text(trp('sync_last_sync', {'p0': _fmtLastSync(_lastSync)}),
                style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: _syncing
                ?  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                :  Icon(Icons.refresh, size: 20, color: AppColors.brandCyan),
            onTap: _syncing ? null : _manualSync,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr('sync_how_sync_works_n_first_connection_full_sync'),
              style:  TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
