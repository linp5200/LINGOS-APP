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

import '../../core/storage/app_store.dart';
import '../../core/theme/app_theme.dart';
import '../connect/connect_screen.dart';
import 'home_shell.dart';

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
                    child: const Text('跳过', style: TextStyle(color: AppColors.dim)),
                  ),
                  const Spacer(),
                  if (_page < 2)
                    FilledButton(
                      onPressed: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: const Text('下一步'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: () => _finish(goConnect: true),
                      child: const Text('连接主机'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _finish(),
                      child: const Text('开始使用'),
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
          const Text('欢迎使用 LING OS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          const Text(
            '个人 / 家庭安防智能 AI 系统。\n\n'
            '· 生命线：地震预警 / 台风 / 火灾 / 入侵——宁可误报不可漏报\n'
            '· AI 对话 + 69 项技能（家庭自动化 / 监控 / 语音 / 记忆）\n'
            '· 数据本地优先，安全与隐私高于一切',
            style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
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
          const Text('连接你的主机',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text(
            'LING OS 服务端运行在你的主机（Linux 设备）上。\n\n'
            '· 同一局域网：连接页「搜索局域网主机」→ 一键填入\n'
            '· 认证：终端验证码 → 连接码（两步）\n'
            '· 也可以先跳过——本地模式可用，之后在 设置 → 连接设置 中连接',
            style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          const Text('提示：服务端启动后终端会显示验证码。',
              style: TextStyle(fontSize: 11, color: AppColors.dim)),
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
          const Text('就绪检查',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _checkLine('通知权限', '允许通知——危机/预警才能弹到你（设置时会请求）'),
          _checkLine('后台保活', '建议开启（设置 → 通知与后台）——锁屏也能收危机推送'),
          _checkLine('电池优化', '为本应用关闭电池限制（系统设置 → 应用 → 电池）'),
          const SizedBox(height: 16),
          const Text('完成后即可开始。全部可稍后在「设置」中调整。',
              style: TextStyle(fontSize: 11, color: AppColors.dim)),
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
