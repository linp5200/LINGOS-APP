/// 日志页（先生要求：查看 + 导出日志——连接/WS/命令全链路）
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../core/theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: '复制日志',
            onPressed: _copyLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空',
            onPressed: () {
              _logger.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: const Text(
              '日志已记录（内存 500 行 + 文件）——点击右上角复制导出',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: _logger.logs.isEmpty
                ? const Center(
                    child: Text('暂无日志——连接后自动记录', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logger.logs.length,
                    itemBuilder: (ctx, i) {
                      final line = _logger.logs[i];
                      final color = line.contains('失败') || line.contains('错误') || line.contains('【空')
                          ? AppColors.brandRed
                          : line.contains('✅') || line.contains('成功')
                              ? AppColors.brandCyan
                              : AppColors.textSecondary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace', height: 1.3),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logger.exportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志已复制——可粘贴分享')));
  }
}
