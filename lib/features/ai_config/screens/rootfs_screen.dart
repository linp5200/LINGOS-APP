/// Rootfs 本地沙箱管理（0.1.9 第二批——完整实现）
/// 多发行版安装向导 + 状态卡片 + 配置表单 + rootfs 下载引擎
/// proot 二进制路径可配置（先生 Termux 已有——通过挂载共享接入）
library;

import 'dart:async';
import '../../../core/i18n/app_i18n.dart';

import 'package:flutter/material.dart';

import '../../../core/storage/app_store.dart';
import '../../../core/theme/app_theme.dart';

/// 【i18n】改为 getter：发行版描述经 tr() 后需在每次访问时求值
List<Map<String, Object>> get kDistros => [
  {'id': 'alpine', 'name': 'Alpine', 'desc': tr('rootfs_lightweight_50mb_fast_start'), 'icon': Icons.landscape_outlined,
   'url': 'https://mirrors.aliyun.com/alpine/latest-stable/releases/aarch64/alpine-minirootfs-3.24.0-aarch64.tar.gz',
   'size': '~3MB'},
  {'id': 'ubuntu', 'name': 'Ubuntu', 'desc': tr('rootfs_general_purpose_apt_full_ecosystem'), 'icon': Icons.circle_outlined,
   'url': 'https://mirrors.aliyun.com/ubuntu-cloud-images/', 'size': tr('rootfs_400mb_pick_a_version')},
  {'id': 'debian', 'name': 'Debian', 'desc': tr('rootfs_stable_repos_common_on_servers'), 'icon': Icons.hexagon_outlined,
   'url': 'https://mirrors.aliyun.com/debian-cd/', 'size': tr('rootfs_350mb_pick_a_version')},
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

  /// 安装向导：选发行版 → （诚实标注：下载引擎未落地）
  /// 【2026-09-18 诚实化】原实现为「模拟下载进度 → 直接标记安装完成」（假安装——
  ///   什么都没下载，审计 P0#10 项）。现诚实标注「开发中」，不再伪造安装结果。
  Future<void> _installFlow() async {
    final distro = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _DistroSelectScreen()),
    );
    if (distro == null) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trp('rootfs_engine_in_development', {'p0': distro['name']})),
        content: Text(
          tr('rootfs_the_rootfs_download_extract_engine_is_not'),
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('rootfs_got_it'))),
        ],
      ),
    );
  }

  Future<void> _editProotPath() async {
    final ctrl = TextEditingController(text: _rootfs?['prootPath']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('rootfs_proot_binary_path')),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '/data/data/com.termux/files/usr/bin/proot',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
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
        title: Text(tr('rootfs_uninstall_sandbox')),
        content: Text(tr('rootfs_delete_the_rootfs_config_kept_uninstall')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('rootfs_uninstall'))),
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
      appBar: AppBar(title: Text(tr('rootfs_rootfs_sandbox_management'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rootfs == null
              ? _buildEmpty()
              : _buildInstalled(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.developer_board_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(tr('rootfs_no_sandbox_installed_pick_a_distro_to'), style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _installFlow,
            icon: const Icon(Icons.construction, size: 18),
            label: Text(tr('rootfs_install_sandbox_in_development')),
          ),
          const SizedBox(height: 24),
          Text(tr('rootfs_technical_proot_no_root_same_lineage_as'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
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
                  Text(trp('rootfs_distro_installed', {'p0': r['name']}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              _info(tr('rootfs_rootfs_path'), r['path']?.toString() ?? ''),
              _info(tr('rootfs_size'), r['size']?.toString() ?? ''),
              _info(tr('rootfs_proot_path'), r['prootPath']?.toString() ?? tr('rootfs_not_configured')),
              _info(tr('rootfs_installed_at'),
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
          title: Text(tr('rootfs_proot_path'), style: const TextStyle(fontSize: 14)),
          subtitle: Text(r['prootPath']?.toString() ?? tr('rootfs_not_configured_tap_to_set'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          onTap: _editProotPath,
        ),
        ListTile(
          leading: const Icon(Icons.memory, size: 20, color: AppColors.textSecondary),
          title: Text(tr('rootfs_cpu_limit'), style: const TextStyle(fontSize: 14)),
          trailing: Text(tr('rootfs_default_all'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        ListTile(
          leading: const Icon(Icons.speed, size: 20, color: AppColors.textSecondary),
          title: Text(tr('rootfs_memory_limit'), style: const TextStyle(fontSize: 14)),
          trailing: Text(tr('rootfs_default'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined, size: 20, color: AppColors.textSecondary),
          title: Text(tr('rootfs_seccomp_policy'), style: const TextStyle(fontSize: 14)),
          trailing: Text(tr('rootfs_standard'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 12),
        // 操作
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('rootfs_starting_the_sandbox_needs_the_proot_binary'))),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(tr('rootfs_start')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uninstall,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(tr('rootfs_uninstall')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(tr('rootfs_running_app_list_appears_once_the_engine_is'),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
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
      appBar: AppBar(title: Text(tr('rootfs_choose_a_distro'))),
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
          Text(
            tr('rootfs_ubuntu_debian_need_a_version_image_the'),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
