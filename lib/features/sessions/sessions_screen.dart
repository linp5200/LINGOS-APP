/// 会话管理（0.1.9——点击进入对话页继续对话 + 长按多选批量删除）
library;

import 'dart:async';
import '../../core/i18n/app_i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_screen.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  // 【0.2.1 #7】三横按钮回调（作为底部导航 tab 时打开 Drawer）
  final VoidCallback? onOpenDrawer;
  const SessionsScreen({super.key, this.onOpenDrawer});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = false;
  bool _selectMode = false;
  // 【0.2.1 #1】离线只读模式（断连时显示缓存 + 操作拦截）
  bool _offline = false;
  final Set<String> _selected = {};
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'offline') {
        // 【0.2.1 #1】断连 → 切离线只读 + 载入缓存
        setState(() => _offline = true);
        _loadCached();
        return;
      }
      if (evt is Map && evt['type'] == 'connection_ok') {
        setState(() => _offline = false);
        _refresh();
        return;
      }
      if (evt is Map && evt['type'] == 'command_response') {
        final data = evt['data'];
        Map<String, dynamic>? resp;
        if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map) resp = Map<String, dynamic>.from(decoded);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null || resp['status'] != 'ok') return;
        final list = resp['data'];
        if (list is List) {
          setState(() {
            _sessions = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  void _refresh() {
    if (_offline) return; // 离线只读——不请求
    setState(() => _loading = true);
    // 【0.2.2】手动刷新走同步协议（先生裁决 B：自动 + 手动刷新）
    ref.read(connectionProvider).refreshSync().then((_) {
      if (mounted) setState(() => _loading = false);
      // 刷新后从缓存读取最新列表
      _reloadFromCache();
    });
  }

  /// 【0.2.2】从本地缓存刷新列表（同步落库后展示）
  Future<void> _reloadFromCache() async {
    final cached = await OfflineCache.instance.getCachedSessions();
    if (!mounted) return;
    setState(() {
      _sessions = cached;
      _loading = false;
    });
  }

  /// 【0.2.1 #1】断连：载入本地缓存（只读显示）
  Future<void> _loadCached() async {
    final cached = await OfflineCache.instance.getCachedSessions();
    if (!mounted) return;
    setState(() {
      _sessions = cached;
      _loading = false;
    });
  }

  /// 【0.2.1 #1】操作拦截：离线时任何修改提示"当前尚未连接主机，无法修改"
  bool _guardOffline() {
    if (!_offline) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('sess_not_connected_to_a_host_cannot_modify'))),
    );
    return true;
  }

  void _create() async {
    if (_guardOffline()) return; // 【0.2.1 #1】离线拦截
    final ctrl = TextEditingController();
    // 【0.2.1 9.3】会话创建完善：默认名 + 描述字段
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sess_new_session')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(hintText: tr('sess_session_title_empty_auto_named')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(hintText: tr('sess_session_description_optional')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('sess_create'))),
        ],
      ),
    );
    if (ok == true) {
      final title = ctrl.text.trim().isEmpty ? tr('sess_new_session_2') : ctrl.text.trim();
      final cm = ref.read(connectionProvider);
      final resp = await cm.requestJson({'cmd': 'session_create', 'title': title});
      _refresh();
      // 【0.2.1 9.3】创建后自动进入新会话
      final data = resp?['data'];
      final newId = data is Map ? data['id']?.toString() : null;
      if (newId != null && newId.isNotEmpty && mounted) {
        ref.read(chatControllerProvider.notifier).setSession(newId);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
      }
    }
  }

  /// 【0.1.9】点击会话 → 进入对话页（载入该会话继续对话）
  void _openChat(String id) {
    ref.read(chatControllerProvider.notifier).setSession(id);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _rename(String id) async {
    if (_guardOffline()) return; // 【0.2.1 #1】离线拦截
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sess_rename')),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: tr('sess_new_title'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
        ],
      ),
    );
    if (ok == true && ctrl.text.isNotEmpty) {
      final cm = ref.read(connectionProvider);
      final resp = await cm.requestJson({
        'cmd': 'session_rename',
        'id': id,
        'title': ctrl.text,
        'device_id': await AppStore().getDeviceId(),
      });
      _refresh();
      if (!mounted) return;
      final code = resp?['code']?.toString();
      if (code == 'readonly') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('sess_this_session_is_read_only_created_on'))),
        );
      } else if (code == 'conflict') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp?['msg']?.toString() ?? tr('sess_edit_busy_another_device_is_editing_try'))),
        );
      }
    }
  }

  void _delete(String id) async {
    if (_guardOffline()) return; // 【0.2.1 #1】离线拦截
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({
      'cmd': 'session_delete',
      'id': id,
      'device_id': await AppStore().getDeviceId(),
    });
    _refresh();
    if (!mounted) return;
    final code = resp?['code']?.toString();
    if (code == 'readonly') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('sess_this_session_is_read_only_created_on_2'))),
      );
    }
  }

  /// 【0.1.9】多选批量删除
  void _batchDelete() {
    if (_guardOffline()) return; // 【0.2.1 #1】离线拦截
    if (_selected.isEmpty) return;
    for (final id in _selected) {
      ref.read(connectionProvider).sendCommand({'cmd': 'session_delete', 'id': id});
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    _refresh();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 【0.2.1 #7】三横按钮（tab 模式打开 Drawer）；选择模式显示关闭
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }))
            : (widget.onOpenDrawer != null
                ? IconButton(
                    icon: const Icon(Icons.menu, size: 22),
                    onPressed: widget.onOpenDrawer,
                  )
                : null),
        title: Text(_selectMode ? trp('sess_selected', {'p0': '${_selected.length}'}) : tr('cfg_session_manager')),
        actions: [
          if (_selectMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.brandRed),
              onPressed: _batchDelete,
            )
          else ...[
            IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _create),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
          ],
        ],
      ),
      body: _offline
          ? Column(
              children: [
                // 【0.2.1 #1】离线只读横幅
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.brandCyan.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 16, color: AppColors.brandCyan),
                      const SizedBox(width: 8),
                      Text(tr('sess_offline_read_only_mode_showing_cached'),
                          style: const TextStyle(fontSize: 12, color: AppColors.brandCyan)),
                    ],
                  ),
                ),
                Expanded(child: _buildList()),
              ],
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(child: Text(tr('sess_no_sessions'), style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final id = s['id']?.toString() ?? '';
                    final sel = _selected.contains(id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: sel ? AppColors.surface.withValues(alpha: 0.8) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: sel ? const BorderSide(color: AppColors.brandCyan) : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(
                          sel ? Icons.check_circle : Icons.chat_bubble_outline,
                          size: 20,
                          color: sel ? AppColors.brandCyan : AppColors.brandCyan,
                        ),
                        title: Text(s['title']?.toString() ?? tr('sess_untitled'),
                            style: const TextStyle(fontSize: 14)),
                        // 【0.2.1 9.1】会话占用显示（token 占用/消息数——服务端 session_list 已带 token_total）
                        subtitle: Text(
                            trp('sess_message_count', {
                              'p0': (s['message_count']?.toString() ?? '0'),
                              'p1': _fmtTokens(s['token_total']),
                              'p2': s['updated'] != null ? _fmtTime(s['updated']) : '',
                            }),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: _selectMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.drive_file_rename_outline, size: 18),
                                      onPressed: () => _rename(id)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => _delete(id)),
                                ],
                              ),
                        // 【0.1.9】点击进入对话页；长按进入多选
                        onTap: () => _selectMode ? _toggleSelect(id) : _openChat(id),
                        onLongPress: () => setState(() {
                          _selectMode = true;
                          _selected.add(id);
                        }),
                      ),
                    );
                  },
                );
  }

  String _fmtTime(dynamic ts) {
    if (ts is! num) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000);
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inMinutes < 1) return tr('sess_just_now');
    if (d.inHours < 1) return trp('sess_min_ago', {'p0': '${d.inMinutes}'});
    if (d.inDays < 1) return trp('sess_h_ago', {'p0': '${d.inHours}'});
    return '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

  /// 【0.2.1 9.1】token 占用格式化（K/M 单位）
  String _fmtTokens(dynamic v) {
    if (v is! num || v <= 0) return '0 token';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M token';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K token';
    return '${v.toInt()} token';
  }
