/// 管理服务端文件（0.1.9 骨架——定案：限定 /LINGOS 根 + 仅查看下载）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class ServerFilesScreen extends StatelessWidget {
  const ServerFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '管理服务端文件',
      planItems: [
        '系统目录导航（根=/LINGOS）：system/config / skills / data / Debug / state / registry / bin',
        '目录带图标与说明（结构化导航）',
        '文件操作：查看（文本）/ 下载',
        '编辑走浏览文件页（不在此处）',
        '不内置备份（走服务端 backup 命令）',
      ],
      note: '批量 4 填充——当前显示规划结构',
    );
  }
}
