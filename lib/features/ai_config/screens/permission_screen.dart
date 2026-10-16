/// 权限管理（0.1.9——19 权限 × 5 模式（含影子）——服务端 permission_list/set）
/// 后台模式已移入 通知与后台
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // 【A4修复】真实 Android 授权

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// 【i18n】改为 getter：文案经 tr() 后需在每次访问时求值（语言切换即时生效）
Map<String, String> get kPermLabels => {
  'location': tr('perm_location'),
  'camera': tr('perm_camera'),
  'record_audio': tr('perm_audio_recording'),
  'record_screen': tr('perm_screen_recording'),
  'accelerometer': tr('perm_accelerometer'),
  'phone_state': tr('perm_phone_state'),
  'installed_apps': tr('perm_installed_apps'),
  'external_storage': tr('perm_external_storage'),
  'network_control': tr('perm_network_control'),
  'bluetooth_control': tr('perm_bluetooth_control'),
  'scan_bluetooth': tr('perm_bluetooth_scan'),
  'launch_app': tr('perm_launch_app'),
  'install_app': tr('perm_install_app'),
  'jump_app': tr('perm_switch_to_app'),
  'background_data': tr('perm_background_data'),
  'background_task': tr('perm_background_tasks'),
  'auto_start': tr('notif_auto_start'),
};

Map<String, String> get kModeLabels => {
  'deny': tr('perm_mode_deny'),
  'allow_once': tr('perm_once'),
  'allow_while': tr('perm_while_in_use'),
  'allow_always': tr('perm_always'),
  'shadow': tr('perm_shadow'),
};

const kModeIcons = {
  'deny': Icons.block,
  'allow_once': Icons.touch_app_outlined,
  'allow_while': Icons.screen_share_outlined,
  'allow_always': Icons.check_circle_outline,
  'shadow': Icons.visibility_off_outlined,
};

// 【A3修复】权限分组（同类可收放 + 类级统一授权）
List<Map<String, Object>> get kPermGroups => [
  {'name': tr('perm_devices'), 'icon': Icons.devices_outlined, 'perms': ['location', 'camera', 'record_audio', 'record_screen', 'accelerometer']},
  {'name': tr('tl_storage'), 'icon': Icons.storage_outlined, 'perms': ['external_storage']},
  {'name': tr('dash_net'), 'icon': Icons.wifi_outlined, 'perms': ['network_control', 'bluetooth_control', 'scan_bluetooth']},
  {'name': tr('notif_background'), 'icon': Icons.hourglass_bottom, 'perms': ['background_data', 'background_task', 'auto_start']},
  {'name': tr('perm_apps'), 'icon': Icons.apps_outlined, 'perms': ['phone_state', 'installed_apps', 'launch_app', 'install_app', 'jump_app']},
  // 【0.2.1 #8-1】智能家居组（ha_control——AI-AGENT#10 权限：默认直接执行，高风险强制确认）
  {'name': tr('nav_home'), 'icon': Icons.home_outlined, 'perms': ['ha_control']},
];

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  List<String> _modes = [];
  Map<String, dynamic> _current = {};
  bool _loading = true;
  String? _error;
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
        final info = resp['data'];
        if (info is Map && info['perms'] is List) {
          setState(() {
            _modes = (info['modes'] as List).map((e) => e.toString()).toList();
            _current = info['current'] is Map
                ? Map<String, dynamic>.from(info['current'] as Map)
                : {};
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
    ref.read(connectionProvider).sendCommand({'cmd': 'permission_list'});
  }

  void _setMode(String perm, String mode) {
    setState(() => _current[perm] = mode);
    ref.read(connectionProvider).sendCommand({'cmd': 'permission_set', 'perm': perm, 'mode': mode});
    // 【A4修复】真实 Android 授权——允许类模式时请求系统权限
    if (mode == 'allow_always' || mode == 'allow_once' || mode == 'allow_while') {
      _requestSystem(perm);
    }
  }

  /// 【A4修复】映射到 Android 权限并真实请求
  /// 【0.2.1 #8-3】授权失败 → 跳系统设置引导（openAppSettings——引导链完整）
  Future<void> _requestSystem(String perm) async {
    final p = _androidPerm(perm);
    if (p == null) return; // 无系统映射（影子/配置类）
    final status = await p.status;
    if (!status.isGranted) {
      final result = await p.request();
      if (!mounted) return;
      if (result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('perm_system_permission_granted')), duration: Duration(seconds: 2)),
        );
        return;
      }
      // 【0.2.1 #8-3】授权失败——跳系统设置引导（openAppSettings）
      final goSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('perm_system_permission_required')),
          content: Text(trp('perm_permission_was_denied_you_can_enable_it', {'p0': '$perm'})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('perm_not_now'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('perm_open_settings'))),
          ],
        ),
      );
      if (goSettings == true && mounted) {
        await openAppSettings();
      }
    }
  }

  Permission? _androidPerm(String perm) {
    switch (perm) {
      case 'location':
        return Permission.location;
      case 'camera':
        return Permission.camera;
      case 'record_audio':
        return Permission.microphone;
      case 'phone_state':
        return Permission.phone;
      case 'external_storage':
        return Permission.storage;
      case 'network_control':
      case 'bluetooth_control':
      case 'scan_bluetooth':
        return Permission.bluetooth;
      default:
        return null; // 无系统映射（加速度计/后台/应用类）
    }
  }

  /// 【A3修复】类级统一授权（同组所有权限设为同一模式）
  void _setGroupMode(List<String> perms, String mode) {
    setState(() {
      for (final p in perms) {
        _current[p] = mode;
      }
    });
    for (final p in perms) {
      ref.read(connectionProvider).sendCommand({'cmd': 'permission_set', 'perm': p, 'mode': mode});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('cfg_permissions')), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.brandRed)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 影子模式说明（防 AI 获取敏感信息）
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        tr('perm_shadow_mode_shadowed_permissions_return'),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 【A3修复】按组分组的权限列表（可收放 + 类级授权）
                    for (final g in kPermGroups)
                      _groupCard(g['name'] as String, g['icon'] as IconData,
                          (g['perms'] as List).map((e) => e.toString()).toList()),
                    const SizedBox(height: 16),
                    Text(
                      tr('perm_token_permission_management_issue_revoke'),
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
    );
  }

  /// 【A3修复】分组卡片（可收放 + 类级统一授权）
  Widget _groupCard(String groupName, IconData icon, List<String> perms) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: AppColors.brandCyan),
        title: Text(groupName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(trp('perm_permissions', {'p0': '${perms.length}'}),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          // 类级统一授权
          Row(
            children: [
              Text(tr('perm_grant_all'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              SizedBox(width: 4),
            ],
          ),
          Row(
            children: [
              _groupAction(tr('perm_allow_all'), 'allow_always', perms, AppColors.brandCyan),
              const SizedBox(width: 8),
              _groupAction(tr('perm_deny_all'), 'deny', perms, AppColors.brandRed),
            ],
          ),
          const SizedBox(height: 8),
          // 类内权限项
          for (final perm in perms)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                kModeIcons[_current[perm]] ?? Icons.tune,
                size: 18,
                color: _current[perm] == 'shadow' ? Colors.orange : AppColors.textSecondary,
              ),
              title: Text(kPermLabels[perm] ?? perm, style: const TextStyle(fontSize: 13)),
              subtitle: Text(_modeDesc(_current[perm]?.toString() ?? 'deny'),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              trailing: DropdownButton<String>(
                value: _current[perm]?.toString() ?? 'deny',
                underline: const SizedBox.shrink(),
                items: _modes
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(kModeLabels[m] ?? m,
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _setMode(perm, v);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _groupAction(String label, String mode, List<String> perms, Color color) {
    return InkWell(
      onTap: () => _setGroupMode(perms, mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color)),
      ),
    );
  }

  String _modeDesc(String mode) {
    switch (mode) {
      case 'deny':
        return tr('perm_access_denied');
      case 'allow_once':
        return tr('perm_ask_every_time');
      case 'allow_while':
        return tr('perm_allow_while_in_use');
      case 'allow_always':
        return tr('chat_always_allow');
      case 'shadow':
        return tr('perm_return_empty_data');
      default:
        return mode;
    }
  }
}
