/// 通知与后台（0.1.9——通知开关/渠道 + 后台保活/模式 + 电池优化/自启动引导）
library;

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';

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
      appBar: AppBar(title: Text(tr('cfg_notifications_background'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(tr('notif_notifications')),
                SwitchListTile(
                  value: _alertNotif,
                  onChanged: (v) => _setBool('notif_alert', v, () => _alertNotif = v),
                  title: Text(tr('notif_alert_notifications'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_server_alerts_app_push'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                SwitchListTile(
                  value: _capsule,
                  onChanged: (v) => _setBool('notif_capsule', v, () => _capsule = v),
                  title: Text(tr('notif_dynamic_capsule_focus_notification'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_android_16_persistent_notification_redmi'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                SwitchListTile(
                  value: _taskNotif,
                  onChanged: (v) => _setBool('notif_task', v, () => _taskNotif = v),
                  title: Text(tr('notif_task_notifications'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_let_ai_agents_notify_you_proactively_alert'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const Divider(),
                _section(tr('notif_background')),
                SwitchListTile(
                  value: _keepAlive,
                  onChanged: (v) => _setBool('keep_alive', v, () => _keepAlive = v),
                  title: Text(tr('notif_keep_alive_in_background'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_foreground_service_persistent_notification'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom, size: 20, color: AppColors.textSecondary),
                  title: Text(tr('notif_background_mode'), style: TextStyle(fontSize: 14)),
                  trailing: DropdownButton<String>(
                    value: _bgMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'allow', child: Text(tr('notif_allow_persistent'))),
                      DropdownMenuItem(value: 'allow_minutes', child: Text(tr('notif_timed'))),
                      DropdownMenuItem(value: 'deny', child: Text(tr('notif_deny_disconnect_when_backgrounded'))),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _bgMode = v);
                      await _store.savePrefString('bg_mode', v);
                    },
                  ),
                ),
                const Divider(),
                _section(tr('notif_background_permissions_system_settings')),
                ListTile(
                  leading: const Icon(Icons.battery_charging_full, size: 20, color: AppColors.brandCyan),
                  title: Text(tr('notif_battery_optimization'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_request_ignoring_battery_optimization_key'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  onTap: () => _openBatterySettings(),
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new, size: 20, color: AppColors.brandCyan),
                  title: Text(tr('notif_auto_start'), style: TextStyle(fontSize: 14)),
                  subtitle: Text(tr('notif_vendor_auto_start_permission_miui_needs'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  onTap: () => _openAutoStartSettings(),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('notif_reconnect_exponential_backoff_1s_2s_4s_max'),
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }

  void _openBatterySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('notif_please_allow_ling_os_to_ignore_battery'))),
    );
  }

  void _openAutoStartSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('notif_please_enable_auto_start_for_ling_os_app'))),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
