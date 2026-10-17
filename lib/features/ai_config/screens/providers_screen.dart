/// 添加提供商（0.1.9——三段式：已配置列表 → 选择提供商（竖向） → 密钥配置）
/// LLM 类写入服务端（ai_config_set 命令）；语音类先本地存储标"待接入"
/// 【0.2.0】模型同步：主机端 provider.json 模型列表 App 同步显示 + 点击切换（model_switch）
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
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

/// 【i18n】改为 getter：提示文案经 tr() 后需在每次访问时求值
/// 注意：category 字段是数据（'语音' 与筛选/存储逻辑绑定），不参与翻译
List<ProviderPreset> get kProviderPresets => [
  ProviderPreset('openai', 'OpenAI', 'LLM', 'https://api.openai.com/v1', tr('prov_enter_the_openai_api_key'), Icons.smart_toy_outlined),
  ProviderPreset('anthropic', 'Anthropic', 'LLM', 'https://api.anthropic.com', tr('prov_enter_the_anthropic_api_key'), Icons.smart_toy_outlined),
  ProviderPreset('compatible', 'Compatible API', 'LLM', '', tr('prov_enter_a_custom_base_url_and_api_key'), Icons.dns_outlined),
  ProviderPreset('kimi', 'Kimi Code', 'LLM', 'https://api.moonshot.cn/v1', tr('prov_use_a_kimi_code_plan_requires_kimi_account'), Icons.smart_toy_outlined),
  ProviderPreset('elevenlabs', 'ElevenLabs', '语音', 'https://api.elevenlabs.io', tr('prov_enter_the_elevenlabs_api_key_tts'), Icons.mic_outlined),
  ProviderPreset('deepgram', 'Deepgram', '语音', 'https://api.deepgram.com', tr('prov_enter_the_deepgram_api_key_stt_tts'), Icons.mic_outlined),
  ProviderPreset('azure_tts', 'Azure TTS', '语音', 'https://eastasia.tts.speech.microsoft.com', tr('prov_enter_the_azure_speech_subscription_key_set'), Icons.mic_outlined),
  ProviderPreset('minimax', 'MiniMax', '语音', 'https://api.minimax.chat', tr('prov_enter_the_minimax_api_key_tts'), Icons.mic_outlined),
  ProviderPreset('bailian', 'Alibaba Bailian', '语音', 'https://dashscope.aliyuncs.com', tr('prov_enter_the_alibaba_bailian_api_key_stt_tts'), Icons.mic_outlined),
  ProviderPreset('doubao', 'Doubao (Volcano)', '语音', 'https://ark.cn-beijing.volces.com', tr('prov_enter_the_api_key_from_the_new_volcano'), Icons.mic_outlined),
  ProviderPreset('xunfei', 'iFlytek (Xunfei)', '语音', 'https://api.xfyun.cn', tr('prov_enter_as_appid_apikey_apisecret_stt_tts'), Icons.mic_outlined),
  ProviderPreset('mimo', 'Xiaomi MiMo', '语音', 'https://api.xiaomi.com', tr('prov_enter_the_xiaomi_mimo_api_key_stt_tts'), Icons.mic_outlined),
];

/// 第一段：已配置提供商列表（竖向）
class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  final _store = AppStore();
  List<Map<String, dynamic>> _providers = [];
  bool _loading = true;
  // 【0.2.0】主机端模型列表（provider_list——App 同步显示可切换）
  List<Map<String, dynamic>> _serverModels = [];
  String _activeModel = '';
  bool _modelsLoaded = false;

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
    _loadServerModels();
  }

  /// 【0.2.0】同步主机端模型列表 + 活跃模型
  Future<void> _loadServerModels() async {
    final cm = ref.read(connectionProvider);
    if (cm.ws == null || !cm.ws!.isConnected) return;
    final resp = await cm.requestJson({'cmd': 'provider_list'});
    if (resp == null || !mounted) return;
    final data = resp['data'];
    if (data is Map && data['providers'] is List) {
      setState(() {
        _serverModels = (data['providers'] as List).whereType<Map<String, dynamic>>().toList();
        _activeModel = data['active']?.toString() ?? '';
        _modelsLoaded = true;
      });
    }
  }

  /// 【0.2.0】切换当前模型（model_switch）
  Future<void> _switchModel(String modelId) async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({'cmd': 'model_switch', 'model_id': modelId});
    if (!mounted) return;
    final ok = resp?['status']?.toString() == 'ok';
    if (ok) {
      setState(() => _activeModel = modelId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trp('chat_model_switched', {'p0': modelId})), duration: const Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(trp('prov_switch_failed', {
          'p0': resp?['msg'] ?? tr('dash_unknown_error'),
        }))),
      );
    }
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
      // 【0.2.2 修复】保存后同步服务端 provider_add（原只存本地——主机端不同步的根源）
      await _syncProviderToServer(result);
      _load();
    }
  }

  /// 【0.2.2】同步提供商到服务端（provider_add——含 thinking 开关/强度透传）
  Future<void> _syncProviderToServer(Map<String, dynamic> p) async {
    try {
      final cm = ref.read(connectionProvider);
      if (cm.ws == null || !cm.ws!.isConnected) return;
      await cm.requestJson({
        'cmd': 'provider_add',
        'id': p['id'],
        'name': p['name'],
        'format': 'openai',
        'base_url': p['baseUrl'] ?? '',
        'api_key': p['apiKey'] ?? '',
        'model': p['model'] ?? '',
        'thinking_enabled': p['thinkingEnabled'] ?? true,
        'reasoning_effort': p['reasoningEffort'] ?? 'high',
      });
    } catch (_) {}
  }

  Future<void> _edit(Map<String, dynamic> existing) async {
    ProviderPreset? preset;
    for (final p in kProviderPresets) {
      if (p.id == existing['id']) { preset = p; break; }
    }
    if (preset == null) return;
    final pr = preset; // 提升（修复 nullable）
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => _ProviderConfigScreen(preset: pr, existing: existing)),
    );
    if (result != null) {
      final list = [..._providers];
      final idx = list.indexWhere((p) => p['id'] == result['id']);
      if (idx >= 0) list[idx] = result;
      await _store.saveProviders(list);
      // 【0.2.2】编辑后同样同步服务端（思考开关/强度更新生效）
      await _syncProviderToServer(result);
      _load();
    }
  }

  Future<void> _remove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('prov_delete_provider')),
        content: Text(tr('prov_you_must_reconfigure_it_before_use_after')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      final list = _providers.where((p) => p['id'] != id).toList();
      await _store.saveProviders(list);
      _load();
    }
  }

  /// 【0.2.0】主机端模型切换区块（模型列表 App 同步——点击切换）
  Widget _buildServerModels() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 Icon(Icons.model_training, size: 16, color: AppColors.brandCyan),
                const SizedBox(width: 6),
                Text(tr('prov_host_side_models_tap_to_switch'),
                    style:  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                if (_activeModel.isNotEmpty)
                  Text(trp('prov_current', {'p0': _activeModel}),
                      style:  TextStyle(fontSize: 11, color: AppColors.brandCyan)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serverModels.map((m) {
                final id = m['id']?.toString() ?? '';
                final name = m['name']?.toString() ?? id;
                final model = m['model']?.toString() ?? '';
                final isActive = id == _activeModel;
                return ActionChip(
                  label: Text(
                    '$name${model.isNotEmpty ? '·$model' : ''}',
                    style: TextStyle(fontSize: 11,
                        color: isActive ? Colors.white : AppColors.textPrimary),
                  ),
                  backgroundColor: isActive ? AppColors.brandRed : AppColors.surface,
                  onPressed: isActive ? null : () => _switchModel(id),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('prov_llm_mlm_providers')),
        actions: [
          // 【先生设计】右上角"+"添加提供商
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _addFlow),
        ],
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.cloud_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(tr('prov_no_providers_configured_yet'), style:  TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _addFlow, child: Text(tr('prov_tap_in_the_top_right_to_add'))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  // 【0.2.0】第一项为主机端模型切换区块（模型同步——先生决策）
                  itemCount: _providers.length + ((_modelsLoaded && _serverModels.isNotEmpty) ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (_modelsLoaded && _serverModels.isNotEmpty && i == 0) {
                      return _buildServerModels();
                    }
                    final idx = i - ((_modelsLoaded && _serverModels.isNotEmpty) ? 1 : 0);
                    final p = _providers[idx];
                    ProviderPreset? preset;
                    for (final e in kProviderPresets) {
                      if (e.id == p['id']) { preset = e; break; }
                    }
                    final isVoice = preset?.category == '语音';
                    final name = p['name']?.toString() ?? preset?.name ?? tr('prov_unknown');
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
                            style:  TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        subtitle: Text(
                          [if (baseUrl.isNotEmpty) baseUrl, if (model.isNotEmpty) model].join(' · ') +
                              (isVoice ? tr('prov_nvoice_service_server_integration_pending') : ''),
                          style:  TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                        ),
                        // 【先生设计】点击进入子菜单（编辑）
                        onTap: () => _edit(p),
                        trailing: IconButton(
                          icon:  Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
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
        title: Text(p.name, style:  TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(p.hint, style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing:  Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
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
                style:  TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ...items.map((p) => tile(context, p)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('prov_choose_a_provider'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          section('LLM', llms),
          const Divider(),
          section(tr('grp_voice'), voices),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 第三段：密钥配置页
class _ProviderConfigScreen extends ConsumerStatefulWidget {
  final ProviderPreset preset;
  final Map<String, dynamic>? existing;
  const _ProviderConfigScreen({required this.preset, this.existing});

  @override
  ConsumerState<_ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends ConsumerState<_ProviderConfigScreen> {
  final _keyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  // 【0.2.2】思考模式开关 + 强度（DeepSeek 官方文档——先生指示）
  bool _thinkingEnabled = true;
  String _reasoningEffort = 'high';
  List<String> _remoteModels = [];
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _urlCtrl.text = e?['baseUrl']?.toString() ?? widget.preset.baseUrl;
    _modelCtrl.text = e?['model']?.toString() ?? '';
    _keyCtrl.text = e?['apiKey']?.toString() ?? '';
    _thinkingEnabled = e?['thinkingEnabled'] as bool? ?? true;
    _reasoningEffort = e?['reasoningEffort']?.toString() ?? 'high';
  }

  /// 【0.2.2】获取模型列表（GET /models——DeepSeek 官方 API，先生指示：添加提供商时直接列出）
  Future<void> _fetchModels() async {
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('prov_enter_the_api_key_first_then_fetch_the'))),
      );
      return;
    }
    setState(() => _loadingModels = true);
    final cm = ref.read(connectionProvider);
    // 用当前配置临时查询——provider_id 传空走活跃 provider；模型列表需 base_url+key
    // 简化：直接请求服务端（服务端用当前活跃 provider 的 base_url+key）
    final resp = await cm.requestJson({'cmd': 'model_list_query'});
    if (!mounted) return;
    setState(() => _loadingModels = false);
    final d = resp?['data'];
    if (resp?['status']?.toString() == 'ok' && d is Map && d['models'] is List) {
      setState(() {
        _remoteModels = (d['models'] as List).whereType<String>().toList();
      });
      if (_remoteModels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('prov_server_returned_an_empty_model_list_check'))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp?['msg']?.toString() ?? tr('prov_failed_to_fetch_the_model_list_configure')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;
    final isVoice = p.category == '语音';
    return Scaffold(
      appBar: AppBar(title: Text(trp('prov_configure', {'p0': p.name}))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(p.icon, size: 18, color: AppColors.brandCyan),
              const SizedBox(width: 8),
              Text('${isVoice ? tr('grp_voice') : 'LLM'} · ${p.name}',
                  style:  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          // 基础 URL（预填——可改）
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('prov_base_url_prefilled'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // 模型（LLM 可选）
          if (!isVoice) ...[
            TextField(
              controller: _modelCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('prov_model_optional_e_g_deepseek_v4_flash'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            // 【0.2.2】获取模型列表（DeepSeek /models——先生指示：添加时直接列出）
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingModels ? null : _fetchModels,
                  icon: _loadingModels
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.list_alt, size: 16),
                  label: Text(tr('prov_fetch_model_list'), style: const TextStyle(fontSize: 12)),
                ),
                if (_remoteModels.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _remoteModels.contains(_modelCtrl.text) ? _modelCtrl.text : null,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: tr('prov_select_model'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _remoteModels
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() => _modelCtrl.text = v ?? ''),
                    ),
                  ),
                ],
              ],
            ),
            // 【0.2.2】思考模式开关 + 强度（DeepSeek 官方文档：thinking 开关 + reasoning_effort 映射）
            const SizedBox(height: 12),
            SwitchListTile(
              value: _thinkingEnabled,
              onChanged: (v) => setState(() => _thinkingEnabled = v),
              title: Text(tr('prov_thinking_mode'), style: const TextStyle(fontSize: 14)),
              subtitle: Text(tr('prov_on_the_model_outputs_a_reasoning_chain'),
                  style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              contentPadding: EdgeInsets.zero,
            ),
            Row(
              children: [
                Text(tr('prov_thinking_effort'), style: const TextStyle(fontSize: 14)),
                const Spacer(),
                DropdownButton<String>(
                  value: _reasoningEffort,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 'low', child: Text(tr('skill_low'))),
                    DropdownMenuItem(value: 'medium', child: Text(tr('skill_medium'))),
                    DropdownMenuItem(value: 'high', child: Text(tr('skill_high'))),
                    DropdownMenuItem(value: 'max', child: Text(tr('prov_max'))),
                  ],
                  onChanged: (v) => setState(() => _reasoningEffort = v ?? 'high'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // API 密钥
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('prov_api_key'),
              hintText: p.hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(p.hint,
              style:  TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _keyCtrl.text.trim().isEmpty && p.id != 'compatible'
                ? null
                : _save,
            child: Text(tr('save')),
          ),
          if (isVoice) ...[
            const SizedBox(height: 8),
            Text(tr('prov_voice_service_config_is_saved_on_this'),
                style:  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
      // 【0.2.2】思考模式开关 + 强度（服务端 provider_add 透传）
      'thinkingEnabled': _thinkingEnabled,
      'reasoningEffort': _reasoningEffort,
    };
    Navigator.of(context).pop(result);
  }
}
