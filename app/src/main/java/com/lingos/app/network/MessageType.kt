package com.lingos.app.network

/**
 * 消息类型 - 与服务端 connection_handler.h 对齐
 * 0x0001-0x000A（服务端枚举 connection_msg_type_t）
 */
enum class MessageType(val value: Short) {
    AUTH_CODE(0x0001),
    AUTH_RESPONSE(0x0002),
    CONNECTION_CODE(0x0003),
    CONNECTION_RESPONSE(0x0004),
    COMMAND(0x0005),
    COMMAND_RESPONSE(0x0006),
    STATUS(0x0007),
    HEARTBEAT(0x0008),
    HEARTBEAT_ACK(0x0009),
    ERROR(0x000A);

    companion object {
        private val map = values().associateBy { it.value }
        fun fromValue(value: Short): MessageType? = map[value]
    }
}
