/// 关于页（先生：版本显示需带图标/Logo——非纯文字）
/// 显示 App 图标 + LINGOS Logo + 版本 0.4.3+18 + server 关联信息
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          Center(
            child: Text('LING OS',
                style: const TextStyle(
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
              child: const Text('v0.4.3+18',
                  style: TextStyle(
                      fontFamily: fuiMono, fontSize: 13, color: AppColors.green, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 28),
          // 信息行（图标 + 内容——先生要求每项带图标）
          _info(Icons.smartphone, 'App', '0.4.3+18 · Flutter'),
          _info(Icons.dns_outlined, 'Server', '0.4.3 · LN-0.4.3'),
          _info(Icons.account_tree_outlined, '架构', '核心/通讯/配置/数据/插件/安全/AI/天气'),
          _info(Icons.folder_open, '数据根', '/LINGOS'),
          _info(Icons.link, '仓库', 'github.com/linp5200/LINGOS-APP'),
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

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gray),
          const SizedBox(width: 14),
          Text(label + '  ',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: fuiMono, fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
