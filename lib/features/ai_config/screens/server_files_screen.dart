/// 管理服务端文件（0.1.9——/LINGOS 九大目录结构化导航 + 查看/下载）
/// 定案：仅查看/下载——编辑走浏览文件；不内置备份
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

const kSystemDirs = [
  {'path': '/LINGOS/system/config', 'name': '系统配置', 'icon': Icons.settings_outlined, 'desc': 'ai_config / security / 权限规则'},
  {'path': '/LINGOS/skills', 'name': '技能', 'icon': Icons.extension_outlined, 'desc': '内置 / 自定义 / 商店技能'},
  {'path': '/LINGOS/data', 'name': '数据', 'icon': Icons.storage_outlined, 'desc': 'AI记忆 / 日志 / 共享 / 会话'},
  {'path': '/LINGOS/Debug', 'name': '日志', 'icon': Icons.article_outlined, 'desc': 'lingos_*.log / error_*.log'},
  {'path': '/LINGOS/state', 'name': '状态', 'icon': Icons.memory, 'desc': 'tokens.json / components / usage'},
  {'path': '/LINGOS/registry', 'name': '注册表', 'icon': Icons.dns_outlined, 'desc': '技能索引 / 注册数据'},
  {'path': '/LINGOS/bin', 'name': '二进制', 'icon': Icons.code, 'desc': 'lingos_linux / lingosd / Python'},
  {'path': '/LINGOS/apps', 'name': '应用', 'icon': Icons.apps_outlined, 'desc': '已安装应用'},
  {'path': '/LINGOS/plugins', 'name': '插件', 'icon': Icons.extension, 'desc': '预警 / 功能插件'},
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
      SnackBar(content: Text('查看 $path——完整阅读请用"浏览文件"页')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath == '/LINGOS' ? '管理服务端文件' : _currentPath),
      ),
      body: _currentPath == '/LINGOS'
          // 根视图：九大目录卡片
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('LINGOS 系统目录', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                for (final d in kSystemDirs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(d['icon'] as IconData, size: 22, color: AppColors.brandCyan),
                      title: Text('${d['name']}（${d['path']}）', style: const TextStyle(fontSize: 14)),
                      subtitle: Text(d['desc'] as String,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                      onTap: () => _list(d['path'] as String),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('仅查看/下载——编辑请用"浏览文件"页；备份走服务端 backup 命令',
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
                              title: const Text('返回上级', style: TextStyle(fontSize: 14)),
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
