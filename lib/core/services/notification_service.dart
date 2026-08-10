/// 通知服务（先生要求添加通知——连接状态/紧急/预警）
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// 发送通知（连接状态/紧急/预警）
  Future<void> show(String title, String body, {int id = 0, String? payload}) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'lingos_channel',
          'LING OS 通知',
          channelDescription: '连接状态/紧急/预警通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (_) {}
  }
}
