/// 全局 Provider（Riverpod——应用级单例）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection_manager.dart';

export 'connection/connection_manager.dart';

/// 全局连接管理器
final connectionProvider = Provider<ConnectionManager>((ref) {
  final mgr = ConnectionManager();
  ref.onDispose(mgr.dispose);
  return mgr;
});
