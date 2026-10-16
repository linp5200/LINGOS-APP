/// 人格（0.1.9——诺克/诺玛选择 + 参数展示——服务端 personality_get/set）
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class _PersonalityInfo {
  final String id;
  final String name;
  final String desc;
  final String gender;
  final String voice;
  final int strict;
  final int warmth;
  final int speed;

  const _PersonalityInfo(this.id, this.name, this.desc, this.gender, this.voice,
      this.strict, this.warmth, this.speed);
}

/// 【i18n】改为 getter：姓名/描述经 tr() 后需在每次访问时求值
List<_PersonalityInfo> get _kPersonalities => [
  _PersonalityInfo('nook', tr('pers_nook'), tr('pers_calm_rational_absolutely_loyal_the_core_ai'),
      tr('pers_male'), tr('pers_male'), 8, 3, 7),
  _PersonalityInfo('noma', tr('pers_noma'), tr('pers_gentle_warm_wise_the_companion_ai_of_ling_os'),
      tr('pers_female'), tr('pers_female'), 4, 9, 5),
];

class PersonalityScreen extends ConsumerStatefulWidget {
  const PersonalityScreen({super.key});

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen> {
  String _current = 'nook';
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'command_response') {
        final data = evt['data'];
        Map<String, dynamic>? resp;
        if (data is String) {
          final d = jsonDecode(data);
          if (d is Map) resp = Map<String, dynamic>.from(d);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null || resp['status'] != 'ok') return;
        final info = resp['data'];
        if (info is Map && info['personality'] != null) {
          setState(() {
            _current = info['personality'].toString();
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'personality_get'});
  }

  void _select(String id) async {
    ref.read(connectionProvider).sendCommand({'cmd': 'personality_set', 'name': id});
    setState(() => _current = id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('pers_personality_switched'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('cfg_personality')), actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.brandRed)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 人格选择卡片
                    for (final p in _kPersonalities) _personalityCard(p),
                    const SizedBox(height: 16),
                    Text(tr('pers_voice_field_links_to_speech_tts_channel'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
    );
  }

  Widget _personalityCard(_PersonalityInfo p) {
    final sel = _current == p.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: sel ? const BorderSide(color: AppColors.brandCyan, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _select(p.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 20, color: sel ? AppColors.brandCyan : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(p.desc,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _param(tr('pers_gender'), p.gender),
                  const SizedBox(width: 16),
                  _param(tr('pers_voice'), p.voice),
                ],
              ),
              const SizedBox(height: 8),
              _slider(tr('pers_strictness'), p.strict),
              _slider(tr('pers_warmth'), p.warmth),
              _slider(tr('pers_speed'), p.speed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _param(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _slider(String label, int value) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            max: 10,
            divisions: 10,
            onChanged: null, // 只读展示（配置化后续批次）
          ),
        ),
        SizedBox(
          width: 24,
          child: Text('$value',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
