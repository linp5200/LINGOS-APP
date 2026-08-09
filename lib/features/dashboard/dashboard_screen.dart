/// 仪表盘（协议 v3——系统信息真实数据——无 mock）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

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
          if (data is String) {
            final resp = jsonDecode(data);
            if (resp is Map && resp['status'] == 'ok') {
              final info = resp['data'];
              if (info is Map) {
                setState(() {
                  _info = Map<String, dynamic>.from(info);
                  _loading = false;
                });
              }
            }
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
      appBar: AppBar(title: const Text('仪表盘'), actions: [
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
