/// Token 完整用量（0.1.9 骨架——定案：仅 DeepSeek 统计 + JSONL 持久化）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class TokenUsageScreen extends StatelessWidget {
  const TokenUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: 'Token 完整用量',
      planItems: [
        '汇总卡片：总用量 / 请求次数 / 输入·输出分项',
        '时间过滤：今天 / 近7天 / 近30天 / 全部 / 自定义区间',
        '分组视图：按提供商（DeepSeek）与按模型',
        '明细列表：每次请求时间/模型/输入/输出 token（可展开）',
        'Ollama 本地模型：无 usage 返回——显示"未知"',
        '服务端：/LINGOS/state/token_usage.jsonl 追加持久化 + token_usage_query 命令',
      ],
      note: '依赖服务端新增命令 token_usage_query（批次 4）——当前显示规划结构',
    );
  }
}
