/// 插件屏（【第6期】App 插件屏补齐——对接服务端真实 plugin_list / plugin_reload）
///
/// 服务端能力（src/python/ai_server.py:1646 cmd_plugin_list → plugin_status()）：
///   · plugin_list   → {status, dir, loaded, plugins[], skills[], commands[]}
///   · plugin_reload → {status, reloaded}
/// 数据源：plugin_loader 扫描插件目录（默认 /LINGOS/plugins）后的真实内存表。
/// 无数据一律显示 --，不伪造插件名/数量（先生铁律：禁假数据）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/icons/lingos_icon.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class PluginScreen extends ConsumerStatefulWidget {
  const PluginScreen({super.key});

  @override
  ConsumerState<PluginScreen> createState() => _PluginScreenState();
}

class _PluginScreenState extends ConsumerState<PluginScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _reachable = false;
  String _dir = '';
  int? _loaded;
  List<String> _plugins = const [];
  List<String> _skills = const [];
  List<String> _commands = const [];
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? _extract(Map<String, dynamic>? resp) {
    try {
      // 【P0-1 契约修复】requestJson 现在返回"命令回包"本身
      if (resp != null &&
          (resp.containsKey('plugins') || resp.containsKey('loaded') || resp.containsKey('dir'))) {
        return resp;
      }
      final d = resp?['data'];
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        if (m.containsKey('plugins') || m.containsKey('loaded')) return m;
        final inner = m['data'];
        if (inner is Map) {
          final m2 = Map<String, dynamic>.from(inner);
          if (m2.containsKey('plugins') || m2.containsKey('loaded')) return m2;
        }
      }
    } catch (_) {}
    return null;
  }

  List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await ref.read(connectionProvider).requestJson(
          {'cmd': 'plugin_list'},
          timeout: const Duration(seconds: 10),
        );
    final d = _extract(resp);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reachable = d != null;
      if (d != null) {
        _dir = d['dir']?.toString() ?? '';
        final n = d['loaded'];
        _loaded = (n is num) ? n.toInt() : null;
        _plugins = _strList(d['plugins']);
        _skills = _strList(d['skills']);
        _commands = _strList(d['commands']);
      } else {
        _dir = '';
        _loaded = null;
        _plugins = const [];
        _skills = const [];
        _commands = const [];
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _msg = '';
    });
    final resp = await ref.read(connectionProvider).requestJson(
          {'cmd': 'plugin_reload'},
          timeout: const Duration(seconds: 30),
        );
    String msg = '';
    try {
      final d = resp?['data'];
      if (d is Map) {
        if (d['status'] == 'error') {
          final e = d['msg']?.toString() ?? '--';
          msg = trp('plg_reload_failed', {'p0': e});
        } else {
          final n = d['reloaded'];
          msg = trp('plg_reloaded', {'p0': n == null ? '--' : n.toString()});
        }
      } else {
        msg = tr('upg_host_not_connected');
      }
    } catch (_) {
      msg = tr('upg_host_not_connected');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = msg;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final loadedTxt = _loaded == null ? '--' : _loaded.toString();
    final dirTxt = _dir.isEmpty ? '--' : _dir;
    // 【CI】tr() 结果先落局部变量，再用插值拼接（避免 prefer_interpolation_to_compose_strings）
    final loadedLabel = tr('plg_loaded');
    final dirLabel = tr('plg_dir');
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(tr('cfg_plugins')),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
        ],
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: LingIcon(
                      LingIcons.internalService,
                      size: 30,
                      color: _reachable ? AppColors.green : AppColors.amber,
                      scope: LingScope.server,
                      status: _reachable ? LingStatus.none : LingStatus.error,
                    ),
                    title: Text(
                      _reachable
                          ? '$loadedLabel: $loadedTxt'
                          : tr('plg_unavailable'),
                      style: TextStyle(
                          fontSize: 13,
                          color: _reachable ? AppColors.white : AppColors.amber),
                    ),
                    subtitle: Text(
                      '$dirLabel: $dirTxt',
                      style:  TextStyle(
                          fontFamily: fuiMono, fontSize: 11, color: AppColors.dim),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _listCard(tr('plg_plugins'), _plugins, Icons.extension_outlined),
                const SizedBox(height: 10),
                _listCard(tr('plg_skills'), _skills, Icons.psychology_outlined),
                const SizedBox(height: 10),
                _listCard(tr('plg_commands'), _commands, Icons.terminal),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(_busy ? tr('plg_reloading') : tr('plg_reload')),
                ),
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_msg,
                      textAlign: TextAlign.center,
                      style:  TextStyle(fontSize: 12, color: AppColors.amber)),
                ],
                const SizedBox(height: 16),
                Text(tr('plg_note'),
                    style:  TextStyle(fontSize: 11, color: AppColors.dim)),
              ],
            ),
    );
  }

  Widget _listCard(String title, List<String> items, IconData icon) {
    final cnt = _reachable ? items.length.toString() : '--';
    return Card(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: Icon(icon, size: 18, color: AppColors.gray),
            title: Text(title,
                style:  TextStyle(fontSize: 12, color: AppColors.gray)),
            trailing: Text(cnt,
                style:  TextStyle(
                    fontFamily: fuiMono, fontSize: 12, color: AppColors.white)),
          ),
          if (_reachable && items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(tr('plg_empty'),
                  style:  TextStyle(fontSize: 11, color: AppColors.dim)),
            ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in items)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lineDim),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(n,
                          style:  TextStyle(
                              fontFamily: fuiMono,
                              fontSize: 11,
                              color: AppColors.gray)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
