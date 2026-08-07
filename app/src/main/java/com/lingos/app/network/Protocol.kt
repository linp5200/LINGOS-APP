package com.lingos.app.network

import java.nio.ByteBuffer
import java.nio.ByteOrder

object Protocol {
    const val MAGIC: Int = 0x4C4E4753
    const val VERSION: Short = 0x0001

    fun encode(type: MessageType, payload: ByteArray): ByteArray {
        val totalLength = 12 + payload.size
        val buffer = ByteBuffer.allocate(totalLength).order(ByteOrder.BIG_ENDIAN)
        buffer.putInt(MAGIC); buffer.putShort(VERSION); buffer.putShort(type.value); buffer.putInt(payload.size); buffer.put(payload)
        return buffer.array()
    }

    fun decode(data: ByteArray): Pair<MessageType, ByteArray>? {
        if (data.size < 12) return null
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        val magic = buffer.int; if (magic != MAGIC) return null
        val version = buffer.short; if (version != VERSION) return null
        val typeValue = buffer.short; val type = MessageType.fromValue(typeValue) ?: return null
        val length = buffer.int; if (data.size < 12 + length) return null
        val payload = ByteArray(length); buffer.get(payload)
        return Pair(type, payload)
    }

    fun encodeAuthCode(code: String): ByteArray { val payload = code.toByteArray(Charsets.UTF_8); return encode(MessageType.AUTH_CODE, payload) }
    fun encodeConnectionCode(code: String): ByteArray { val payload = code.toByteArray(Charsets.UTF_8); return encode(MessageType.CONNECTION_CODE, payload) }
    fun encodeCommand(command: String, params: Map<String, Any> = emptyMap()): ByteArray {
        val json = buildString {
            append("{\"command\":\"$command\",\"params\":{")
            params.entries.forEachIndexed { index, entry ->
                val value = when (entry.value) { is String -> "\"${entry.value}\""; else -> entry.value.toString() }
                append("\"${entry.key}\":$value"); if (index < params.size - 1) append(",")
            }
            append("}}")
        }
        val payload = json.toByteArray(Charsets.UTF_8); return encode(MessageType.COMMAND, payload)
    }
    fun encodeHeartbeat(): ByteArray { val payload = "{}".toByteArray(Charsets.UTF_8); return encode(MessageType.HEARTBEAT, payload) }
    fun encodeStatus(status: Map<String, Any>): ByteArray { val json = buildString { append("{"); status.entries.forEachIndexed { index, entry -> val value = when (entry.value) { is String -> "\"${entry.value}\""; else -> entry.value.toString() }; append("\"${entry.key}\":$value"); if (index < status.size - 1) append(",") }; append("}") }; val payload = json.toByteArray(Charsets.UTF_8); return encode(MessageType.STATUS, payload) }
}
