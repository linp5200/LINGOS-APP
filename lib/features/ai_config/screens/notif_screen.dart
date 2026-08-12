/// 通知与后台（0.1.9 骨架——定案：灵动胶囊+焦点通知 / 任务通知 AI+预警联动 / 电池优化自启动引导）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class NotifScreen extends StatelessWidget {
  const NotifScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '通知与后台',
      planItems: [
        '预警通知开关（服务端预警 → App 推送）',
        '通知渠道：App 推送（WS 在线直推 / 离线本地兜底）+ 系统通知',
        '安卓16+ 灵动胶囊 / 焦点通知（Redmi HyperOS 常驻通知 + Focus Notifications API）',
        '任务通知：允许 AI / agent 主动通知（gui_notify）+ 预警联动',
        '后台保活：前台服务 + 常驻通知；后台模式（允许/限时/拒绝）；断线重连指数退避',
        '后台权限：电池优化 + 自启动（跳系统设置引导）',
      ],
      note: '通知服务已具备（NotificationService）——保活与权限引导批次 4 开发',
    );
  }
}
