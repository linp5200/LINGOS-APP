/// LING OS 图标体系（先生 2026-09-12 定稿）
///
/// 设计依据（先生手稿三张 + 线上逐轮校对）：
///   · 图标库 **Tabler**（MIT · 5000+ · stroke2）
///   · **库有原生变体就不叠加**（wifi-off / bluetooth-x / server-off…）
///   · 基础图形 + 角标（Flutter Badge 式叠加）
///   · 角标：左上 H(本地)/S(服务端)/AI · 右上 W(互联网通讯)
///          右下 I(互联网连接) / ⇅(同步中) / E(错误·红·**恒最末**)
///   · 尺寸：图标区正方形 52 基准 · 角标字号 22 字重 800
///   · E 色 #E5484D；除 E 外全部黑白灰
///   · 冲突=alert-circle · 未知=help-circle · 选择提示符已取消
library;

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// 转发导出：引用本文件即可使用 TablerIcons.*（避免各处重复 import）
export 'package:flutter_tabler_icons/flutter_tabler_icons.dart' show TablerIcons;

/// 角标错误色（先生定稿）
const Color kLingErrorColor = Color(0xFFE5484D);

// ============================================================
// 1. 基础图形（Tabler 原生）
// ============================================================
class LingIcons {
  LingIcons._();

  // —— 基础图形 ——
  static const IconData upload = TablerIcons.arrow_up;
  static const IconData download = TablerIcons.arrow_down;
  static const IconData sync = TablerIcons.arrows_up_down;
  static const IconData connect = TablerIcons.wifi;
  static const IconData signal = TablerIcons.antenna_bars_3;
  static const IconData bluetooth = TablerIcons.bluetooth;
  static const IconData host = TablerIcons.server_2;
  static const IconData internalService = TablerIcons.settings;   // 内部服务
  static const IconData ai = TablerIcons.sparkles;                 // AI ✨
  static const IconData device = TablerIcons.cpu;

  // —— 状态变体（库原生，**不叠加**）——
  static const IconData connectOff = TablerIcons.wifi_off;
  static const IconData bluetoothOff = TablerIcons.bluetooth_off;
  static const IconData bluetoothUnavailable = TablerIcons.bluetooth_x;
  static const IconData bluetoothConnected = TablerIcons.bluetooth_connected;
  static const IconData hostOff = TablerIcons.server_off;
  static const IconData worldOff = TablerIcons.world_off;
  static const IconData routerOff = TablerIcons.router_off;
  static const IconData cloudOff = TablerIcons.cloud_off;
  static const IconData plugOff = TablerIcons.plug_off;

  /// 信号强度（1~5 档，0 = 无信号）
  static IconData signalLevel(int level) {
    switch (level) {
      case 1: return TablerIcons.antenna_bars_1;
      case 2: return TablerIcons.antenna_bars_2;
      case 3: return TablerIcons.antenna_bars_3;
      case 4: return TablerIcons.antenna_bars_4;
      case 5: return TablerIcons.antenna_bars_5;
      default: return TablerIcons.antenna_bars_off;
    }
  }

  // —— 语义标记 ——
  static const IconData conflict = TablerIcons.alert_circle;
  static const IconData warning = TablerIcons.alert_triangle;
  static const IconData unknown = TablerIcons.help_circle;
}

// ============================================================
// 2. 角标系统
// ============================================================

/// 域（左上角标）
enum LingScope {
  none,     // 无
  host,     // H —— 本地
  server,   // S —— 服务端（主机端）
}

/// 状态角标（右下）
enum LingStatus {
  none,
  internet,   // I —— 以互联网形式连接
  syncing,    // ⇅ —— 正在与主机同步
  conflict,   // ! —— 冲突
  unknown,    // ? —— 未知
  error,      // E —— 错误（红，**恒最末**）
}

/// 完整图标：基础图形 + 角标叠加
class LingIcon extends StatelessWidget {
  const LingIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.scope = LingScope.none,
    this.ai = false,
    this.wan = false,            // 右上 W
    this.status = LingStatus.none,
    this.badgeScale = 0.82,      // 角标字号 / 图标尺寸（先生：字号22 / 图标52 ≈ 0.42）
  });

  final IconData icon;
  final double size;
  final Color? color;
  final LingScope scope;
  final bool ai;                // AI 角标（与 H/S 并列）
  final bool wan;               // W 右上
  final LingStatus status;
  final double badgeScale;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFE8EAED);
    // 角标字号（先生：图标 52 → 角标 22，即 0.42；此处按比例适配小图标）
    final fs = (size * badgeScale * 0.52).clamp(8.0, 22.0);
    final fw = FontWeight.w800;

    Widget badge(String text, {bool red = false}) => Text(
          text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: fw,
            fontFamily: 'monospace',
            height: 1.0,
            color: red ? kLingErrorColor : c,
          ),
        );

    // 左上：H / S +（可选）AI
    final tlText = [
      if (scope == LingScope.host) 'H',
      if (scope == LingScope.server) 'S',
      if (ai) 'AI',
    ].join();

    // 右下：状态（E 恒最末）
    String brText = '';
    bool brRed = false;
    switch (status) {
      case LingStatus.internet: brText = 'I'; break;
      case LingStatus.syncing: brText = '⇅'; break;
      case LingStatus.conflict: brText = '!'; break;
      case LingStatus.unknown: brText = '?'; break;
      case LingStatus.error: brText = 'E'; brRed = true; break;
      case LingStatus.none: break;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon, size: size, color: c)),
          if (tlText.isNotEmpty)
            Positioned(left: -fs * 0.35, top: -fs * 0.3, child: badge(tlText)),
          if (wan)
            Positioned(right: -fs * 0.4, top: -fs * 0.3, child: badge('W')),
          if (brText.isNotEmpty)
            Positioned(right: -fs * 0.4, bottom: -fs * 0.35, child: badge(brText, red: brRed)),
        ],
      ),
    );
  }
}

// ============================================================
// 3. 时长/PING 指示（启动动画的静态版 —— 先生动画待定稿）
// ============================================================
/// 静态「同步」图标（动画版待先生确认效果后接入）
class LingSyncIndicator extends StatelessWidget {
  const LingSyncIndicator({super.key, this.size = 24, this.color, this.active = false});

  final double size;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return LingIcon(LingIcons.sync,
        size: size, color: color, status: active ? LingStatus.syncing : LingStatus.none);
  }
}

// ============================================================
// 4. 常用组合（业务语义 → 图标）
// ============================================================
class LingStatusIcon extends StatelessWidget {
  const LingStatusIcon({
    super.key,
    required this.connected,
    this.syncing = false,
    this.error = false,
    this.isServer = false,
    this.size = 20,
  });

  final bool connected;
  final bool syncing;
  final bool error;
  final bool isServer;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LingIcon(
      connected ? LingIcons.connect : LingIcons.connectOff,
      size: size,
      scope: isServer ? LingScope.server : LingScope.host,
      status: error
          ? LingStatus.error
          : (syncing ? LingStatus.syncing : LingStatus.none),
    );
  }
}
