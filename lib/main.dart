/// LING OS App 入口（Flutter 重写——协议 v3）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/connect/connect_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
