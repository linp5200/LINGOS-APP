/// 管理服务端文件（0.1.9——/LINGOS 九大目录结构化导航 + 查看/下载）
/// 定案：仅查看/下载——编辑走浏览文件；不内置备份
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// 【i18n】改为 getter：目录名/说明经 tr() 后需在每次访问时求值
List<Map<String, Object>> get kSystemDirs => [
  {'path': '/LINGOS/system/config', 'name': tr('srvf_system_config'), 'icon': Icons.settings_outlined, 'desc': tr('srvf_ai_config_security_permission_rules')},
  {'path': '/LINGOS/skills', 'name': tr('cfg_skills'), 'icon': Icons.extension_outlined, 'desc': tr('srvf_built_in_custom_store_skills')},
  {'path': '/LINGOS/data', 'name': tr('grp_data'), 'icon': Icons.storage_outlined, 'desc': tr('srvf_ai_memory_logs_shared_sessions')},
  {'path': '/LINGOS/Debug', 'name': tr('cfg_logs'), 'icon': Icons.article_outlined, 'desc': 'lingos_*.log / error_*.log'},
  {'path': '/LINGOS/state', 'name': tr('dash_status'), 'icon': Icons.memory, 'desc': 'tokens.json / components / usage'},
  {'path': '/LINGOS/registry', 'name': tr('srvf_registry'), 'icon': Icons.dns_outlined, 'desc': tr('srvf_skill_index_registry_data')},
  {'path': '/LINGOS/bin', 'name': tr('srvf_binaries'), 'icon': Icons.code, 'desc': 'lingos_linux / lingosd / Python'},
  {'path': '/LINGOS/apps', 'name': tr('perm_apps'), 'icon': Icons.apps_outlined, 'desc': tr('srvf_installed_apps')},
  {'path': '/LINGOS/plugins', 'name': tr('srvf_plugins'), 'icon': Icons.extension, 'desc': tr('srvf_alert_feature_plugins')},
];

class ServerFilesScreen extends ConsumerStatefulWidget {
  const ServerFilesScreen({super.key});

  @override
  ConsumerState<ServerFilesScreen> createState() => _ServerFilesScreenState();
}

class _ServerFilesScreenState extends ConsumerState<ServerFilesScreen> {
  List<Map<String, dynamic>> _files = [];
  String _currentPath = '/LINGOS';
  bool _loading = false;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
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
            _files = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  void _list(String path) {
    setState(() {
      _currentPath = path;
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'file_list', 'path': path});
  }

  void _view(String path) {
    ref.read(connectionProvider).sendCommand({'cmd': 'file_read', 'path': path});
    // file_read 响应经 command_response 返回——简化：提示用浏览文件页
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trp('srvf_viewing_use_the_browse_files_page_for_full', {'p0': '$path'}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath == '/LINGOS' ? tr('cfg_server_files') : _currentPath),
      ),
      body: _currentPath == '/LINGOS'
          // 根视图：九大目录卡片
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(tr('srvf_lingos_system_directories'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                for (final d in kSystemDirs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(d['icon'] as IconData, size: 22, color: AppColors.brandCyan),
                      title: Text(
                          trp('srvf_dir_title',
                              {'p0': '${d['name']}', 'p1': '${d['path']}'}),
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(d['desc'] as String,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                      onTap: () => _list(d['path'] as String),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(tr('srvf_view_download_only_edit_on_the_browse_files'),
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            )
          // 目录内文件列表
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.brandRed)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 返回上级
                        if (_currentPath != '/LINGOS')
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.arrow_upward, size: 20),
                              title: Text(tr('srvf_go_up'), style: TextStyle(fontSize: 14)),
                              onTap: () {
                                final idx = _currentPath.lastIndexOf('/');
                                _list(idx > 0 ? _currentPath.substring(0, idx) : '/LINGOS');
                              },
                            ),
                          ),
                        for (final f in _files)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                f['is_dir'] == true || f['type'] == 'dir'
                                    ? Icons.folder_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              title: Text(f['name']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13)),
                              trailing: f['is_dir'] == true || f['type'] == 'dir'
                                  ? const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary)
                                  : IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 16),
                                      onPressed: () => _view('$_currentPath/${f['name']}'),
                                    ),
                              onTap: (f['is_dir'] == true || f['type'] == 'dir')
                                  ? () => _list('$_currentPath/${f['name']}')
                                  : () => _view('$_currentPath/${f['name']}'),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
