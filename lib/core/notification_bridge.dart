/// LING OS 通知桥（【0.7.0 P3】后台推送）
///
/// 先生设定："App 不在前台 → 收不到预警/危机推送（只有前台 WS 链）"
///   → 本桥：全局订阅连接事件流，按生命周期与级别决定是否发本地通知：
///     · crisis_alert / crisis_repush  → 始终发（critical——生命线，绕过静默）
///     · alert_event L2+              → 非前台时发（前台由预警页横幅呈现）
///     · 保持轻量：解析失败静默，不影响事件主链
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'services/notification_service.dart';
import 'storage/app_store.dart';   // 【0.7.0-hf2】通知开关接线

class NotificationBridge extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBridge({super.key, required this.child});

  @override
  ConsumerState<NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends ConsumerState<NotificationBridge>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _sub;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  final _store = AppStore();   // 【0.7.0-hf2】读取用户通知开关

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _sub = ref.read(connectionProvider).events.listen(_onEvent);
    } catch (_) {
      _sub = null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  Future<void> _onEvent(dynamic line) async {
    try {
      final m = jsonDecode(line.toString());
      if (m is! Map) return;
      final type = m['type']?.toString() ?? '';
      final raw = m['data'];
      Map<String, dynamic> d = {};
      if (raw is Map) {
        d = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        final dec = jsonDecode(raw);
        if (dec is Map) d = Map<String, dynamic>.from(dec);
      }

      // ① 危机/生命线——始终 critical 通知（生命线不可静音——先生铁律）
      if (type == 'crisis_alert' || type == 'crisis_repush') {
        final fg = _lifecycle == AppLifecycleState.resumed;
        if (!fg) {
          NotificationService.instance.showCritical(
            '🚨 ${d['name'] ?? '危机'}警报',
            (d['detail']?.toString().isNotEmpty ?? false)
                ? d['detail'].toString()
                : '请立即打开 App 查看处置面板',
            payload: 'crisis:${d['crisis_id'] ?? ''}',
          );
        }
      }

      // ② 预警事件——非前台时按级别推送（L2+）；【0.7.0-hf2】读取「预警通知」开关
      if (type == 'alert_event') {
        final lvl = int.tryParse('${d['level']}') ?? 0;
        final fg = _lifecycle == AppLifecycleState.resumed;
        final on = await _store.getPrefBool('notif_alert', true);
        if (!fg && lvl >= 2 && on) {
          NotificationService.instance.show(
            '⚠️ ${d['type'] ?? '预警'}（L$lvl）',
            d['description']?.toString() ?? '',
            id: 900 + lvl,
          );
        }
      }

      // ③ 【0.7.0-hf2】服务端通知推送（notify_event——AI/任务/预警联动）→ 本地通知
      //   前台也应提示（轻量）——但避免与自身 UI 重复：仅非前台弹系统通知。
      if (type == 'notify_event') {
        final fg = _lifecycle == AppLifecycleState.resumed;
        final on = await _store.getPrefBool('notif_task', true);
        final lv = d['level']?.toString() ?? 'info';
        if (!fg && on) {
          if (lv == 'critical' || lv == 'error') {
            NotificationService.instance.showCritical(
              d['title']?.toString() ?? '通知',
              d['body']?.toString() ?? '',
              id: 700 + lv.length,
            );
          } else {
            NotificationService.instance.show(
              d['title']?.toString() ?? '通知',
              d['body']?.toString() ?? '',
              id: 700 + lv.length,
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
