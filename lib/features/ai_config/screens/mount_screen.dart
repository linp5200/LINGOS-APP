/// 挂载外部文件（0.1.9——双来源 + 持久化 + 只读/读写权限）
/// 配置保存 AppStore——沙箱 proot -b 绑定（批次4 沙箱安装器对接）
library;

import 'package:flutter/material.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class MountScreen extends StatefulWidget {
  const MountScreen({super.key});

  @override
  State<MountScreen> createState() => _MountScreenState();
}

class _MountScreenState extends State<MountScreen> {
  final _store = AppStore();
  List<Map<String, dynamic>> _mounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _store.getMounts();
    if (!mounted) return;
    setState(() {
      _mounts = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _MountEditScreen()),
    );
    if (result != null) {
      final list = [..._mounts, result];
      await _store.saveMounts(list);
      _load();
    }
  }

  Future<void> _remove(int index) async {
    final list = [..._mounts]..removeAt(index);
    await _store.saveMounts(list);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('挂载外部文件'),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _add),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mounts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('暂无挂载——点击 + 添加',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mounts.length,
                  itemBuilder: (ctx, i) {
                    final m = _mounts[i];
                    final ro = m['readonly'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(ro ? Icons.lock_outline : Icons.link,
                            size: 20, color: AppColors.brandCyan),
                        title: Text('${m['source']} → ${m['target']}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${ro ? '只读' : '读写'} · ${m['persist'] == true ? '持久化' : '临时'}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _remove(i),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _MountEditScreen extends StatefulWidget {
  const _MountEditScreen();

  @override
  State<_MountEditScreen> createState() => _MountEditScreenState();
}

class _MountEditScreenState extends State<_MountEditScreen> {
  String _sourceType = 'android'; // android / server
  final _sourceCtrl = TextEditingController(text: '/storage/emulated/0/');
  final _targetCtrl = TextEditingController(text: '/mnt/external');
  bool _readonly = false;
  bool _persist = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加挂载')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('来源类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Android 外部存储', style: TextStyle(fontSize: 12)),
                selected: _sourceType == 'android',
                onSelected: (_) => setState(() {
                  _sourceType = 'android';
                  _sourceCtrl.text = '/storage/emulated/0/';
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('服务端 /LINGOS', style: TextStyle(fontSize: 12)),
                selected: _sourceType == 'server',
                onSelected: (_) => setState(() {
                  _sourceType = 'server';
                  _sourceCtrl.text = '/LINGOS/data/shared';
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sourceCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '来源路径',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '挂载到（沙箱内路径）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _readonly,
            onChanged: (v) => setState(() => _readonly = v),
            title: const Text('只读', style: TextStyle(fontSize: 14)),
          ),
          SwitchListTile(
            value: _persist,
            onChanged: (v) => setState(() => _persist = v),
            title: const Text('持久化（沙箱重启自动重挂）', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sourceCtrl.text.trim().isEmpty || _targetCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop({
                      'source': _sourceCtrl.text.trim(),
                      'target': _targetCtrl.text.trim(),
                      'readonly': _readonly,
                      'persist': _persist,
                    }),
            child: const Text('保存'),
          ),
          const SizedBox(height: 12),
          const Text(
            '技术：proot -b 目录绑定（无需 root）——沙箱安装器就绪后自动生效',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
