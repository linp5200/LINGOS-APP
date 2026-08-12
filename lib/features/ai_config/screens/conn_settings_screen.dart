/// 连接与设置（0.1.9——原设置页迁移定案）
/// #主机：主机IP（纯显示）/ 连接密钥 / 连接状态 / 连接方式 / 加密
/// #应用日志：日志
/// 退出登录：本页底部（红色）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/connection/connection_mode.dart';
import '../../connect/connect_screen.dart';
import '../../logs/logs_screen.dart';

class ConnSettingsScreen extends ConsumerStatefulWidget {
  const ConnSettingsScreen({super.key});

  @override
  ConsumerState<ConnSettingsScreen> createState() => _ConnSettingsScreenState();
}

class _ConnSettingsScreenState extends ConsumerState<ConnSettingsScreen> {
  final _store = AppStore();
  String? _token;
  String? _host;
  int? _port;
  bool _allowPlaintext = false;
  String _connectionModeId = 'native';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _store.getToken();
    final host = await _store.getHost();
    final port = await _store.getPort();
    final plain = await _store.getAllowPlaintext();
    final mode = await _store.getConnectionModeId();
    if (!mounted) return;
    setState(() {
      _token = token;
      _host = host;
      _port = port;
      _allowPlaintext = plain;
      _connectionModeId = mode;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('将清除本地 token 并吊销服务端会话，需重新认证。确认退出？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(connectionProvider).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(connectionProvider);
    final connected = mgr.state == ConnState.authenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('连接与设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('主机'),
                // 【定案】主机IP 纯显示——不允许点击
                ListTile(
                  leading: const Icon(Icons.dns_outlined, size: 20),
                  title: const Text('主机IP'),
                  subtitle: Text('$_host${_port != null ? ':$_port' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key, size: 20),
                  title: const Text('连接密钥'),
                  subtitle: Text(
                      _token != null && _token!.isNotEmpty
                          ? '${_token!.substring(0, _token!.length > 8 ? 8 : _token!.length)}...'
                          : '未认证',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
                ListTile(
                  leading: Icon(Icons.circle,
                      size: 14, color: connected ? Colors.green : AppColors.brandRed),
                  title: const Text('连接状态'),
                  subtitle: Text(mgr.state.name,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
                // 【定案】连接方式（原 APP 设定）
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
                        .map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.label)))
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
                  child: Text(ConnectionMode.fromId(_connectionModeId).description,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                // 【定案】加密（原 APP 设定——默认 wss）
                SwitchListTile(
                  value: _allowPlaintext,
                  onChanged: (v) async {
                    setState(() => _allowPlaintext = v);
                    await _store.saveAllowPlaintext(v);
                  },
                  title: const Text('加密'),
                  subtitle: const Text(
                    '加密模式默认（wss://）——本地服务端无 TLS 时需开启明文（ws://）',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const Divider(),
                _section('应用日志'),
                ListTile(
                  leading: const Icon(Icons.article_outlined, size: 20),
                  title: const Text('日志'),
                  subtitle: const Text('连接/WS/命令全链路日志——查看与导出',
                      style: TextStyle(color: AppColors.textSecondary)),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LogsScreen())),
                ),
                const Divider(),
                const SizedBox(height: 8),
                // 【定案】退出登录——本页底部（红色）
                ListTile(
                  leading: const Icon(Icons.logout, size: 20, color: AppColors.brandRed),
                  title: const Text('退出登录', style: TextStyle(color: AppColors.brandRed)),
                  subtitle: const Text('清除 token（加密存储）+ 吊销 + 设备解绑',
                      style: TextStyle(color: AppColors.textSecondary)),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
