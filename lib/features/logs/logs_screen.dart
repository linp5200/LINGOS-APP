/// 日志页（2026-08-22 定稿 + 2026-09-18 服务端日志接线）
/// - Tab 1：App 日志（本地——显示最近 100 行 + 默认不保存 + 导出落盘）
/// - Tab 2：服务端日志（file_read /LINGOS/log/lingos.log——此前不读服务端，审计项修复）
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _logger = AppLogger.instance;
  bool _enabled = true;
  bool _saveToFile = false;

  // 【2026-09-18】服务端日志（file_read /LINGOS/log/lingos.log）
  String _serverLog = '';
  String _serverErr = '';
  bool _serverLoading = false;

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

  /// 【2026-09-18】读取服务端日志（file_read → 取最后 120 行）
  Future<void> _loadServerLog() async {
    setState(() {
      _serverLoading = true;
      _serverErr = '';
    });
    try {
      final resp = await ref.read(connectionProvider).requestJson(
        {'cmd': 'file_read', 'path': '/LINGOS/log/lingos.log'},
        timeout: const Duration(seconds: 10),
      );
      if (!mounted) return;
      if (resp == null) {
        setState(() {
          _serverErr = '未连接主机或请求超时——连接后重试';
          _serverLoading = false;
        });
        return;
      }
      if (resp['status'] != 'ok') {
        setState(() {
          _serverErr = '读取失败：${resp['msg'] ?? resp['status']}';
          _serverLoading = false;
        });
        return;
      }
      final data = resp['data'];
      final content = data is String ? data : (data is Map ? data['data']?.toString() ?? '' : '');
      final lines = content.split('\n');
      final tail = lines.length > 120 ? lines.sublist(lines.length - 120) : lines;
      setState(() {
        _serverLog = tail.join('\n');
        _serverLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErr = '读取异常：$e';
        _serverLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('日志'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'App 日志', height: 40),
              Tab(text: '服务端日志', height: 40),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '导出日志',
              onPressed: _copyLogs,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '清空（App 日志）',
              onPressed: () {
                _logger.clear();
                setState(() {});
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAppLogTab(),
            _buildServerLogTab(),
          ],
        ),
      ),
    );
  }

  // ---------- Tab 1：App 日志（原功能） ----------
  Widget _buildAppLogTab() {
    return Column(
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
    );
  }

  // ---------- Tab 2：服务端日志（【2026-09-18】新增） ----------
  Widget _buildServerLogTab() {
    final connected = ref.watch(connectionProvider).isConnected;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  connected ? '主机日志 /LINGOS/log/lingos.log · 最近 120 行' : '未连接主机——连接后拉取服务端日志',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: _serverLoading
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                tooltip: '刷新服务端日志',
                onPressed: _serverLoading ? null : _loadServerLog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _serverErr.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_serverErr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6)),
                  ),
                )
              : _serverLog.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('尚未拉取——点右上刷新按钮读取服务端日志',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadServerLog,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('拉取服务端日志'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _serverLog.split('\n').length,
                      itemBuilder: (ctx, i) {
                        final line = _serverLog.split('\n')[i];
                        final isErr = line.contains('ERROR');
                        final isWarn = line.contains('WARN');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFamily: fuiMono,
                              height: 1.35,
                              color: isErr
                                  ? AppColors.brandRed
                                  : isWarn
                                      ? AppColors.yellow
                                      : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logger.exportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志已导出——可粘贴分享')));
  }
}
