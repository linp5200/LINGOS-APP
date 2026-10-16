/// 升级更新屏（【第6期】App 升级屏补齐——对接服务端真实 update_check）
///
/// 服务端能力（src/python/ai_server.py:4693 cmd_update_check）：
///   · update_check → {status, current, latest, update_available, source, checked, message}
///     真源：/LINGOS/system/config/repo.conf 的 repo_url（或 GitHub Releases）
///     未配置更新源时返回 message='未配置更新源（repo.conf）…'，**不是假报"已是最新"**
///
/// 本屏只做「检查 + 呈现」：升级动作由服务端 lingos-upgrade 执行（签名校验 + 回滚），
/// 客户端不伪造进度、不在无数据时编造版本号（无数据一律 --）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/icons/lingos_icon.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _loading = true;
  bool _busy = false;

  /// 服务端返回的真实字段（null = 未取到，界面显示 --）
  String? _current;
  String? _latest;
  String? _source;
  String? _message;
  int? _checked;
  bool? _available;
  bool _reachable = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// 解析服务端响应（WS command_response.data → update_check 平铺字典）
  Map<String, dynamic>? _extract(Map<String, dynamic>? resp) {
    try {
      final d = resp?['data'];
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        if (m.containsKey('current') || m.containsKey('update_available')) return m;
        final inner = m['data'];
        if (inner is Map) {
          final m2 = Map<String, dynamic>.from(inner);
          if (m2.containsKey('current') || m2.containsKey('update_available')) return m2;
        }
        return m;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      if (_current == null) _loading = true;
    });
    final resp = await ref.read(connectionProvider).requestJson(
          {'cmd': 'update_check'},
          timeout: const Duration(seconds: 20),
        );
    final d = _extract(resp);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loading = false;
      _reachable = d != null;
      if (d != null) {
        _current = d['current']?.toString();
        _latest = (d['latest']?.toString().isEmpty ?? true) ? null : d['latest'].toString();
        _source = (d['source']?.toString().isEmpty ?? true) ? null : d['source'].toString();
        _message = (d['message']?.toString().isEmpty ?? true) ? null : d['message'].toString();
        _available = d['update_available'] == true;
        final c = d['checked'];
        _checked = (c is num) ? c.toInt() : null;
      } else {
        _current = null;
        _latest = null;
        _source = null;
        _message = null;
        _available = null;
        _checked = null;
      }
    });
  }

  String get _checkedText {
    if (_checked == null || _checked == 0) return '--';
    final t = DateTime.fromMillisecondsSinceEpoch(_checked! * 1000);
    String p(int n) => n < 10 ? '0$n' : '$n';
    return '${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(tr('cfg_upgrade')),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _check,
            tooltip: tr('upg_check_now'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 状态头（图标体系：下载图形 + 状态角标——不叠加库有原生的语义）
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: LingIcon(
                      LingIcons.download,
                      size: 30,
                      color: !_reachable
                          ? AppColors.amber
                          : (_available == true ? AppColors.green : AppColors.gray),
                      scope: LingScope.server,
                      status: !_reachable
                          ? LingStatus.error
                          : (_available == true ? LingStatus.internet : LingStatus.none),
                    ),
                    title: Text(
                      !_reachable
                          ? tr('upg_host_not_connected')
                          : (_available == true
                              ? trp('upg_update_available', {'p0': _latest ?? '--'})
                              : trp('upg_up_to_date', {'p0': _current ?? '--'})),
                      style: TextStyle(
                        fontSize: 13,
                        color: !_reachable
                            ? AppColors.amber
                            : (_available == true ? AppColors.green : AppColors.white),
                      ),
                    ),
                    subtitle: Text(_message ?? tr('upg_never_checked'),
                        style: const TextStyle(fontSize: 11, color: AppColors.dim)),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      _kv(tr('upg_current_version'), _current ?? '--'),
                      const Divider(height: 1, color: AppColors.divider),
                      _kv(tr('upg_latest_version'), _latest ?? '--'),
                      const Divider(height: 1, color: AppColors.divider),
                      _kv(tr('upg_source'), _source ?? tr('upg_source_unset')),
                      const Divider(height: 1, color: AppColors.divider),
                      _kv(tr('upg_checked_at'), _checkedText),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: Text(_busy ? tr('upg_checking') : tr('upg_check_now')),
                ),
                const SizedBox(height: 16),
                Text(tr('upg_note'),
                    style: const TextStyle(fontSize: 11, color: AppColors.dim)),
              ],
            ),
    );
  }

  Widget _kv(String k, String v) => ListTile(
        dense: true,
        title: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.gray)),
        trailing: Text(v,
            style: const TextStyle(
                fontFamily: fuiMono, fontSize: 12, color: AppColors.white)),
      );
}
