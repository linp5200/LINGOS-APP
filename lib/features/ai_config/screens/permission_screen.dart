/// 权限管理（0.1.9 骨架——定案：19 权限 × 5 模式（含影子）+ 令牌可吊销）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '权限管理',
      planItems: [
        '应用权限列表（19 种）：定位/相机/录音/录屏/加速度计/电话状态/已装应用/外部存储/网络控制/蓝牙控制/扫描蓝牙/启动App/安装App/跳转App/后台数据/后台任务/自启动等',
        '授权模式（5 种）：拒绝 / 单次 / 使用中 / 始终 / 影子（返回空数据）',
        '按 AI 聚合管理（单 app_id）',
        '令牌权限：有效令牌列表（角色/过期时间）+ 吊销',
        '影子模式提示：被影子化权限返回空数据防 AI 获取敏感信息',
        '后台模式已移入 通知与后台',
      ],
      note: '依赖服务端新增 permission_set 命令（批次 4）——当前显示规划结构',
    );
  }
}
