/// 外观与偏好（0.1.9——行业惯例汇总）
/// 外观：主题/强调色/字体大小/显示密度
/// 消息偏好：思考过程/工具调用/流式动画/代码高亮（默认全开）
/// 行为偏好：回车发送/自动滚动/新会话命名
/// 语言：中/英/系统 + 服务端 lang 列表
/// 隐私：日志保留/匿名统计（默认关）
library;

import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('外观与偏好')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('外观'),
                // 主题：深/浅/跟随系统
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined, size: 20),
                  title: const Text('主题'),
                  trailing: DropdownButton<String>(
                    value: _themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                      DropdownMenuItem(value: 'light', child: Text('浅色')),
                      DropdownMenuItem(value: 'dark', child: Text('深色')),
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
                  title: const Text('强调色动态取色'),
                  subtitle: const Text('跟随系统动态色（Material You）——关闭时使用品牌红',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const Divider(),
                _section('消息偏好（默认全开）'),
                _prefSwitch('思考过程显示', 'thinking', 'AI 推理过程灰色流式显示'),
                _prefSwitch('工具调用显示', 'tool', '工具调用与结果展示'),
                _prefSwitch('流式打字动画', 'streaming', '逐字渲染回复'),
                _prefSwitch('代码高亮', 'codeHighlight', 'Markdown 代码块着色'),
                // 【0.2.1 #5】流式思考展开思考链——控制思考链默认展开/收缩
                _prefSwitch('流式思考展开思考链', 'thinkExpand', '思考块默认展开（关=默认收缩，点击展开）'),
                // 【0.2.1 #4】工具块默认展开
                _prefSwitch('工具块默认展开', 'toolExpand', '工具块默认展开（关=默认收缩，点击展开查看参数/结果）'),
                const Divider(),
                // 【0.2.1 #7】开局显示设置——三选项平铺
                _section('启动显示'),
                const Text('启动应用后首先显示',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _startScreenChip('last', '上一次的会话', Icons.history),
                    _startScreenChip('sessions', '会话列表', Icons.forum_outlined),
                    _startScreenChip('dashboard', '仪表盘', Icons.dashboard_outlined),
                  ],
                ),
                const Divider(),
                _section('语言'),
                ListTile(
                  leading: const Icon(Icons.language_outlined, size: 20),
                  title: const Text('App 语言'),
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                      DropdownMenuItem(value: 'zh', child: Text('中文')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _language = v);
                      await _store.saveLanguage(v);
                    },
                  ),
                ),
                const Divider(),
                _section('隐私与数据'),
                SwitchListTile(
                  value: _analytics,
                  onChanged: (v) async {
                    setState(() => _analytics = v);
                    await _store.saveAnalytics(v);
                  },
                  title: const Text('匿名统计'),
                  subtitle: const Text('默认关闭——隐私第一（数据仅存主机、加密）',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 24),
                const Text(
                  '语言联动：服务端 lang 列表将同步至此（后续批次——当前支持中/英/系统）',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
