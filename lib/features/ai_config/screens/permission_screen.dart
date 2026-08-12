/// 权限管理（0.1.9——19 权限 × 5 模式（含影子）——服务端 permission_list/set）
/// 后台模式已移入 通知与后台
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  List<String> _perms = [];
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
            _perms = (info['perms'] as List).map((e) => e.toString()).toList();
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
                    // 权限列表
                    for (final perm in _perms)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            kModeIcons[_current[perm]] ?? Icons.tune,
                            size: 20,
                            color: _current[perm] == 'shadow'
                                ? Colors.orange
                                : AppColors.brandCyan,
                          ),
                          title: Text(kPermLabels[perm] ?? perm,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(_modeDesc(_current[perm]?.toString() ?? 'deny'),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: DropdownButton<String>(
                            value: _current[perm]?.toString() ?? 'deny',
                            underline: const SizedBox.shrink(),
                            items: _modes
                                .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(kModeLabels[m] ?? m,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _setMode(perm, v);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '令牌权限管理（颁发/吊销）——批次4 提供（当前走终端 token 命令）',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
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
