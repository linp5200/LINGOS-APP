/// 主框架（底部导航——Chat/Dashboard/设置 + 抽屉全功能入口）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/fui_widgets.dart';
import '../alerts/alerts_screen.dart';
import '../chat/chat_screen.dart';
import '../connect/connect_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../ha/ha_screen.dart';
import '../ha/ha_control_screen.dart';
import '../vision/vision_screen.dart';
import '../sessions/sessions_screen.dart';
import '../ai_config/ai_config_screen.dart';

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
  // 【A1修复】GlobalKey——子页三横按钮经回调打开 HomeShell 的 Drawer
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // 【0.1.9】底部导航：对话 / 仪表盘（设置已迁入 AI 配置）
  // 【0.2.1 #7】+ 会话列表 tab（开局显示三选项：上一次的会话/会话列表/仪表盘）
  // 【0.4.3 先生裁决】本地模式启动——有已存会话则自动恢复，无则停留本地
  late final List<Widget> _pages = [
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
        case 'last':   _index = 0; break; // 上一次的会话（默认聊天页）
        case 'sessions': _index = 1; break; // 会话列表
        case 'dashboard': _index = 2; break; // 仪表盘
        default:       _index = 1; break;
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
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.surface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('LING OS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('v0.4.3', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // 【0.1.9】设置统一入口（原 AI 配置改名——内部区块不变）
          _item(context, Icons.tune, '设置', const AiConfigScreen()),
          // 【0.4.3】主机连接（本地模式——需连主机时主动进入）
          ListTile(
            leading: const Icon(Icons.link, size: 20, color: AppColors.brandGreen),
            title: const Text('连接主机', style: TextStyle(color: AppColors.brandGreen)),
            subtitle: const Text('对话/同步/远端摄像头需连接', style: TextStyle(fontSize: 10, color: AppColors.dim)),
            onTap: _goConnect,
          ),
          // 【0.2.1 B1 改名】Help AI（帮助档案——原 HA 面板）
          _item(context, Icons.home_work_outlined, 'Help AI', const HaScreen()),
          // 【0.2.1 #11 C2】Home Assistant 独立入口（智能家居——不藏 AI 配置里）
          _item(context, Icons.home_outlined, 'Home Assistant', const HaControlScreen()),
          // 【0.2.2 vision】摄像头独立入口（预览/检测/OCR）
          _item(context, Icons.videocam_outlined, '摄像头', const VisionScreen()),
          _item(context, Icons.notifications_outlined, '预警中心', const AlertsScreen()),
          const Divider(color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.logout, size: 20, color: AppColors.brandRed),
            title: const Text('断开连接', style: TextStyle(color: AppColors.brandRed)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      // 【0.4.3】聊天/会话纯净平面（先生 FUI 定稿：地形只进仪表盘/开屏——由各页自决背景）
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '对话'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '会话'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '仪表盘'),
        ],
      ),
    );
  }
}
