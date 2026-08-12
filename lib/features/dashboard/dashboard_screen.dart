/// 仪表盘（协议 v3——系统信息真实数据——无 mock）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  // 【A1修复】三横按钮回调（HomeShell 打开 Drawer）
  final VoidCallback? onOpenDrawer;
  const DashboardScreen({super.key, this.onOpenDrawer});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _info;
  bool _loading = false;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen((line) {
      try {
        final evt = jsonDecode(line);
        if (evt is Map && evt['type'] == 'command_response') {
          final data = evt['data'];
          Map<String, dynamic>? resp;
          // 【0.1.9】兼容 String（再解析）与 Map（直接）
          if (data is String) {
            final decoded = jsonDecode(data);
            if (decoded is Map) resp = Map<String, dynamic>.from(decoded);
          } else if (data is Map) {
            resp = Map<String, dynamic>.from(data);
          }
          if (resp == null) {
            setState(() {
              _loading = false;
              _info = null;
              _error = '核心数据无有效响应（格式异常）';
            });
            return;
          }
          final r = resp; // final 提升——闭包内可用（修复 nullable 闭包报错）
          if (r['status'] != 'ok') {
            setState(() {
              _loading = false;
              _info = null;
              _error = '获取失败：${r['msg'] ?? r['message'] ?? '未知错误'}';
            });
            return;
          }
          final info = resp['data'];
          if (info is Map && info.isNotEmpty) {
            setState(() {
              _info = Map<String, dynamic>.from(info);
              _loading = false;
              _error = null;
            });
          } else {
            setState(() {
              _loading = false;
              _info = null;
              _error = '核心数据为空（服务端无有效数据）';
            });
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(connectionProvider).sendCommand({'cmd': 'system_info'});
    // 响应经事件流返回（command_response）
    if (!ok) setState(() { _loading = false; _error = '命令发送失败'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 【0.1.9】左上角三横——打开 Drawer（经回调——修复 Scaffold.of 跨层失效）
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          onPressed: widget.onOpenDrawer,
        ),
        title: const Text('仪表盘'),
        actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.brandRed)))
              : _info == null
                  ? const Center(child: Text('点击刷新获取系统状态', style: TextStyle(color: AppColors.textSecondary)))
                  : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final cpu = _info?['cpu_usage']?.toString() ?? '--';
    final mem = _info?['memory_usage']?.toString() ?? '--';
    final disk = _info?['disk_usage']?.toString() ?? '--';
    final net = _info?['network_rx']?.toString() ?? '--';
    final uptime = _info?['uptime']?.toString() ?? '--';
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _card(Icons.memory, 'CPU', '$cpu%', AppColors.brandCyan),
        _card(Icons.storage, '内存', '$mem%', AppColors.brandRed),
        _card(Icons.storage_rounded, '磁盘', '$disk%', Colors.orange),
        _card(Icons.network_check, '网络', net, Colors.green),
        _card(Icons.timer_outlined, '运行时长', '$uptime s', AppColors.textSecondary),
        _card(Icons.info_outline, '状态', _info?['status']?.toString() ?? '--', AppColors.brandCyan),
      ],
    );
  }

  Widget _card(IconData icon, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
