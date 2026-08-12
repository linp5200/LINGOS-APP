/// 文件浏览器（协议 v3——file_list/read/write/delete + 目录导航）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  String _path = '/';
  List<Map<String, dynamic>> _entries = [];
  bool _loading = false;
  StreamSubscription? _sub;
  final List<String> _history = [];
  String? _pendingViewPath; // 【0.1.9】待查看的文件（响应含 content）

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _list('/');
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
        // 【0.1.9】文件查看响应（含 content）——弹窗显示
        if (_pendingViewPath != null) {
          final content = resp['data'] is Map
              ? (resp['data'] as Map)['content']?.toString()
              : resp['content']?.toString();
          if (content != null) {
            final path = _pendingViewPath!;
            _pendingViewPath = null;
            if (mounted) _showContent(path, content);
          }
          return;
        }
        final list = resp['data'];
        if (list is List) {
          setState(() {
            _entries = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  /// 【0.1.9】文本内容查看弹窗
  void _showContent(String path, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(path, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: SingleChildScrollView(
            child: SelectableText(content,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary, height: 1.5, fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _list(String path) {
    _path = path;
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'file_list', 'path': path});
  }

  void _enter(String name) {
    _history.add(_path);
    final next = _path == '/' ? '/$name' : '$_path/$name';
    _list(next);
  }

  void _back() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    _list(prev);
  }

  void _delete(String name) async {
    final path = _path == '/' ? '/$name' : '$_path/$name';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确认删除 $name？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(connectionProvider).sendCommand({'cmd': 'file_delete', 'path': path});
      _list(_path);
    }
  }

  /// 【0.1.9】查看文本文件内容（command_response 含 content）
  void _view(String name) {
    final path = _path == '/' ? '/$name' : '$_path/$name';
    ref.read(connectionProvider).sendCommand({'cmd': 'file_read', 'path': path});
    _pendingViewPath = path;
  }

  /// 【0.1.9】重命名（file_move 命令）
  void _rename(String name) async {
    final ctrl = TextEditingController(text: name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '新文件名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && ctrl.text.trim() != name) {
      final src = _path == '/' ? '/$name' : '$_path/$name';
      final dst = _path == '/' ? '/${ctrl.text.trim()}' : '$_path/${ctrl.text.trim()}';
      ref.read(connectionProvider).sendCommand({'cmd': 'file_move', 'src': src, 'dst': dst});
      _list(_path);
    }
  }

  void _createFile() async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: '文件名')),
            const SizedBox(height: 8),
            TextField(controller: contentCtrl, decoration: const InputDecoration(hintText: '内容'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.isNotEmpty) {
      final path = _path == '/' ? '/${nameCtrl.text}' : '$_path/${nameCtrl.text}';
      ref.read(connectionProvider).sendCommand({'cmd': 'file_write', 'path': path, 'content': contentCtrl.text});
      _list(_path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_path, style: const TextStyle(fontSize: 15)),
        leading: _history.isEmpty ? null : IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: _back),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder_outlined, size: 20), onPressed: _createFile),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => _list(_path)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                final name = e['name']?.toString() ?? '';
                final isDir = e['type']?.toString() == 'dir';
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file_outlined,
                      size: 20, color: isDir ? AppColors.brandCyan : AppColors.textSecondary),
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  subtitle: isDir ? null : Text(_fmtSize(e['size']?.toString() ?? '0'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: isDir
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16),
                                onPressed: () => _view(name)),
                            IconButton(
                                icon: const Icon(Icons.drive_file_rename_outline, size: 16),
                                onPressed: () => _rename(name)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _delete(name)),
                          ],
                        ),
                  onTap: isDir ? () => _enter(name) : () => _view(name),
                );
              },
            ),
    );
  }

  String _fmtSize(String s) {
    final n = int.tryParse(s) ?? 0;
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1024 * 1024 * 1024) return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
