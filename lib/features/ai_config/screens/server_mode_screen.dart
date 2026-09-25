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
        _msg = '未连接主机或查询失败';
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
          title: Text(confirmText ?? '确认操作？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
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
          msg = d['msg']?.toString() ?? '操作失败';
        } else {
          msg = d['msg']?.toString() ?? '已发送';
        }
      } else {
        msg = '无响应（未连接？）';
      }
    } catch (_) {
      msg = '无响应（未连接？）';
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
        title: const Text('服务器模式'),
        backgroundColor: AppColors.surface,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_crisis)
                  const Card(
                    color: Color(0xFF3A0A0A),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('🚨 危机进行中——停止服务器被禁用（人身安全让路）',
                          style: TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
                    ),
                  ),
                Card(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('模式状态', style: TextStyle(fontSize: 14)),
                        trailing: Text(
                          _enabled ? '已开启' : '关闭',
                          style: TextStyle(
                            color: _enabled ? AppColors.brandGreen : AppColors.dim,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_package)
                        const ListTile(
                          dense: true,
                          title: Text('服务器模式包', style: TextStyle(fontSize: 12)),
                          trailing: Text('常规关闭无效', style: TextStyle(fontSize: 11, color: AppColors.brandAmber)),
                        ),
                      const Divider(height: 1, color: AppColors.divider),
                      const ListTile(
                        dense: true,
                        title: Text(
                          '服务器模式 = 只显示日志、不接受输入（控制键 Ctrl-Q/Q）。'
                          '开启后服务端重启仍保持该模式。',
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
                  label: const Text('开启服务器模式（持久化）'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _crisis
                      ? null
                      : () => _send('server_mode_stop',
                          confirm: true, confirmText: '停止整个服务器？\n（服务端所有服务将优雅退出）'),
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.brandRed),
                  label: const Text('停止服务器（唯一停止出口）',
                      style: TextStyle(color: AppColors.brandRed)),
                ),
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.brandAmber)),
                ],
                const SizedBox(height: 18),
                const Text(
                  '提示：服务端「server mode on」也会在自己终端进入日志模式；'
                  '本页操作经 WS 命令通道，与终端等效。',
                  style: TextStyle(fontSize: 11, color: AppColors.dim),
                ),
              ],
            ),
    );
  }
}
