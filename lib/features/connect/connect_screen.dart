/// 连接与认证页（协议 v3——TCP 两步认证）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_store.dart';
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

  ConnectionManager get _mgr => ref.read(connectionProvider);

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = '连接中...';
    });
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 2937;
    final ok = await _mgr.connectTcp(host, port);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _waitingAuth = ok;
      _status = ok ? '已连接——请输入终端显示的验证码' : '连接失败：${_mgr.lastError ?? '未知错误'}（检查主机 IP/端口/服务是否启动）';
    });
  }

  Future<void> _submitAuth() async {
    final ok = await _mgr.sendAuthCode(_authCtrl.text.trim().toUpperCase());
    if (!mounted) return;
    setState(() {
      _waitingAuth = false;
      _waitingConnCode = ok;
      _status = ok ? '验证码已发送——请输入终端显示的连接码' : '发送失败：${_mgr.lastError ?? '未知错误'}';
    });
  }

  Future<void> _submitConnCode() async {
    appLog('Connect', '提交连接码: ${_connCtrl.text.trim().toUpperCase()}');
    final ok = await _mgr.sendConnectionCode(_connCtrl.text.trim().toUpperCase());
    appLog('Connect', '连接码发送结果: ${ok ? "成功" : "失败(${_mgr.lastError})"}');
    if (!mounted) return;
    if (ok) {
      _mgr.startHeartbeat();
      // 认证成功：连 WS（token 直连）并持久化（先生决策：退出恢复）
      final host = _hostCtrl.text.trim();
      final port = int.tryParse(_portCtrl.text.trim()) ?? 2937;
      final t = _mgr.tcp?.token ?? '';
      final showTok = t.isEmpty ? '【空！——根因候选：token 异步未到，跳过 WS 连接】' : '${t.substring(0, t.length > 8 ? 8 : t.length)}...';
      appLog('Connect', '认证成功——准备连 WS。token=$showTok');
      if (t.isNotEmpty) {
        final wsPort = port + 2;
        setState(() => _status = '认证成功——正在连接 WS（$host:$wsPort）...');
        final wsOk = await _mgr.connectWsAndSave(host, port, t);
        if (!mounted) return;
        if (wsOk) {
          setState(() => _status = '✅ 已连接（WS 就绪）');
        } else {
          setState(() => _status = '⚠️ WS 连接失败：${_mgr.lastError ?? '未知'}（命令将走 TCP 兜底）');
        }
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      setState(() => _status = '连接码发送失败');
    }
  }

  @override
  void initState() {
    super.initState();
    _autoResume();
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
      _status = '检测到已保存会话——自动恢复连接...';
    });
    final ok = await _mgr.connectWsAndSave(host, port, token);
    if (!mounted) return;
    if (ok) {
      setState(() => _status = '✅ 会话已恢复（WS token 直连）');
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } else {
      setState(() => _status = 'token 失效——请重新认证');
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
                  const Icon(Icons.language_rounded, size: 56, color: AppColors.brandRed),
                  const SizedBox(height: 12),
                  const Text('LING OS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_status.isEmpty ? '连接到主机' : _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _status.contains('✅') ? AppColors.brandCyan : AppColors.textSecondary)),
                  const SizedBox(height: 28),
                  if (!_waitingAuth && !_waitingConnCode) ...[
                    TextField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(labelText: '主机地址', prefixIcon: Icon(Icons.dns_outlined, size: 20)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '端口', prefixIcon: Icon(Icons.numbers, size: 20)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _connecting ? null : _connect,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _connecting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('连接'),
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
                      decoration: const InputDecoration(
                        labelText: '验证码（6 位——终端黄色显示）',
                        prefixIcon: Icon(Icons.password, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitAuth,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('发送验证码'),
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
                      decoration: const InputDecoration(
                        labelText: '连接码（XXXX-XXXX-XXXX）',
                        prefixIcon: Icon(Icons.vpn_key, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitConnCode,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('确认连接码'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => _mgr.disconnect(),
                    child: const Text('断开连接', style: TextStyle(color: AppColors.textSecondary)),
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
