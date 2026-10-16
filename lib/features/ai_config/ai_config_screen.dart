/// AI 配置主页（先生 2026-09-05 裁决修正：设置从"页内展开"改回"子菜单导航"）
/// 点击分类 → 进入该分类子菜单页（AppBar 显示路径·可逐级返回）——系统设置式层级跳转
/// 每项带图标 + chevron；深层入口（权限/FUI 页）标 [进入]
library;

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';

import '../../core/theme/app_theme.dart';
import '../connect/connect_screen.dart';
import '../memory/memory_screen.dart';
import '../sessions/sessions_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/conn_settings_screen.dart';
import 'screens/server_mode_screen.dart';   // 【0.7.0】服务器模式控制
import 'screens/mcp_screen.dart';
import 'screens/mount_screen.dart';
import 'screens/notif_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/personality_screen.dart';
import 'screens/privilege_screen.dart';
import 'screens/providers_screen.dart';
import 'screens/rootfs_screen.dart';
import 'screens/server_files_screen.dart';
import 'screens/skills_screen.dart';
import 'screens/sync_settings_screen.dart';
import 'screens/token_usage_screen.dart';
import 'screens/upgrade_screen.dart';   // 【第6期】升级屏（update_check 真数据）
import 'screens/plugin_screen.dart';    // 【第6期】插件屏（plugin_list/plugin_reload 真数据）
import '../logs/logs_screen.dart';
import 'screens/about_screen.dart';

/// 分类项
class _CatItem {
  final String label;
  final IconData icon;
  final Widget page;
  const _CatItem(this.label, this.icon, this.page);
}

/// 分类定义
class _Category {
  final String title;
  final IconData icon;
  final List<_CatItem> items;
  const _Category(this.title, this.icon, this.items);
}

/// 【i18n】改为 getter：文案用 tr() 后需在每次 build 求值（语言切换即时生效）
List<_Category> get _categories => [

  _Category(tr('cfg_connection_server'), Icons.settings_ethernet_outlined, [
    _CatItem(tr('cfg_connection_settings'), Icons.link_outlined, const ConnSettingsScreen()),
    _CatItem(tr('cfg_host_authentication'), Icons.dns_outlined, const ConnectScreen()),
    _CatItem(tr('cfg_rootfs_local_sandbox'), Icons.developer_board_outlined, const RootfsScreen()),
    _CatItem(tr('cfg_server_mode'), Icons.dns_outlined, const ServerModeScreen()),   // 【0.7.0】远程开启/停止服务器
  ]),
  _Category(tr('cfg_chat_ai'), Icons.smart_toy_outlined, [
    _CatItem(tr('cfg_model_providers'), Icons.add_circle_outline, const ProvidersScreen()),
    _CatItem(tr('cfg_token_usage'), Icons.data_usage_outlined, const TokenUsageScreen()),
    _CatItem(tr('cfg_personality'), Icons.person_outline, const PersonalityScreen()),
    _CatItem(tr('cfg_skills'), Icons.extension_outlined, const SkillsScreen()),
    _CatItem(tr('cfg_memory'), Icons.psychology_outlined, const MemoryScreen()),
  ]),
  _Category(tr('grp_voice'), Icons.record_voice_over_outlined, [
    _CatItem(tr('cfg_voice_providers_test'), Icons.voice_over_off_outlined, const ProvidersScreen()),
  ]),
  _Category(tr('cfg_notifications_background'), Icons.notifications_active_outlined, [
    _CatItem(tr('cfg_notifications_background'), Icons.notifications_active_outlined, const NotifScreen()),
    _CatItem(tr('cfg_privileges_shizuku'), Icons.security_outlined, const PrivilegeScreen()),
  ]),
  _Category(tr('cfg_appearance_theme'), Icons.palette_outlined, [
    _CatItem(tr('cfg_appearance_preferences'), Icons.palette_outlined, const AppearanceScreen()),
  ]),
  _Category(tr('cfg_sessions_sync'), Icons.sync_outlined, [
    _CatItem(tr('cfg_sync_settings'), Icons.sync_outlined, const SyncSettingsScreen()),
    _CatItem(tr('cfg_session_manager'), Icons.forum_outlined, const SessionsScreen()),
  ]),
  _Category(tr('cfg_privacy_security'), Icons.lock_outline, [
    _CatItem(tr('cfg_permissions'), Icons.admin_panel_settings_outlined, const PermissionScreen()),
    _CatItem(tr('cfg_mount_external_files'), Icons.folder_special_outlined, const MountScreen()),
  ]),
  _Category(tr('cfg_system_logs'), Icons.settings_suggest_outlined, [
    _CatItem(tr('cfg_logs'), Icons.article_outlined, const LogsScreen()),
    _CatItem(tr('cfg_server_files'), Icons.folder_special_outlined, const ServerFilesScreen()),
    const _CatItem('MCP', Icons.dns_outlined, McpScreen()),
    // 【第6期】升级屏/插件屏补齐（原 App 无入口——服务端 update_check/plugin_list 早已存在）
    _CatItem(tr('cfg_upgrade'), Icons.sync_outlined, const UpgradeScreen()),
    _CatItem(tr('cfg_plugins'), Icons.extension_outlined, const PluginScreen()),
  ]),
  _Category(tr('about'), Icons.info_outline, [
    _CatItem(tr('cfg_version_info'), Icons.info_outline, const AboutScreen()),
  ]),
];

class AiConfigScreen extends StatelessWidget {
  const AiConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return ListTile(
            leading: Icon(c.icon, size: 22, color: AppColors.green),
            title: Text(c.title,
                style: const TextStyle(
                    fontFamily: fuiMono,
                    fontSize: 13,
                    color: AppColors.white,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700)),
            subtitle: Text(trp('cfg_items', {'p0': '${c.items.length}'}),
                style: const TextStyle(fontSize: 9, color: AppColors.dim)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => _SubMenuScreen(category: c))),
          );
        },
      ),
    );
  }
}

/// 分类子菜单页（先生要的子菜单导航——进入该分类显示子项，可返回）
class _SubMenuScreen extends StatelessWidget {
  final _Category category;
  const _SubMenuScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 路径标题：设置 / 分类
        title: Text(trp('cfg_settings', {'p0': category.title}),
            style: const TextStyle(fontSize: 15, letterSpacing: 1)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: category.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
        itemBuilder: (context, i) {
          final it = category.items[i];
          return ListTile(
            leading: Icon(it.icon, size: 21, color: AppColors.gray),
            title: Text(it.label,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => it.page)),
          );
        },
      ),
    );
  }
}
