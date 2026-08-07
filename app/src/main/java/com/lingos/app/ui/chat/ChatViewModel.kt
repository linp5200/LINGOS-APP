package com.lingos.app.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.utils.Logger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor() : ViewModel() {
    companion object { private const val TAG = "ChatVM"; private val QUICK_COMMANDS = listOf("/file", "/status", "/help", "/memory", "/device") }
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList()); val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    private val _inputText = MutableStateFlow(""); val inputText: StateFlow<String> = _inputText.asStateFlow()
    private val _chatState = MutableStateFlow<ChatState>(ChatState.Idle); val chatState: StateFlow<ChatState> = _chatState.asStateFlow()
    private val _isVoiceRecording = MutableStateFlow(false); val isVoiceRecording: StateFlow<Boolean> = _isVoiceRecording.asStateFlow()

    init { addSystemMessage("LING OS 已就绪。输入 /help 查看命令。") }
    fun updateInputText(text: String) { _inputText.value = text; if (text.startsWith("/")) { val cmd = text.split(" ").first(); if (QUICK_COMMANDS.contains(cmd)) { handleQuickCommand(cmd, text.removePrefix(cmd).trim()) } } }
    fun sendMessage() { val text = _inputText.value.trim(); if (text.isEmpty() || _chatState.value == ChatState.Thinking) return; val userMsg = ChatMessage(content=text, sender=MessageSender.USER); _messages.update { it + userMsg }; _inputText.value = ""; if (text.startsWith("/")) return; sendToAI(text) }
    fun sendVoiceCommand(text: String) { if (text.isEmpty()) return; _inputText.value = text; sendMessage() }
    fun startVoiceRecording() { _isVoiceRecording.value = true; Logger.d(TAG, "Voice recording started") }
    fun stopVoiceRecording() { _isVoiceRecording.value = false; viewModelScope.launch { delay(1000); sendVoiceCommand("系统状态如何？") }; Logger.d(TAG, "Voice recording stopped") }
    fun clearMessages() { _messages.value = emptyList(); _chatState.value = ChatState.Idle; addSystemMessage("对话已清除") }
    private fun addSystemMessage(content: String) { _messages.update { it + ChatMessage(content=content, sender=MessageSender.SYSTEM, isHighlight=false) } }
    private fun handleQuickCommand(cmd: String, args: String) { when (cmd) { "/help" -> showHelp(); "/status" -> sendToAI("显示系统状态"); "/memory" -> sendToAI("显示记忆摘要"); "/device" -> sendToAI("列出所有设备"); "/file" -> sendToAI("文件操作: $args"); else -> addSystemMessage("未知命令: $cmd") } }
    private fun showHelp() { val helpText = "/help - 显示此帮助\n/status - 显示系统状态\n/memory - 显示记忆摘要\n/device - 列出所有设备\n/file <path> - 文件操作"; _messages.update { it + ChatMessage(content=helpText, sender=MessageSender.SYSTEM, isHighlight=true) } }
    private fun sendToAI(prompt: String) { viewModelScope.launch { _chatState.value = ChatState.Thinking; delay(1000); if (prompt.contains("状态") || prompt.contains("status")) { _chatState.value = ChatState.ToolCall("system_status", "{}"); delay(800) }; val response = when { prompt.contains("状态") -> "系统状态正常。CPU: 12%, 内存: 45%, 网络: 连通"; prompt.contains("设备") -> "发现 3 台设备：\n- 192.168.1.101 (路由器)\n- 192.168.1.102 (智能插座)\n- 192.168.1.103 (摄像头)"; prompt.contains("记忆") -> "记忆摘要：\n- 用户偏好：简洁回复\n- 最近访问：/home/user"; else -> "已收到您的消息。我可以帮您查询系统状态、管理设备或执行文件操作。有什么具体需要？" }; _chatState.value = ChatState.Streaming(""); var currentText = ""; for (char in response) { delay(20); currentText += char; _chatState.value = ChatState.Streaming(currentText) }; delay(200); _messages.update { it + ChatMessage(content=response, sender=MessageSender.NOOK) }; _chatState.value = ChatState.Idle } }
}
