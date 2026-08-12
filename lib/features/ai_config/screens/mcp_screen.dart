/// 额外的 MCP（0.1.9 第二批——完整界面 + 服务端 mcp_* 命令）
/// MCP 工具注册为独立"MCP"技能组——AI 可调用
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class McpScreen extends ConsumerStatefulWidget {
  const McpScreen({super.key});

  @override
  ConsumerState<McpScreen> createState() => _McpScreenState();
}

class _McpScreenState extends ConsumerState<McpScreen> {
  List<Map<String, dynamic>> _servers = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(connectionProvider).events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(String line) {
    try {
      final evt = jsonDecode(line);
      if (evt is Map && evt['type'] == 'command_response') {
        final data = evt['data'];
        Map<String, dynamic>? resp;
        if (data is String) {
          final d = jsonDecode(data);
          if (d is Map) resp = Map<String, dynamic>.from(d);
        } else if (data is Map) {
          resp = Map<String, dynamic>.from(data);
        }
        if (resp == null || resp['status'] != 'ok') return;
        final info = resp['data'];
        if (info is Map && info['servers'] is List) {
          setState(() {
            _servers = (info['servers'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _loading = false;
            _error = null;
          });
        } else if (info is List) {
          setState(() {
            _servers = info.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
            _error = null;
          });
        }
      }
    } catch (_) {}
  }

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'mcp_list'});
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _McpAddScreen()),
    );
    if (result != null) {
      ref.read(connectionProvider).sendCommand({
        'cmd': 'mcp_add',
        'name': result['name'],
        'url': result['url'],
        'auth_type': result['auth_type'],
        'auth_token': result['auth_token'],
      });
      _load();
    }
  }

  Future<void> _test(String name, String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('测试连接 $name（$url）——结果将在刷新后显示')),
    );
    ref.read(connectionProvider).sendCommand({'cmd': 'mcp_test', 'name': name});
  }

  Future<void> _remove(String name) async {
    ref.read(connectionProvider).sendCommand({'cmd': 'mcp_remove', 'name': name});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('额外的 MCP'),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _add),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.brandRed)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _servers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.dns_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text('未配置 MCP 服务器——点击 + 添加',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _add, child: const Text('添加 MCP')),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Text(
                            'MCP（Model Context Protocol）：连接主机以外的外部工具服务器——工具注册为独立"MCP"技能组，AI 可调用。认证可选。',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final s in _servers) _serverCard(s),
                      ],
                    ),
    );
  }

  Widget _serverCard(Map<String, dynamic> s) {
    final name = s['name']?.toString() ?? '';
    final url = s['url']?.toString() ?? '';
    final auth = s['auth_type']?.toString() ?? 'none';
    final status = s['status']?.toString() ?? 'unknown';
    final tools = s['tools'] is List ? (s['tools'] as List) : <dynamic>[];
    final connected = status == 'connected';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(connected ? Icons.cloud_done : Icons.cloud_outlined,
                    size: 18, color: connected ? Colors.green : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text(connected ? '已连接' : (status == 'failed' ? '连接失败' : '未连接'),
                    style: TextStyle(
                        fontSize: 11,
                        color: connected ? Colors.green : (status == 'failed' ? AppColors.brandRed : AppColors.textSecondary))),
              ],
            ),
            const SizedBox(height: 4),
            Text(url, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text('认证: ${auth == 'none' ? '无' : auth}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (tools.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tools.map((t) {
                  final tname = t is Map ? (t['name']?.toString() ?? '?') : t.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tname,
                        style: const TextStyle(fontSize: 10, color: AppColors.brandCyan)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _test(name, url),
                  icon: const Icon(Icons.wifi_tethering, size: 14),
                  label: const Text('测试', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                  onPressed: () => _remove(name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _McpAddScreen extends StatefulWidget {
  const _McpAddScreen();

  @override
  State<_McpAddScreen> createState() => _McpAddScreenState();
}

class _McpAddScreenState extends State<_McpAddScreen> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _authType = 'none';
  final _tokenCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加 MCP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '名称（如 本地NAS）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '服务器 URL（http://...）',
              hintText: 'http://192.168.1.100:3000/mcp',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          const Text('认证方式', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('无认证', style: TextStyle(fontSize: 12)),
                selected: _authType == 'none',
                onSelected: (_) => setState(() => _authType = 'none'),
              ),
              ChoiceChip(
                label: const Text('API Key', style: TextStyle(fontSize: 12)),
                selected: _authType == 'api_key',
                onSelected: (_) => setState(() => _authType = 'api_key'),
              ),
              ChoiceChip(
                label: const Text('Bearer Token', style: TextStyle(fontSize: 12)),
                selected: _authType == 'bearer',
                onSelected: (_) => setState(() => _authType = 'bearer'),
              ),
            ],
          ),
          if (_authType != 'none') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: _authType == 'api_key' ? 'API Key' : 'Bearer Token',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nameCtrl.text.trim().isEmpty || _urlCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop({
                      'name': _nameCtrl.text.trim(),
                      'url': _urlCtrl.text.trim(),
                      'auth_type': _authType,
                      'auth_token': _tokenCtrl.text.trim(),
                    }),
            child: const Text('保存'),
          ),
          const SizedBox(height: 12),
          const Text('MCP 工具将注册为独立"MCP"技能组——AI 对话中可直接调用',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
