/// 关于页（先生：版本显示需带图标/Logo——非纯文字）
/// 【0.4.4 修复】版本不再写死：
///   - App 版本 ← AppInfo（唯一来源）
///   - Server 版本 ← 仅在真实连接后由 system_info 填充；未连接显示「未连接（无法获知）」
library;

import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('关于')),
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
              child: const Icon(Icons.terminal, size: 44, color: AppColors.green),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
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
                  style: const TextStyle(
                      fontFamily: fuiMono, fontSize: 13, color: AppColors.green, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 28),
          // 信息行（图标 + 内容——先生要求每项带图标）
          _info(Icons.smartphone, 'App', '${AppInfo.full} · Flutter'),
          _info(
            connected ? Icons.dns_outlined : Icons.cloud_off_outlined,
            'Server',
            connected ? AppInfo.serverDisplay : '未连接（无法获知）',
            dim: !connected,
          ),
          _info(Icons.account_tree_outlined, '架构', '核心/通讯/配置/数据/插件/安全/AI/天气'),
          _info(Icons.folder_open, '数据根', AppInfo.dataRoot),
          _info(Icons.link, '仓库', AppInfo.repo),
          _info(Icons.palette_outlined, '界面', 'FUI v2 · 灰白地形'),
          const SizedBox(height: 20),
          const Center(
            child: Text('© 2026 LING OS · 本地优先 · 隐私第一',
                style: TextStyle(fontSize: 10, color: AppColors.dim)),
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
              style: const TextStyle(fontSize: 12, color: AppColors.dim)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: dim ? AppColors.dim : AppColors.white)),
          ),
        ],
      ),
    );
  }
}
