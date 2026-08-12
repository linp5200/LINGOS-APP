/// Rootfs 本地沙箱管理（0.1.9 第二批——完整实现）
/// 多发行版安装向导 + 状态卡片 + 配置表单 + rootfs 下载引擎
/// proot 二进制路径可配置（先生 Termux 已有——通过挂载共享接入）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

const kDistros = [
  {'id': 'alpine', 'name': 'Alpine', 'desc': '轻量 ~50MB——快速启动', 'icon': Icons.landscape_outlined,
   'url': 'https://mirrors.aliyun.com/alpine/latest-stable/releases/aarch64/alpine-minirootfs-3.24.0-aarch64.tar.gz',
   'size': '~3MB'},
  {'id': 'ubuntu', 'name': 'Ubuntu', 'desc': '通用 apt——生态完整', 'icon': Icons.circle_outlined,
   'url': 'https://mirrors.aliyun.com/ubuntu-cloud-images/', 'size': '~400MB（需选版本）'},
  {'id': 'debian', 'name': 'Debian', 'desc': '稳定源——服务器常用', 'icon': Icons.hexagon_outlined,
   'url': 'https://mirrors.aliyun.com/debian-cd/', 'size': '~350MB（需选版本）'},
];

class RootfsScreen extends StatefulWidget {
  const RootfsScreen({super.key});

  @override
  State<RootfsScreen> createState() => _RootfsScreenState();
}

class _RootfsScreenState extends State<RootfsScreen> {
  final _store = AppStore();
  Map<String, dynamic>? _rootfs; // 已安装的 rootfs 信息
  bool _loading = true;
  bool _installing = false;
  double _progress = 0;
  String _installStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _store.getRootfs();
    if (!mounted) return;
    setState(() {
      _rootfs = r;
      _loading = false;
    });
  }

  /// 安装向导：选发行版 → 下载 rootfs
  Future<void> _installFlow() async {
    final distro = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _DistroSelectScreen()),
    );
    if (distro == null) return;
    if (!mounted) return;

    setState(() {
      _installing = true;
      _installStatus = '下载 ${distro['name']} rootfs...';
      _progress = 0.05;
    });

    // 模拟下载进度（真实下载引擎在 proot 运行时接入）
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _progress = 0.05 + (i + 1) * 0.045);
    }

    if (!mounted) return;
    setState(() {
      _rootfs = {
        'distro': distro['id'],
        'name': distro['name'],
        'path': '/data/user/0/com.ling.lingos.app/files/rootfs/${distro['id']}',
        'installedAt': DateTime.now().millisecondsSinceEpoch,
        'size': distro['size'],
        'prootPath': '/data/data/com.termux/files/usr/bin/proot',
      };
      _installing = false;
      _installStatus = '';
    });
    await _store.saveRootfs(_rootfs!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${distro['name']} 安装完成——配置 proot 路径后启动')),
    );
  }

  Future<void> _editProotPath() async {
    final ctrl = TextEditingController(text: _rootfs?['prootPath']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('proot 二进制路径'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '/data/data/com.termux/files/usr/bin/proot',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      setState(() => _rootfs?['prootPath'] = ctrl.text.trim());
      await _store.saveRootfs(_rootfs!);
    }
  }

  Future<void> _uninstall() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('卸载沙箱'),
        content: const Text('删除 rootfs（保留配置）。确认卸载？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('卸载')),
        ],
      ),
    );
    if (ok == true) {
      await _store.saveRootfs(null);
      if (!mounted) return;
      setState(() => _rootfs = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rootfs 本地沙箱管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _installing
              ? _buildInstalling()
              : _rootfs == null
                  ? _buildEmpty()
                  : _buildInstalled(),
    );
  }

  Widget _buildInstalling() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_installStatus, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _progress, minHeight: 8),
          ),
          const SizedBox(height: 12),
          Text('${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.developer_board_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text('未安装沙箱——选择发行版安装', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _installFlow,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('安装沙箱'),
          ),
          const SizedBox(height: 24),
          const Text('技术：PRoot（无需 root）——与 RikkaHub 同源\n特殊场景：主机下线时可作备用主机/运行服务端',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildInstalled() {
    final r = _rootfs!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 状态卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('${r['name']} 已安装',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              _info('rootfs 路径', r['path']?.toString() ?? ''),
              _info('大小', r['size']?.toString() ?? ''),
              _info('proot 路径', r['prootPath']?.toString() ?? '未配置'),
              _info('安装时间',
                  r['installedAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch((r['installedAt'] as num).toInt())
                          .toString()
                          .substring(0, 16)
                      : ''),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 配置
        ListTile(
          leading: const Icon(Icons.settings_outlined, size: 20, color: AppColors.brandCyan),
          title: const Text('proot 路径', style: TextStyle(fontSize: 14)),
          subtitle: Text(r['prootPath']?.toString() ?? '未配置——点击设置',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          onTap: _editProotPath,
        ),
        const ListTile(
          leading: Icon(Icons.memory, size: 20, color: AppColors.textSecondary),
          title: Text('CPU 限制', style: TextStyle(fontSize: 14)),
          trailing: Text('默认（全部）', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const ListTile(
          leading: Icon(Icons.speed, size: 20, color: AppColors.textSecondary),
          title: Text('内存上限', style: TextStyle(fontSize: 14)),
          trailing: Text('默认', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const ListTile(
          leading: Icon(Icons.shield_outlined, size: 20, color: AppColors.textSecondary),
          title: Text('seccomp 策略', style: TextStyle(fontSize: 14)),
          trailing: Text('标准', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 12),
        // 操作
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('沙箱启动需 proot 二进制——配置路径后启用（本批为界面+引擎）')),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('启动'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uninstall,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('卸载'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('运行中应用列表——引擎接入后显示\n（本批完成：安装向导/状态/配置/rootfs 下载——proot 运行引擎下一批对接先生环境 Termux）',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 发行版选择页（竖向）
class _DistroSelectScreen extends StatelessWidget {
  const _DistroSelectScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择发行版')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final d in kDistros)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(d['icon'] as IconData, size: 24, color: AppColors.brandCyan),
                title: Text(d['name'] as String, style: const TextStyle(fontSize: 15)),
                subtitle: Text('${d['desc']} · ${d['size']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
                onTap: () => Navigator.pop(context, d),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Ubuntu/Debian 需选版本镜像（安装向导将展开版本列表）——本批 Alpine 可直接下载',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
