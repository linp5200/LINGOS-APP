/// 权限管理（0.1.9——19 权限 × 5 模式（含影子）——服务端 permission_list/set）
/// 后台模式已移入 通知与后台
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // 【A4修复】真实 Android 授权

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

const kPermLabels = {
  'location': '定位',
  'camera': '相机',
  'record_audio': '录音',
  'record_screen': '录屏',
  'accelerometer': '加速度计',
  'phone_state': '电话状态',
  'installed_apps': '已装应用',
  'external_storage': '外部存储',
  'network_control': '网络控制',
  'bluetooth_control': '蓝牙控制',
  'scan_bluetooth': '扫描蓝牙',
  'launch_app': '启动App',
  'install_app': '安装App',
  'jump_app': '跳转App',
  'background_data': '后台数据',
  'background_task': '后台任务',
  'auto_start': '自启动',
};

const kModeLabels = {
  'deny': '拒绝',
  'allow_once': '单次',
  'allow_while': '使用中',
  'allow_always': '始终',
  'shadow': '影子',
};

const kModeIcons = {
  'deny': Icons.block,
  'allow_once': Icons.touch_app_outlined,
  'allow_while': Icons.screen_share_outlined,
  'allow_always': Icons.check_circle_outline,
  'shadow': Icons.visibility_off_outlined,
};

// 【A3修复】权限分组（同类可收放 + 类级统一授权）
const kPermGroups = [
  {'name': '设备', 'icon': Icons.devices_outlined, 'perms': ['location', 'camera', 'record_audio', 'record_screen', 'accelerometer']},
  {'name': '存储', 'icon': Icons.storage_outlined, 'perms': ['external_storage']},
  {'name': '网络', 'icon': Icons.wifi_outlined, 'perms': ['network_control', 'bluetooth_control', 'scan_bluetooth']},
  {'name': '后台', 'icon': Icons.hourglass_bottom, 'perms': ['background_data', 'background_task', 'auto_start']},
  {'name': '应用', 'icon': Icons.apps_outlined, 'perms': ['phone_state', 'installed_apps', 'launch_app', 'install_app', 'jump_app']},
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
  Future<void> _requestSystem(String perm) async {
    final p = _androidPerm(perm);
    if (p == null) return; // 无系统映射（影子/配置类）
    final status = await p.status;
    if (!status.isGranted) {
      final result = await p.request();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$perm：${result.isGranted ? '系统授权成功' : '系统授权被拒绝'}\n'
            '（应用内模式已设置——系统授权在设置→应用→权限可改）',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
      appBar: AppBar(title: const Text('权限管理'), actions: [
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
                      child: const Text(
                        '影子模式：被影子化的权限返回空数据——防止 AI 获取敏感信息（隐私保护）',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 【A3修复】按组分组的权限列表（可收放 + 类级授权）
                    for (final g in kPermGroups)
                      _groupCard(g['name'] as String, g['icon'] as IconData,
                          (g['perms'] as List).map((e) => e.toString()).toList()),
                    const SizedBox(height: 16),
                    const Text(
                      '令牌权限管理（颁发/吊销）——批次4 提供（当前走终端 token 命令）',
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
        subtitle: Text('${perms.length} 项权限',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          // 类级统一授权
          Row(
            children: [
              Text('统一授权：', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              _groupAction('全部允许', 'allow_always', perms, AppColors.brandCyan),
              const SizedBox(width: 8),
              _groupAction('全部拒绝', 'deny', perms, AppColors.brandRed),
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
        return '拒绝访问';
      case 'allow_once':
        return '每次询问';
      case 'allow_while':
        return '使用期间允许';
      case 'allow_always':
        return '始终允许';
      case 'shadow':
        return '返回空数据';
      default:
        return mode;
    }
  }
}
