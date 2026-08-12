/// 挂载外部文件（0.1.9 骨架——定案：双来源 + 持久化 + 读写权限）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class MountScreen extends StatelessWidget {
  const MountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '挂载外部文件',
      planItems: [
        '挂载点列表：名称 / 来源路径 / 挂载到（沙箱内）/ 状态',
        '来源：Android 外部存储（/storage/emulated/0）+ 服务端 /LINGOS 目录（双来源）',
        '挂载到沙箱路径（如 /mnt/external）',
        '每挂载点权限：只读 / 读写',
        '持久化：配置保存——沙箱重启自动重挂',
        '技术：proot -b 目录绑定（无需 root）',
      ],
      note: '沙箱挂载管理批次 4 开发——当前显示规划结构',
    );
  }
}
