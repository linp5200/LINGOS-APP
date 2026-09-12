/// LING OS App 国际化运行时（先生 2026-09-12 · 0.5.1）
///
/// 用法：
///   import '../core/i18n/app_i18n.dart';
///   Text(tr('nav_options'))
///   Text(trCtx(context, 'opt_privacy_mode'))
///
/// 语言来源：AppStore 的 ui_language（system/zh/en）
///   · system → 跟随设备语言
///   · zh / en → 强制
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';

/// 当前语言（由 App 启动时从 AppStore 载入；切换时更新）
class AppLocale extends StateNotifier<AppLang> {
  AppLocale() : super(AppLang.zh);

  void set(AppLang l) => state = l;

  /// 从设备语言 + 用户设置解析
  static AppLang resolve(String? setting, Locale? device) {
    if (setting == null || setting.isEmpty || setting == 'system') {
      return appLangFrom(device?.languageCode);
    }
    return appLangFrom(setting);
  }
}

/// 全局语言 Provider
final appLangProvider = StateNotifierProvider<AppLocale, AppLang>((ref) => AppLocale());

/// 便捷：直接取字符串（默认中文；UI 内推荐用 trCtx）
String tr(String key, [AppLang? lang]) => AppStrings.get(key, lang ?? AppLang.zh);

/// 上下文版：自动读取当前语言
String trCtx(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return AppStrings.get(key, appLangFrom(code));
}

/// 预警级别 → 本地化名称（L1~L4 / Minor~Extreme）
String alertLevelLabel(dynamic level, [AppLang? lang]) {
  final l = lang ?? AppLang.zh;
  final s = (level ?? '').toString().toUpperCase();
  if (s.contains('L4') || s.contains('EXTREME')) return AppStrings.get('alert_l4', l);
  if (s.contains('L3') || s.contains('SEVERE')) return AppStrings.get('alert_l3', l);
  if (s.contains('L2') || s.contains('MODERATE')) return AppStrings.get('alert_l2', l);
  if (s.contains('L1') || s.contains('MINOR')) return AppStrings.get('alert_l1', l);
  return s.isEmpty ? '--' : s;
}
