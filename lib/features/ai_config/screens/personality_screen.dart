/// 人格（0.1.9 骨架——定案：诺克/诺玛切换 + 文件化 + 音色联动语音）
library;

import 'package:flutter/material.dart';

import 'plan_page.dart';

class PersonalityScreen extends StatelessWidget {
  const PersonalityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlanPage(
      title: '人格',
      planItems: [
        '人格选择：诺克（冷静/理性/绝对忠诚——核心AI）/ 诺玛（温柔/温暖/睿智——陪伴AI）',
        '人格参数：性别 / 音色 / 严谨度 / 温暖度 / 语速（0-10 滑杆）',
        '自定义人格：不支持（仅内置双人格切换）',
        '音色字段联动语音（TTS 通道——本期只存参数）',
        '服务端：人格文件化 /LINGOS/system/config/personality.json + personality_set 命令',
      ],
      note: '依赖服务端人格文件化改造（批次 4）——当前显示规划结构',
    );
  }
}
