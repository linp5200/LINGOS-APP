/// LING OS App 入口（Flutter 重写——协议 v3）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/connect/connect_screen.dart';

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
      home: const ConnectScreen(),
    );
  }
}
