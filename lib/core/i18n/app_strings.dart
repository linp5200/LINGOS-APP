/// LING OS App 国际化字符串表（先生 2026-09-12 · 0.5.1）
///
/// 设计说明：
///   · **不依赖 intl / .arb 代码生成** —— 避免 CI 版本冲突与构建复杂化
///   · 纯 Dart Map 查表，支持 zh / en
///   · 未收录的 key 回落为 key 本身（便于发现遗漏）
///   · 预警分级等"随语言变化"的文案也在此表
library;

/// 支持的语言
enum AppLang { zh, en }

/// 由语言代码解析
AppLang appLangFrom(String? code) {
  if (code == null) return AppLang.zh;
  final c = code.toLowerCase();
  if (c.startsWith('en')) return AppLang.en;
  return AppLang.zh;
}

class AppStrings {
  AppStrings._();

  /// 语言代码 → 显示名
  static const Map<String, String> langName = {
    'zh': '中文',
    'en': 'English',
  };

  /// 字符串表（key → {zh, en}）
  static const Map<String, List<String>> _t = {
    // ---------- 通用 ----------
    'app_name': ['LING OS', 'LING OS'],
    'ok': ['确定', 'OK'],
    'cancel': ['取消', 'Cancel'],
    'save': ['保存', 'Save'],
    'close': ['关闭', 'Close'],
    'refresh': ['刷新', 'Refresh'],
    'loading': ['加载中…', 'Loading…'],
    'no_data': ['无数据（不模拟）', 'No data (not simulated)'],
    'not_connected': ['未连接主机', 'Not connected'],
    'connect_host': ['连接主机', 'Connect Host'],
    'disconnect': ['断开连接', 'Disconnect'],
    'retry': ['重试', 'Retry'],
    'add': ['新建', 'Add'],
    'delete': ['删除', 'Delete'],
    'search': ['搜索', 'Search'],
    'settings': ['设置', 'Settings'],
    'about': ['关于', 'About'],
    'unknowable': ['未连接（无法获知）', 'Unknown (not connected)'],

    // ---------- 导航 ----------
    'nav_console': ['主控台', 'Console'],
    'nav_chat': ['对话', 'Chat'],
    'nav_sessions': ['会话', 'Sessions'],
    'nav_dashboard': ['仪表盘', 'Dashboard'],
    'nav_alert': ['预警中心', 'Alerts'],
    'nav_weather': ['天气', 'Weather'],
    'nav_vision': ['摄像头', 'Cameras'],
    'nav_ha': ['Home Assistant', 'Home Assistant'],
    'nav_help_ai': ['Help AI', 'Help AI'],
    'nav_home': ['智能家居', 'Smart Home'],
    'nav_timeline': ['监控时间线', 'NVR Timeline'],
    'nav_notify': ['通知中心', 'Notifications'],
    'nav_media': ['媒体控制', 'Media'],
    'nav_kb': ['知识库', 'Knowledge Base'],
    'nav_options': ['可选项', 'Options'],

    // ---------- 可选项 ----------
    'opt_title': ['可选项', 'Options'],
    'opt_privacy_mode': ['隐私保护模式', 'Privacy Protection Mode'],
    'opt_privacy_desc': ['一次性开启全部安全增强 + 隐私技术',
      'Enable all security hardening + privacy tech at once'],
    'opt_enable_strictest': ['启用（最严）', 'Enable (strictest)'],
    'opt_restore_default': ['恢复默认', 'Restore defaults'],
    'opt_enabled': ['已启用', 'Enabled'],
    'opt_disabled': ['未启用', 'Disabled'],
    'opt_locked': ['底线', 'Baseline'],
    'opt_on': ['开', 'On'],
    'opt_off': ['关', 'Off'],
    'opt_dangerous': ['危险', 'Dangerous'],
    'opt_needs_condition': ['需条件', 'Requires condition'],
    'opt_danger_confirm': ['这是危险开关，关闭会降低安全性。确定继续？',
      'This is a dangerous switch; disabling reduces security. Continue?'],

    // ---------- 分组 ----------
    'grp_security': ['安全', 'Security'],
    'grp_privacy': ['隐私', 'Privacy'],
    'grp_feature': ['功能', 'Features'],
    'grp_ui': ['界面', 'Interface'],
    'grp_voice': ['语音', 'Voice'],
    'grp_ai': ['AI', 'AI'],
    'grp_data': ['数据', 'Data'],
    'grp_conn': ['连接', 'Connection'],
    'grp_other': ['其他', 'Other'],

    // ---------- 智能家居 ----------
    'home_title': ['智能家居', 'Smart Home'],
    'home_scene': ['场景', 'Scenes'],
    'home_area': ['区域', 'Areas'],
    'home_zone': ['地理围栏', 'Zones'],
    'home_automation': ['自动化', 'Automations'],
    'home_energy': ['能源（24h）', 'Energy (24h)'],
    'home_discovered': ['发现的设备', 'Discovered devices'],
    'home_energy_kwh': ['用电', 'Usage'],
    'home_energy_cost': ['费用', 'Cost'],
    'home_energy_tariff': ['电价', 'Tariff'],
    'home_create_scene': ['新建场景', 'New Scene'],
    'home_scan': ['发现设备', 'Scan devices'],
    'home_presence': ['在家/离家', 'Presence'],
    'home_home': ['在家', 'Home'],
    'home_away': ['离家', 'Away'],

    // ---------- 时间线 / NVR ----------
    'tl_title': ['监控时间线', 'NVR Timeline'],
    'tl_events_24h': ['24 小时事件', '24h events'],
    'tl_storage': ['存储', 'Storage'],
    'tl_used': ['已用', 'Used'],
    'tl_limit': ['上限', 'Limit'],
    'tl_recordings': ['录像', 'Recordings'],
    'tl_object_recordings': ['含对象', 'With objects'],
    'tl_event_list': ['事件列表', 'Events'],
    'tl_no_events': ['暂无事件', 'No events'],

    // ---------- 通知 ----------
    'nt_title': ['通知中心', 'Notifications'],
    'nt_mark_all_read': ['全部已读', 'Mark all read'],
    'nt_clear': ['清空', 'Clear'],
    'nt_dnd': ['免打扰', 'Do Not Disturb'],
    'nt_total': ['共', 'Total'],
    'nt_unread': ['未读', 'Unread'],
    'nt_empty': ['暂无通知', 'No notifications'],
    'nt_silenced': ['静默', 'Silenced'],
    'nt_dnd_hint': ['免打扰中（critical 仍推送）', 'DND active (critical still delivered)'],

    // ---------- 媒体 ----------
    'md_title': ['媒体控制', 'Media'],
    'md_no_player': ['无媒体设备', 'No media players'],
    'md_no_media': ['（无媒体）', '(no media)'],

    // ---------- 知识库 ----------
    'kb_title': ['知识库', 'Knowledge Base'],
    'kb_docs': ['文档', 'Documents'],
    'kb_chunks': ['分块', 'Chunks'],
    'kb_upload': ['上传', 'Upload'],
    'kb_query_hint': ['输入问题检索知识库…', 'Ask a question about the knowledge base…'],
    'kb_ask': ['检索', 'Search'],
    'kb_results': ['检索结果', 'Results'],
    'kb_doc_list': ['文档列表', 'Documents'],
    'kb_empty': ['知识库为空', 'Knowledge base is empty'],
    'kb_not_found': ['未找到相关内容', 'No relevant content found'],

    // ---------- 预警分级（随语言）----------
    'alert_l1': ['L1 轻微', 'L1 Minor'],
    'alert_l2': ['L2 中等', 'L2 Moderate'],
    'alert_l3': ['L3 严重', 'L3 Severe'],
    'alert_l4': ['L4 极端', 'L4 Extreme'],
    'alert_forecast': ['预告', 'Forecast'],

    // ---------- 连接 ----------
    'conn_encrypted': ['加密', 'Encrypted'],
    'conn_plaintext': ['明文', 'Plaintext'],
    'conn_connecting': ['连接中…', 'Connecting…'],
    'conn_connected': ['已连接', 'Connected'],
    'conn_offline': ['离线', 'Offline'],

    // ---------- 通用（补充）----------
    'common_not_simulated': ['（显示 -- 不模拟）', '(showing --, not simulated)'],

    // ---------- 天气屏 ----------
    'weather_title': ['天气', 'Weather'],
    'weather_unreachable': ['天气源不可达', 'Weather source unreachable'],
    'weather_location': ['当前位置', 'Current location'],
    'weather_feels': ['体感', 'Feels like'],
    'weather_humidity': ['湿度', 'Humidity'],
    'weather_wind': ['风速', 'Wind speed'],
    'weather_wind_dir': ['风向', 'Wind direction'],
    'weather_pressure': ['气压', 'Pressure'],
    'weather_visibility': ['能见度', 'Visibility'],
    'weather_hourly': ['逐小时', 'Hourly'],
    'weather_daily': ['7 日预报', '7-day forecast'],
    // WMO 天气状况（weather_screen 代码映射）
    'w_clear': ['晴', 'Clear'],
    'w_partly': ['少云', 'Partly cloudy'],
    'w_overcast': ['阴', 'Overcast'],
    'w_fog': ['雾', 'Fog'],
    'w_drizzle': ['毛毛雨', 'Drizzle'],
    'w_rain': ['雨', 'Rain'],
    'w_snow': ['雪', 'Snow'],
    'w_showers': ['阵雨', 'Showers'],
    'w_snow_showers': ['阵雪', 'Snow showers'],
    'w_thunder': ['雷暴', 'Thunderstorm'],

    // ---------- 预警屏（补充）----------
    'alert_title': ['预警中心', 'Alert Center'],
    'alert_generic': ['预警', 'Alert'],
    'alert_new': ['新预警', 'New alert'],
    'alert_none': ['暂无预警', 'No alerts'],
    'alert_source': ['来源：', 'Source: '],
    'alert_type': ['类型：', 'Type: '],

    // ---------- 仪表盘（补充）----------
    'dash_invalid_resp': ['核心数据无有效响应（格式异常）', 'Invalid core response (malformed)'],
    'dash_fetch_fail': ['获取失败：', 'Fetch failed: '],
    'dash_unknown_error': ['未知错误', 'Unknown error'],
    'dash_empty': ['核心数据为空（服务端无有效数据）', 'Empty core data (server returned nothing)'],
    'dash_cmd_fail': ['命令发送失败', 'Command send failed'],
    'dash_tap_refresh': ['点击刷新获取系统状态', 'Tap refresh to load system status'],
    'dash_mem': ['内存', 'Memory'],
    'dash_disk': ['磁盘', 'Disk'],
    'dash_uptime': ['运行时长', 'Uptime'],
    'dash_net': ['网络', 'Network'],
    'dash_status': ['状态', 'Status'],

    // ---------- 启动屏 ----------
    'boot_restore_detected': ['检测到已保存会话——自动恢复…', 'Saved session detected — auto restoring…'],
    'boot_restore_ok': ['会话已恢复', 'Session restored'],
    'boot_restore_fail': ['自动恢复失败——本地模式', 'Auto restore failed — local mode'],
    'boot_local_mode': ['LOCAL MODE —— 未连接主机，本地功能可用', 'LOCAL MODE — host not connected, local features available'],
    'boot_enter_console': ['进入主控台 ›', 'Enter Console ›'],
  };

  /// 取字符串
  static String get(String key, AppLang lang) {
    final v = _t[key];
    if (v == null) return key;
    return lang == AppLang.en ? v[1] : v[0];
  }

  /// 是否已收录
  static bool has(String key) => _t.containsKey(key);

  /// 全部 key（供完整性检查）
  static List<String> allKeys() => _t.keys.toList();
}
