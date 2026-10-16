/// 预警中心（协议 v3——alert_query 查询 + alert_event 实时广播）
/// 【0.4.4】新增 alert_event 实时消费（此前仅轮询）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

// ============================================================
// 【追加·先生已批】预警级别口径（与三端逐值对齐，2026-10-16）
//   C 端   src/alert/alert_utils.c:alert_level_label → 0=info，1..5=L1..L5
//   Python alert_store.py / cmd_alert_query          → 同口径（旧历史文件为整数 level）
//   WebUI  webui/index.html normLevel()/lvHigh()     → 同口径（L0=urgent 通道）
//   高危 = L0 紧急 / L3 橙 / L4 红 / L5 危急（最高）——必须醒目，不得降级显示
// ============================================================
class _AlertLevel {
  _AlertLevel._();

  /// 归一：''/0/'info' → 'info'；1..5（整数或字符串）→ 'L1'..'L5'；其余原样大写
  static String norm(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s.isEmpty || s == 'INFO' || s == '0') return 'info';
    if (s.length == 1 && s.codeUnitAt(0) >= 0x31 && s.codeUnitAt(0) <= 0x35) {
      return 'L$s'; // 旧数据：整数级别 1..5
    }
    return s;
  }

  /// 高危判定（保留旧英文取值 high/critical/emergency，不丢既有行为）
  static bool isHigh(String key) {
    if (key == 'L0' || key == 'L3' || key == 'L4' || key == 'L5') return true;
    return key.contains('HIGH') || key.contains('CRITICAL') || key.contains('EMERG');
  }

  /// 配色（与 WebUI lvColor 同色系：红=最高/橙=高危起点/琥珀=注意/蓝=提示/灰=信息）
  static Color color(String key) {
    if (key == 'L0' || key == 'L4' || key == 'L5') return AppColors.brandRed;
    if (key == 'L3') return const Color(0xFFFF9F45);
    if (key == 'L2') return AppColors.amber;
    if (key == 'L1') return AppColors.blue;
    return AppColors.dim;
  }

  /// 展示标签：info 走 i18n，L0..L5 原样（与 WebUI 标签一致）
  static String label(String key) => key == 'info' ? tr('alert_level_info') : key;
}

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
        // 【0.4.4 新增】服务端实时广播 alert_event（alertd → ai_server → WS）
        //   此前 App 只有 alert_query 轮询 → 预警不能即时弹出（先生实测反馈）
        if (evt is Map && evt['type'] == 'alert_event') {
          final payload = evt['data'] ?? evt['alert'] ?? evt;
          if (payload is Map) {
            final a = Map<String, dynamic>.from(payload);
            setState(() {
              _alerts.insert(0, a);
              if (_alerts.length > 200) _alerts.removeLast();
            });
            _showBanner(a);
          }
          return;
        }
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

  /// 实时预警横幅（先生：预警需即时可见）
  void _showBanner(Map<String, dynamic> a) {
    if (!mounted) return;
    final title = a['title']?.toString() ??
        a['description']?.toString() ??
        tr('alert_new');
    // 【追加】三端口径归一（原实现只认 'L3'，L0/L4/L5 与整数级别都被当普通预警）
    final levelKey = _AlertLevel.norm(a['level']);
    final isHigh = _AlertLevel.isHigh(levelKey);
    final shown =
        isHigh ? '[${_AlertLevel.label(levelKey)}] $title' : title;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isHigh ? AppColors.brandRed : AppColors.surfaceHigh,
        content: Row(children: [
          Icon(isHigh ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
              size: 18, color: isHigh ? Colors.white : AppColors.brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(shown,
                style: TextStyle(
                    fontSize: 12,
                    color: isHigh ? Colors.white : AppColors.textPrimary)),
          ),
        ]),
        duration: Duration(seconds: isHigh ? 8 : 4),
      ),
    );
  }

  void _refresh() {
    setState(() => _loading = true);
    ref.read(connectionProvider).sendCommand({'cmd': 'alert_query'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('alert_title')), actions: [
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
                      Text(tr('alert_none'), style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _refresh, child: Text(tr('refresh'))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (ctx, i) {
                    final a = _alerts[i];
                    // 【追加】级别口径与三端一致：info/L0–L5（原实现只按 high/medium 英文子串，
                    //   L3/L4/L5 一律显示成 brandCyan"信息色"——红级预警最不显眼）
                    final levelKey = _AlertLevel.norm(a['level']);
                    final high = _AlertLevel.isHigh(levelKey);
                    final color = _AlertLevel.color(levelKey);
                    final ts = a['timestamp'];
                    final timeText = a['time']?.toString() ??
                        (ts is num
                            ? DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000)
                                .toString()
                                .substring(5, 16)
                            : '');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      // 高危：卡片描边同色（与 WebUI 的左边框/加粗同风格）
                      shape: high
                          ? RoundedRectangleBorder(
                              side: BorderSide(color: color, width: 1.2),
                              borderRadius: BorderRadius.circular(8))
                          : null,
                      child: ListTile(
                        leading: Icon(
                            high
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_active_outlined,
                            color: color,
                            size: 22),
                        title: Text(
                            a['title']?.toString() ??
                                a['description']?.toString() ??
                                tr('alert_generic'),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: high ? color : null)),
                        subtitle: Text([
                          if (a['location']?.toString().isNotEmpty ?? false) a['location'].toString(),
                          if (a['source']?.toString().isNotEmpty ?? false) '${tr('alert_source')}${a['source']}',
                          if (a['type']?.toString().isNotEmpty ?? false) '${tr('alert_type')}${a['type']}',
                        ].join(' · ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: color),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(_AlertLevel.label(levelKey),
                                style: TextStyle(
                                    fontFamily: fuiMono,
                                    fontSize: 10,
                                    color: color,
                                    fontWeight:
                                        high ? FontWeight.w700 : FontWeight.w400)),
                          ),
                          if (timeText.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(timeText,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
