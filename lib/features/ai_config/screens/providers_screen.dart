/// 添加提供商（0.1.9——三段式：已配置列表 → 选择提供商（竖向） → 密钥配置）
/// LLM 类写入服务端（ai_config_set 命令）；语音类先本地存储标"待接入"
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
  final IconData icon;

  const ProviderPreset(this.id, this.name, this.category, this.baseUrl, this.hint, this.icon);
}

const kProviderPresets = [
  ProviderPreset('openai', 'OpenAI', 'LLM', 'https://api.openai.com/v1', '输入 OpenAI API 密钥', Icons.smart_toy_outlined),
  ProviderPreset('anthropic', 'Anthropic', 'LLM', 'https://api.anthropic.com', '输入 Anthropic API 密钥', Icons.smart_toy_outlined),
  ProviderPreset('compatible', 'Compatible API', 'LLM', '', '输入自定义基础 URL 与 API 密钥', Icons.dns_outlined),
  ProviderPreset('kimi', 'Kimi Code', 'LLM', 'https://api.moonshot.cn/v1', '使用 Kimi Code plan——需 Kimi 账号登录', Icons.smart_toy_outlined),
  ProviderPreset('elevenlabs', 'ElevenLabs', '语音', 'https://api.elevenlabs.io', '输入 ElevenLabs API 密钥（TTS）', Icons.mic_outlined),
  ProviderPreset('deepgram', 'Deepgram', '语音', 'https://api.deepgram.com', '输入 Deepgram API 密钥（识别+合成）', Icons.mic_outlined),
  ProviderPreset('azure_tts', 'Azure TTS', '语音', 'https://eastasia.tts.speech.microsoft.com', '输入 Azure 语音服务订阅密钥；基础URL设为你的区域', Icons.mic_outlined),
  ProviderPreset('minimax', 'MiniMax', '语音', 'https://api.minimax.chat', '输入 MiniMax API 密钥（TTS）', Icons.mic_outlined),
  ProviderPreset('bailian', 'Alibaba Bailian', '语音', 'https://dashscope.aliyuncs.com', '输入阿里云百炼 API 密钥（识别+合成）', Icons.mic_outlined),
  ProviderPreset('doubao', 'Doubao (Volcano)', '语音', 'https://ark.cn-beijing.volces.com', '从火山引擎新控制台输入 API 密钥（识别+合成）', Icons.mic_outlined),
  ProviderPreset('xunfei', 'iFlytek (Xunfei)', '语音', 'https://api.xfyun.cn', '以“appId;apiKey;apiSecret”形式输入（识别+合成）', Icons.mic_outlined),
  ProviderPreset('mimo', 'Xiaomi MiMo', '语音', 'https://api.xiaomi.com', '输入小米 MiMo API 密钥（识别+合成）', Icons.mic_outlined),
];

/// 第一段：已配置提供商列表（竖向）
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

  Future<void> _addFlow() async {
    // 第二段：选择提供商
    final preset = await Navigator.of(context).push<ProviderPreset>(
      MaterialPageRoute(builder: (_) => const _ProviderSelectScreen()),
    );
    if (preset == null) return;
    if (!mounted) return;
    // 第三段：密钥配置
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => _ProviderConfigScreen(preset: preset)),
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

  Future<void> _edit(Map<String, dynamic> existing) async {
    ProviderPreset? preset;
    for (final p in kProviderPresets) {
      if (p.id == existing['id']) { preset = p; break; }
    }
    if (preset == null) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => _ProviderConfigScreen(preset: preset, existing: existing)),
    );
    if (result != null) {
      final list = [..._providers];
      final idx = list.indexWhere((p) => p['id'] == result['id']);
      if (idx >= 0) list[idx] = result;
      await _store.saveProviders(list);
      _load();
    }
  }

  Future<void> _remove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提供商'),
        content: const Text('删除后需重新配置才能使用。确认删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      final list = _providers.where((p) => p['id'] != id).toList();
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
          // 【先生设计】右上角"+"添加提供商
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _addFlow),
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
                      TextButton(onPressed: _addFlow, child: const Text('点击右上角 + 添加')),
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
                    final name = p['name']?.toString() ?? preset?.name ?? '未知';
                    final baseUrl = p['baseUrl']?.toString() ?? '';
                    final model = p['model']?.toString() ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isVoice ? Icons.mic_outlined : Icons.smart_toy_outlined,
                          size: 22,
                          color: AppColors.brandCyan,
                        ),
                        title: Text(name,
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        subtitle: Text(
                          [if (baseUrl.isNotEmpty) baseUrl, if (model.isNotEmpty) model].join(' · ') +
                              (isVoice ? '\n语音服务——服务端待接入' : ''),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                        ),
                        // 【先生设计】点击进入子菜单（编辑）
                        onTap: () => _edit(p),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                          onPressed: () => _remove(p['id']?.toString() ?? ''),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 第二段：选择提供商（竖向列表——LLM/语音 分类）
class _ProviderSelectScreen extends StatelessWidget {
  const _ProviderSelectScreen();

  @override
  Widget build(BuildContext context) {
    final llms = kProviderPresets.where((p) => p.category == 'LLM').toList();
    final voices = kProviderPresets.where((p) => p.category == '语音').toList();

    Widget tile(BuildContext ctx, ProviderPreset p) {
      return ListTile(
        leading: Icon(p.icon, size: 20, color: AppColors.brandCyan),
        title: Text(p.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(p.hint, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        onTap: () => Navigator.pop(ctx, p),
      );
    }

    Widget section(String title, List<ProviderPreset> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ...items.map((p) => tile(context, p)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('选择提供商')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          section('LLM', llms),
          const Divider(),
          section('语音', voices),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 第三段：密钥配置页
class _ProviderConfigScreen extends StatefulWidget {
  final ProviderPreset preset;
  final Map<String, dynamic>? existing;
  const _ProviderConfigScreen({required this.preset, this.existing});

  @override
  State<_ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends State<_ProviderConfigScreen> {
  final _keyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _urlCtrl.text = e?['baseUrl']?.toString() ?? widget.preset.baseUrl;
    _modelCtrl.text = e?['model']?.toString() ?? '';
    _keyCtrl.text = e?['apiKey']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;
    final isVoice = p.category == '语音';
    return Scaffold(
      appBar: AppBar(title: Text('配置 ${p.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(p.icon, size: 18, color: AppColors.brandCyan),
              const SizedBox(width: 8),
              Text('${isVoice ? '语音' : 'LLM'} · ${p.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          // 基础 URL（预填——可改）
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '基础 URL（已预填）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // 模型（LLM 可选）
          if (!isVoice)
            TextField(
              controller: _modelCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: '模型（可选，如 deepseek-chat）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          if (!isVoice) const SizedBox(height: 12),
          // API 密钥
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'API 密钥',
              hintText: p.hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(p.hint,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _keyCtrl.text.trim().isEmpty && p.id != 'compatible'
                ? null
                : _save,
            child: const Text('保存'),
          ),
          if (isVoice) ...[
            const SizedBox(height: 8),
            const Text('语音服务配置将保存到本机——服务端语音通道接入后自动生效',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final p = widget.preset;
    final result = <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'category': p.category,
      'baseUrl': _urlCtrl.text.trim().isEmpty ? p.baseUrl : _urlCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'apiKey': _keyCtrl.text.trim(),
      'configuredAt': DateTime.now().millisecondsSinceEpoch,
    };
    Navigator.of(context).pop(result);
  }
}
