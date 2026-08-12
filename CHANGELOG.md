# LING OS App 更新日志（CHANGELOG）

版本线：SemVer 2.0.0（主.次.修订）· 包名：LINGOS_<架构>_android_beta_<版本>.apk

---

## [0.2.0] - 规划中（先生指示下一版本）

### 新增（计划）
- AI 配置 15 子菜单剩余项填充（Rootfs 沙箱运行引擎对接 Termux proot）
- MCP 工具注册为技能（独立 MCP 技能组——AI 对话可调用）
- 服务端 ai_config_set 写提供商生效（LLM 类配置真实切换）
- 语音类提供商服务端通道（TTS/识别）
- 预警系统深化（App 推送联动 alert_query）

---

## [0.1.9] - 2026-08-12（当前最新）

### 修复（Bug Fixes）
- **对话消息无法发送**：App 发送 `content` 字段、服务端只认 `prompt`——改为 App 发 `prompt` 适配（服务端现状）
- **AI 回复不显示**：服务端 AI 事件包装为 `chat_event`，App 无法识别——新增解包（data 内递归解析 content/thinking/tool/done）
- **仪表盘数据空白**：command_response 的 data 类型不匹配（App 期望 String、服务端发 Map）——兼容两种类型 + status 校验 + 空数据明确提示
- **AI 工具并行调用崩溃**：服务端 `call_deepseek_stream` 缺 `tool_calls_acc` 初始化（NameError）——已补
- **权限/人格设置无效**：服务端命令解析未扁平化 `params` 嵌套（参数全空）——解析后扁平化到顶层
- **左上角三横点击无响应**：Scaffold.of 跨层找不到 HomeShell 的 drawer——改用 GlobalKey + 回调
- **版本号不更新**：build.gradle 硬编码 versionName "0.1.8" 覆盖 pubspec——改为动态 `flutter.versionName`
- **日志重复入口**：AI 配置主页与连接与设置内重复——删主页入口，设置主页独立"日志"入口 + 记录开关

### 新增（Features）
- **AI 配置界面（15 子菜单）**：
  - LLM/MLM 提供商：添加提供商（12 家预填——OpenAI/Anthropic/Compatible/Kimi + 语音 8 家；三段式：列表→选择→密钥配置）
  - Token 完整用量：汇总卡片/时间过滤/按模型分组/明细（服务端 token_usage_query + JSONL 落盘）
  - 权限管理：19 权限 × 5 模式（拒绝/单次/使用中/始终/影子）+ 分组折叠（设备/存储/网络/后台/应用）+ 类级统一授权 + **真实 Android 系统授权**（permission_handler）
  - 记忆管理：时间显示 + 摘要展开 + AI 自动写入开关
  - 会话管理：点击进入对话续接 + 长按多选批量删除
  - 人格：诺克/诺玛选择 + 参数滑杆（服务端 personality_get/set）
  - 技能：68 技能分组 + 风险色标 + 启用开关（启用 ≠ 权限：容器内全权/主机需授权）
  - 额外的 MCP：服务器列表/添加（认证可选）/测试连接/删除（服务端 mcp_add/remove/list/test）
  - Rootfs 本地沙箱管理：多发行版安装向导（Alpine/Ubuntu/Debian）+ 下载进度 + 状态卡片 + proot 路径配置
  - 挂载外部文件：Android 外部存储 + 服务端 /LINGOS 双来源 + 持久化 + 只读/读写
  - 管理服务端文件：/LINGOS 九大目录结构化导航 + 查看
  - 浏览文件：点击查看内容 + 重命名（增强）
  - 通知与后台：预警/灵动胶囊/任务通知开关 + 后台保活/模式 + 电池优化/自启动引导
  - 连接与设置：主机IP/连接密钥/连接状态/连接方式/加密 + 退出登录
  - 外观与偏好：主题（深/浅/跟随系统）+ 强调色动态取色 + 语言 + 消息偏好（全开）+ 隐私统计（默认关）
  - **特权**：Shizuku 检测/授权 + AI 经 adb 执行命令通道（shizuku_api 1.2.2）
- **导航重构**：左上角三横 Drawer 统一入口（设置/HA/预警）+ 底部保留对话/仪表盘；原设置/记忆/文件迁入 AI 配置
- **对话交互**：发送键 ↔ 中断键切换 + "已终止（继续）"重发原文续接（服务端 interrupt 帧 + chat 独立线程）
- **预警适配**：alert_query 返回 events 字段渲染 + 字段映射（description/location/timestamp）
- **打包**：CI 资产加 `LINGOS_` 前缀（arm64-v8a/armeabi-v7a/x86_64/all 四包）

### 服务端配套（ai_server.py——先生环境 cp 即生效）
- 新增 12 命令：token_usage_query / permission_set / permission_list / skill_list_full / skill_enable / personality_set / personality_get / ai_config_set / mcp_add / mcp_remove / mcp_list / mcp_test
- S1/S2 修复（见上）
- websocket_server.c：WS 端口 2939（原 3940 与协议不符）+ interrupt 帧 + chat 转发独立线程

### 技术备注
- CI 桌面端（Linux/Windows）构建失败不阻塞 Android 发布（continue-on-error）
- Windows STL1011 为 CI VS18 环境问题（与代码无关）

---

## [0.1.8] - 2026-08-11

### 修复
- WS 端口 = TCP 端口 + 2（2937→2939 协议约定——曾用错端口导致 WS 未连）
- App 认证前心跳（0x0008 首包拒绝）
- token 重验证弹窗（验证码/登出）

### 新增
- raw socket WebSocket（绕开 HttpClient 101 兼容问题）
- token 加密存储 + 设备绑定
