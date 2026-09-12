/// 可选项设置屏（先生 2026-09-12 · 0.5.0）
///
/// 对应服务端 options_list / options_set / privacy_mode
/// 三档：🔒 底线（不可改） · 🟢 默认开 · 🔵 默认关
/// 危险开关需二次确认；需条件项标注提示。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  List<Map<String, dynamic>> _opts = [];
  bool _privacyMode = false;
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  static const _groups = ['安全', '隐私', '功能', '界面', '语音', 'AI', '数据', '连接'];

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
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
      // 只处理 options 相关响应
      final inner = resp['data'];
      Map<String, dynamic>? payload;
      if (inner is Map) {
        payload = Map<String, dynamic>.from(inner);
      } else if (resp['options'] is List) {
        payload = resp;
      }
      if (payload == null) return;
      if (payload['options'] is List) {
        setState(() {
          _opts = (payload!['options'] as List)
              .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
              .toList();
          _privacyMode = payload!['privacy_mode'] == true;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {}
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'options_list'});
  }

  Future<void> _toggle(Map<String, dynamic> o) async {
    if (o['kind'] == 0) return; // 底线不可改
    final cur = o['value'] == true;
    final dangerous = o['dangerous'] == true;
    if (dangerous && cur) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.brandRed, size: 20),
            SizedBox(width: 8),
            Text('危险操作', style: TextStyle(fontSize: 15)),
          ]),
          content: Text('「${o['name_zh']}」是危险开关，关闭会降低安全性。确定继续？',
              style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定', style: TextStyle(color: AppColors.brandRed)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    ref.read(connectionProvider).sendCommand({
      'cmd': 'options_set',
      'key': o['key'],
      'value': !cur,
      'force': true,
    });
    await Future.delayed(const Duration(milliseconds: 300));
    _refresh();
  }

  void _privacyModeApply(bool on) {
    ref.read(connectionProvider).sendCommand({'cmd': 'privacy_mode', 'enable': on});
    Future.delayed(const Duration(milliseconds: 400), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('可选项'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh),
        ],
      ),
      body: !connected
          ? _offline()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errView()
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _privacyCard(),
                        const SizedBox(height: 10),
                        ..._buildGroups(),
                      ],
                    ),
    );
  }

  Widget _offline() => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.dim),
          SizedBox(height: 10),
          Text('未连接主机', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('可选项需从主机读取', style: TextStyle(fontSize: 11, color: AppColors.dim)),
        ]),
      );

  Widget _errView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.brandRed),
          const SizedBox(height: 10),
          Text(_error ?? '加载失败', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TextButton(onPressed: _refresh, child: const Text('重试')),
        ]),
      );

  Widget _privacyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
            color: _privacyMode ? AppColors.brandGreen : AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined,
              size: 18,
              color: _privacyMode ? AppColors.brandGreen : AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('隐私保护模式',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(_privacyMode ? '已启用' : '未启用',
              style: TextStyle(
                  fontSize: 11,
                  color: _privacyMode ? AppColors.brandGreen : AppColors.dim)),
        ]),
        const SizedBox(height: 6),
        const Text('一次性开启全部安全增强 + 隐私技术',
            style: TextStyle(fontSize: 10, color: AppColors.dim)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _privacyModeApply(true),
              child: const Text('启用（最严）', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _privacyModeApply(false),
              child: const Text('恢复默认', style: TextStyle(fontSize: 11)),
            ),
          ),
        ]),
      ]),
    );
  }

  List<Widget> _buildGroups() {
    final out = <Widget>[];
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final o in _opts) {
      final g = (o['group'] is num) ? (o['group'] as num).toInt() : 0;
      grouped.putIfAbsent(g, () => []).add(o);
    }
    final keys = grouped.keys.toList()..sort();
    for (final g in keys) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text('▍${g < _groups.length ? _groups[g] : '其他'}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.brandGreen, letterSpacing: 1)),
      ));
      for (final o in grouped[g]!) {
        out.add(_optionTile(o));
      }
    }
    return out;
  }

  Widget _optionTile(Map<String, dynamic> o) {
    final kind = (o['kind'] is num) ? (o['kind'] as num).toInt() : 0;
    final value = o['value'] == true;
    final dangerous = o['dangerous'] == true;
    final needsCond = o['needs_condition'] == true;
    final locked = kind == 0;
    final locale = Localizations.localeOf(context).languageCode;
    final name = (locale == 'zh')
        ? (o['name_zh'] ?? o['key'])
        : (o['name_en'] ?? o['key']);
    final desc = (locale == 'zh') ? (o['desc_zh'] ?? '') : (o['desc_en'] ?? '');

    return InkWell(
      onTap: locked ? null : () => _toggle(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.lineDim),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
            locked
                ? Icons.lock_outline
                : (value ? Icons.toggle_on : Icons.toggle_off),
            size: 20,
            color: locked
                ? AppColors.dim
                : (value ? AppColors.brandGreen : AppColors.dim),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(fontSize: 12, color: AppColors.white),
                      overflow: TextOverflow.ellipsis),
                ),
                if (dangerous)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 13, color: AppColors.brandRed),
                  ),
                if (needsCond)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Text('需条件',
                        style: TextStyle(fontSize: 9, color: AppColors.brandAmber)),
                  ),
              ]),
              if (desc.isNotEmpty)
                Text(desc,
                    style: const TextStyle(fontSize: 9.5, color: AppColors.dim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text(locked ? '底线' : (value ? '开' : '关'),
              style: TextStyle(
                  fontSize: 11,
                  color: locked
                      ? AppColors.dim
                      : (value ? AppColors.brandGreen : AppColors.dim))),
        ]),
      ),
    );
  }
}
