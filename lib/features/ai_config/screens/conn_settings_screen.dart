/// 连接与设置（0.1.9——原设置页迁移定案）
/// #主机：主机IP（纯显示）/ 连接密钥 / 连接状态 / 连接方式 / 加密
/// #应用日志：日志
/// 退出登录：本页底部（红色）
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/connection/connection_mode.dart';
import '../../connect/connect_screen.dart';

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
  // 【0.2.0】语音设置
  bool _voiceProxy = true;
  bool _autoRead = false;
  bool _continuousChat = false;

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
    final voiceProxy = await _store.getVoiceProxy();
    final autoRead = await _store.getAutoRead();
    final continuousChat = await _store.getContinuousChat();
    if (!mounted) return;
    setState(() {
      _token = token;
      _host = host;
      _port = port;
      _allowPlaintext = plain;
      _connectionModeId = mode;
      _voiceProxy = voiceProxy;
      _autoRead = autoRead;
      _continuousChat = continuousChat;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('cset_log_out')),
        content: Text(tr('cset_this_clears_the_local_token_and_revokes_the')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('cset_exit'))),
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
      appBar: AppBar(title: Text(tr('cset_connection_settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(tr('home_host')),
                // 【定案】主机IP 纯显示——不允许点击
                ListTile(
                  leading: const Icon(Icons.dns_outlined, size: 20),
                  title: Text(tr('cset_host_ip')),
                  subtitle: Text('$_host${_port != null ? ':$_port' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key, size: 20),
                  title: Text(tr('cset_connection_key')),
                  subtitle: Text(
                      _token != null && _token!.isNotEmpty
                          ? '${_token!.substring(0, _token!.length > 8 ? 8 : _token!.length)}...'
                          : tr('cset_not_authenticated'),
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
                ListTile(
                  leading: Icon(Icons.circle,
                      size: 14, color: connected ? Colors.green : AppColors.brandRed),
                  title: Text(tr('cset_connection_status')),
                  subtitle: Text(mgr.state.name,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
                // 【定案】连接方式（原 APP 设定）
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _connectionModeId,
                    decoration: InputDecoration(
                      labelText: tr('cset_connection_mode'),
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
                  title: Text(tr('conn_encrypted')),
                  subtitle: Text(
                    tr('cset_encrypted_by_default_wss_enable_plaintext'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                // 【0.2.0】音频提供商使用服务端代理（先生决策：本地直连/代理可选）
                SwitchListTile(
                  value: _voiceProxy,
                  onChanged: (v) async {
                    setState(() => _voiceProxy = v);
                    await _store.saveVoiceProxy(v);
                  },
                  title: Text(tr('cset_audio_providers_via_server_proxy')),
                  subtitle: Text(
                    tr('cset_on_speech_synthesized_recognized_on_the'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                // 【0.2.0】自动朗读（默认关——先生决策）
                SwitchListTile(
                  value: _autoRead,
                  onChanged: (v) async {
                    setState(() => _autoRead = v);
                    await _store.saveAutoRead(v);
                  },
                  title: Text(tr('cset_auto_read_aloud')),
                  subtitle: Text(
                    tr('cset_read_ai_replies_aloud_automatically_off_by'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                // 【0.2.0】连续对话（家居等情景默认开——先生决策）
                SwitchListTile(
                  value: _continuousChat,
                  onChanged: (v) async {
                    setState(() => _continuousChat = v);
                    await _store.saveContinuousChat(v);
                  },
                  title: Text(tr('cset_continuous_chat')),
                  subtitle: Text(
                    tr('cset_continuous_chat_by_default_in_home_voice'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                // 【定案】退出登录——本页底部（红色）
                ListTile(
                  leading: const Icon(Icons.logout, size: 20, color: AppColors.brandRed),
                  title: Text(tr('cset_log_out'), style: TextStyle(color: AppColors.brandRed)),
                  subtitle: Text(tr('cset_clear_token_encrypted_revoke_unbind_device'),
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
