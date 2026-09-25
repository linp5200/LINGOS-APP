/// 主控台（先生 lingos-app-preview-final 对照——本地/连接双态首页）
/// 本地态：版本真值/主机--/本地服务入口/连接主机引导（不模拟假数据）
/// 【0.7.0】连接态：概览卡升级为 server 真数据（CPU/内存/磁盘/版本/运行时间 5s 刷新）
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../connect/connect_screen.dart';
import '../alerts/alerts_screen.dart';
import '../sessions/sessions_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const HomeScreen({super.key, this.onOpenDrawer});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;
  bool _connected = false;
  Map<String, dynamic> _info = {};   // server system_info data

  @override
  void initState() {
    super.initState();
    // 监听连接状态（Riverpod 监听在 build 里更惯用；这里用定时器统一驱动）
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final cm = ref.read(connectionProvider);
    // 【0.7.0】连接判定：复用 ConnectionManager 的 isConnected（WS/TCP 任一活）
    final conn = cm.isConnected;
    if (!conn) {
      if (mounted && (_connected || _info.isNotEmpty)) {
        setState(() {
          _connected = false;
          _info = {};
        });
      }
      return;
    }
    try {
      final resp = await cm.requestJson({'cmd': 'system_info'},
          timeout: const Duration(seconds: 6));
      final d = resp?['data'];
      Map<String, dynamic>? inner;
      if (d is Map && d['data'] is Map) {
        inner = Map<String, dynamic>.from(d['data'] as Map);
      } else if (d is Map) {
        inner = Map<String, dynamic>.from(d);
      }
      if (!mounted) return;
      setState(() {
        _connected = true;
        if (inner != null) _info = inner;
      });
    } catch (_) {
      if (mounted) setState(() => _connected = true);
    }
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String _num(String k, {int digits = 0, String unit = ''}) {
    final v = _info[k];
    if (v is num) return '${v.toStringAsFixed(digits)}$unit';
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          onPressed: widget.onOpenDrawer,
        ),
        title: const Text('主控台'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: _connected ? AppColors.green : AppColors.amber,
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_connected ? 'ONLINE' : 'LOCAL',
                    style: TextStyle(
                        fontFamily: fuiMono,
                        fontSize: 10,
                        color: _connected ? AppColors.green : AppColors.amber)),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _tick,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // 【0.7.0】连接态：server 真数据概览（此前只有"本地"纯占位）
            if (_connected) ...[
              _section(context, '系统状态 · SERVER'),
              Row(children: [
                Expanded(child: _card('服务器版本', AppInfo.serverInternalVersion ?? '--', 'LN')),
                const SizedBox(width: 8),
                Expanded(child: _card('运行时间', _uptime(), 'UPTIME')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _card('CPU', _num('cpu_usage', digits: 1, unit: '%'), 'LOAD')),
                const SizedBox(width: 8),
                Expanded(child: _card('内存空闲', _memFree(), 'RAM')),
                const SizedBox(width: 8),
                Expanded(child: _card('磁盘', _num('disk_usage', digits: 1, unit: '%'), 'DISK')),
              ]),
              const SizedBox(height: 16),
            ] else ...[
              _section(context, '系统状态 · 本地'),
              Row(children: [
                Expanded(child: _card('主机', '--', '需连接', warn: true)),
                const SizedBox(width: 8),
                Expanded(child: _card('App 版本', AppInfo.tag, '本地')),
              ]),
              const SizedBox(height: 16),
            ],
            _section(context, '服务入口'),
            _item(context, Icons.chat_bubble_outline, '对话 AI',
                _connected ? 'CHAT · 已连接' : 'CHAT · 需主机模型',
                _connected ? AppColors.green : AppColors.gray,
                () => _toast(context, _connected ? '请在底部「对话」标签使用' : '会话需连接主机后使用')),
            _item(context, Icons.notifications_outlined, '预警', 'ALERT · 本地',
                AppColors.green, () => _push(context, const AlertsScreen())),
            _item(context, Icons.forum_outlined, '会话', 'SESSIONS · 本地缓存',
                AppColors.gray, () => _push(context, SessionsScreen(onOpenDrawer: widget.onOpenDrawer))),
            _item(context, Icons.link, '连接主机', 'CONNECT · 同步后可用全部功能',
                AppColors.green, () => _push(context, const ConnectScreen())),
            _item(context, Icons.videocam_outlined, '摄像头',
                _connected ? 'MONITOR · 在线' : 'MONITOR · 需连接主机',
                _connected ? AppColors.green : AppColors.gray,
                () => _toast(context, _connected ? '请在 设置→视觉 中查看' : '监控需连接主机')),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                  _connected
                      ? '已连接：数据每 5 秒自动刷新（下拉可手动刷新）'
                      : '连接后：此屏变为 server 真数据控制台（CPU/内存/磁盘实时）',
                  style: const TextStyle(
                      fontFamily: fuiMono, fontSize: 9, color: AppColors.dim, height: 1.8)),
            ),
          ],
        ),
      ),
    );
  }

  String _uptime() {
    final v = _info['uptime'];
    if (v is num) {
      final h = v ~/ 3600;
      final m = (v % 3600) ~/ 60;
      return h > 0 ? '${h}h${m}m' : '${m}m';
    }
    return '--';
  }

  String _memFree() {
    final free = _info['free_ram'];
    final total = _info['total_ram'];
    if (free is num && total is num && total > 0) {
      return '${(free / 1024).toStringAsFixed(0)}/${(total / 1024).toStringAsFixed(0)}MB';
    }
    return '--';
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 14, height: 1, color: AppColors.line),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontFamily: fuiMono,
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.gray)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.lineDim)),
      ]),
    );
  }

  Widget _card(String label, String value, String sub, {bool warn = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.lineDim),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.dim)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: const TextStyle(
                  fontFamily: fuiMono,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white)),
        ),
        Text(sub,
            style: TextStyle(fontSize: 9, color: warn ? AppColors.amber : AppColors.dim)),
      ]),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String sub,
      Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, size: 22, color: color),
      title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(sub,
          style: const TextStyle(fontFamily: fuiMono, fontSize: 9, color: AppColors.dim)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
      onTap: onTap,
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2)));
  }
}
