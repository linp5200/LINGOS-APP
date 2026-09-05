/// AI 配置主页（先生 2026-09-05 裁决修正：设置从"页内展开"改回"子菜单导航"）
/// 点击分类 → 进入该分类子菜单页（AppBar 显示路径·可逐级返回）——系统设置式层级跳转
/// 每项带图标 + chevron；深层入口（权限/FUI 页）标 [进入]
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../connect/connect_screen.dart';
import '../memory/memory_screen.dart';
import '../sessions/sessions_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/conn_settings_screen.dart';
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

const List<_Category> _categories = [
  _Category('连接与服务器', Icons.settings_ethernet_outlined, [
    _CatItem('连接设置', Icons.link_outlined, ConnSettingsScreen()),
    _CatItem('主机（认证）', Icons.dns_outlined, ConnectScreen()),
    _CatItem('Rootfs 本地沙箱', Icons.developer_board_outlined, RootfsScreen()),
  ]),
  _Category('对话与 AI', Icons.smart_toy_outlined, [
    _CatItem('模型提供商', Icons.add_circle_outline, ProvidersScreen()),
    _CatItem('Token 用量', Icons.data_usage_outlined, TokenUsageScreen()),
    _CatItem('人格', Icons.person_outline, PersonalityScreen()),
    _CatItem('技能', Icons.extension_outlined, SkillsScreen()),
    _CatItem('记忆管理', Icons.psychology_outlined, MemoryScreen()),
  ]),
  _Category('语音', Icons.record_voice_over_outlined, [
    _CatItem('语音提供商与测试', Icons.voice_over_off_outlined, ProvidersScreen()),
  ]),
  _Category('通知与后台', Icons.notifications_active_outlined, [
    _CatItem('通知与后台', Icons.notifications_active_outlined, NotifScreen()),
    _CatItem('特权（Shizuku）', Icons.security_outlined, PrivilegeScreen()),
  ]),
  _Category('外观与主题', Icons.palette_outlined, [
    _CatItem('外观与偏好', Icons.palette_outlined, AppearanceScreen()),
  ]),
  _Category('会话与同步', Icons.sync_outlined, [
    _CatItem('同步设置', Icons.sync_outlined, SyncSettingsScreen()),
    _CatItem('会话管理', Icons.forum_outlined, SessionsScreen()),
  ]),
  _Category('隐私与安全', Icons.lock_outline, [
    _CatItem('权限管理', Icons.admin_panel_settings_outlined, PermissionScreen()),
    _CatItem('挂载外部文件', Icons.folder_special_outlined, MountScreen()),
  ]),
  _Category('系统与日志', Icons.settings_suggest_outlined, [
    _CatItem('日志', Icons.article_outlined, LogsScreen()),
    _CatItem('管理服务端文件', Icons.folder_special_outlined, ServerFilesScreen()),
    _CatItem('MCP', Icons.dns_outlined, McpScreen()),
  ]),
  _Category('关于', Icons.info_outline, [
    _CatItem('版本与信息', Icons.info_outline, AboutScreen()),
  ]),
];

class AiConfigScreen extends StatelessWidget {
  const AiConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
            subtitle: Text('${c.items.length} 项',
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
        title: Text('设置 / ${category.title}',
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
