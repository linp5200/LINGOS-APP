/// 技能（0.1.9 骨架——定案：68 技能分组 + 启用≠权限）
/// 启用 ≠ 权限：容器内=全权 / 主机/手机=必须用户授权
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '技能',
      planItems: [
        '技能分组展示（68 个）：文件 / 记忆 / 系统(System) / 网络 / Git / 配置 / 危险 / GUI / 预警等',
        'System 组：sys_command / system_reboot / system_update 等高危技能重点展示',
        '风险标签：low 绿 / medium 黄 / high 橙 / critical 红',
        '启用开关（≠权限）：允许 AI 调用',
        '权限模型：proot/rootfs 容器内 = 技能拥有所有权限；主机/手机端操作 = 必须用户授权',
        '授权链路：authorization_service 审批（高风险操作确认）',
      ],
      note: '依赖服务端 skill_enable / skill_list_full 命令（批次 4）——当前显示规划结构',
    );
  }
}
