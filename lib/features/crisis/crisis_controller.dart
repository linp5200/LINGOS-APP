/// 危机响应控制器（§2B 危险时刻全权响应——App 端）
/// 监听 crisis_alert / crisis_resolved 事件 → 全屏告警卡 + ACK 回执
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/protocol/events.dart';

/// 危机状态（全局——HomeShell 顶层监听）
class CrisisState {
  final bool active;
  final Map<String, dynamic>? data;
  /// 已弹出的告警 ID（防重复弹窗——同一危机只弹一次）
  final String shownId;

  const CrisisState({this.active = false, this.data, this.shownId = ''});

  String get crisisId => data?['crisis_id']?.toString() ?? '';
  String get name => data?['name']?.toString() ?? '危机';
  String get crisisType => data?['crisis_type']?.toString() ?? '';
  String get source => data?['source']?.toString() ?? '';
  String get detail => data?['detail']?.toString() ?? '';
  bool get acked => data?['acked'] == true;
  List get actions => (data?['actions'] is List) ? (data!['actions'] as List) : const [];

  CrisisState copyWith({bool? active, Map<String, dynamic>? data, String? shownId}) =>
      CrisisState(active: active ?? this.active, data: data ?? this.data, shownId: shownId ?? this.shownId);
}

class CrisisController extends StateNotifier<CrisisState> {
  final Ref ref;
  StreamSubscription? _sub;

  CrisisController(this.ref) : super(const CrisisState()) {
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
  }

  void _onEvent(String line) {
    final evt = LingEvent.parse(line);
    if (evt == null) return;
    switch (evt.type) {
      case EvtType.crisisAlert:
        final d = (evt.data['data'] is Map) ? Map<String, dynamic>.from(evt.data['data']) : <String, dynamic>{};
        state = CrisisState(active: true, data: d, shownId: state.shownId);
      case EvtType.crisisResolved:
        final d = (evt.data['data'] is Map) ? Map<String, dynamic>.from(evt.data['data']) : <String, dynamic>{};
        state = CrisisState(active: false, data: d, shownId: state.shownId);
      case EvtType.chatEvent:
        final inner = evt.data['data'];
        if (inner is Map) _onEvent(jsonEncode(inner));
    }
  }

  /// 用户「我已知情」→ 回执服务端（记录 ACK 时间——生命线投递确认）
  Future<void> acknowledge() async {
    try {
      await ref.read(connectionProvider).sendCommand({'cmd': 'crisis_ack'});
      final d = Map<String, dynamic>.from(state.data ?? {});
      d['acked'] = true;
      state = state.copyWith(data: d);
    } catch (_) {}
  }

  /// 标记弹窗已展示（防重复）
  void markShown() {
    state = state.copyWith(shownId: state.crisisId);
  }

  /// 主动查询一次危机状态（连接恢复时）
  Future<void> refresh() async {
    try {
      final resp = await ref.read(connectionProvider).requestJson({'cmd': 'crisis_status'});
      if (resp != null && resp['status'] == 'ok') {
        final d = (resp['data'] is Map) ? Map<String, dynamic>.from(resp['data']) : <String, dynamic>{};
        state = CrisisState(active: d['active'] == true, data: d, shownId: state.shownId);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final crisisProvider = StateNotifierProvider<CrisisController, CrisisState>((ref) {
  return CrisisController(ref);
});
