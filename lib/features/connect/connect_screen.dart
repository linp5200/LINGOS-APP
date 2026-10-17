/// 连接与认证页（协议 v3——TCP 两步认证）
library;

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
import '../../core/services/discovery_service.dart';   // 【0.7.0 P3】局域网自动发现
import '../home/home_shell.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _hostCtrl = TextEditingController(text: '127.0.0.1');
  final _portCtrl = TextEditingController(text: '2937');
  final _authCtrl = TextEditingController();
  final _connCtrl = TextEditingController();

  bool _connecting = false;
  bool _waitingAuth = false;
  bool _waitingConnCode = false;
  String _status = '';
  // 【2026-09-18 接线】连接历史（最近主机——一键填入）
  List<Map<String, dynamic>> _history = [];
  // 【0.7.0 P3】自动发现（连接 2 步化第一步）
  bool _scanning = false;
  List<DiscoveredHost> _found = [];

  ConnectionManager get _mgr => ref.read(connectionProvider);

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = tr('conn_connecting');
    });
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 2937;
    final ok = await _mgr.connectTcp(host, port);
    if (ok) {
      // 【2026-09-18 接线】连接成功 → 记录历史（一键重连）
      try {
        await AppStore().addHostHistory(host, port);
        await _loadHistory();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _waitingAuth = ok;
      _status = ok
          ? tr('conn_enter_verification_code')
          : trp('conn_failed_check_host_ip_port', {
              'p0': _mgr.lastError ?? tr('dash_unknown_error'),
            });
    });
  }

  /// 【0.7.0 P3】局域网自动发现（UDP 广播——连接 2 步化）
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = [];
      _status = tr('conn_searching_for_lan_hosts');
    });
    final hosts = await DiscoveryService.scan(timeoutMs: 3000);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _found = hosts;
      _status = hosts.isEmpty
          ? tr('conn_no_hosts_found_same_lan_and_service_running')
          : trp('conn_found_hosts_tap_to_select', {'p0': '${hosts.length}'});
    });
  }

  Future<void> _submitAuth() async {
    final ok = await _mgr.sendAuthCode(_authCtrl.text.trim().toUpperCase());
    if (!mounted) return;
    setState(() {
      _waitingAuth = false;
      _waitingConnCode = ok;
      _status = ok
          ? tr('conn_code_sent_enter_connection_code')
          : trp('conn_auth_code_send_failed', {
              'p0': _mgr.lastError ?? tr('dash_unknown_error'),
            });
    });
  }

  Future<void> _submitConnCode() async {
    appLog('Connect', '提交连接码: ${_connCtrl.text.trim().toUpperCase()}');
    final ok = await _mgr.sendConnectionCode(_connCtrl.text.trim().toUpperCase());
    appLog('Connect', '连接码发送结果: ${ok ? "成功" : "失败(${_mgr.lastError})"}');
    if (!mounted) return;
    if (ok) {
      _mgr.startHeartbeat();
      // 【方案B】认证成功——WS 由 ConnectionManager 在 token 收到时自动连接
      appLog('Connect', '认证成功——等待 token 事件自动连 WS');
      setState(() => _status = tr('conn_authenticated_connecting'));
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      _enterHome();
    } else {
      setState(() => _status = tr('conn_failed_to_send_connection_code'));
    }
  }

  /// 【0.4.3】进入主框架：从 HomeShell 进入则 pop 回；独立(失效重登)则 pushReplacement
  void _enterHome() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _autoResume();
  }

  /// 【2026-09-18 接线】加载连接历史（最近 5 个主机）
  Future<void> _loadHistory() async {
    final h = await AppStore().getHostHistory();
    if (!mounted) return;
    setState(() => _history = h);
  }

  /// 【先生决策】token 自动恢复：重进 App → 持久 token → WS 直连免认证
  Future<void> _autoResume() async {
    final store = AppStore();
    final token = await store.getToken();
    final host = await store.getHost();
    final port = await store.getPort();
    appLog('Connect', '自动恢复检查: token=${token == null ? "无" : token.isEmpty ? "空" : "有"} host=$host port=$port');
    if (token == null || token.isEmpty || host == null || port == null) return;
    if (!mounted) return;
    setState(() {
      _status = tr('conn_saved_session_detected_auto_reconnecting');
    });
    final ok = await _mgr.connectWsAndSave(host, port, token);
    if (!mounted) return;
    if (ok) {
      setState(() => _status = tr('conn_session_restored_direct_ws_token'));
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _enterHome();
    } else {
      setState(() => _status = tr('conn_token_expired_please_re_authenticate'));
      await _mgr.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Icon(Icons.language_rounded, size: 56, color: AppColors.brandRed),
                  const SizedBox(height: 12),
                   Text('LING OS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_status.isEmpty ? tr('conn_connect_to_host') : _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _status.contains('✅') ? AppColors.brandCyan : AppColors.textSecondary)),
                  const SizedBox(height: 28),
                  if (!_waitingAuth && !_waitingConnCode) ...[
                    TextField(
                      controller: _hostCtrl,
                      decoration: InputDecoration(labelText: tr('conn_host_address'), prefixIcon: const Icon(Icons.dns_outlined, size: 20)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('conn_port'), prefixIcon: const Icon(Icons.numbers, size: 20)),
                    ),
                    // 【0.7.0 P3】自动发现（连接 2 步化——搜索 → 一键填入）
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_find, size: 18),
                      label: Text(_scanning ? tr('conn_searching') : tr('conn_search_lan_hosts')),
                    ),
                    if (_found.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _found.map((h) {
                          return ActionChip(
                            avatar: const Icon(Icons.computer, size: 14),
                            label: Text('${h.name} · ${h.ip}',
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() {
                              _hostCtrl.text = h.ip;
                              _portCtrl.text = '${h.port}';
                              _status = trp('conn_selected_tap_to_connect', {'p0': h.name, 'p1': h.ip});
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                    // 【2026-09-18 接线】连接历史（最近主机——点击填入）
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _history.map((e) {
                          final h = e['h']?.toString() ?? '';
                          final p = (e['p'] as num?)?.toInt() ?? 2937;
                          return ActionChip(
                            label: Text('$h:$p', style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() {
                              _hostCtrl.text = h;
                              _portCtrl.text = '$p';
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _connecting ? null : _connect,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _connecting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(tr('grp_conn')),
                    ),
                  ],
                  if (_waitingAuth) ...[
                    TextField(
                      controller: _authCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) {
                        final u = v.toUpperCase();
                        if (u != v) {
                          _authCtrl.value = _authCtrl.value.copyWith(text: u, selection: TextSelection.collapsed(offset: u.length));
                        }
                      },
                      decoration: InputDecoration(
                        labelText: tr('conn_code_6_digits_shown_in_yellow_on_the'),
                        prefixIcon: const Icon(Icons.password, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitAuth,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(tr('conn_send_code')),
                    ),
                  ],
                  if (_waitingConnCode) ...[
                    TextField(
                      controller: _connCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) {
                        final u = v.toUpperCase();
                        if (u != v) {
                          _connCtrl.value = _connCtrl.value.copyWith(text: u, selection: TextSelection.collapsed(offset: u.length));
                        }
                      },
                      decoration: InputDecoration(
                        labelText: tr('conn_connection_code_xxxx_xxxx_xxxx'),
                        prefixIcon: const Icon(Icons.vpn_key, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitConnCode,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(tr('conn_confirm_code')),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => _mgr.disconnect(),
                    child: Text(tr('disconnect'), style:  TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
