package com.lingos.app.ui.chat

import androidx.compose.ui.graphics.Color
import com.lingos.app.ui.theme.LINGOSColors

sealed class ChatState { object Idle : ChatState(); object Thinking : ChatState(); data class Streaming(val content: String) : ChatState(); data class ToolCall(val toolName: String, val args: String) : ChatState(); data class Error(val message: String) : ChatState() }
data class ChatMessage(val id: String = System.currentTimeMillis().toString(), val content: String, val sender: MessageSender, val timestamp: Long = System.currentTimeMillis(), val isHighlight: Boolean = false) { val isUser: Boolean get() = sender == MessageSender.USER }
enum class MessageSender { USER, NOOK, SYSTEM }
