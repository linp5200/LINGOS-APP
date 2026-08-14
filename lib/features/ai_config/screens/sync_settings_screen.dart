/// 【0.2.2 同步协议】同步设置页（先生裁决 2026-08-14）
/// - "允许其他设备修改本设备会话"全局开关（服务端强制）
/// - 手动同步按钮（先生裁决 B：连接成功自动 + 手动刷新）
/// - 最近同步时间显示
library;

import 'dart:async';

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
      content: Text(v ? '已允许其他设备修改本设备会话' : '已恢复默认（仅创建者可修改）'),
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
      content: Text('同步完成'),
      duration: const Duration(seconds: 2),
    ));
  }

  String _fmtLastSync(double ts) {
    if (ts <= 0) return '从未同步';
    final t = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _allowCross,
            onChanged: _toggleCross,
            title: const Text('允许其他设备修改本设备会话', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '关闭时：每会话仅创建者可修改/追加，其他设备只读（服务端强制）\n'
              '开启时：所有设备可修改任何会话',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync, size: 20, color: AppColors.brandCyan),
            title: Text(_syncing ? '同步中…' : '手动同步', style: const TextStyle(fontSize: 14)),
            subtitle: Text('最近同步：${_fmtLastSync(_lastSync)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: _syncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 20, color: AppColors.brandCyan),
            onTap: _syncing ? null : _manualSync,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '同步机制：\n'
              '· 首次连接：完整同步包（全量快照）\n'
              '· 之后：时间戳增量（新增/修改消息）+ 列表哈希对比（增删/改名）\n'
              '· 并发冲突：设备优先——最新改动生效，冲突窗口内双方修改均拒绝',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
