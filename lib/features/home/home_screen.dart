/// 主控台（先生 lingos-app-preview-final 对照——本地模式首页）
/// 本地态：版本真值/主机--/本地服务入口/连接主机引导（不模拟假数据）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';
import '../connect/connect_screen.dart';
import '../alerts/alerts_screen.dart';
import '../vision/vision_screen.dart';
import '../sessions/sessions_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const HomeScreen({super.key, this.onOpenDrawer});

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          onPressed: onOpenDrawer,
        ),
        title: const Text('主控台'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.amber, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('LOCAL',
                    style: TextStyle(
                        fontFamily: fuiMono, fontSize: 10, color: AppColors.amber)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 系统状态区（本地真值）
          _section(context, '系统状态 · 本地'),
          Row(children: [
            Expanded(child: _localCard('主机', '--', '需连接')),
            const SizedBox(width: 8),
            Expanded(child: _localCard('App 版本', '0.4.3', '本地')),
          ]),
          const SizedBox(height: 16),
          _section(context, '本地服务'),
          _item(context, Icons.chat_bubble_outline, '对话 AI', 'CHAT · 需主机模型',
              AppColors.gray, () => _toast(context, '会话需连接主机后使用')),
          _item(context, Icons.notifications_outlined, '预警', 'ALERT · 本地',
              AppColors.green, () => _push(context, const AlertsScreen())),
          _item(context, Icons.forum_outlined, '会话', 'SESSIONS · 本地缓存',
              AppColors.gray, () => _push(context, SessionsScreen(onOpenDrawer: onOpenDrawer))),
          _item(context, Icons.link, '连接主机', 'CONNECT · 同步后可用全部功能',
              AppColors.green, () => _push(context, const ConnectScreen())),
          _item(context, Icons.videocam_outlined, '摄像头', 'MONITOR · 需连接主机',
              AppColors.gray, () => _toast(context, '监控需连接主机')),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('连接后：此屏变为 server 真数据控制台（CPU/内存/磁盘/事件流实时）',
                style: TextStyle(
                    fontFamily: fuiMono, fontSize: 9, color: AppColors.dim, height: 1.8)),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 14, height: 1, color: AppColors.line),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontFamily: fuiMono,
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.gray)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.lineDim)),
      ]),
    );
  }

  Widget _localCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.lineDim),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.dim)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontFamily: fuiMono,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white)),
        Text(sub,
            style: const TextStyle(fontSize: 9, color: AppColors.amber)),
      ]),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String sub,
      Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, size: 22, color: color),
      title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(sub,
          style: const TextStyle(fontFamily: fuiMono, fontSize: 9, color: AppColors.dim)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
      onTap: onTap,
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), duration: const Duration(seconds: 2)));
  }
}
