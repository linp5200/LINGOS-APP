/// 【0.2.0】语音助手（录音 → STT 上传 → 文本；TTS 合成 → 下载 → 播放）
/// 架构（先生决策）：音频本体不走 WS——WS 信令 + HTTP(8088) REST 传输
/// - 服务端代理：录音文件 POST 到 host:8088/api/audio/stt；TTS 经 WS voice_tts 拿 file → GET 下载
/// - 本地直连：预留（provider 密钥在 App——本版走服务端代理为主）
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceHelper {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  bool _recording = false;

  String _host = '127.0.0.1';
  int _audioPort = 8088;
  String _token = '';

  void configure({required String host, required String token, int audioPort = 8088}) {
    _host = host;
    _token = token;
    _audioPort = audioPort;
  }

  /// 请求录音权限（RECORD_AUDIO——manifest 已声明）
  Future<bool> ensureMicPermission() async {
    final st = await Permission.microphone.request();
    return st.isGranted;
  }

  /// 开始录音（连续对话/按住说话）
  Future<String?> startRecording() async {
    if (_recording) return null;
    if (!await ensureMicPermission()) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/lingos_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const cfg = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      );
      await _recorder.start(cfg, path: path);
      _recording = true;
      return path;
    } catch (e) {
      return null;
    }
  }

  /// 停止录音 → 返回录音文件路径（失败 null）
  Future<String?> stopRecording() async {
    if (!_recording) return null;
    try {
      final path = await _recorder.stop();
      _recording = false;
      return path;
    } catch (_) {
      _recording = false;
      return null;
    }
  }

  /// 录音文件上传服务端 8088 STT → 识别文本（服务端代理）
  Future<String?> transcribe(String filePath, {String provider = ''}) async {
    try {
      final resp = await _dio.post(
        'http://$_host:$_audioPort/api/audio/stt',
        data: FormData.fromMap({
          'provider': provider,
          'file': await MultipartFile.fromFile(filePath),
        }),
        options: Options(
          headers: {'Authorization': 'Bearer $_token'},
          contentType: 'multipart/form-data',
        ),
        // 语音文件上传走 HTTP——不占 WS 帧
      );
      final data = resp.data;
      if (data is Map && data['text'] != null) {
        return data['text'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// TTS：WS voice_tts 拿 file 名 → GET 8088 下载 → 播放（返回是否成功）
  Future<bool> speak(String text, {String provider = '', String? remoteFile}) async {
    try {
      String? fileName;
      if (remoteFile != null && remoteFile.isNotEmpty) {
        // 已有服务端文件路径（如 /LINGOS/data/audio/xxx.wav）→ 取文件名
        fileName = remoteFile.split('/').last;
      } else {
        // 经 WS 信令合成（voice_tts 命令返回 file 路径——由调用方先触发）
        return false;
      }
      final dir = await getTemporaryDirectory();
      final localPath = '${dir.path}/lingos_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _dio.download(
        'http://$_host:$_audioPort/api/audio/file?name=$fileName',
        localPath,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      await _player.stop();
      await _player.play(DeviceFileSource(localPath));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
