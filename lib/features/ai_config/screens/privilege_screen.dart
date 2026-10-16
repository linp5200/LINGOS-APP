/// 特权（0.1.9 A5——Shizuku 授权 + AI 经 adb 执行命令）
/// shizuku_api 1.2.2：ShizukuApi().requestPermission/pingBinder/checkPermission/runCommand
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:shizuku_api/shizuku_api.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class PrivilegeScreen extends StatefulWidget {
  const PrivilegeScreen({super.key});

  @override
  State<PrivilegeScreen> createState() => _PrivilegeScreenState();
}

class _PrivilegeScreenState extends State<PrivilegeScreen> {
  final _store = AppStore();
  final _api = ShizukuApi();
  bool? _granted; // null=未检测
  bool _checking = true;
  bool _adbEnabled = false;
  String _lastOutput = '';

  @override
  void initState() {
    super.initState();
    _check();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final a = await _store.getPrefBool('adb_enabled', false);
    if (!mounted) return;
    setState(() => _adbEnabled = a);
  }

  Future<void> _check() async {
    try {
      final granted = await _api.checkPermission() ?? false;
      if (!mounted) return;
      setState(() {
        _granted = granted;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _granted = false;
        _checking = false;
      });
    }
  }

  Future<void> _requestShizuku() async {
    try {
      final ok = await _api.requestPermission() ?? false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? tr('priv_shizuku_authorization_granted') : tr('priv_authorization_cancelled_failed'))),
      );
      _check();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trp('priv_request_failed_make_sure_shizuku_is', {'p0': '$e'}))),
      );
    }
  }

  /// 测试 Shizuku 命令通道
  Future<void> _testAdb() async {
    try {
      if (!(_granted ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('priv_authorize_shizuku_first'))),
        );
        return;
      }
      final out = await _api.runCommand('pm list packages -3 | head -5');
      if (!mounted) return;
      setState(() => _lastOutput = (out == null || out.isEmpty) ? tr('priv_no_output_make_sure_shizuku_is_active') : out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastOutput = trp('priv_execution_failed', {'p0': '$e'}));
    }
  }

  Future<void> _toggleAdb(bool v) async {
    setState(() => _adbEnabled = v);
    await _store.savePrefBool('adb_enabled', v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v ? tr('priv_ai_now_has_an_adb_channel_shizuku') : tr('priv_ai_adb_channel_closed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(tr('priv_privileges'))),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(granted ? Icons.verified : Icons.gpp_maybe,
                              size: 20, color: granted ? Colors.green : AppColors.brandRed),
                          const SizedBox(width: 8),
                          const Text('Shizuku',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(trp('priv_status', {'p0': granted ? tr('priv_granted') : tr('priv_not_granted')}),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      if (!granted) ...[
                        Text(tr('priv_the_shizuku_app_com_moe_shizuku_xyz_must_be'),
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _requestShizuku,
                          icon: const Icon(Icons.gpp_good, size: 18),
                          label: Text(tr('priv_authorize_shizuku')),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _testAdb,
                                icon: const Icon(Icons.terminal, size: 18),
                                label: Text(tr('priv_test_command_channel')),
                              ),
                            ),
                          ],
                        ),
                        if (_lastOutput.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_lastOutput,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _adbEnabled,
                  onChanged: _toggleAdb,
                  title: Text(tr('priv_ai_can_run_commands_via_shizuku'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('priv_once_authorized_the_ai_nook_can_run_adb'),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const Divider(),
                Text(
                  tr('priv_note_n_after_shizuku_authorization_the_app'),
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
    );
  }
}
