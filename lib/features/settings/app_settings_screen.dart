/// APP 设定（子菜单——明文传输开关——默认加密）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connection/connection_mode.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  final _store = AppStore();
  bool _allowPlaintext = false;
  String _connectionModeId = 'native';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _store.getAllowPlaintext();
    final m = await _store.getConnectionModeId();
    if (!mounted) return;
    setState(() {
      _allowPlaintext = v;
      _connectionModeId = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APP 设定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _allowPlaintext,
                  onChanged: (v) async {
                    setState(() => _allowPlaintext = v);
                    await _store.saveAllowPlaintext(v);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('明文传输开关已更新')),
                    );
                  },
                  title: const Text('允许明文传输'),
                  subtitle: const Text(
                    '加密模式默认（wss://）——本地服务端无 TLS 时需开启明文（ws://）',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const Divider(),
                // 【先生要求】一行下拉（节省空间——可展开）
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _connectionModeId,
                    decoration: const InputDecoration(
                      labelText: '连接方式',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ConnectionMode.values
                        .map((m) => DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(m.label),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _connectionModeId = v);
                      await _store.saveConnectionMode(v);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    ConnectionMode.fromId(_connectionModeId).description,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '安全说明：明文传输（ws://）不加密——仅用于本地/信任网络。默认关闭（加密优先——隐私保护原则）。',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }
}
