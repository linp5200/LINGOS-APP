/// 全局主题（rikka 风格——Material3 精致深色）
library;

import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0D0D10);
  static const surface = Color(0xFF1A1A1F);
  static const surfaceHigh = Color(0xFF232329);
  static const brandRed = Color(0xFFE53935);
  static const brandCyan = Color(0xFF00BCD4);
  static const textPrimary = Color(0xFFEEEEEE);
  static const textSecondary = Color(0xFF999999);
  static const divider = Color(0xFF222228);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.brandRed,
    secondary: AppColors.brandCyan,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    error: AppColors.brandRed,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brandRed.withValues(alpha: 0.2),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandCyan),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
  );
}
