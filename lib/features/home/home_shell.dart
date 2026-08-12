/// 主框架（底部导航——Chat/Dashboard/设置 + 抽屉全功能入口）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';
import '../alerts/alerts_screen.dart';
import '../chat/chat_screen.dart';
import '../connect/connect_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../ha/ha_screen.dart';
import '../ai_config/ai_config_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _tokenListenerAttached = false;

  // 【0.1.9】底部导航：对话 / 仪表盘（设置已迁入 AI 配置）
  static const _pages = [ChatScreen(), DashboardScreen()];

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
    }
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
                Text('v0.1.9', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // 【0.1.9】AI 配置统一入口（设置/记忆/会话/文件已迁入）
          _item(context, Icons.tune, 'AI 配置', const AiConfigScreen()),
          _item(context, Icons.home_work_outlined, 'HA 面板', const HaScreen()),
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
      drawer: _buildDrawer(context),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '对话'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '仪表盘'),
        ],
      ),
    );
  }
}
