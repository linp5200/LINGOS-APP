/// 服务器模式控制屏（【0.7.0】对接服务端 server mode 功能）
///
/// 服务端能力：
///   · server_mode_status — 查状态（enabled/package/crisis）
///   · server_mode_on     — 开启（持久化——服务端重启后直接进入）
///   · server_mode_stop   — 停止服务器（危机时被服务端拒绝——人身安全让路）
///
/// 说明：stop 是"停止整个服务器"的重操作 → 客户端二次确认。
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class ServerModeScreen extends ConsumerStatefulWidget {
  const ServerModeScreen({super.key});

  @override
  ConsumerState<ServerModeScreen> createState() => _ServerModeScreenState();
}

class _ServerModeScreenState extends ConsumerState<ServerModeScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _package = false;
  bool _crisis = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await ref
        .read(connectionProvider)
        .requestJson({'cmd': 'server_mode_status'}, timeout: const Duration(seconds: 8));
    final data = _extract(resp);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data != null) {
        _enabled = data['enabled'] == true;
        _package = data['package_mode'] == true;
        _crisis = data['crisis_active'] == true;
        _msg = '';
      } else {
        _msg = tr('srvm_host_not_connected_or_query_failed');
      }
    });
  }

  Map<String, dynamic>? _extract(Map<String, dynamic>? resp) {
    try {
      final d = resp?['data'];
      if (d is Map && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      if (d is Map && (d.containsKey('enabled') || d.containsKey('package_mode'))) {
        return Map<String, dynamic>.from(d);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _send(String cmd, {bool confirm = false, String? confirmText}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(confirmText ?? tr('srvm_confirm_action')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('srvm_confirm'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    final resp = await ref
        .read(connectionProvider)
        .requestJson({'cmd': cmd}, timeout: const Duration(seconds: 10));
    String msg = '';
    try {
      final d = resp?['data'];
      if (d is Map) {
        if (d['status'] == 'error') {
          msg = d['msg']?.toString() ?? tr('srvm_operation_failed');
        } else {
          msg = d['msg']?.toString() ?? tr('srvm_sent');
        }
      } else {
        msg = tr('srvm_no_response_not_connected');
      }
    } catch (_) {
      msg = tr('srvm_no_response_not_connected');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = msg;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(tr('cfg_server_mode')),
        backgroundColor: AppColors.surface,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_crisis)
                  Card(
                    color: Color(0xFF3A0A0A),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(tr('srvm_crisis_in_progress_stopping_the_server_is'),
                          style: TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
                    ),
                  ),
                Card(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(tr('srvm_mode_status'), style: TextStyle(fontSize: 14)),
                        trailing: Text(
                          _enabled ? tr('srvm_enabled') : tr('close'),
                          style: TextStyle(
                            color: _enabled ? AppColors.brandGreen : AppColors.dim,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_package)
                        ListTile(
                          dense: true,
                          title: Text(tr('srvm_server_mode_package'), style: TextStyle(fontSize: 12)),
                          trailing: Text(tr('srvm_normal_stop_has_no_effect'), style: TextStyle(fontSize: 11, color: AppColors.brandAmber)),
                        ),
                      const Divider(height: 1, color: AppColors.divider),
                      ListTile(
                        dense: true,
                        title: Text(
                          tr('srvm_server_mode_logs_only_no_input_accepted'),
                          style: TextStyle(fontSize: 11, color: AppColors.dim),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _enabled ? null : () => _send('server_mode_on'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(tr('srvm_enable_server_mode_persistent')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _crisis
                      ? null
                      : () => _send('server_mode_stop',
                          confirm: true, confirmText: tr('srvm_stop_the_entire_server_n_all_server')),
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.brandRed),
                  label: Text(tr('srvm_stop_server_the_only_exit'),
                      style: TextStyle(color: AppColors.brandRed)),
                ),
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.brandAmber)),
                ],
                const SizedBox(height: 18),
                Text(
                  tr('srvm_note_the_server_side_server_mode_on_also'),
                  style: TextStyle(fontSize: 11, color: AppColors.dim),
                ),
              ],
            ),
    );
  }
}
