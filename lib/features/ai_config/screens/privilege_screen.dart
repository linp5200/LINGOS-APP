/// 特权（0.1.9 A5——Shizuku 授权 + AI 经 adb 执行命令）
/// 需系统已安装 Shizuku（com.moe.shizuku.xyz）+ 已激活
library;

import 'package:flutter/material.dart';
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
  bool _shizukuInstalled = false;
  bool _shizukuGranted = false;
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
      final installed = await Shizuku.isShizukuAvailable();
      final granted = installed ? await Shizuku.isBinderReceived() : false;
      if (!mounted) return;
      setState(() {
        _shizukuInstalled = installed;
        _shizukuGranted = granted;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shizukuInstalled = false;
        _shizukuGranted = false;
        _checking = false;
      });
    }
  }

  Future<void> _requestShizuku() async {
    try {
      await Shizuku.requestPermission();
      _check();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请求失败：$e')),
      );
    }
  }

  /// 测试 adb 通道（Shizuku 执行 pm list 前几行）
  Future<void> _testAdb() async {
    try {
      if (!_shizukuGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先授权 Shizuku')),
        );
        return;
      }
      final result = await Shizuku.exec('pm list packages -3 | head -5');
      if (!mounted) return;
      setState(() => _lastOutput = result ?? '（无输出）');
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastOutput = '执行失败：$e');
    }
  }

  Future<void> _toggleAdb(bool v) async {
    setState(() => _adbEnabled = v);
    await _store.savePrefBool('adb_enabled', v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v ? 'AI 已获 adb 通道（Shizuku）' : 'AI adb 通道已关闭')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('特权')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Shizuku 状态
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
                          Icon(_shizukuGranted
                              ? Icons.verified
                              : Icons.gpp_maybe,
                              size: 20,
                              color: _shizukuGranted ? Colors.green : AppColors.brandRed),
                          const SizedBox(width: 8),
                          Text('Shizuku',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('已安装：${_shizukuInstalled ? '是' : '否'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('已授权：${_shizukuGranted ? '是' : '否'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      if (!_shizukuInstalled)
                        const Text(
                            '未检测到 Shizuku——请安装并激活 Shizuku（com.moe.shizuku.xyz）\n无线调试或 root 均可',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5))
                      else if (!_shizukuGranted)
                        FilledButton.icon(
                          onPressed: _requestShizuku,
                          icon: const Icon(Icons.gpp_good, size: 18),
                          label: const Text('授权 Shizuku'),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _testAdb,
                                icon: const Icon(Icons.terminal, size: 18),
                                label: const Text('测试 adb'),
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
                // AI adb 通道开关
                SwitchListTile(
                  value: _adbEnabled,
                  onChanged: _toggleAdb,
                  title: const Text('AI 可经 adb 执行命令', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('授权后 AI（Nook）可通过 Shizuku 执行 adb 命令（高危命令仍需确认）',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  activeColor: AppColors.brandCyan,
                ),
                const Divider(),
                const Text(
                  '说明：\n'
                  '· Shizuku 授权后，App 获得 adb shell 级权限（pm/am/dumpsys 等）\n'
                  '· AI 调用特权技能时经 Shizuku 执行——高危操作（rm/reboot 等）仍需用户确认\n'
                  '· 授权状态可在系统设置→应用→LINGOS→权限 查看',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
    );
  }
}
