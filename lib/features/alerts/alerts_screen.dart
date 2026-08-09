/// 预警中心（协议 v3——alert_query 查询预警）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = false;
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
              final list = resp['data'];
              if (list is List) {
                setState(() {
                  _alerts = list.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
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

  void _refresh() {
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'alert_query'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('预警中心'), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _refresh),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text('暂无预警', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _refresh, child: const Text('刷新')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (ctx, i) {
                    final a = _alerts[i];
                    final level = a['level']?.toString() ?? 'info';
                    final color = level.contains('high') || level.contains('critical')
                        ? AppColors.brandRed
                        : level.contains('medium') || level.contains('warn')
                            ? Colors.orange
                            : AppColors.brandCyan;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber_rounded, color: color, size: 22),
                        title: Text(a['title']?.toString() ?? '预警',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(a['message']?.toString() ?? a['content']?.toString() ?? ''),
                        trailing: Text(a['time']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    );
                  },
                ),
    );
  }
}
