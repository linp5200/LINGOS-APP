package com.lingos.app.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.network.ConnectionManager
import com.lingos.app.utils.Logger
import dagger.hilt.android.lifecycle.HiltViewModel
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "ChatVM"; private val QUICK_COMMANDS = listOf("/file", "/status", "/help", "/memory", "/device"); private const val WS_PORT = 2939 }
    private var webSocket: WebSocket? = null
    private var streamingContent = ""
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList()); val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    private val _inputText = MutableStateFlow(""); val inputText: StateFlow<String> = _inputText.asStateFlow()
    private val _chatState = MutableStateFlow<ChatState>(ChatState.Idle); val chatState: StateFlow<ChatState> = _chatState.asStateFlow()
    private val _isVoiceRecording = MutableStateFlow(false); val isVoiceRecording: StateFlow<Boolean> = _isVoiceRecording.asStateFlow()

    init { addSystemMessage("LING OS 已就绪。输入 /help 查看命令。"); connectToAI() }
    fun updateInputText(text: String) { _inputText.value = text; if (text.startsWith("/")) { val cmd = text.split(" ").first(); if (QUICK_COMMANDS.contains(cmd)) { handleQuickCommand(cmd, text.removePrefix(cmd).trim()) } } }
    fun sendMessage() { val text = _inputText.value.trim(); if (text.isEmpty() || _chatState.value == ChatState.Thinking) return; val userMsg = ChatMessage(content=text, sender=MessageSender.USER); _messages.update { it + userMsg }; _inputText.value = ""; if (text.startsWith("/")) return; sendToAI(text) }
    fun sendVoiceCommand(text: String) { if (text.isEmpty()) return; _inputText.value = text; sendMessage() }
    fun startVoiceRecording() { _isVoiceRecording.value = true; Logger.d(TAG, "Voice recording started") }
    fun stopVoiceRecording() { _isVoiceRecording.value = false; Logger.d(TAG, "Voice recording stopped（STT 识别在 ChatScreen 层）") }
    fun onVoiceRecognized(text: String) { if (text.isNotBlank()) sendVoiceCommand(text) }
    fun clearMessages() { _messages.value = emptyList(); _chatState.value = ChatState.Idle; addSystemMessage("对话已清除") }
    private fun addSystemMessage(content: String) { _messages.update { it + ChatMessage(content=content, sender=MessageSender.SYSTEM, isHighlight=false) } }
    private fun handleQuickCommand(cmd: String, args: String) { when (cmd) { "/help" -> showHelp(); "/status" -> sendToAI("显示系统状态"); "/memory" -> sendToAI("显示记忆摘要"); "/device" -> sendToAI("列出所有设备"); "/file" -> sendToAI("文件操作: $args"); else -> addSystemMessage("未知命令: $cmd") } }
    private fun showHelp() { val helpText = "/help - 显示此帮助\n/status - 显示系统状态\n/memory - 显示记忆摘要\n/device - 列出所有设备\n/file <path> - 文件操作"; _messages.update { it + ChatMessage(content=helpText, sender=MessageSender.SYSTEM, isHighlight=true) } }
    private fun sendToAI(prompt: String) {
        val ws = webSocket
        if (ws == null) {
            addSystemMessage("AI 通道未连接（请先连接主机）")
            return
        }
        _chatState.value = ChatState.Thinking
        streamingContent = ""
        val json = org.json.JSONObject().put("type", "chat").put("prompt", prompt).toString()
        ws.send(json)
    }

    /** 【B4】连接 2939 WebSocket（token 认证 + 数据流对话） */
    private fun connectToAI() {
        val host = connectionManager.getHost() ?: return
        val token = connectionManager.getToken() ?: return
        try {
            val client = OkHttpClient.Builder()
                .readTimeout(0, java.util.concurrent.TimeUnit.MILLISECONDS)
                .build()
            val request = Request.Builder().url("ws://$host:$WS_PORT").build()
            webSocket = client.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(ws: WebSocket, response: Response) {
                    ws.send("""{"type":"auth","token":"$token"}""")
                }
                override fun onMessage(ws: WebSocket, text: String) {
                    handleWsEvent(text)
                }
                override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                    Logger.w(TAG, "WS 连接失败: ${t.message}")
                }
            })
            Logger.d(TAG, "已连接 2939 AI 通道")
        } catch (e: Exception) {
            Logger.e(TAG, "WS 连接异常", e)
        }
    }

    /** 【B8】系统通知（gui_notify） */
    private fun sendSystemNotification(title: String, body: String) {
        try {
            val context = android.app.ActivityManager::class.java
            val notifManager = context
        } catch (_: Exception) {}
        // 通知需要 Context——通过 ConnectionManager 间接不可得，此处仅记录
        Logger.i(TAG, "通知: $title - $body")
        addSystemMessage("🔔 $title: $body")
    }

    private fun handleWsEvent(text: String) {
        try {
            val obj = org.json.JSONObject(text)
            when (obj.optString("type")) {
                "auth_ok" -> Logger.d(TAG, "WS 认证成功")
                "auth_error" -> { addSystemMessage("连接失败：token 无效"); _chatState.value = ChatState.Idle }
                "chat_event" -> {
                    val data = obj.optJSONObject("data") ?: return
                    when (data.optString("type")) {
                        "thinking" -> { }
                        "content" -> {
                            val delta = data.optString("delta", data.optString("content"))
                            if (delta.isNotEmpty()) {
                                streamingContent += delta
                                _chatState.value = ChatState.Streaming(streamingContent)
                            }
                        }
                        "tool_call" -> {
                            val name = data.optString("name", data.optString("tool", "tool"))
                            _chatState.value = ChatState.ToolCall(name, "")
                        }
                        "gui_notify" -> {
                            val title = data.optString("title", "LING OS 通知")
                            val body = data.optString("message", data.optString("content", ""))
                            if (body.isNotBlank()) sendSystemNotification(title, body)
                        }
                        "done" -> {
                            if (streamingContent.isNotBlank()) {
                                _messages.update { it + ChatMessage(content=streamingContent, sender=MessageSender.NOOK) }
                            }
                            streamingContent = ""
                            _chatState.value = ChatState.Idle
                        }
                    }
                }
                "chat_done" -> {
                    if (streamingContent.isNotBlank()) {
                        _messages.update { it + ChatMessage(content=streamingContent, sender=MessageSender.NOOK) }
                    }
                    streamingContent = ""
                    _chatState.value = ChatState.Idle
                }
                "chat_error" -> {
                    addSystemMessage("AI 错误：${obj.optString("message")}")
                    streamingContent = ""
                    _chatState.value = ChatState.Idle
                }
            }
        } catch (e: Exception) {
            Logger.w(TAG, "WS 事件解析失败: ${e.message}")
        }
    }
}
