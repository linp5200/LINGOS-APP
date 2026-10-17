/// 主题变体控制器（A/B/C 运行时切换 + 持久化）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

AppThemeVariant variantFromCode(String code) {
  switch (code.toUpperCase()) {
    case 'B':
      return AppThemeVariant.home;
    case 'C':
      return AppThemeVariant.norma;
    case 'A':
    default:
      return AppThemeVariant.silent;
  }
}

String variantToCode(AppThemeVariant v) {
  switch (v) {
    case AppThemeVariant.home:
      return 'B';
    case AppThemeVariant.norma:
      return 'C';
    case AppThemeVariant.silent:
      return 'A';
  }
}

class ThemeVariantController extends StateNotifier<AppThemeVariant> {
  ThemeVariantController(super.initial) {
    AppThemeState.apply(initial);
  }

  void applyTheme(AppThemeVariant v) {
    AppThemeState.apply(v);
    state = v;
  }
}

final themeVariantProvider =
    StateNotifierProvider<ThemeVariantController, AppThemeVariant>((ref) {
  final c = ThemeVariantController(AppThemeState.variant);
  return c;
});
