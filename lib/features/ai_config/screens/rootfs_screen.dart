/// Rootfs 本地沙箱管理（0.1.9 骨架——定案：多发行版 + rikkahub 借鉴 + 备用主机）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class RootfsScreen extends StatelessWidget {
  const RootfsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: 'Rootfs 本地沙箱管理',
      planItems: [
        '安装（多发行版可选）：Alpine（轻量）/ Ubuntu（apt 通用）/ Debian（稳定源）',
        '技术路线：PRoot（无需 root）——与 RikkaHub / Minis 沙箱同源',
        '沙箱状态：发行版 / rootfs 路径 / 磁盘占用 / 运行状态',
        '表单化配置：CPU 限制 / 内存上限（滑杆）+ seccomp 策略（宽松/标准/严格）',
        '沙箱内运行应用列表 + 停止',
        '特殊场景：主机下线时可作备用主机连接 / 运行服务端',
      ],
      note: '沙箱安装器（下载 rootfs + proot 启动）批次 4 开发——当前显示规划结构',
    );
  }
}
