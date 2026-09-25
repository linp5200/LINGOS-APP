/// 主框架（底部导航——Chat/Dashboard/设置 + 抽屉全功能入口）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/app_info.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/icons/lingos_icon.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';
import '../alerts/alerts_screen.dart';
import '../weather/weather_screen.dart';
import '../ext/ext_screens.dart';
import '../options/options_screen.dart';
import '../commands/command_panel_screen.dart';   // 【0.7.0 P3】命令面板（~130 命令总出口）
import '../chat/chat_screen.dart';
import '../connect/connect_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../ha/ha_screen.dart';
import '../ha/ha_control_screen.dart';
import '../vision/vision_screen.dart';
import '../sessions/sessions_screen.dart';
import '../ai_config/ai_config_screen.dart';
import '../crisis/crisis_controller.dart';
import 'home_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _tokenListenerAttached = false;
  bool _startupNavApplied = false;
  bool _autoConnectDone = false;
  // 【0.6.0 §2B】已弹窗的危机 ID（防重复弹窗）
  String _lastCrisisShown = '';
  // 【A1修复】GlobalKey——子页三横按钮经回调打开 HomeShell 的 Drawer
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // 【0.4.3 先生预览对照】导航 = 主控台(本地态) / 对话 / 会话 / 仪表盘
  late final List<Widget> _pages = [
    HomeScreen(onOpenDrawer: _openDrawer),
    ChatScreen(onOpenDrawer: _openDrawer),
    SessionsScreen(onOpenDrawer: _openDrawer),
    DashboardScreen(onOpenDrawer: _openDrawer),
  ];

  /// 【0.4.3】自动恢复连接（本地模式启动——有 token 静默重连，无则本地）
  Future<void> _autoRestoreConnection() async {
    if (_autoConnectDone) return;
    _autoConnectDone = true;
    try {
      final store = AppStore();
      final token = await store.getToken();
      if (token == null || token.isEmpty) return; // 无会话——本地模式
      final host = await store.getHost();
      final port = await store.getPort();
      if (host == null || host.isEmpty) return;
      final cm = ref.read(connectionProvider);
      if (cm.state == ConnState.authenticated) return;
      final ok = await cm.connectWsAndSave(host, port ?? 2939, token);
      appLog('HomeShell', '自动恢复连接: ${ok ? "成功" : "失败(本地模式)"}');
    } catch (e) {
      appLog('HomeShell', '自动恢复连接异常: $e');
    }
  }

  /// 【0.4.3】去连接页（本地模式引导——设置入口保留在 AI 配置树）
  void _goConnect() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectScreen()));
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tokenListenerAttached) {
      _tokenListenerAttached = true;
      final cm = ref.read(connectionProvider);
      cm.events.listen((line) {
        if (line.contains('token_invalid')) {
          _showTokenInvalidDialog();
        }
      });
      // 【0.2.1 #7】开局显示设置（上一次的会话/会话列表/仪表盘——默认会话列表 9.2）
      _applyStartupScreen();
      // 【0.4.3 先生裁决】本地模式——有 token 自动恢复连接，无则停留本地
      _autoRestoreConnection();
    }
  }

  Future<void> _applyStartupScreen() async {
    if (_startupNavApplied) return;
    _startupNavApplied = true;
    final start = await AppStore().getStartScreen();
    if (!mounted) return;
    setState(() {
      switch (start) {
        case 'last':   _index = 1; break; // 上一次的会话（默认对话页）
        case 'sessions': _index = 2; break; // 会话列表
        case 'dashboard': _index = 3; break; // 仪表盘
        default:       _index = 0; break;   // 默认主控台（本地态）
      }
    });
  }

  /// 【先生设计】令牌无效弹窗（手动重新验证——验证码/登出）
  Future<void> _showTokenInvalidDialog() async {
    if (!mounted) return;
    final cm = ref.read(connectionProvider);
    final store = AppStore();
    final oldToken = await store.getToken() ?? '';
    final codeCtrl = TextEditingController();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('令牌无法使用', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('当前令牌已被服务端拒绝——需要重新验证。',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              '若新令牌仍被拒绝：可在主机端输入 token remove login <当前App的IP> <时间> 强行使用（受限模式——危险操作不允许）。\n'
              '或输入 token login again <验证码> 重新验证。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '主机端验证码（token login again <验证码>）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 登出并重新连接（清 token——回连接页）
              await store.clearToken();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ConnectScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('登出并重新连接'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              // 发送验证码 + 旧 token（服务端匹配 pending——新 token + 删旧）
              final payload = '$code|$oldToken';
              await cm.sendConnectionCode(payload);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('发送验证码'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('LING OS',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(AppInfo.tag,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // 【0.1.9】设置统一入口（原 AI 配置改名——内部区块不变）
          _item(context, LingIcons.internalService, trCtx(context, 'settings'), const AiConfigScreen()),
          // 【0.4.3】主机连接（本地模式——需连主机时主动进入）
          ListTile(
            leading: const LingIcon(LingIcons.connect, size: 20, color: AppColors.brandGreen),
            title: Text(trCtx(context, 'connect_host'),
                style: const TextStyle(color: AppColors.brandGreen)),
            subtitle: const Text('对话/同步/远端摄像头需连接', style: TextStyle(fontSize: 10, color: AppColors.dim)),
            onTap: _goConnect,
          ),
          // 【0.2.1 B1 改名】Help AI（帮助档案——原 HA 面板）
          _item(context, TablerIcons.help_circle, trCtx(context, 'nav_help_ai'), const HaScreen()),
          // 【0.2.1 #11 C2】Home Assistant 独立入口（智能家居——不藏 AI 配置里）
          _item(context, TablerIcons.home, trCtx(context, 'nav_ha'), const HaControlScreen()),
          // 【0.2.2 vision】摄像头独立入口（预览/检测/OCR）
          _item(context, TablerIcons.device_cctv, trCtx(context, 'nav_vision'), const VisionScreen()),
          _item(context, LingIcons.conflict, trCtx(context, 'nav_alert'), const AlertsScreen()),
          // 【0.4.4】天气独立入口（服务端 weather_current/forecast 已有，App 此前缺屏）
          _item(context, TablerIcons.cloud, trCtx(context, 'nav_weather'), const WeatherScreen()),
          // 【0.5.1】批次2~5 新功能（先生 2026-09-12）
          _item(context, TablerIcons.home_cog, trCtx(context, 'nav_home'), const HomeExtScreen()),
          _item(context, TablerIcons.timeline, trCtx(context, 'nav_timeline'), const TimelineScreen()),
          const Divider(color: AppColors.divider),
          _item(context, TablerIcons.bell, trCtx(context, 'nav_notify'), const NotifyCenterScreen()),
          _item(context, TablerIcons.music, trCtx(context, 'nav_media'), const MediaScreen()),
          _item(context, TablerIcons.book, trCtx(context, 'nav_kb'), const KbScreen()),
          _item(context, TablerIcons.adjustments, trCtx(context, 'nav_options'), const OptionsScreen()),
          // 【0.7.0 P3】命令面板（~130 命令无入口的总出口——先生"摸不到"治疗）
          _item(context, TablerIcons.terminal_2, '命令面板', const CommandPanelScreen()),
          const Divider(color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.logout, size: 20, color: AppColors.brandRed),
            title: Text(trCtx(context, 'disconnect'),
                style: const TextStyle(color: AppColors.brandRed)),
            onTap: () {
              ref.read(connectionProvider).disconnect();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, Widget page) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  // ============================================================
  // 【0.6.0 §2B】危机 UI（生命线呈现——全屏告警卡 + 常驻横幅）
  // ============================================================

  Widget _buildCrisisBanner(CrisisState c) {
    return Material(
      color: const Color(0xFFB71C1C),
      child: InkWell(
        onTap: () => _showCrisisDialog(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('🚨 ${c.name}警报处置中——点击查看',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (!c.acked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('待确认', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showCrisisDialog(CrisisState c) async {
    if (!mounted) return;
    final actions = c.actions;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2A0A0A),
          icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 42),
          title: Text('🚨 ${c.name}警报',
              style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.source.isNotEmpty)
                  Text('触发源：${c.source}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (c.detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(c.detail, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                const Text('系统已执行的类别动作：', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                const SizedBox(height: 4),
                ...actions.take(8).map((a) {
                  final m = (a is Map) ? a : const {};
                  final st = m['status']?.toString() ?? '';
                  final tag = st == 'done'
                      ? '✓'
                      : st == 'noted'
                          ? 'ℹ'
                          : st.startsWith('pending')
                              ? '⏳'
                              : '✗';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('$tag ${m['desc'] ?? ''}（${m['detail'] ?? st}）',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  );
                }),
                const SizedBox(height: 8),
                const Text('AI 已获全权处置授权——在线时将持续补充处置动作。',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                // 【0.7.0】生命线投递状态（server crisis_delivery——多通道并行+ACK）
                FutureBuilder<Map<String, dynamic>?>(
                  future: ref.read(connectionProvider).requestJson(
                      {'cmd': 'crisis_delivery_status'},
                      timeout: const Duration(seconds: 6)),
                  builder: (bctx, snap) {
                    String txt = '投递状态：查询中…';
                    try {
                      final d = snap.data?['data'];
                      final inner = (d is Map && d['data'] is Map) ? d['data'] as Map : d;
                      if (inner is Map) {
                        final acked = inner['acked'] == true;
                        final running = inner['running'] == true;
                        txt = '投递状态：${acked ? "✅ 已确认（ACK）" : (running ? "📡 多通道投递中（含重推）" : "—")}';
                      } else if (snap.connectionState != ConnectionState.waiting) {
                        txt = '投递状态：未连接';
                      }
                    } catch (_) {}
                    return Text(txt, style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11));
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
              onPressed: () {
                ref.read(crisisProvider.notifier).acknowledge();
                Navigator.pop(ctx);
              },
              child: const Text('我已知情'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crisis = ref.watch(crisisProvider);
    // 【0.6.0 §2B】危机弹窗（同一危机只弹一次——生命线呈现）
    ref.listen(crisisProvider, (prev, next) {
      if (next.active && next.crisisId.isNotEmpty && _lastCrisisShown != next.crisisId) {
        _lastCrisisShown = next.crisisId;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showCrisisDialog(next));
      }
    });
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      // 【0.4.3】聊天/会话纯净平面（先生 FUI 定稿：地形只进仪表盘/开屏——由各页自决背景）
      body: Column(children: [
        if (crisis.active) _buildCrisisBanner(crisis),
        Expanded(child: _pages[_index]),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '主控台'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '对话'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '会话'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '仪表盘'),
        ],
      ),
    );
  }
}
