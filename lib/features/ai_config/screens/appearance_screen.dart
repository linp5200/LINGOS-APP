/// 外观与偏好（0.1.9——行业惯例汇总）
/// 外观：主题/强调色/字体大小/显示密度
/// 消息偏好：思考过程/工具调用/流式动画/代码高亮（默认全开）
/// 行为偏好：回车发送/自动滚动/新会话命名
/// 语言：中/英/系统 + 服务端 lang 列表
/// 隐私：日志保留/匿名统计（默认关）
library;

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _store = AppStore();
  String _themeMode = 'system';
  bool _accentDynamic = true;
  String _language = 'system';
  Map<String, bool> _msgPrefs = const {};
  bool _analytics = false;
  bool _loading = true;
  String _startScreen = 'sessions'; // 【0.2.1 #7】开局显示（默认会话列表——9.2 裁决）

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final theme = await _store.getThemeMode();
    final accent = await _store.getAccentDynamic();
    final lang = await _store.getLanguage();
    final prefs = await _store.getMsgPrefs();
    final analytics = await _store.getAnalytics();
    final start = await _store.getStartScreen();
    if (!mounted) return;
    setState(() {
      _themeMode = theme;
      _accentDynamic = accent;
      _language = lang;
      _msgPrefs = prefs;
      _analytics = analytics;
      _startScreen = start;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('cfg_appearance_preferences'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(tr('look_appearance')),
                // 主题：深/浅/跟随系统
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined, size: 20),
                  title: Text(tr('look_theme')),
                  trailing: DropdownButton<String>(
                    value: _themeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'system', child: Text(tr('look_follow_system'))),
                      DropdownMenuItem(value: 'light', child: Text(tr('look_light'))),
                      DropdownMenuItem(value: 'dark', child: Text(tr('look_dark'))),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _themeMode = v);
                      await _store.saveThemeMode(v);
                    },
                  ),
                ),
                // 强调色：动态取色（Material You）
                SwitchListTile(
                  value: _accentDynamic,
                  onChanged: (v) async {
                    setState(() => _accentDynamic = v);
                    await _store.saveAccentDynamic(v);
                  },
                  title: Text(tr('look_dynamic_accent_color')),
                  subtitle: Text(tr('look_follow_system_dynamic_color_material_you'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const Divider(),
                _section(tr('look_message_preferences_all_on_by_default')),
                _prefSwitch(tr('look_show_thinking_process'), 'thinking', tr('look_stream_ai_reasoning_in_gray')),
                _prefSwitch(tr('look_show_tool_calls'), 'tool', tr('look_show_tool_calls_and_results')),
                _prefSwitch(tr('look_streaming_typewriter_animation'), 'streaming', tr('look_render_replies_character_by_character')),
                _prefSwitch(tr('look_code_highlighting'), 'codeHighlight', tr('look_colorize_markdown_code_blocks')),
                // 【0.2.1 #5】流式思考展开思考链——控制思考链默认展开/收缩
                _prefSwitch(tr('look_expand_thinking_chain_while_streaming'), 'thinkExpand', tr('look_thinking_blocks_expanded_by_default_off')),
                // 【0.2.1 #4】工具块默认展开
                _prefSwitch(tr('look_tool_blocks_expanded_by_default'), 'toolExpand', tr('look_tool_blocks_expanded_by_default_off')),
                const Divider(),
                // 【0.2.1 #7】开局显示设置——三选项平铺
                _section(tr('look_startup_screen')),
                Text(tr('look_show_first_when_the_app_starts'),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _startScreenChip('last', tr('look_last_session'), Icons.history),
                    _startScreenChip('sessions', tr('look_session_list'), Icons.forum_outlined),
                    _startScreenChip('dashboard', tr('nav_dashboard'), Icons.dashboard_outlined),
                  ],
                ),
                const Divider(),
                _section(tr('look_language')),
                ListTile(
                  leading: const Icon(Icons.language_outlined, size: 20),
                  title: Text(tr('look_app_language')),
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'system', child: Text(tr('look_follow_system'))),
                      DropdownMenuItem(value: 'zh', child: Text(tr('look_chinese'))),
                      const DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _language = v);
                      await _store.saveLanguage(v);
                    },
                  ),
                ),
                const Divider(),
                _section(tr('look_privacy_data')),
                SwitchListTile(
                  value: _analytics,
                  onChanged: (v) async {
                    setState(() => _analytics = v);
                    await _store.saveAnalytics(v);
                  },
                  title: Text(tr('look_anonymous_analytics')),
                  subtitle: Text(tr('look_off_by_default_privacy_first_data_stays_on'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 24),
                Text(
                  tr('look_language_sync_the_server_lang_list_will'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }

  Widget _prefSwitch(String title, String key, String subtitle) {
    return SwitchListTile(
      value: _msgPrefs[key] ?? true,
      onChanged: (v) async {
        setState(() => _msgPrefs = {..._msgPrefs, key: v});
        await _store.saveMsgPrefs(_msgPrefs);
      },
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  /// 【0.2.1 #7】开局显示选项 chip（平铺选择）
  Widget _startScreenChip(String value, String label, IconData icon) {
    final selected = _startScreen == value;
    return GestureDetector(
      onTap: () async {
        setState(() => _startScreen = value);
        await _store.saveStartScreen(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandRed.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.divider, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.brandRed : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? AppColors.brandRed : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
