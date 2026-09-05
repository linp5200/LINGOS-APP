/// FUI / Tactical HUD 组件库（先生 2026-08-22 定稿——自绘方式）
/// 极细线框 / 经纬网格 / 十字准星 / 等宽数据行 / 括号分隔 / 扫描线
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// FUI 等高线地形背景（先生 2026-09-04 定稿——灰白地形图语言）
/// 算法：高斯峰海拔场 + Marching Squares 提取等值线（链化连续）——与 HTML 原型一致
/// 用法：作全屏背景层（低不透明度白线），内容叠其上
class FuiTerrainBackground extends StatelessWidget {
  final double opacity;
  final int seed;
  final Color lineColor;
  const FuiTerrainBackground({
    super.key,
    this.opacity = 0.10,
    this.seed = 20260904,
    this.lineColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _TerrainPainter(seed: seed, opacity: opacity, lineColor: lineColor),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TerrainPainter extends CustomPainter {
  final int seed;
  final double opacity;
  final Color lineColor;
  _TerrainPainter({required this.seed, required this.opacity, required this.lineColor});

  // 确定性伪随机（同 seed 同地形）
  double _rnd(List<int> state) {
    state[0] = (state[0] * 1103515245 + 12345) & 0x7fffffff;
    return state[0] / 0x7fffffff;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10 || size.height < 10) return;
    final gw = (size.width / 12).round().clamp(20, 80);
    final gh = (size.height / 12).round().clamp(16, 60);

    // 1) 高斯峰海拔场（4-6 峰）
    final st = [seed];
    final peaks = <List<double>>[];
    final nPeaks = 5;
    for (var i = 0; i < nPeaks; i++) {
      peaks.add([
        _rnd(st), _rnd(st),                       // cx cy（相对）
        0.09 + _rnd(st) * 0.20, 0.09 + _rnd(st) * 0.20, // rx ry
        0.9 + _rnd(st) * 1.4,                     // 幅值
        _rnd(st) * math.pi,                       // 旋转
      ]);
    }
    final field = List<double>.filled(gw * gh, 0);
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        final nx = x / (gw - 1), ny = y / (gh - 1);
        var v = 0.0;
        for (final p in peaks) {
          final dx = nx - p[0], dy = ny - p[1];
          final ex = dx * math.cos(p[5]) + dy * math.sin(p[5]);
          final ey = -dx * math.sin(p[5]) + dy * math.cos(p[5]);
          final vv = (ex / p[2]) * (ex / p[2]) + (ey / p[3]) * (ey / p[3]);
          v += p[4] * math.exp(-vv);
        }
        // 低频扰动（谷地自然）
        v += 0.16 * (math.sin(nx * 7.1 + seed) + math.cos(ny * 5.7 + seed) +
            0.5 * math.sin((nx + ny) * 11.9));
        field[y * gw + x] = v;
      }
    }
    var mn = double.infinity, mx = -double.infinity;
    for (final f in field) {
      if (f < mn) mn = f;
      if (f > mx) mx = f;
    }
    final pLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 2) Marching Squares 提取等值线（9-10 层，每 4 层为计曲线加粗）
    for (var lv = 0; lv < 10; lv++) {
      final th = mn + (mx - mn) * (lv + 1) / 11;
      final isIndex = (lv % 4 == 3);
      pLine
        ..strokeWidth = isIndex ? 1.1 : 0.55
        ..color = lineColor.withValues(alpha: opacity * (isIndex ? 1.0 : 0.5));
      final path = Path();
      for (var y = 0; y < gh - 1; y++) {
        for (var x = 0; x < gw - 1; x++) {
          final i = y * gw + x;
          final tl = field[i], tr = field[i + 1];
          final br = field[i + gw + 1], bl = field[i + gw];
          double lerp(double a, double b) {
            final t = (th - a) / (b - a);
            return t < 0 ? 0 : (t > 1 ? 1 : t);
          }

          final pts = <List<double>>[];
          if ((tl > th) != (tr > th)) pts.add([x + lerp(tl, tr), y]);
          if ((tr > th) != (br > th)) pts.add([x + 1, y + lerp(tr, br)]);
          if ((bl > th) != (br > th)) pts.add([x + lerp(bl, br), y + 1]);
          if ((tl > th) != (bl > th)) pts.add([x, y + lerp(tl, bl)]);
          if (pts.length == 2) {
            path.moveTo(pts[0][0] / (gw - 1) * size.width, pts[0][1] / (gh - 1) * size.height);
            path.lineTo(pts[1][0] / (gw - 1) * size.width, pts[1][1] / (gh - 1) * size.height);
          } else if (pts.length == 4) {
            final c = (tl + tr + bl + br) * 0.25;
            if (c > th) {
              path.moveTo(pts[0][0] / (gw - 1) * size.width, pts[0][1] / (gh - 1) * size.height);
              path.lineTo(pts[1][0] / (gw - 1) * size.width, pts[1][1] / (gh - 1) * size.height);
              path.moveTo(pts[2][0] / (gw - 1) * size.width, pts[2][1] / (gh - 1) * size.height);
              path.lineTo(pts[3][0] / (gw - 1) * size.width, pts[3][1] / (gh - 1) * size.height);
            } else {
              path.moveTo(pts[0][0] / (gw - 1) * size.width, pts[0][1] / (gh - 1) * size.height);
              path.lineTo(pts[3][0] / (gw - 1) * size.width, pts[3][1] / (gh - 1) * size.height);
              path.moveTo(pts[1][0] / (gw - 1) * size.width, pts[1][1] / (gh - 1) * size.height);
              path.lineTo(pts[2][0] / (gw - 1) * size.width, pts[2][1] / (gh - 1) * size.height);
            }
          }
        }
      }
      canvas.drawPath(path, pLine);
    }

    // 3) 淡坐标网格
    final pGrid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = Colors.white.withValues(alpha: opacity * 0.25);
    final gridPath = Path();
    for (var g = 1; g < 6; g++) {
      final px = size.width * g / 6;
      gridPath.moveTo(px, 0);
      gridPath.lineTo(px, size.height);
    }
    for (var g = 1; g < 5; g++) {
      final py = size.height * g / 5;
      gridPath.moveTo(0, py);
      gridPath.lineTo(size.width, py);
    }
    canvas.drawPath(gridPath, pGrid);
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter old) =>
      old.seed != seed || old.opacity != opacity;
}

/// FUI 等宽数据行：`[ LABEL ] value`
class FuiDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;
  final double fontSize;
  const FuiDataRow(this.label, this.value,
      {super.key, this.alert = false, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('[ $label ]',
              style: TextStyle(
                  fontFamily: fuiMono,
                  fontSize: fontSize,
                  color: AppColors.gray,
                  letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontFamily: fuiMono,
                    fontSize: fontSize,
                    color: alert ? AppColors.red : AppColors.white,
                    fontWeight: alert ? FontWeight.w700 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

/// FUI 极细线框面板（锐角 + 可选角标）
class FuiPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final bool alert;
  const FuiPanel({super.key, required this.child, this.title, this.padding = const EdgeInsets.all(12), this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: alert ? AppColors.red : AppColors.line, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text('[ ${title!} ]',
                style: TextStyle(fontFamily: fuiMono, fontSize: 10, color: alert ? AppColors.red : AppColors.gray, letterSpacing: 1)),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// FUI 十字准星图标（自绘——无第三方依赖）
class FuiCrosshair extends StatelessWidget {
  final Color color;
  final double size;
  const FuiCrosshair({super.key, this.color = const Color(0xFF8A8A8A), this.size = 16});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _CrosshairPainter(color));
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;
  _CrosshairPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    // 十字线
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), p);
    canvas.drawLine(Offset(0, cy), Offset(w, cy), p);
    // 中心点
    canvas.drawCircle(Offset(cx, cy), 1.5, p);
    // 四角小刻度
    canvas.drawLine(Offset(0, cy - 3), Offset(0, cy + 3), p);
    canvas.drawLine(Offset(w, cy - 3), Offset(w, cy + 3), p);
    canvas.drawLine(Offset(cx - 3, 0), Offset(cx + 3, 0), p);
    canvas.drawLine(Offset(cx - 3, h), Offset(cx + 3, h), p);
  }
  @override
  bool shouldRepaint(covariant _CrosshairPainter old) => old.color != color;
}

/// FUI 经纬网格背景（数据详情/开屏）
class FuiGridBackground extends StatelessWidget {
  final Widget child;
  final Color lineColor;
  final double spacing;
  const FuiGridBackground({super.key, required this.child, this.lineColor = const Color(0xFF111111), this.spacing = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(lineColor, spacing),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  _GridPainter(this.color, this.spacing);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // 对角线等高线（左上→右下）
    final d = math.sqrt(size.width * size.width + size.height * size.height);
    for (double off = -d; off < d; off += spacing * 2) {
      canvas.drawLine(
          Offset(math.max(0, off), math.max(0, -off)),
          Offset(math.min(size.width, off + size.height), math.min(size.height, size.width - off)),
          p..strokeWidth = 0.3);
    }
  }
  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.color != color || old.spacing != spacing;
}

/// FUI 雷达扫描线（动效——旋转扇区）
class FuiRadarSweep extends StatefulWidget {
  final Color color;
  final double size;
  const FuiRadarSweep({super.key, this.color = const Color(0xFFFF2A2A), this.size = 80});

  @override
  State<FuiRadarSweep> createState() => _FuiRadarSweepState();
}

class _FuiRadarSweepState extends State<FuiRadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RadarPainter(widget.color, _ctrl.value * 2 * math.pi),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double angle;
  _RadarPainter(this.color, this.angle);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // 同心圆
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF2A2A2A);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.66, ring);
    canvas.drawCircle(c, r * 0.33, ring);
    // 十字
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);
    // 扫描扇区
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + math.pi / 3,
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), angle, math.pi / 3, true, sweep);
    // 扫线
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
        c, Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle)), line);
  }
  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.angle != angle;
}

/// FUI 括号标题（大字号粗体 + [ ] 分隔）
class FuiHeader extends StatelessWidget {
  final String text;
  final Color color;
  const FuiHeader(this.text, {super.key, this.color = const Color(0xFFF0F0F0)});

  @override
  Widget build(BuildContext context) {
    return Text(
      '[ $text ]',
      style: TextStyle(
        fontFamily: fuiMono,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        color: color,
      ),
    );
  }
}
