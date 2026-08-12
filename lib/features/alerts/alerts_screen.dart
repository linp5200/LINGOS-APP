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
          Map<String, dynamic>? resp;
          // 【0.1.9】兼容 String（再解析）与 Map（直接）
          if (data is String) {
            final decoded = jsonDecode(data);
            if (decoded is Map) resp = Map<String, dynamic>.from(decoded);
          } else if (data is Map) {
            resp = Map<String, dynamic>.from(data);
          }
          if (resp == null || resp['status'] != 'ok') {
            setState(() => _loading = false);
            return;
          }
          // 【0.1.9】alert_query 返回 {status,count,events:[...]}——从 events 取
          final events = resp['events'] ?? resp['data'];
          if (events is List) {
            setState(() {
              _alerts = events.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
              _loading = false;
            });
          } else {
            setState(() {
              _alerts = [];
              _loading = false;
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
                        title: Text(
                            a['title']?.toString() ??
                                a['description']?.toString() ??
                                '预警',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          if (a['location']?.toString().isNotEmpty ?? false) a['location'].toString(),
                          if (a['source']?.toString().isNotEmpty ?? false) '来源: ${a['source']}',
                          if (a['type']?.toString().isNotEmpty ?? false) '类型: ${a['type']}',
                        ].join(' · ')),
                        trailing: Text(
                            a['time']?.toString() ??
                                (a['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch((a['timestamp'] as num).toInt() * 1000).toString().substring(5, 16) : ''),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    );
                  },
                ),
    );
  }
}
