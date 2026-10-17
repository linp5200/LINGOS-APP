/// 关于页（先生：版本显示需带图标/Logo——非纯文字）
/// 【0.4.4 修复】版本不再写死：
///   - App 版本 ← AppInfo（唯一来源）
///   - Server 版本 ← 仅在真实连接后由 system_info 填充；未连接显示「未连接（无法获知）」
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    final cm = ref.watch(connectionProvider);
    final connected = cm.isConnected;

    return Scaffold(
      appBar: AppBar(title: Text(tr('about'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Logo + 图标（先生：版本要有图形标识）
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
              child:  Icon(Icons.terminal, size: 44, color: AppColors.green),
            ),
          ),
          const SizedBox(height: 16),
           Center(
            child: Text('LING OS',
                style: TextStyle(
                    fontFamily: fuiMono,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                    color: AppColors.white)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(AppInfo.tag,
                  style:  TextStyle(
                      fontFamily: fuiMono, fontSize: 13, color: AppColors.green, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 28),
          // 信息行（图标 + 内容——先生要求每项带图标）
          _info(Icons.smartphone, 'App', '${AppInfo.full} · Flutter'),
          _info(
            connected ? Icons.dns_outlined : Icons.cloud_off_outlined,
            'Server',
            connected ? AppInfo.serverDisplay : tr('unknowable'),
            dim: !connected,
          ),
          _info(Icons.account_tree_outlined, tr('about_architecture'), tr('about_core_comm_config_data_plugin_security_ai')),
          _info(Icons.folder_open, tr('about_data_root'), AppInfo.dataRoot),
          _info(Icons.link, tr('about_repository'), AppInfo.repo),
          _info(Icons.palette_outlined, tr('grp_ui'), tr('about_fui_v2_gray_white_terrain')),
          const SizedBox(height: 20),
          Center(
            child: Text(tr('about_2026_ling_os_local_first_privacy_first'),
                style:  TextStyle(fontSize: 10, color: AppColors.dim)),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value, {bool dim = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: dim ? AppColors.dim : AppColors.gray),
          const SizedBox(width: 14),
          Text('$label  ',
              style:  TextStyle(fontSize: 12, color: AppColors.dim)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: dim ? AppColors.dim : AppColors.white)),
          ),
        ],
      ),
    );
  }
}
