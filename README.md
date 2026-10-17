# LING OS App（Flutter）

LING OS 的移动/远程客户端：与主机 WebSocket 实时对话、查看预警、控制智能家居、管理模型/记忆/文件/视觉。

当前版本：**0.8.0（内测）** · 与 server 0.9.0 配套 · 协议 v3

---

## 功能

- AI 对话：流式输出、思考块/工具块折叠、内联提问卡片、审批卡片、中断/继续、TTS 朗读
- 会话：列表/新建/重命名/删除、会话内切换模型（历史消息回看开发中）
- 预警：实时 alert_event 横幅 + 预警中心（info/L0-L5 级别与配色）
- 智能家居：HA 状态/实体/控制（需主机侧配置）
- 系统：日志（App/服务端）、升级、插件、rootfs、连接设置、开发者选项
- 其他：记忆、命令面板、文件浏览、通知中心、天气、视觉（监控/AI 视觉）、离线缓存

## 构建

    flutter pub get
    flutter build apk --release --target-platform android-arm64
    # 或 flutter build linux

CI：GitHub Actions（Android/Linux；Windows 已知依赖兼容问题，不阻塞）。
Release 资产：arm64-v8a / armeabi-v7a / x86_64 / all。

## 协议

- WS 2939：auth / chat / interrupt / command（协议 v3）
- HTTP 8080：/api/cmd、/system/health、文件接口
- 回包统一由主机侧封装；客户端按命令名匹配响应

## 已知限制（内测）

- 部分命令响应解析与主机回包契约存在差异，正在统一。
- 历史会话回看、复制/重发、Markdown 渲染、极简主题在下一轮 UI 批次。
- 语音识别（STT）尚未接线（TTS 可用）。

## 目录

    lib/core/        连接/协议/存储/日志/主题/i18n
    lib/features/    聊天/预警/会话/家居/视觉/天气/设置等 17 个功能域
    android/ linux/  平台工程

## 许可

当前为内测公开仓库，未附开源许可证（保留所有权利）。
