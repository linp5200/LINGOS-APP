package com.lingos.app.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 【B15】协议编解码单元测试 */
class ProtocolTest {

    @Test
    fun encodeAuthCode_roundTrip() {
        val bytes = Protocol.encodeAuthCode("ABC123")
        val decoded = Protocol.decode(bytes)
        assertEquals(MessageType.AUTH_CODE, decoded?.first)
        assertEquals("ABC123", String(decoded!!.second, Charsets.UTF_8))
    }

    @Test
    fun decode_garbage_returnsNull() {
        assertNull(Protocol.decode(byteArrayOf(1, 2, 3)))
    }

    @Test
    fun encodeCommand_payloadFormat() {
        val bytes = Protocol.encodeCommand("system_info")
        val decoded = Protocol.decode(bytes)
        assertEquals(MessageType.COMMAND, decoded?.first)
        val json = String(decoded!!.second, Charsets.UTF_8)
        assertEquals(true, json.contains("system_info"))
    }
}
