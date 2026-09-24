/// LING OS 局域网发现服务（UDP 广播——协议对齐 C 端 discovery_server）
///
/// 协议（src/daemon/discovery_server.c）：
///   · 端口 2937/UDP
///   · 魔术字 "LINGOS-DISCOVER"
///   · 响应 JSON: {"type":"lingos","name":<主机名>,"version":<版本>,
///                 "ip":<局域网IP>,"port":2937,"capabilities":[...]}
///
/// 用途：App 连接 2 步化的第一步——自动发现主机（替代手动输 IP）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredHost {
  final String name;
  final String ip;
  final String version;
  final int port;

  const DiscoveredHost({
    required this.name,
    required this.ip,
    required this.version,
    required this.port,
  });

  factory DiscoveredHost.fromJson(Map<String, dynamic> m, String fallbackIp) {
    return DiscoveredHost(
      name: m['name']?.toString() ?? 'LING OS',
      ip: (m['ip']?.toString().isNotEmpty ?? false) ? m['ip'].toString() : fallbackIp,
      version: m['version']?.toString() ?? '',
      port: (m['port'] is num) ? (m['port'] as num).toInt() : 2937,
    );
  }

  @override
  String toString() => '$name ($ip:$port)';
}

class DiscoveryService {
  DiscoveryService._();

  static const int discoveryPort = 2937;
  static const String magic = 'LINGOS-DISCOVER';

  /// 扫描局域网主机（广播 + 收集响应，最多等待 timeoutMs）
  ///
  /// 注：需要在 Android 上具备网络权限（默认有）；部分设备多网卡时
  /// 广播可能受限——失败时返回空列表（UI 提示手动输入即可）。
  static Future<List<DiscoveredHost>> scan({int timeoutMs = 3000}) async {
    final results = <String, DiscoveredHost>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final payload = utf8.encode(magic);
      // ① 全局广播
      try {
        socket.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
      } catch (_) {}
      // ② 子网定向广播（取本机 IPv4 的 /24 广播地址——部分网络丢弃 255.255.255.255）
      try {
        final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        for (final f in ifaces) {
          for (final a in f.addresses) {
            if (a.isLoopback) continue;
            final parts = a.address.split('.');
            if (parts.length == 4) {
              final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                socket.send(payload, InternetAddress(bcast), discoveryPort);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket?.receive();
        if (dg == null) return;
        try {
          final m = jsonDecode(utf8.decode(dg.data));
          if (m is Map && m['type'] == 'lingos') {
            final host = DiscoveredHost.fromJson(
                Map<String, dynamic>.from(m), dg.address.address);
            results[host.ip] = host;
          }
        } catch (_) {}
      });

      await Future<void>.delayed(Duration(milliseconds: timeoutMs));
    } catch (_) {
      // 发现失败静默——UI 回退手动输入
    } finally {
      try {
        if (sub != null) await sub.cancel();
      } catch (_) {}
      try {
        socket?.close();
      } catch (_) {}
    }
    return results.values.toList();
  }
}
