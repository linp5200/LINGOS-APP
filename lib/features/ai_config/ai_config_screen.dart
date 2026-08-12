/// AI 配置（0.1.9——15 子菜单统一入口）
/// 结构：LLM/MLM 提供商 · AI 管理 · 存储 · 通知与后台 · 连接与设置 · 外观与偏好
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../memory/memory_screen.dart';
import '../sessions/sessions_screen.dart';
import '../files/files_screen.dart';
import 'screens/providers_screen.dart';
import 'screens/token_usage_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/personality_screen.dart';
import 'screens/skills_screen.dart';
import 'screens/mcp_screen.dart';
import 'screens/rootfs_screen.dart';
import 'screens/mount_screen.dart';
import 'screens/server_files_screen.dart';
import 'screens/notif_screen.dart';
import 'screens/conn_settings_screen.dart';
import 'screens/appearance_screen.dart';

class AiConfigScreen extends StatelessWidget {
  const AiConfigScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section(context, 'LLM/MLM 提供商'),
          _tile(context, Icons.add_circle_outline, '添加提供商', '配置 URL / API KEY / AI model',
              () => _push(context, const ProvidersScreen())),
          _tile(context, Icons.data_usage_outlined, 'Token 完整用量', '显示所有 token 用量（可指定时间）',
              () => _push(context, const TokenUsageScreen())),

          _section(context, 'AI 管理'),
          _tile(context, Icons.admin_panel_settings_outlined, '权限管理', '管理 AI 权限',
              () => _push(context, const PermissionScreen())),
          _tile(context, Icons.psychology_outlined, '记忆管理', '管理 AI 记忆',
              () => _push(context, const MemoryScreen())),
          _tile(context, Icons.forum_outlined, '会话管理', '管理各个会话',
              () => _push(context, const SessionsScreen())),
          _tile(context, Icons.person_outline, '人格', '诺克 / 诺玛',
              () => _push(context, const PersonalityScreen())),
          _tile(context, Icons.extension_outlined, '技能', 'AI 技能管理（启用 ≠ 权限）',
              () => _push(context, const SkillsScreen())),
          _tile(context, Icons.dns_outlined, '额外的 MCP', '配置主机以外的 MCP',
              () => _push(context, const McpScreen())),

          _section(context, '存储'),
          _tile(context, Icons.developer_board_outlined, 'Rootfs 本地沙箱管理', '多发行版安装与管理',
              () => _push(context, const RootfsScreen())),
          _tile(context, Icons.link_outlined, '挂载外部文件', '双来源 + 持久化',
              () => _push(context, const MountScreen())),
          _tile(context, Icons.folder_special_outlined, '管理服务端文件', 'LINGOS 系统目录',
              () => _push(context, const ServerFilesScreen())),
          _tile(context, Icons.folder_outlined, '浏览文件', '通用文件浏览',
              () => _push(context, const FilesScreen())),

          _section(context, '通知与后台'),
          _tile(context, Icons.notifications_active_outlined, '通知与后台', '通知渠道 / 保活 / 电池优化',
              () => _push(context, const NotifScreen())),

          _section(context, '连接与设置'),
          _tile(context, Icons.dns_outlined, '主机', '主机IP / 连接密钥 / 连接状态 / 连接方式 / 加密',
              () => _push(context, const ConnSettingsScreen())),

          _section(context, '外观与偏好'),
          _tile(context, Icons.palette_outlined, '外观与偏好', '主题 / 强调色 / 语言 / 消息偏好 / 隐私',
              () => _push(context, const AppearanceScreen())),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.brandCyan),
      title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
