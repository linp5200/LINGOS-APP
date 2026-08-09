/// 设置页（连接信息/token/主题/会话）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _store = AppStore();
  String? _token;
  String? _host;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _store.getToken();
    final host = await _store.getHost();
    final sid = await _store.getSessionId();
    setState(() {
      _token = token;
      _host = host;
      _sessionId = sid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(connectionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('连接'),
          ListTile(
            leading: const Icon(Icons.dns_outlined, size: 20),
            title: const Text('主机'),
            subtitle: Text(_host ?? '未保存', style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key, size: 20),
            title: const Text('Token'),
            subtitle: Text(_token != null ? '${_token!.substring(0, _token!.length > 8 ? 8 : _token!.length)}...' : '未认证',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, size: 20),
            title: const Text('当前会话'),
            subtitle: Text(_sessionId ?? 'default', style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: Icon(Icons.circle, size: 14, color: mgr.state == ConnState.authenticated ? Colors.green : AppColors.brandRed),
            title: const Text('连接状态'),
            subtitle: Text(mgr.state.name, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const Divider(),
          _section('操作'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, size: 20),
            title: const Text('清除本地数据'),
            subtitle: const Text('Token/主机/会话记录', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () async {
              await _store.clear();
              await _load();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除')));
            },
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
