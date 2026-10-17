/// 挂载外部文件（0.1.9——双来源 + 持久化 + 只读/读写权限）
/// 配置保存 AppStore——沙箱 proot -b 绑定（批次4 沙箱安装器对接）
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';

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
        title: Text(tr('cfg_mount_external_files')),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _add),
        ],
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator())
          : _mounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.link_off, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(tr('mnt_no_mounts_tap_to_add'),
                          style:  TextStyle(color: AppColors.textSecondary)),
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
                            style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
      appBar: AppBar(title: Text(tr('mnt_add_mount'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('mnt_source_type'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: Text(tr('mnt_android_external_storage'), style: const TextStyle(fontSize: 12)),
                selected: _sourceType == 'android',
                onSelected: (_) => setState(() {
                  _sourceType = 'android';
                  _sourceCtrl.text = '/storage/emulated/0/';
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tr('mnt_server_lingos'), style: const TextStyle(fontSize: 12)),
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
            decoration: InputDecoration(
              labelText: tr('mnt_source_path'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('mnt_mount_at_path_inside_the_sandbox'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _readonly,
            onChanged: (v) => setState(() => _readonly = v),
            title: Text(tr('mnt_read_only'), style: const TextStyle(fontSize: 14)),
          ),
          SwitchListTile(
            value: _persist,
            onChanged: (v) => setState(() => _persist = v),
            title: Text(tr('mnt_persistent_remount_on_sandbox_restart'), style: const TextStyle(fontSize: 14)),
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
            child: Text(tr('save')),
          ),
          const SizedBox(height: 12),
          Text(
            tr('mnt_technical_proot_b_directory_binding_no_root'),
            style:  TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
