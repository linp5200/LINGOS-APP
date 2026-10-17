/// 用户管理（2026-10-17）：服务端 user_manager（PBKDF2/角色/默认 owner）
/// 命令面：user_list / user_add / user_update / user_set_role /
///         user_reset_password / user_delete
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  StreamSubscription? _sub;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<String> _roles = const ['owner', 'admin', 'user', 'guest'];

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
        if (resp == null) return;
        if (resp['status'] != 'ok') {
          setState(() {
            _loading = false;
            _error = (resp['msg'] ?? resp['message'] ?? '操作失败').toString();
          });
          return;
        }
        final d = resp['data'];
        if (d is List) {
          setState(() {
            _users = d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final rs = resp['roles'];
            if (rs is List && rs.isNotEmpty) {
              _roles = rs.map((e) => e.toString()).toList();
            }
            _loading = false;
            _error = null;
          });
        } else {
          _load();
        }
      }
    } catch (_) {}
  }

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(connectionProvider).sendCommand({'cmd': 'user_list'});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _addUser() async {
    final nameCtl = TextEditingController();
    final dispCtl = TextEditingController();
    final passCtl = TextEditingController();
    String role = 'user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('添加用户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '用户名（字母开头 3-32 位）')),
                TextField(controller: dispCtl, decoration: const InputDecoration(labelText: '显示名（可选）')),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: '角色'),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setLocal(() => role = v ?? 'user'),
                ),
                TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: '初始密码（至少 8 位）')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
          ],
        ),
      ),
    );
    if (ok == true) {
      ref.read(connectionProvider).sendCommand({
        'cmd': 'user_add',
        'username': nameCtl.text.trim(),
        'display_name': dispCtl.text.trim(),
        'role': role,
        'password': passCtl.text,
      });
      _toast('已提交添加（若失败请检查用户名/密码规则）');
      Future.delayed(const Duration(milliseconds: 800), _load);
    }
    nameCtl.dispose();
    dispCtl.dispose();
    passCtl.dispose();
  }

  Future<void> _resetPassword(String username) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('重置密码：$username'),
        content: TextField(controller: ctl, obscureText: true, decoration: const InputDecoration(labelText: '新密码（至少 8 位）')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true && ctl.text.isNotEmpty) {
      ref.read(connectionProvider).sendCommand({'cmd': 'user_reset_password', 'username': username, 'password': ctl.text});
      _toast('密码已更新');
      Future.delayed(const Duration(milliseconds: 600), _load);
    }
    ctl.dispose();
  }

  Future<void> _setRole(String username, String role) async {
    ref.read(connectionProvider).sendCommand({'cmd': 'user_set_role', 'username': username, 'role': role});
    Future.delayed(const Duration(milliseconds: 500), _load);
  }

  Future<void> _toggle(String username, bool enabled) async {
    ref.read(connectionProvider).sendCommand({'cmd': 'user_update', 'username': username, 'enabled': enabled});
    Future.delayed(const Duration(milliseconds: 500), _load);
  }

  Future<void> _delete(String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定删除 $username ？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(connectionProvider).sendCommand({'cmd': 'user_delete', 'username': username});
      Future.delayed(const Duration(milliseconds: 600), _load);
    }
  }

  Widget _roleChip(String role) {
    final color = role == 'owner'
        ? Colors.amber
        : role == 'admin'
            ? Colors.orangeAccent
            : Colors.blueGrey;
    return Chip(
      label: Text(role, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('添加用户'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无用户（服务端首次加载会创建默认 owner：admin / lingos，请尽快修改）', textAlign: TextAlign.center),
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final u = _users[i];
                        final username = (u['username'] ?? '').toString();
                        final role = (u['role'] ?? 'user').toString();
                        final enabled = u['enabled'] != false;
                        final mustChange = u['must_change_password'] == true;
                        final created = (u['created'] ?? 0).toString();
                        final lastLogin = (u['last_login'] ?? 0).toString();
                        final subtitle = '$username · 创建 $created · 登录 $lastLogin';
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(Icons.person, color: enabled ? null : Colors.grey),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text((u['display_name'] ?? username).toString(), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              _roleChip(role),
                              if (!enabled) const Padding(padding: EdgeInsets.only(left: 4), child: Text('已禁用')),
                              if (mustChange) const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text('待改密', style: TextStyle(color: Colors.orange, fontSize: 11))),
                            ],
                          ),
                          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'reset') _resetPassword(username);
                              if (v == 'delete') _delete(username);
                              if (v == 'enable') _toggle(username, !enabled);
                              if (v.startsWith('role:')) _setRole(username, v.substring(5));
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'reset', child: Text('重置密码')),
                              PopupMenuItem(value: 'enable', child: Text(enabled ? '禁用账户' : '启用账户')),
                              ..._roles.map((r) => PopupMenuItem(value: 'role:$r', child: Text('设为 $r'))),
                              const PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
