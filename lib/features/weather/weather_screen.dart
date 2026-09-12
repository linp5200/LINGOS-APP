/// 天气屏（协议 v3 —— weather_current / weather_forecast）
/// 【0.4.4 新增】此前 App 端完全没有天气界面（服务端 + Web UI 已有）
/// 数据源：服务端 Open-Meteo / wttr.in / 自定义；无数据时显示「--」不模拟
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _hourly = [];
  List<Map<String, dynamic>> _daily = [];
  bool _loading = false;
  String? _error;
  StreamSubscription? _sub;

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
      if (resp['status'] != 'ok') {
        setState(() {
          _loading = false;
          _error = resp?['msg']?.toString() ?? '天气源不可达';
        });
        return;
      }
      // weather_current → {status,data:{...}} ；weather_forecast → {status,hourly,daily}
      final inner = resp['data'];
      if (inner is Map) {
        final m = Map<String, dynamic>.from(inner);
        if (m.containsKey('temp') || m.containsKey('temperature')) {
          setState(() {
            _current = m;
            _loading = false;
            _error = null;
          });
          return;
        }
      }
      // 闭包内类型提升失效 → 提取非空局部变量（CI: unchecked_use_of_nullable_value）
      final r = resp;
      if (r['hourly'] is List || r['daily'] is List) {
        setState(() {
          _hourly = ((r['hourly'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
              .toList();
          _daily = ((r['daily'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
              .toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {}
  }

  void _refresh() {
    final cm = ref.read(connectionProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    cm.sendCommand({'cmd': 'weather_current'});
    cm.sendCommand({'cmd': 'weather_forecast'});
  }

  /// WMO 天气代码 → 图标 + 中文
  static (IconData, String) _codeInfo(dynamic code) {
    final c = int.tryParse(code?.toString() ?? '') ?? -1;
    if (c == 0) return (Icons.wb_sunny_outlined, '晴');
    if (c <= 2) return (Icons.wb_cloudy_outlined, '少云');
    if (c == 3) return (Icons.cloud_outlined, '阴');
    if (c <= 48) return (Icons.foggy, '雾');
    if (c <= 57) return (Icons.grain, '毛毛雨');
    if (c <= 67) return (Icons.water_drop_outlined, '雨');
    if (c <= 77) return (Icons.ac_unit, '雪');
    if (c <= 82) return (Icons.grain, '阵雨');
    if (c <= 86) return (Icons.ac_unit, '阵雪');
    if (c <= 99) return (Icons.thunderstorm_outlined, '雷暴');
    return (Icons.help_outline, '--');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('天气'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loading ? null : _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.brandRed.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.brandRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('$_error（显示 -- 不模拟）',
                        style: const TextStyle(fontSize: 12, color: AppColors.brandRed)),
                  ),
                ]),
              ),
            _currentCard(),
            if (_hourly.isNotEmpty) _hourlyCard(),
            if (_daily.isNotEmpty) _dailyCard(),
          ],
        ),
      ),
    );
  }

  Widget _currentCard() {
    final c = _current;
    final (icon, label) = _codeInfo(c?['code']);
    final temp = c?['temp'] ?? c?['temperature'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c?['city']?.toString() ?? '当前位置',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 52, color: AppColors.brandGreen),
          const SizedBox(width: 18),
          Text(temp == null ? '--' : '$temp°',
              style: const TextStyle(
                  fontFamily: fuiMono,
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _metric(Icons.thermostat, '体感', c?['feels_like'] ?? c?['apparent_temperature'], '°'),
          _metric(Icons.water_drop_outlined, '湿度', c?['humidity'], '%'),
          _metric(Icons.air, '风速', c?['wind_speed'] ?? c?['wind_speed_10m'], 'km/h'),
          _metric(Icons.explore_outlined, '风向', c?['wind_dir'] ?? c?['wind_direction'], '°'),
          _metric(Icons.speed, '气压', c?['pressure'] ?? c?['surface_pressure'], 'hPa'),
          _metric(Icons.visibility_outlined, '能见度', c?['visibility'], 'm'),
          _metric(Icons.wb_sunny_outlined, 'UV', c?['uv'] ?? c?['uv_index'], ''),
        ]),
      ]),
    );
  }

  Widget _metric(IconData ic, String label, dynamic v, String unit) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 15, color: AppColors.textSecondary),
      const SizedBox(width: 5),
      Text('$label ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      Text(v == null ? '--' : '$v$unit',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
    ]);
  }

  Widget _hourlyCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('逐小时', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _hourly.length,
            itemBuilder: (ctx, i) {
              final h = _hourly[i];
              final t = h['time']?.toString() ?? '';
              final (ic, _) = _codeInfo(h['code']);
              return Container(
                width: 62,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.lineDim),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(t.length >= 13 ? t.substring(11, 13) : t,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Icon(ic, size: 18, color: AppColors.brandGreen),
                  const SizedBox(height: 6),
                  Text(h['temp'] == null ? '--' : '${h['temp']}°',
                      style: const TextStyle(fontFamily: fuiMono, fontSize: 12)),
                  if (h['pop'] != null)
                    Text('${h['pop']}%',
                        style: const TextStyle(fontSize: 9, color: AppColors.brandCyan)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _dailyCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('7 日预报', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ..._daily.map((d) {
          final (ic, label) = _codeInfo(d['code']);
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.lineDim),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              SizedBox(
                  width: 78,
                  child: Text(d['date']?.toString() ?? '--',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
              Icon(ic, size: 17, color: AppColors.brandGreen),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
              Text(
                  '${d['temp_min'] ?? '--'}° / ${d['temp_max'] ?? '--'}°',
                  style: const TextStyle(fontFamily: fuiMono, fontSize: 12)),
            ]),
          );
        }),
      ]),
    );
  }
}
