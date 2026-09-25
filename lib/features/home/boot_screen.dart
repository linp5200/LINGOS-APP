/// Boot 启动屏（先生 lingos-app-preview-final.html 对照落地——先生 2026-09-05）
/// 内容：LINGOS 大标 + 自检日志逐行动画 + LOCAL MODE 提示 + 进入主控台/连接主机 两按钮
/// 逻辑：本地模式启动（不强制连接）；有已存会话自动恢复；需用时手动连
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/fui_widgets.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/app_info.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
import '../../core/providers.dart';
import '../connect/connect_screen.dart';
import '../onboarding/onboarding_screen.dart';   // 【0.7.0】首启引导
import 'home_shell.dart';

class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _done = false;          // boot 动画完成
  bool _restoring = false;     // 自动恢复中
  String _restoreStatus = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
        _afterBoot();
      });
  }

  /// 【0.7.0】启动分流：首启 → 引导页（一次）；否则 → 自动恢复连接
  Future<void> _afterBoot() async {
    try {
      final store = AppStore();
      final done = await store.getPrefBool('onboarding_done', false);
      if (!done) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        return;
      }
    } catch (_) {}
    _autoRestore();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 【0.4.3】自动恢复连接（有 token 静默重连 WS）
  Future<void> _autoRestore() async {
    try {
      final store = AppStore();
      final token = await store.getToken();
      if (token == null || token.isEmpty) return; // 无会话——停留本地
      final host = await store.getHost();
      final port = await store.getPort();
      if (host == null || host.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _restoring = true;
        _restoreStatus = tr('boot_restore_detected');
      });
      final cm = ref.read(connectionProvider);
      final ok = await cm.connectWsAndSave(host, port ?? 2939, token);
      appLog('Boot', '自动恢复: ${ok ? "成功" : "失败(本地模式)"}');
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreStatus = ok ? tr('boot_restore_ok') : tr('boot_restore_fail');
      });
      if (ok) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeShell()));
      }
    } catch (e) {
      appLog('Boot', '恢复异常: $e');
    }
  }

  void _enterHome() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  void _goConnect() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // 灰白地形背景（先生 FUI v2）
          const Positioned.fill(child: FuiTerrainBackground(opacity: 0.10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // LOGO
                  const Text('LING OS',
                      style: TextStyle(
                          fontFamily: fuiMono,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                          color: AppColors.white)),
                  const SizedBox(height: 10),
                  // 【0.5.2 修复】版本动态化（原硬编码 LN-0.4.3——先生报告版本不更新）
                  Text('SYSTEM INITIALIZE · ${AppInfo.tag}',
                      style: const TextStyle(
                          fontFamily: fuiMono,
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.gray)),
                  const Spacer(flex: 1),
                  // 自检日志（FadeTransition 逐行动画）
                  _buildBootLog(),
                  const Spacer(flex: 1),
                  // LOCAL MODE 提示
                  if (_done) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.06),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                              width: 7,
                              height: 7,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: AppColors.amber, shape: BoxShape.circle))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _restoring
                                  ? _restoreStatus
                                  : tr('boot_local_mode'),
                              style: const TextStyle(
                                  fontFamily: fuiMono,
                                  fontSize: 10,
                                  color: AppColors.amber)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _enterHome,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.white,
                              side: const BorderSide(color: AppColors.line),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(tr('boot_enter_console'),
                                style: const TextStyle(
                                    fontFamily: fuiMono, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _goConnect,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green,
                              side: BorderSide(color: AppColors.green.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(tr('connect_host'),
                                style: const TextStyle(
                                    fontFamily: fuiMono, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 自检日志（boot 动画期间逐行显现）
  Widget _buildBootLog() {
    const lines = [
      'env_bootstrap   OK',
      'registry core   8 modules',
      'ui theme v2     FUI',
      'host link       OFFLINE · 手动',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.lineDim),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            FadeTransition(
              opacity: CurvedAnimation(parent: _ctrl, curve: Interval(
                  i * 0.18, i * 0.18 + 0.4, curve: Curves.easeOut)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '▸ ${lines[i]}',
                  style: const TextStyle(
                      fontFamily: fuiMono,
                      fontSize: 10,
                      color: AppColors.gray),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
