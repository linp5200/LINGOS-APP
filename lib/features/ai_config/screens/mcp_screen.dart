/// 额外的 MCP（0.1.9 骨架——定案：全链路 + 独立技能组 + 认证可选）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class McpScreen extends StatelessWidget {
  const McpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '额外的 MCP',
      planItems: [
        'MCP 服务器列表：名称 / URL / 状态（已连接/未连接）',
        '添加 MCP：名称 + 服务器 URL + 认证（API Key / Bearer Token / 无认证可选）',
        '测试连接按钮',
        'MCP 工具注册为技能（独立"MCP"技能组——AI 可调用）',
        '连接状态管理 + 断线重连',
      ],
      note: '服务端 MCP 客户端从零开发（批次 4）——当前显示规划结构',
    );
  }
}
