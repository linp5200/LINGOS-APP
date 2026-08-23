/// AI 配置主页（2026-08-22 先生裁决：树状分类——9 大类子菜单导航）
/// 分类：连接与服务器 / 对话与AI / 语音 / 通知与后台 / 外观与主题 / 会话与同步 / 隐私与安全 / 系统与日志 / 关于
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

class AiConfigScreen extends StatelessWidget {
  const AiConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 9 大类（先生定稿树状分类）——每类含子项
    final categories = <(String, IconData, List<(String, IconData, Widget)>)>[
      (
        '连接与服务器',
        Icons.settings_ethernet_outlined,
        [
          ('连接设置', Icons.link_outlined, const ConnSettingsScreen()),
          ('主机', Icons.dns_outlined, const ConnectScreen()),
          ('Rootfs 本地沙箱', Icons.developer_board_outlined, const RootfsScreen()),
        ],
      ),
      (
        '对话与 AI',
        Icons.smart_toy_outlined,
        [
          ('添加提供商', Icons.add_circle_outline, const ProvidersScreen()),
          ('Token 用量', Icons.data_usage_outlined, const TokenUsageScreen()),
          ('人格', Icons.person_outline, const PersonalityScreen()),
          ('技能', Icons.extension_outlined, const SkillsScreen()),
          ('记忆管理', Icons.psychology_outlined, const MemoryScreen()),
        ],
      ),
      (
        '语音',
        Icons.record_voice_over_outlined,
        [
          ('语音提供商', Icons.voice_over_off_outlined, const ProvidersScreen()),
        ],
      ),
      (
        '通知与后台',
        Icons.notifications_active_outlined,
        [
          ('通知与后台', Icons.notifications_active_outlined, const NotifScreen()),
          ('特权', Icons.security_outlined, const PrivilegeScreen()),
        ],
      ),
      (
        '外观与主题',
        Icons.palette_outlined,
        [
          ('外观与偏好', Icons.palette_outlined, const AppearanceScreen()),
        ],
      ),
      (
        '会话与同步',
        Icons.sync_outlined,
        [
          ('同步设置', Icons.sync_outlined, const SyncSettingsScreen()),
          ('会话管理', Icons.forum_outlined, const SessionsScreen()),
        ],
      ),
      (
        '隐私与安全',
        Icons.lock_outline,
        [
          ('权限管理', Icons.admin_panel_settings_outlined, const PermissionScreen()),
          ('挂载外部文件', Icons.folder_special_outlined, const MountScreen()),
        ],
      ),
      (
        '系统与日志',
        Icons.settings_suggest_outlined,
        [
          ('日志', Icons.article_outlined, const LogsScreen()),
          ('管理服务端文件', Icons.folder_special_outlined, const ServerFilesScreen()),
          ('MCP', Icons.dns_outlined, const McpScreen()),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (title, icon, items) in categories)
            _CategorySection(title: title, icon: icon, items: items, context: context),
        ],
      ),
    );
  }
}

/// 分类区块——点击展开子菜单（树状）
class _CategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, IconData, Widget)> items;
  final BuildContext context;

  const _CategorySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: AppColors.red),
        title: Text('[ $title ]',
            style: const TextStyle(
                fontFamily: fuiMono,
                fontSize: 13,
                color: AppColors.white,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
        iconColor: AppColors.gray,
        collapsedIconColor: AppColors.dim,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        children: [
          for (final (label, subIcon, page) in items)
            ListTile(
              dense: true,
              leading: Icon(subIcon, size: 17, color: AppColors.gray),
              title: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.dim),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => page)),
            ),
        ],
      ),
    );
  }
}
