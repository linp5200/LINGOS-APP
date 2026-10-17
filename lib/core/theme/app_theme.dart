/// LING OS App 主题（三方向运行时主题：A 静默深色 / B 暖白家居 / C 诺玛 HUD）
/// 设计依据：docs/LINGOS-UI方向与设计系统-20261017.md
/// 说明：AppColors 变为"运行时调色板 getter"——切换主题后所有引用自动生效。
/// 注意：因此 AppColors 不再可用于 const 表达式（相关 const 已移除）。
library;

import 'package:flutter/material.dart';

enum AppThemeVariant { silent, home, norma }

class LingPalette {
  final String name;
  final bool dark;
  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color lineDim;
  final Color white;
  final Color gray;
  final Color dim;
  final Color dd;
  final Color green;
  final Color amber;
  final Color red;
  final Color blue;

  const LingPalette({
    required this.name,
    required this.dark,
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.lineDim,
    required this.white,
    required this.gray,
    required this.dim,
    required this.dd,
    required this.green,
    required this.amber,
    required this.red,
    required this.blue,
  });
}

const LingPalette kPaletteSilent = LingPalette(
  name: 'A 静默深色', dark: true,
  bg: Color(0xFF0B0D10), bgAlt: Color(0xFF07090C),
  surface: Color(0xFF12151A), surfaceHigh: Color(0xFF191D24),
  line: Color(0x14FFFFFF), lineDim: Color(0x0AFFFFFF),
  white: Color(0xFFE8EAED), gray: Color(0xFF9AA3AF),
  dim: Color(0xFF5C6470), dd: Color(0xFF3A424C),
  green: Color(0xFF3DDC97), amber: Color(0xFFE8A33D),
  red: Color(0xFFE5484D), blue: Color(0xFF5AC8FA),
);

const LingPalette kPaletteHome = LingPalette(
  name: 'B 暖白家居', dark: false,
  bg: Color(0xFFF7F5F0), bgAlt: Color(0xFFF0EDE6),
  surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFF0EDE6),
  line: Color(0x1A000000), lineDim: Color(0x0F000000),
  white: Color(0xFF1C1F24), gray: Color(0xFF5B616B),
  dim: Color(0xFF8A9099), dd: Color(0xFFB9BEC6),
  green: Color(0xFF0F9D6E), amber: Color(0xFFC77B1E),
  red: Color(0xFFC43D3D), blue: Color(0xFF2F7CD6),
);

const LingPalette kPaletteNorma = LingPalette(
  name: 'C 诺玛 HUD', dark: true,
  bg: Color(0xFF070A0F), bgAlt: Color(0xFF05070B),
  surface: Color(0xFF0E141D), surfaceHigh: Color(0xFF131B26),
  line: Color(0x2978C8FF), lineDim: Color(0x1478C8FF),
  white: Color(0xFFE6F1FF), gray: Color(0xFF9DB4CC),
  dim: Color(0xFF5A7186), dd: Color(0xFF35485C),
  green: Color(0xFF4FD1FF), amber: Color(0xFFFFB454),
  red: Color(0xFFFF5C5C), blue: Color(0xFF7AA2FF),
);

LingPalette paletteOf(AppThemeVariant v) {
  switch (v) {
    case AppThemeVariant.home:
      return kPaletteHome;
    case AppThemeVariant.norma:
      return kPaletteNorma;
    case AppThemeVariant.silent:
      return kPaletteSilent;
  }
}

/// 全局主题状态（运行时调色板）
class AppThemeState {
  AppThemeState._();

  static AppThemeVariant variant = AppThemeVariant.silent;
  static LingPalette palette = kPaletteSilent;

  static void apply(AppThemeVariant v) {
    variant = v;
    palette = paletteOf(v);
  }
}

/// App 颜色（运行时 getter——主题切换自动生效）
class AppColors {
  AppColors._();

  static LingPalette get _p => AppThemeState.palette;

  static Color get bg => _p.bg;
  static Color get bgAlt => _p.bgAlt;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get line => _p.line;
  static Color get lineDim => _p.lineDim;
  static Color get white => _p.white;
  static Color get gray => _p.gray;
  static Color get dim => _p.dim;
  static Color get dd => _p.dd;
  static Color get green => _p.green;
  static Color get amber => _p.amber;
  static Color get yellow => _p.amber;
  static Color get red => _p.red;
  static Color get blue => _p.blue;
  // 兼容旧引用
  static Color get brandRed => _p.red;
  static Color get brandCyan => _p.gray;
  static Color get brandGreen => _p.green;
  static Color get brandAmber => _p.amber;
  static Color get textPrimary => _p.white;
  static Color get textSecondary => _p.gray;
  static Color get divider => _p.line;
}

/// FUI 等宽字体（数据/参数/日志用）
const String fuiMono = 'monospace';

ThemeData buildAppTheme([AppThemeVariant? variant]) {
  final v = variant ?? AppThemeState.variant;
  AppThemeState.apply(v);
  final p = AppThemeState.palette;
  final scheme = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.green,
    onPrimary: p.dark ? Colors.black : Colors.white,
    secondary: p.gray,
    onSecondary: p.dark ? Colors.black : Colors.white,
    surface: p.surface,
    onSurface: p.white,
    error: p.red,
    onError: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.green.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10, color: p.gray, letterSpacing: 0.5),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: p.bg),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.green),
      ),
      hintStyle: TextStyle(color: p.dim, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: p.white,
      displayColor: p.white,
    ),
  );
}
