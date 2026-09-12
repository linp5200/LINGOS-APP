/// LING OS App 国际化运行时（先生 2026-09-12 · 0.5.1）
///
/// 两种用法：
///   Text(tr('nav_options'))            ← 推荐：无需 context（读全局语言态）
///   Text(trCtx(context, 'nav_options')) ← 需要按 Localizations 精确判定时使用
///
/// 设计说明：
///   · **不用 intl / .arb**（避免 CI 版本冲突与代码生成）
///   · 全局语言态 `AppLangState.current`：语言切换时更新，MaterialApp 的
///     locale 变化会触发全树 rebuild → tr() 读到新值
///   · 未收录 key 回落为 key 本身（便于发现遗漏）
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';

/// 全局语言态（供无 context 的 tr() 使用）
class AppLangState {
  AppLangState._();
  static AppLang current = AppLang.zh;
}

/// 当前语言 Provider（UI 内可 watch）
class AppLocale extends StateNotifier<AppLang> {
  AppLocale() : super(AppLang.zh);

  void set(AppLang l) {
    state = l;
    AppLangState.current = l;   // 同步全局态
  }

  /// 从设备语言 + 用户设置解析
  static AppLang resolve(String? setting, Locale? device) {
    if (setting == null || setting.isEmpty || setting == 'system') {
      return appLangFrom(device?.languageCode);
    }
    return appLangFrom(setting);
  }
}

final appLangProvider =
    StateNotifierProvider<AppLocale, AppLang>((ref) => AppLocale());

/// ★ 主用：无需 context 的取字符串
String tr(String key) => AppStrings.get(key, AppLangState.current);

/// 上下文版（按 Localizations 精确判定）
String trCtx(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return AppStrings.get(key, appLangFrom(code));
}

/// 预警级别 → 本地化名称（L1~L4 / Minor~Extreme）
String alertLevelLabel(dynamic level, [AppLang? lang]) {
  final l = lang ?? AppLangState.current;
  final s = (level ?? '').toString().toUpperCase();
  if (s.contains('L4') || s.contains('EXTREME')) return AppStrings.get('alert_l4', l);
  if (s.contains('L3') || s.contains('SEVERE')) return AppStrings.get('alert_l3', l);
  if (s.contains('L2') || s.contains('MODERATE')) return AppStrings.get('alert_l2', l);
  if (s.contains('L1') || s.contains('MINOR')) return AppStrings.get('alert_l1', l);
  return s.isEmpty ? '--' : s;
}
