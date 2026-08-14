/// 【0.2.2 vision】摄像头页面（先生裁决：凡支持播放的都可以——App/Web/桌面）
/// - 视频源管理（V4L2 / RTSP——vision.conf 配置）
/// - MJPEG 实时预览（rtsp_streamer HTTP :8891 / 或 visiond 提供）
/// - 检测状态显示（YOLO 标签/OCR 文字/世界坐标——来自 visiond 事件）
/// - 抓拍按钮（截图保存）
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
  // 检测事件（visiond → ai_server → WS ha_event 同级扩展）
  final List<Map<String, dynamic>> _detections = [];
  final List<Map<String, dynamic>> _ocrs = [];

  String _host() {
    final cm = ref.read(connectionProvider);
    final u = cm.ws?.url ?? '';
    return u.replaceFirst('wss://', '').replaceFirst('ws://', '').split(':').first;
  }

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _loadConfig();
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

  Future<void> _loadConfig() async {
    final cm = ref.read(connectionProvider);
    final resp = await cm.requestJson({'cmd': 'vision_config_get'});
    if (!mounted || resp == null) return;
    final d = resp['data'];
    if (d is Map) {
      setState(() {
        _source = d['camera_source']?.toString() ?? 'v4l2';
        _rtspUrl = d['rtsp_url']?.toString() ?? '';
        _httpPort = (d['rtsp_http_port'] as num?)?.toInt() ?? 8891;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _host();
    return Scaffold(
      appBar: AppBar(title: const Text('摄像头')),
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
                      Text('视频源: ${_source == 'rtsp' ? 'RTSP ($_rtspUrl)' : 'V4L2 (/dev/video0)'}',
                          style: const TextStyle(fontSize: 13)),
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
                ],
              ),
            ),
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
                    '${d['label'] ?? '?'} (${((d['confidence'] as num?)?.toDouble() ?? 0.0) * 100.0}.toStringAsFixed(0)}%)'
                    '${d['world_x'] != null ? '  @x=${(d['world_x'] as num).toInt()}cm y=${(d['world_y'] as num).toInt()}cm' : ''}',
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
                  child: Text('“${o['text'] ?? ''}” (${((o['confidence'] as num?)?.toDouble() ?? 0.0) * 100.0}.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                )),
            const SizedBox(height: 8),
          ],
          if (_detections.isEmpty && _ocrs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('暂无检测结果——等待 visiond 识别事件',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}
