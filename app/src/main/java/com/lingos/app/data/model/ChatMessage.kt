package com.lingos.app.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class MessageSender { USER, NOOK, SYSTEM }
@Entity(tableName = "chat_messages")
data class ChatMessage(@PrimaryKey(autoGenerate = true) val id: Long = 0, val sessionId: String, val content: String, val sender: MessageSender, val timestamp: Long = System.currentTimeMillis(), val isHighlight: Boolean = false, val isRead: Boolean = true, val metadata: Map<String, String> = emptyMap())
data class ChatSession(val id: String, val title: String, val createdAt: Long, val updatedAt: Long, val messageCount: Int = 0, val lastMessage: String? = null, val lastMessageTime: Long? = null)
