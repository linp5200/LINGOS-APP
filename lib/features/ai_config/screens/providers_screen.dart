/// 添加提供商（0.1.9——12 家预填——供应商类型与基础 URL 预填，只需 API 密钥）
/// LLM 类写入服务端（后续批次 ai_config_set 命令）；语音类先本地存储标"待接入"
library;

import 'package:flutter/material.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class ProviderPreset {
  final String id;
  final String name;
  final String category; // LLM / 语音
  final String baseUrl;
  final String hint;
  final bool keyOnly; // 是否只需填 API 密钥

  const ProviderPreset(this.id, this.name, this.category, this.baseUrl, this.hint,
      {this.keyOnly = true});
}

const kProviderPresets = [
  ProviderPreset('openai', 'OpenAI', 'LLM', 'https://api.openai.com/v1', '输入 OpenAI API 密钥'),
  ProviderPreset('anthropic', 'Anthropic', 'LLM', 'https://api.anthropic.com', '输入 Anthropic API 密钥'),
  ProviderPreset('compatible', 'Compatible API', 'LLM', '', '输入自定义基础 URL 与 API 密钥', keyOnly: false),
  ProviderPreset('kimi', 'Kimi Code', 'LLM', 'https://api.moonshot.cn/v1', '使用 Kimi Code plan——需 Kimi 账号登录'),
  ProviderPreset('elevenlabs', 'ElevenLabs', '语音', 'https://api.elevenlabs.io', '输入 ElevenLabs API 密钥（TTS）'),
  ProviderPreset('deepgram', 'Deepgram', '语音', 'https://api.deepgram.com', '输入 Deepgram API 密钥（识别+合成）'),
  ProviderPreset('azure_tts', 'Azure TTS', '语音', 'https://eastasia.tts.speech.microsoft.com', '输入 Azure 语音服务订阅密钥；基础URL设为你的区域', keyOnly: false),
  ProviderPreset('minimax', 'MiniMax', '语音', 'https://api.minimax.chat', '输入 MiniMax API 密钥（TTS）'),
  ProviderPreset('bailian', 'Alibaba Bailian', '语音', 'https://dashscope.aliyuncs.com', '输入阿里云百炼 API 密钥（识别+合成）'),
  ProviderPreset('doubao', 'Doubao (Volcano)', '语音', 'https://ark.cn-beijing.volces.com', '从火山引擎新控制台输入 API 密钥（识别+合成）'),
  ProviderPreset('xunfei', 'iFlytek (Xunfei)', '语音', 'https://api.xfyun.cn', '以“appId;apiKey;apiSecret”形式输入（识别+合成）'),
  ProviderPreset('mimo', 'Xiaomi MiMo', '语音', 'https://api.xiaomi.com', '输入小米 MiMo API 密钥（识别+合成）'),
];

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _store = AppStore();
  List<Map<String, dynamic>> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _store.getProviders();
    if (!mounted) return;
    setState(() {
      _providers = list;
      _loading = false;
    });
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => _ProviderEditScreen(existing: existing)),
    );
    if (result != null) {
      final list = [..._providers];
      final idx = list.indexWhere((p) => p['id'] == result['id']);
      if (idx >= 0) {
        list[idx] = result;
      } else {
        list.add(result);
      }
      await _store.saveProviders(list);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM/MLM 提供商'),
        actions: [
          // 【先生设计】右上角"+"为添加提供商
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: () => _addOrEdit()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text('尚未配置提供商', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _addOrEdit(),
                        child: const Text('点击右上角 + 添加'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _providers.length,
                  itemBuilder: (ctx, i) {
                    final p = _providers[i];
                    ProviderPreset? preset;
                    for (final e in kProviderPresets) {
                      if (e.id == p['id']) { preset = e; break; }
                    }
                    final isVoice = preset?.category == '语音';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isVoice ? Icons.mic_outlined : Icons.smart_toy_outlined,
                          size: 22,
                          color: AppColors.brandCyan,
                        ),
                        title: Text(p['name']?.toString() ?? preset?.name ?? '未知',
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        subtitle: Text(
                          '${p['baseUrl']?.toString() ?? ''}${p['model'] != null && (p['model'] as String).isNotEmpty ? ' · ${p['model']}' : ''}'
                          '${isVoice ? '\n语音服务——服务端待接入' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () => _addOrEdit(p),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 添加/编辑页
class _ProviderEditScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ProviderEditScreen({this.existing});

  @override
  State<_ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<_ProviderEditScreen> {
  final _keyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  ProviderPreset? _selected;
  late final bool _isEdit;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existing != null;
    if (_isEdit) {
      final e = widget.existing!;
      for (final p in kProviderPresets) {
        if (p.id == e['id']) { _selected = p; break; }
      }
      _urlCtrl.text = e['baseUrl']?.toString() ?? '';
      _modelCtrl.text = e['model']?.toString() ?? '';
      _keyCtrl.text = e['apiKey']?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑提供商' : '添加提供商')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 类型选择（添加时可选——编辑时锁定）
          if (!_isEdit) ...[
            const Text('选择提供商', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kProviderPresets.map((p) {
                final sel = _selected?.id == p.id;
                return ChoiceChip(
                  label: Text(p.name, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _selected = p;
                    _urlCtrl.text = p.baseUrl;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (_selected != null) ...[
            Text('${_selected!.category == '语音' ? '语音' : 'LLM'} · ${_selected!.name}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            // 基础 URL（预填——可改）
            TextField(
              controller: _urlCtrl,
              enabled: _selected!.keyOnly || _selected!.id == 'compatible',
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: '基础 URL（已预填）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // 模型（可选）
            if (_selected!.category == 'LLM')
              TextField(
                controller: _modelCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: '模型（可选，如 deepseek-chat）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            if (_selected!.category == 'LLM') const SizedBox(height: 12),
            // API 密钥
            TextField(
              controller: _keyCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'API 密钥',
                hintText: _selected!.hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(_selected!.hint,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _keyCtrl.text.trim().isEmpty && _selected!.id != 'compatible'
                  ? null
                  : _save,
              child: const Text('保存'),
            ),
            if (_selected!.category == '语音') ...[
              const SizedBox(height: 8),
              const Text('语音服务配置将保存到本机——服务端语音通道接入后自动生效',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selected == null) return;
    final preset = _selected!;
    final result = <String, dynamic>{
      'id': preset.id,
      'name': preset.name,
      'category': preset.category,
      'baseUrl': _urlCtrl.text.trim().isEmpty ? preset.baseUrl : _urlCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'apiKey': _keyCtrl.text.trim(),
      'configuredAt': DateTime.now().millisecondsSinceEpoch,
    };
    Navigator.of(context).pop(result);
  }
}
