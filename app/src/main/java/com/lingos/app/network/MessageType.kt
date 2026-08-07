package com.lingos.app.network

enum class MessageType(val value: Short) {
    AUTH_CODE(0x0001), AUTH_RESPONSE(0x0002), CONNECTION_CODE(0x0003), CONNECTION_RESPONSE(0x0004), COMMAND(0x0005), STATUS(0x0006), HEARTBEAT(0x0007), ERROR(0x0008);
    companion object { private val map = values().associateBy { it.value }; fun fromValue(value: Short): MessageType? = map[value] }
}
