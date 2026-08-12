/// 规划占位页（0.1.9——子菜单骨架）
/// 显示定案的规划内容——服务端命令就绪后填充实现
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PlanPage extends StatelessWidget {
  final String title;
  final List<String> planItems;
  final String note;

  const PlanPage({
    super.key,
    required this.title,
    required this.planItems,
    this.note = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              Icon(Icons.construction, size: 18, color: AppColors.brandCyan),
              SizedBox(width: 8),
              Text('功能规划中——服务端命令就绪后启用',
                  style: TextStyle(fontSize: 12, color: AppColors.brandCyan)),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in planItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary, height: 1.5)),
                  ),
                ],
              ),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(note,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
}
