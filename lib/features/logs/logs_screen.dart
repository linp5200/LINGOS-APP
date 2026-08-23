/// 日志页（2026-08-22 定稿：显示最近 100 行 + 默认不保存 + 导出落盘）
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _logger = AppLogger.instance;
  bool _enabled = true;
  bool _saveToFile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppStore();
    final v = await store.getLoggingEnabled();
    final s = await store.getLogSaveToFile();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _saveToFile = s;
      _logger.enabled = v;
      _logger.setSaveToFile(s);
    });
  }

  Future<void> _toggle(bool v) async {
    final store = AppStore();
    setState(() => _enabled = v);
    _logger.enabled = v;
    await store.saveLoggingEnabled(v);
  }

  Future<void> _toggleSave(bool v) async {
    final store = AppStore();
    setState(() => _saveToFile = v);
    _logger.setSaveToFile(v);
    await store.saveLogSaveToFile(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: '导出日志',
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
          SwitchListTile(
            dense: true,
            value: _enabled,
            onChanged: _toggle,
            title: const Text('记录日志', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            subtitle: const Text('关闭后不再记录新日志（连接/WS/命令）',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          SwitchListTile(
            dense: true,
            value: _saveToFile,
            onChanged: _toggleSave,
            title: const Text('保存到文件', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            subtitle: const Text('默认关=仅导出落盘；开=保留全部日志到文件',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: const Text(
              '显示最近 100 行——导出时落盘',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: _logger.recentLogs.isEmpty
                ? const Center(
                    child: Text('暂无日志——连接后自动记录', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logger.recentLogs.length,
                    itemBuilder: (ctx, i) {
                      final entry = _logger.recentLogs[i];
                      final txt = entry['txt'] as String;
                      final lvl = entry['level'] as String;
                      final color = lvl == 'ERROR' || txt.contains('失败') || txt.contains('错误')
                          ? AppColors.brandRed
                          : lvl == 'WARN'
                              ? AppColors.yellow
                              : AppColors.textSecondary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          txt,
                          style: TextStyle(fontSize: 11, color: color, fontFamily: fuiMono, height: 1.3),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志已导出——可粘贴分享')));
  }
}
