/// LING OS App 入口（Flutter 重写——协议 v3）
/// 【0.4.3 先生裁决】开屏不再强制连接主机——本地模式可用，需用时手动连（设置→连接）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/services/notification_service.dart';
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
      // 【0.4.3】Boot 启动屏（本地模式——先生预览落地）：
      // 不强制连接；有已存 token 自动恢复；需用时"连接主机"按钮
      home: const BootScreen(),
    );
  }
}
