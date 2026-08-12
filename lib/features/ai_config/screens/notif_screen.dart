/// 通知与后台（0.1.9——通知开关/渠道 + 后台保活/模式 + 电池优化/自启动引导）
library;

import 'package:flutter/material.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class NotifScreen extends StatefulWidget {
  const NotifScreen({super.key});

  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  final _store = AppStore();
  bool _alertNotif = true;
  bool _capsule = true; // 灵动胶囊
  bool _taskNotif = true; // 任务通知（AI 主动）
  bool _keepAlive = false; // 后台保活
  String _bgMode = 'deny';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await _store.getPrefBool('notif_alert', true);
    final c = await _store.getPrefBool('notif_capsule', true);
    final t = await _store.getPrefBool('notif_task', true);
    final k = await _store.getPrefBool('keep_alive', false);
    final b = await _store.getPrefString('bg_mode', 'deny');
    if (!mounted) return;
    setState(() {
      _alertNotif = a;
      _capsule = c;
      _taskNotif = t;
      _keepAlive = k;
      _bgMode = b;
      _loading = false;
    });
  }

  Future<void> _setBool(String key, bool v, void Function() update) async {
    setState(update);
    await _store.savePrefBool(key, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知与后台')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('通知'),
                SwitchListTile(
                  value: _alertNotif,
                  onChanged: (v) => _setBool('notif_alert', v, () => _alertNotif = v),
                  title: const Text('预警通知', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('服务端预警 → App 推送', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  activeThumbColor: AppColors.brandCyan,
                ),
                SwitchListTile(
                  value: _capsule,
                  onChanged: (v) => _setBool('notif_capsule', v, () => _capsule = v),
                  title: const Text('灵动胶囊 / 焦点通知', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('安卓16+ 常驻通知呈现（Redmi HyperOS）', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  activeThumbColor: AppColors.brandCyan,
                ),
                SwitchListTile(
                  value: _taskNotif,
                  onChanged: (v) => _setBool('notif_task', v, () => _taskNotif = v),
                  title: const Text('任务通知', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('允许 AI / agent 主动通知你 + 预警联动', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  activeThumbColor: AppColors.brandCyan,
                ),
                const Divider(),
                _section('后台'),
                SwitchListTile(
                  value: _keepAlive,
                  onChanged: (v) => _setBool('keep_alive', v, () => _keepAlive = v),
                  title: const Text('后台保活', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('前台服务 + 常驻通知——保持 WS 连接', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  activeThumbColor: AppColors.brandCyan,
                ),
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom, size: 20, color: AppColors.textSecondary),
                  title: const Text('后台模式', style: TextStyle(fontSize: 14)),
                  trailing: DropdownButton<String>(
                    value: _bgMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'allow', child: Text('允许（常驻）')),
                      DropdownMenuItem(value: 'allow_minutes', child: Text('限时')),
                      DropdownMenuItem(value: 'deny', child: Text('拒绝（退后台即断）')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _bgMode = v);
                      await _store.savePrefString('bg_mode', v);
                    },
                  ),
                ),
                const Divider(),
                _section('后台权限（跳系统设置）'),
                ListTile(
                  leading: const Icon(Icons.battery_charging_full, size: 20, color: AppColors.brandCyan),
                  title: const Text('电池优化', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('请求忽略电池优化——保活关键', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  onTap: () => _openBatterySettings(),
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new, size: 20, color: AppColors.brandCyan),
                  title: const Text('自启动', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('厂商自启动权限（MIUI 需引导设置）', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  onTap: () => _openAutoStartSettings(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '断线重连：指数退避 1s/2s/4s...上限30s（协议 v3 已定义）',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }

  void _openBatterySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在系统设置中允许 LING OS 忽略电池优化（省电策略→无限制）')),
    );
  }

  void _openAutoStartSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在系统设置中开启 LING OS 自启动权限（应用管理→自启动）')),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
