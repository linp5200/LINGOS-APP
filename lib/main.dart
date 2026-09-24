/// LING OS App 入口（Flutter 重写——协议 v3）
/// 【0.4.3 先生裁决】开屏不再强制连接主机——本地模式可用，需用时手动连（设置→连接）
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/services/notification_service.dart';
import 'core/notification_bridge.dart';   // 【0.7.0 P3】后台推送（危机/预警本地通知）
import 'core/theme/app_theme.dart';
import 'features/home/boot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();          // 日志（版本+环境）
  await NotificationService.instance.init(); // 通知服务
  runApp(const ProviderScope(child: LingOsApp()));
}

class LingOsApp extends StatelessWidget {
  const LingOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LING OS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 【0.5.1 先生裁决】中英双语：Material 组件本地化 + 支持语言声明
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      localeResolutionCallback: (device, supported) {
        // AppStore 的 ui_language 可强制 zh/en；否则跟随设备
        final code = device?.languageCode ?? 'zh';
        return supported.firstWhere(
          (l) => l.languageCode == code,
          orElse: () => const Locale('zh'),
        );
      },
      // 【0.4.3】Boot 启动屏（本地模式——先生预览落地）：
      // 不强制连接；有已存 token 自动恢复；需用时"连接主机"按钮
      // 【0.7.0 P3】NotificationBridge：全局订阅事件流 → 后台时危机/预警本地通知
      home: const NotificationBridge(child: BootScreen()),
    );
  }
}
