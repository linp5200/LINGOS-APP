package com.lingos.app.network

import com.lingos.app.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException

/** 发现到的 LING OS 主机 */
data class DiscoveredHost(
    val name: String,
    val version: String,
    val ip: String,
    val port: Int,
    val capabilities: List<String> = emptyList()
) {
    val displayName: String get() = if (name.isNotBlank()) name else ip
}

/**
 * 局域网发现服务：UDP 广播 LINGOS-DISCOVER → 收集 LING OS 主机响应
 * 协议与服务端 discovery_server.c 对应
 */
object DiscoveryManager {
    private const val TAG = "Discovery"
    private const val DISCOVERY_PORT = 2937
    private const val DISCOVERY_MAGIC = "LINGOS-DISCOVER"
    private const val DEFAULT_TIMEOUT_MS = 2000L
    private const val BROADCAST_RETRIES = 3
    private const val BUF_SIZE = 2048

    /** 局域网扫描，返回发现的主机列表（已去重） */
    suspend fun scan(timeoutMs: Long = DEFAULT_TIMEOUT_MS): List<DiscoveredHost> = withContext(Dispatchers.IO) {
        val results = mutableListOf<DiscoveredHost>()
        var socket: DatagramSocket? = null
        try {
            socket = DatagramSocket()
            socket.broadcast = true
            socket.soTimeout = timeoutMs.toInt()
            val payload = DISCOVERY_MAGIC.toByteArray(Charsets.UTF_8)
            val broadcastAddr = InetAddress.getByName("255.255.255.255")
            repeat(BROADCAST_RETRIES) {
                try {
                    val packet = DatagramPacket(payload, payload.size, broadcastAddr, DISCOVERY_PORT)
                    socket.send(packet)
                } catch (e: Exception) {
                    Logger.w(TAG, "广播发送失败: ${e.message}")
                }
            }
            val endTime = System.currentTimeMillis() + timeoutMs
            val buf = ByteArray(BUF_SIZE)
            while (System.currentTimeMillis() < endTime) {
                val remaining = endTime - System.currentTimeMillis()
                if (remaining <= 0) break
                socket.soTimeout = remaining.toInt().coerceAtLeast(1)
                try {
                    val recv = DatagramPacket(buf, buf.size)
                    socket.receive(recv)
                    val json = String(recv.data, 0, recv.length, Charsets.UTF_8)
                    val host = parseResponse(json, recv.address?.hostAddress ?: "")
                    if (host != null && results.none { it.ip == host.ip }) {
                        results.add(host)
                        Logger.i(TAG, "发现主机: ${host.name} @ ${host.ip}:${host.port} v${host.version}")
                    }
                } catch (e: SocketTimeoutException) {
                    break
                } catch (e: Exception) {
                    Logger.w(TAG, "接收响应异常: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Logger.e(TAG, "扫描失败", e)
        } finally {
            try { socket?.close() } catch (_: Exception) {}
        }
        results
    }

    private fun parseResponse(json: String, fallbackIp: String): DiscoveredHost? {
        return try {
            val obj = JSONObject(json)
            if (obj.optString("type") != "lingos") return null
            val caps = obj.optJSONArray("capabilities")?.let { arr ->
                (0 until arr.length()).map { arr.optString(it) }
            } ?: emptyList()
            DiscoveredHost(
                name = obj.optString("name", "LING-OS"),
                version = obj.optString("version", "unknown"),
                ip = obj.optString("ip", fallbackIp),
                port = obj.optInt("port", 2937),
                capabilities = caps
            )
        } catch (e: Exception) {
            Logger.w(TAG, "响应解析失败: ${e.message}")
            null
        }
    }
}
