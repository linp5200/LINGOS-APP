/// LING OS App 扩展功能屏（先生 2026-09-12 · 0.5.0/0.5.1）
///
/// 对应服务端 ext_dispatch 的 82 个扩展命令：
///   · HomeExtScreen    智能家居（场景/区域/围栏/能源/自动化）
///   · TimelineScreen   监控时间线 + 存储
///   · NotifyScreen     通知中心（含免打扰）
///   · MediaScreen      媒体播放器控制
///   · KbScreen         知识库（上传 + RAG 检索）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// 通用：发送命令并监听对应响应（各屏共用）
mixin _ExtMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  StreamSubscription? extSub;
  final Map<String, dynamic> extData = {};

  void extInit(List<String> listenCmds) {
    extSub = ref.read(connectionProvider).events.listen((line) {
      try {
        final evt = jsonDecode(line);
        if (evt is! Map || evt['type'] != 'command_response') return;
        final data = evt['data'];
        Map<String, dynamic>? resp;
        if (data is String) {
          final d = jsonDecode(data);
          if (d is Map) resp = Map<String, dynamic>.from(d);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null) return;
        final cmds = resp['cmd'];
        if (cmds is! String) return;
        if (!listenCmds.contains(cmds) && !listenCmds.contains(cmds.trim())) return;
        setState(() {
          extData[cmds.trim()] = resp!['data'] ?? resp;
          extData['_status_$cmds'] = resp!['status'];
        });
      } catch (_) {}
    });
  }

  void extSend(String cmd, [Map<String, dynamic>? params]) {
    final m = <String, dynamic>{'cmd': cmd};
    if (params != null) m.addAll(params);
    ref.read(connectionProvider).sendCommand(m);
  }

  @override
  void dispose() {
    extSub?.cancel();
    super.dispose();
  }
}

// ============================================================
// 智能家居
// ============================================================
class HomeExtScreen extends ConsumerStatefulWidget {
  const HomeExtScreen({super.key});
  @override
  ConsumerState<HomeExtScreen> createState() => _HomeExtScreenState();
}

class _HomeExtScreenState extends ConsumerState<HomeExtScreen>
    with _ExtMixin<HomeExtScreen> {
  @override
  void initState() {
    super.initState();
    extInit(['home_overview', 'scene_list', 'area_list', 'zone_list', 'energy_summary', 'automation_list', 'discovery_list']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    extSend('home_overview');
    extSend('scene_list');
    extSend('area_list');
    extSend('zone_list');
    extSend('energy_summary', {'hours': 24});
    extSend('automation_list');
    extSend('discovery_list');
  }

  Future<void> _createScene() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('新建场景', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: c,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(hintText: '场景名称', hintStyle: TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      extSend('scene_create', {'name': name});
      await Future.delayed(const Duration(milliseconds: 400));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('智能家居'), actions: [
        IconButton(icon: const Icon(Icons.search, size: 20), onPressed: () {
          extSend('discovery_scan');
        }),
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
      ]),
      body: !connected
          ? const Center(child: Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)))
          : ListView(padding: const EdgeInsets.all(14), children: [
              _statRow(),
              const SizedBox(height: 12),
              _section('场景', extData['scene_list'], Icons.movie_filter_outlined,
                  onAdd: _createScene),
              _section('区域', extData['area_list'], Icons.meeting_room_outlined),
              _section('地理围栏', extData['zone_list'], Icons.place_outlined),
              _section('自动化', extData['automation_list'], Icons.auto_mode_outlined),
              _energyCard(),
              _section('发现的设备', extData['discovery_list'], Icons.devices_other_outlined),
            ]),
    );
  }

  Widget _statRow() {
    final ov = extData['home_overview'];
    final d = (ov is Map) ? ov : const {};
    final items = [
      ['场景', d['scenes']],
      ['区域', d['areas']],
      ['围栏', d['zones']],
      ['自动化', d['automations']],
    ];
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.lineDim),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Text(it[1] == null ? '--' : '${it[1]}',
                  style: const TextStyle(
                      fontFamily: fuiMono, fontSize: 16, color: AppColors.brandGreen)),
              const SizedBox(height: 3),
              Text(it[0] as String,
                  style: const TextStyle(fontSize: 10, color: AppColors.dim)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _section(String title, dynamic list, IconData icon, {VoidCallback? onAdd}) {
    final items = (list is List) ? list : const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.lineDim),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (onAdd != null)
              InkWell(onTap: onAdd, child: const Text('＋ 新建',
                  style: TextStyle(fontSize: 10, color: AppColors.brandGreen))),
          ]),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('暂无（显示 -- 不模拟）',
                style: TextStyle(fontSize: 10, color: AppColors.dim))
          else
            ...items.take(8).map<Widget>((e) {
              final m = (e is Map) ? e : const {};
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Container(width: 4, height: 4, decoration: const BoxDecoration(
                      color: AppColors.brandGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      (m['name'] ?? m['title'] ?? m['entity_id'] ?? '?').toString(),
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (m['trigger'] != null)
                    Text('${m['trigger']}',
                        style: const TextStyle(fontSize: 9, color: AppColors.dim)),
                ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _energyCard() {
    final e = extData['energy_summary'];
    final m = (e is Map) ? e : const {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lineDim),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt_outlined, size: 15, color: AppColors.brandAmber),
          SizedBox(width: 6),
          Text('能源（24h）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _metric('用电', m['total_energy_kwh'], 'kWh'),
          _metric('费用', m['total_cost'], '${m['currency'] ?? ''}'),
          _metric('电价', m['tariff'], ''),
        ]),
      ]),
    );
  }

  Widget _metric(String label, dynamic v, String unit) {
    return Expanded(
      child: Column(children: [
        Text(v == null ? '--' : '$v$unit',
            style: const TextStyle(fontFamily: fuiMono, fontSize: 13, color: AppColors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.dim)),
      ]),
    );
  }
}

// ============================================================
// 时间线 / NVR
// ============================================================
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});
  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with _ExtMixin<TimelineScreen> {
  @override
  void initState() {
    super.initState();
    extInit(['nvr_overview', 'timeline_segments', 'timeline_query', 'storage_status']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    extSend('nvr_overview');
    extSend('timeline_segments', {'hours': 24});
    extSend('timeline_query', {'hours': 24, 'limit': 100});
    extSend('storage_status');
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final seg = extData['timeline_segments'];
    final segs = (seg is Map && seg['segments'] is List) ? (seg['segments'] as List) : const [];
    final tq = extData['timeline_query'];
    final items = (tq is Map && tq['items'] is List) ? (tq['items'] as List) : const [];
    final st = extData['storage_status'];
    final stm = (st is Map) ? st : const {};
    final ov = extData['nvr_overview'];
    final ovm = (ov is Map) ? ov : const {};

    return Scaffold(
      appBar: AppBar(title: const Text('监控时间线'), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
      ]),
      body: !connected
          ? const Center(child: Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)))
          : ListView(padding: const EdgeInsets.all(14), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.lineDim),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('24 小时事件  ·  ${ovm['timeline_events'] ?? '--'} 条',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 62,
                    child: segs.isEmpty
                        ? const Center(
                            child: Text('无事件（显示 -- 不模拟）',
                                style: TextStyle(fontSize: 10, color: AppColors.dim)))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: segs.map<Widget>((s) {
                              final m = (s is Map) ? s : const {};
                              final total = ((m['motion'] ?? 0) as num) +
                                  ((m['object'] ?? 0) as num) +
                                  ((m['other'] ?? 0) as num);
                              final obj = ((m['object'] ?? 0) as num) > 0;
                              final h = total <= 0 ? 2.0 : (total * 4.0).clamp(2.0, 58.0);
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0.5),
                                  child: Container(
                                    height: h,
                                    decoration: BoxDecoration(
                                      color: obj
                                          ? AppColors.blue
                                          : (total > 0 ? AppColors.brandGreen : AppColors.lineDim),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 4),
                  const Text('每柱=1 小时 · 绿=移动 · 蓝=对象',
                      style: TextStyle(fontSize: 8, color: AppColors.dim)),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.lineDim),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('存储',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('已用 ${stm['used_gb'] ?? '--'} GB / 上限 ${stm['limit_gb'] ?? '--'} GB',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text('录像 ${stm['recordings'] ?? '--'} 段 · 含对象 ${stm['object_recordings'] ?? '--'} 段',
                      style: const TextStyle(fontSize: 10, color: AppColors.dim)),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('事件列表', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              if (items.isEmpty)
                const Text('暂无事件', style: TextStyle(fontSize: 10, color: AppColors.dim))
              else
                ...items.reversed.take(30).map<Widget>((e) {
                  final m = (e is Map) ? e : const {};
                  final ts = (m['ts'] is num)
                      ? DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt() * 1000)
                      : null;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        m['kind'] == 'object' ? Icons.person_outline : Icons.directions_run,
                        size: 16,
                        color: AppColors.brandGreen),
                    title: Text('${m['kind'] ?? '?'}  ${m['camera'] ?? ''}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                        ts == null
                            ? ''
                            : '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10, color: AppColors.dim)),
                  );
                }),
            ]),
    );
  }
}

// ============================================================
// 通知中心
// ============================================================
class NotifyCenterScreen extends ConsumerStatefulWidget {
  const NotifyCenterScreen({super.key});
  @override
  ConsumerState<NotifyCenterScreen> createState() => _NotifyCenterScreenState();
}

class _NotifyCenterScreenState extends ConsumerState<NotifyCenterScreen>
    with _ExtMixin<NotifyCenterScreen> {
  @override
  void initState() {
    super.initState();
    extInit(['notify_list']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() => extSend('notify_list', {'limit': 100});

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final d = extData['notify_list'];
    final m = (d is Map) ? d : const {};
    final items = (m['items'] is List) ? (m['items'] as List) : const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
              icon: const Icon(Icons.done_all, size: 20),
              tooltip: '全部已读',
              onPressed: () {
                extSend('notify_mark_read', {'all_items': true});
                Future.delayed(const Duration(milliseconds: 300), _refresh);
              }),
          IconButton(
              icon: Icon(m['dnd'] == true ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
                  size: 20),
              tooltip: '免打扰',
              onPressed: () {
                extSend('notify_dnd', {'enabled': m['dnd'] != true});
                Future.delayed(const Duration(milliseconds: 300), _refresh);
              }),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
        ],
      ),
      body: !connected
          ? const Center(child: Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(children: [
                  Text('共 ${m['total'] ?? '--'} · 未读 ${m['unread'] ?? '--'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  if (m['dnd'] == true)
                    const Text('免打扰中（critical 仍推送）',
                        style: TextStyle(fontSize: 10, color: AppColors.brandAmber)),
                ]),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('暂无通知', style: TextStyle(color: AppColors.dim)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final n = items[i];
                          final mm = (n is Map) ? n : const {};
                          final lv = (mm['level'] ?? 'info').toString();
                          final color = lv == 'critical' || lv == 'error'
                              ? AppColors.brandRed
                              : lv == 'warn'
                                  ? AppColors.brandAmber
                                  : AppColors.brandGreen;
                          final read = mm['read'] == true;
                          return Opacity(
                            opacity: read ? 0.5 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.lineDim),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3)),
                                    child: Text(lv.toUpperCase(),
                                        style: TextStyle(fontSize: 8, color: color)),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text('${mm['title'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                  if (mm['silenced'] == true)
                                    const Text('静默',
                                        style: TextStyle(fontSize: 9, color: AppColors.dim)),
                                ]),
                                if ((mm['body'] ?? '').toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('${mm['body']}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

// ============================================================
// 媒体控制
// ============================================================
class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});
  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen>
    with _ExtMixin<MediaScreen> {
  @override
  void initState() {
    super.initState();
    extInit(['media_list']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() => extSend('media_list');

  void _cmd(String entity, String c) {
    extSend('media_command', {'entity_id': entity, 'command': c});
    Future.delayed(const Duration(milliseconds: 250), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final l = extData['media_list'];
    final list = (l is List) ? l : const [];

    return Scaffold(
      appBar: AppBar(title: const Text('媒体控制'), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
      ]),
      body: !connected
          ? const Center(child: Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)))
          : list.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.music_off_outlined, size: 40, color: AppColors.dim),
                  SizedBox(height: 10),
                  Text('无媒体设备', style: TextStyle(color: AppColors.textSecondary)),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: list.map<Widget>((p) {
                    final m = (p is Map) ? p : const {};
                    final eid = '${m['entity_id'] ?? ''}';
                    final vol = ((m['volume'] ?? 0) as num).toDouble();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.lineDim),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.speaker_outlined, size: 15, color: AppColors.brandGreen),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(eid,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${m['state'] ?? 'idle'}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ]),
                        if ((m['media_title'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text('♪ ${m['media_title']}${(m['media_artist'] ?? '').toString().isNotEmpty ? ' · ${m['media_artist']}' : ''}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(height: 8),
                        Row(children: [
                          IconButton(
                              icon: const Icon(Icons.play_arrow, size: 20),
                              onPressed: () => _cmd(eid, 'play')),
                          IconButton(
                              icon: const Icon(Icons.pause, size: 20),
                              onPressed: () => _cmd(eid, 'pause')),
                          IconButton(
                              icon: const Icon(Icons.stop, size: 20),
                              onPressed: () => _cmd(eid, 'stop')),
                          IconButton(
                              icon: const Icon(Icons.volume_down, size: 20),
                              onPressed: () => _cmd(eid, 'volume_down')),
                          IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              onPressed: () => _cmd(eid, 'volume_up')),
                          const Spacer(),
                          Text('${(vol * 100).round()}%',
                              style: const TextStyle(
                                  fontFamily: fuiMono, fontSize: 11, color: AppColors.brandGreen)),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
    );
  }
}

// ============================================================
// 知识库（RAG）
// ============================================================
class KbScreen extends ConsumerStatefulWidget {
  const KbScreen({super.key});
  @override
  ConsumerState<KbScreen> createState() => _KbScreenState();
}

class _KbScreenState extends ConsumerState<KbScreen> with _ExtMixin<KbScreen> {
  final _pathCtl = TextEditingController();
  final _queryCtl = TextEditingController();
  List<Map<String, dynamic>> _hits = [];

  @override
  void initState() {
    super.initState();
    extInit(['kb_list', 'kb_ask', 'kb_upload']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _pathCtl.dispose();
    _queryCtl.dispose();
    super.dispose();
  }

  void _refresh() => extSend('kb_list');

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    final d = extData['kb_list'];
    final m = (d is Map) ? d : const {};
    final docs = (m['docs'] is List) ? (m['docs'] as List) : const [];

    return Scaffold(
      appBar: AppBar(title: const Text('知识库'), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
      ]),
      body: !connected
          ? const Center(child: Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)))
          : ListView(padding: const EdgeInsets.all(14), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.lineDim),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('文档 ${docs.length} 篇 · 分块 ${m['total_chunks'] ?? '--'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _pathCtl,
                        style: const TextStyle(fontSize: 11),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '/path/to/document',
                          hintStyle: TextStyle(fontSize: 11),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () {
                        final p = _pathCtl.text.trim();
                        if (p.isEmpty) return;
                        extSend('kb_upload', {'path': p});
                        Future.delayed(const Duration(milliseconds: 800), _refresh);
                      },
                      child: const Text('上传', style: TextStyle(fontSize: 11)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '输入问题检索知识库…',
                      hintStyle: TextStyle(fontSize: 11),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () {
                    final q = _queryCtl.text.trim();
                    if (q.isEmpty) return;
                    _hits = [];
                    extSend('kb_ask', {'query': q});
                    Future.delayed(const Duration(milliseconds: 800), () {
                      final r = extData['kb_ask'];
                      if (r is Map && r['retrieved'] is List) {
                        setState(() {
                          _hits = (r['retrieved'] as List)
                              .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
                              .toList();
                        });
                      }
                    });
                  },
                  child: const Text('检索', style: TextStyle(fontSize: 11)),
                ),
              ]),
              if (_hits.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('检索结果', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                ..._hits.map<Widget>((h) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.lineDim),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('${h['doc'] ?? ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${h['score'] ?? ''} · ${h['method'] ?? ''}',
                              style: const TextStyle(fontSize: 9, color: AppColors.dim)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${h['text'] ?? ''}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis),
                      ]),
                    )),
              ],
              const SizedBox(height: 14),
              const Text('文档列表', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              if (docs.isEmpty)
                const Text('知识库为空（显示 -- 不模拟）',
                    style: TextStyle(fontSize: 10, color: AppColors.dim))
              else
                ...docs.map<Widget>((doc) {
                  final dm = (doc is Map) ? doc : const {};
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        dm['has_vectors'] == true ? Icons.hub_outlined : Icons.text_snippet_outlined,
                        size: 16,
                        color: AppColors.brandGreen),
                    title: Text('${dm['name'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    subtitle: Text('${dm['chunks'] ?? 0} 块 · ${dm['chars'] ?? 0} 字符',
                        style: const TextStyle(fontSize: 9)),
                  );
                }),
            ]),
    );
  }
}
