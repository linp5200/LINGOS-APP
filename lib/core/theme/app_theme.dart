/// 全局主题（FUI / Tactical HUD——先生 2026-08-22 定稿）
/// 纯黑白灰高对比 + 少量鲜红点缀；极细线框；等宽字体用于数据
library;

import 'package:flutter/material.dart';

class AppColors {
  // FUI 主色板：纯黑/白/冷灰 + 鲜红（警报/强调）
  static const bg = Color(0xFF050505);          // 纯黑底
  static const surface = Color(0xFF0A0A0A);      // 面板
  static const surfaceHigh = Color(0xFF111111);  // 高亮面板
  static const line = Color(0xFF262626);         // 极细线框
  static const lineDim = Color(0xFF1A1A1A);
  static const white = Color(0xFFF0F0F0);        // 主文字
  static const gray = Color(0xFF8A8A8A);         // 次级
  static const dim = Color(0xFF4A4A4A);          // 弱化
  static const red = Color(0xFFFF2A2A);          // 鲜红——唯一强调色
  static const yellow = Color(0xFFFFD24A);       // 警告（仅日志/预警）
  // 兼容旧引用（brand 前缀）
  static const brandRed = red;
  static const brandCyan = gray;                 // 原青→灰（FUI 去彩色）
  static const textPrimary = white;
  static const textSecondary = gray;
  static const divider = line;
}

/// FUI 等宽字体（数据/参数/日志用——monospace）
const String fuiMono = 'monospace';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.red,
    secondary: AppColors.gray,
    surface: AppColors.surface,
    onSurface: AppColors.white,
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    error: AppColors.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.red.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10, color: AppColors.gray, letterSpacing: 1),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),  // FUI 锐角
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      hintStyle: const TextStyle(color: AppColors.dim, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),  // 锐角
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    ),
  );
}
