/// 全局主题（FUI v2 / Tactical HUD——先生 2026-09-04 定稿）
/// 灰白地形图语言：中深灰渐变底（少纯黑）/ 白线框架 / 色彩功能化
/// 绿=在线/数据 · 琥珀=未连/警告 · 红=录影/警报（唯一警报色）
library;

import 'package:flutter/material.dart';

class AppColors {
  // FUI v2 色板：中深灰（非纯黑）为底，白线低透明做框架
  static const bg = Color(0xFF1E2126);          // 中深灰底（替代纯黑）
  static const bgAlt = Color(0xFF16191D);        // 更深一档（局部）
  static const surface = Color(0xFF2B3038);      // 面板（半透明灰感）
  static const surfaceHigh = Color(0xFF333942);  // 高亮面板
  static const line = Color(0x47FFFFFF);         // 白线框 rgba(255,.28)
  static const lineDim = Color(0x24FFFFFF);      // 白线框 rgba(255,.14)
  static const white = Color(0xFFF4F6F8);        // 主文字
  static const gray = Color(0xFFA9B1BC);         // 次级文字
  static const dim = Color(0xFF6B7480);          // 弱化
  static const dd = Color(0xFF3E454F);           // 更弱（标签）
  // 功能色（先生定：色彩功能化，不作装饰）
  static const green = Color(0xFF6CF59A);        // 在线/检测/数据
  static const amber = Color(0xFFFFBE4D);        // 未连/警告
  static const yellow = amber;                    // 兼容旧引用（日志 WARN）
  static const red = Color(0xFFFF4D4D);          // 录影/警报（仅警报）
  static const blue = Color(0xFF5AB0FF);         // 信息（可选）
  // 兼容旧引用（brand 前缀 + text 前缀——全局不破坏）
  static const brandRed = red;
  static const brandCyan = gray;                 // 原青→灰
  static const brandGreen = green;
  static const brandAmber = amber;
  static const textPrimary = white;
  static const textSecondary = gray;
  static const divider = line;
}

/// FUI 等宽字体（数据/参数/日志用——monospace）
const String fuiMono = 'monospace';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.green,          // FUI v2：主强调=绿（在线/数据）
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
      indicatorColor: AppColors.green.withValues(alpha: 0.15),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 10, color: AppColors.gray, letterSpacing: 1),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.bg),
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
        borderSide: const BorderSide(color: AppColors.green),
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
