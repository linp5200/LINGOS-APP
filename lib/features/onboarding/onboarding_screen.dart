/// LING OS 首启引导（【0.7.0】onboarding——先生 P3 残项补齐）
///
/// 设计（对标 HA onboarding——三步卡片）：
///   ① 欢迎（定位：个人/家庭安防智能 AI 系统）
///   ② 连接主机（跳连接页 / 跳过稍后连）
///   ③ 就绪清单（通知权限提示 + 后台保活建议 + 完成）
///
/// 触发：BootScreen 启动时若 onboarding_done != true → 进入本页（一次）
library;

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';

import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';
import '../connect/connect_screen.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _store = AppStore();
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish({bool goConnect = false}) async {
    await _store.savePrefBool('onboarding_done', true);
    if (!mounted) return;
    if (goConnect) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ConnectScreen()));
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcome(),
                  _connectStep(),
                  _checklist(),
                ],
              ),
            ),
            // 步进指示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.brandGreen : AppColors.dim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _finish(),
                    child: Text(tr('onb_skip'), style: const TextStyle(color: AppColors.dim)),
                  ),
                  const Spacer(),
                  if (_page < 2)
                    FilledButton(
                      onPressed: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: Text(tr('onb_next')),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: () => _finish(goConnect: true),
                      child: Text(tr('connect_host')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _finish(),
                      child: Text(tr('onb_get_started')),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wb_twilight, size: 64, color: AppColors.brandGreen),
          const SizedBox(height: 18),
          Text(tr('onb_welcome_to_ling_os'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Text(
            tr('onb_a_personal_home_security_ai_system_n_n'),
            style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _connectStep() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lan_outlined, size: 56, color: AppColors.brandGreen),
          const SizedBox(height: 18),
          Text(tr('onb_connect_your_host'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text(
            tr('onb_the_ling_os_server_runs_on_your_host_a'),
            style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Text(tr('onb_tip_the_terminal_shows_the_verification'),
              style: const TextStyle(fontSize: 11, color: AppColors.dim)),
        ],
      ),
    );
  }

  Widget _checklist() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checklist_rtl, size: 56, color: AppColors.brandGreen),
          const SizedBox(height: 18),
          Text(tr('onb_readiness_check'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _checkLine(tr('onb_notification_permission'), tr('onb_allow_notifications_so_crises_alerts_can')),
          _checkLine(tr('notif_keep_alive_in_background'), tr('onb_recommended_settings_notifications')),
          _checkLine(tr('notif_battery_optimization'), tr('onb_disable_battery_restrictions_for_this_app')),
          const SizedBox(height: 16),
          Text(tr('onb_you_can_start_once_done_everything_can_be'),
              style: const TextStyle(fontSize: 11, color: AppColors.dim)),
        ],
      ),
    );
  }

  Widget _checkLine(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
