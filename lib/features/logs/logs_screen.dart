/// 日志页（2026-08-22 定稿 + 2026-09-18 服务端日志接线）
/// - Tab 1：App 日志（本地——显示最近 100 行 + 默认不保存 + 导出落盘）
/// - Tab 2：服务端日志（file_read /LINGOS/log/lingos.log——此前不读服务端，审计项修复）
library;

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
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
          _serverErr = tr('log_host_not_connected_or_request_timed_out');
          _serverLoading = false;
        });
        return;
      }
      if (resp['status'] != 'ok') {
        setState(() {
          _serverErr = trp('log_read_failed', {'p0': resp['msg'] ?? resp['status']});
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
        _serverErr = trp('log_read_error', {'p0': '$e'});
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
          title: Text(tr('cfg_logs')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('log_app_logs'), height: 40),
              Tab(text: tr('log_server_logs'), height: 40),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: tr('log_export_logs'),
              onPressed: _copyLogs,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: tr('log_clear_app_logs'),
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
          title: Text(tr('log_logging'), style:  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          subtitle: Text(tr('log_when_off_no_new_logs_are_recorded_connect'),
              style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
        SwitchListTile(
          dense: true,
          value: _saveToFile,
          onChanged: _toggleSave,
          title: Text(tr('log_save_to_file'), style:  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          subtitle: Text(tr('log_off_by_default_only_exports_are_written_on'),
              style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Text(
            tr('log_shows_the_last_100_lines_written_to_disk_on'),
            style:  TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: _logger.recentLogs.isEmpty
              ? Center(
                  child: Text(tr('log_no_logs_yet_recording_starts_after'), style:  TextStyle(color: AppColors.textSecondary)),
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
                  connected ? tr('log_host_logs_lingos_log_lingos_log_last_120') : tr('log_host_not_connected_server_logs_are_fetched'),
                  style:  TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: _serverLoading
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                tooltip: tr('log_refresh_server_logs'),
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
                        style:  TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6)),
                  ),
                )
              : _serverLog.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tr('log_not_fetched_yet_tap_refresh_to_read_server'),
                              style:  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadServerLog,
                            icon: const Icon(Icons.download, size: 16),
                            label: Text(tr('log_fetch_server_logs')),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('log_logs_exported_ready_to_paste_and_share'))));
  }
}
