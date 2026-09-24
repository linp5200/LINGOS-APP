/// 【0.2.2 vision】摄像头页面（先生裁决：凡支持播放的都可以——App/Web/桌面）
/// - 视频源管理（V4L2 / RTSP——vision.conf 配置）
/// - MJPEG 实时预览（rtsp_streamer HTTP :8891 / 或 visiond 提供）
/// - 检测状态显示（YOLO 标签/OCR 文字/世界坐标——来自 visiond 事件）
/// - 抓拍按钮（截图保存）
///
/// 【2026-09-18 补全】此前仅 vision_config_get 一条命令（审计项）→ 现补：
///   monitor_status / ai_vision_status 状态 + monitor_snapshot 抓拍 + ai_vision_detect 检测
///   （引擎未运行→服务端明确错误，如实展示）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  StreamSubscription? _sub;
  // 视频源配置（vision.conf——服务端查询）
  String _source = 'v4l2';
  String _rtspUrl = '';
  int _httpPort = 8891;
  // 检测事件（visiond → ai_server → WS vision_event）
  final List<Map<String, dynamic>> _detections = [];
  final List<Map<String, dynamic>> _ocrs = [];
  // 【2026-09-18】状态（monitor_status / ai_vision_status）
  Map<String, dynamic>? _monitorStatus;
  Map<String, dynamic>? _visionStatus;
  bool _busy = false;

  String _host() {
    final cm = ref.read(connectionProvider);
    final u = cm.ws?.url ?? '';
    return u.replaceFirst('wss://', '').replaceFirst('ws://', '').split(':').first;
  }

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'vision_event') {
        final d = evt['data'];
        if (d is Map) {
          if (!mounted) return;
          setState(() {
            if (d['detections'] is List) {
              _detections.clear();
              _detections.addAll((d['detections'] as List).whereType<Map<String, dynamic>>());
            }
            if (d['ocr'] is List) {
              _ocrs.clear();
              _ocrs.addAll((d['ocr'] as List).whereType<Map<String, dynamic>>());
            }
          });
        }
      }
    } catch (_) {}
  }

  /// 【2026-09-18 补全】三命令刷新：配置 + 监控状态 + 引擎状态
  Future<void> _refresh() async {
    final cm = ref.read(connectionProvider);
    try {
      final cfg = await cm.requestJson({'cmd': 'vision_config_get'});
      if (mounted && cfg != null && cfg['data'] is Map) {
        final d = cfg['data'] as Map;
        setState(() {
          _source = d['camera_source']?.toString() ?? 'v4l2';
          _rtspUrl = d['rtsp_url']?.toString() ?? '';
          _httpPort = (d['rtsp_http_port'] as num?)?.toInt() ?? 8891;
        });
      }
      final ms = await cm.requestJson({'cmd': 'monitor_status'});
      if (mounted && ms != null && ms['status'] == 'ok') {
        setState(() => _monitorStatus = ms['data'] is Map ? Map<String, dynamic>.from(ms['data'] as Map) : null);
      }
      final vs = await cm.requestJson({'cmd': 'ai_vision_status'});
      if (mounted && vs != null && vs['status'] == 'ok') {
        setState(() => _visionStatus = vs['data'] is Map ? Map<String, dynamic>.from(vs['data'] as Map) : null);
      }
    } catch (_) {}
  }

  /// 【2026-09-18 补全】抓拍（monitor_snapshot——服务端 ffmpeg 单帧）
  Future<void> _snapshot() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resp = await ref.read(connectionProvider).requestJson(
        {'cmd': 'monitor_snapshot', 'camera_id': 'cam0'},
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      final ok = resp != null && resp['status'] == 'ok';
      final msg = ok
          ? '已抓拍：${(resp['data'] is Map ? (resp['data'] as Map)['file'] : null) ?? '完成'}'
          : '抓拍失败：${resp?['msg'] ?? '未连接或超时'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 【2026-09-18 补全】AI 物体检测（ai_vision_detect——yolo.sock 真实调用）
  Future<void> _detect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resp = await ref.read(connectionProvider).requestJson(
        {'cmd': 'ai_vision_detect'},
        timeout: const Duration(seconds: 35),
      );
      if (!mounted) return;
      if (resp != null && resp['status'] == 'ok') {
        final d = resp['data'];
        final dets = (d is Map && d['detections'] is List)
            ? (d['detections'] as List).whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _detections.clear();
          _detections.addAll(dets);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检测完成：${dets.length} 个目标')));
      } else {
        // 引擎未运行/无帧来源 → 服务端明确错误（如实展示，不伪造）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检测失败：${resp?['msg'] ?? '未连接或超时'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _host();
    final md = _monitorStatus;
    final vd = _visionStatus;
    return Scaffold(
      appBar: AppBar(
        title: const Text('摄像头'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新状态',
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 视频源状态
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_source == 'rtsp' ? Icons.videocam : Icons.videocam_outlined,
                          size: 18, color: AppColors.brandCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('视频源: ${_source == 'rtsp' ? 'RTSP ($_rtspUrl)' : 'V4L2 (/dev/video0)'}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('预览: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('http://$host:$_httpPort/stream',
                          style: const TextStyle(fontSize: 12, color: AppColors.brandCyan, fontFamily: 'monospace')),
                    ],
                  ),
                  if (md != null || vd != null) ...[
                    const Divider(height: 16),
                    Text(
                      '监控: ${md != null ? '${(md['cameras'] is List ? (md['cameras'] as List).length : 0)} 路配置' : '--'}'
                      ' · 引擎: ${vd != null ? (vd['yolo'] == true ? 'YOLO 运行中' : 'YOLO 未运行') : '--'}'
                      '${vd != null && vd['visiond'] == true ? ' · visiond 在' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 操作按钮（【2026-09-18】补全：抓拍 + 检测）
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _snapshot,
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('抓拍', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _detect,
                  icon: _busy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.center_focus_strong, size: 16),
                  label: const Text('AI 检测', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // MJPEG 实时预览
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _source == 'rtsp'
                ? Image.network(
                    'http://$host:$_httpPort/stream',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('预览不可用——确认 rtsp_streamer 运行中',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  )
                : const Center(
                    child: Text('V4L2 本地摄像头——预览走服务端（二期）',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
          ),
          const SizedBox(height: 16),
          // 检测结果
          if (_detections.isNotEmpty) ...[
            const Text('物体检测', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ..._detections.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    // 【2026-09-18 修复】原 toStringAsFixed 误置于插值外（显示为字面文本）
                    '${d['label'] ?? '?'} (${(((d['confidence'] as num?)?.toDouble() ?? 0.0) * 100.0).toStringAsFixed(0)}%)'
                    '${d['world_x'] != null ? '  @x=${(d['world_x'] as num).toInt()}cm y=${(d['world_y'] as num?)?.toInt() ?? 0}cm' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                )),
            const SizedBox(height: 8),
          ],
          // OCR 结果
          if (_ocrs.isNotEmpty) ...[
            const Text('文字识别（OCR）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ..._ocrs.map((o) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    // 【2026-09-18 修复】同上——toStringAsFixed 位置修正
                    '“${o['text'] ?? ''}” (${(((o['confidence'] as num?)?.toDouble() ?? 0.0) * 100.0).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (_detections.isEmpty && _ocrs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('暂无检测结果——等待 visiond 识别事件，或点上方「AI 检测」',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}
