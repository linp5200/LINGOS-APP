package com.lingos.app.network

import android.content.Context
import com.lingos.app.utils.Logger
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject

/**
 * LING OS 连接管理器 - TCP + 二进制 TLV 帧协议
 * 与服务端 connection_handler.c (2937) 对应：
 *   MAGIC(4B) | VERSION(2B) | TYPE(2B) | LENGTH(4B) | PAYLOAD
 * 认证流程：AUTH_CODE → CONNECTION_CODE → ESTABLISHED
 */
class ConnectionManager @Inject constructor(@ApplicationContext private val context: Context) {

    companion object {
        private const val TAG = "ConnectionManager"
        private const val DEFAULT_HOST = "127.0.0.1"
        private const val DEFAULT_PORT = 2937
        private const val BACKUP_PORT = 2938
        private const val AUTH_TIMEOUT_MS = 10000L
        private const val COMMAND_TIMEOUT_MS = 5000L
        private const val SOCKET_READ_TIMEOUT_MS = 30000
        private const val HEADER_SIZE = 12
        private const val MAX_PAYLOAD = 65536
    }

    private var host: String? = null
    private var socket: Socket? = null
    private var receiveThread: Thread? = null
    private val running = AtomicBoolean(false)
    private var sessionId: String? = null
    private var authCode = ""
    private var connectionCode = ""
    private var token: String? = null

    // 响应等待（同步化异步接收）
    private var pendingAuth = CompletableDeferred<Result<Boolean>>()
    private var pendingConnCode = CompletableDeferred<Result<Boolean>>()
    private var pendingCommand = CompletableDeferred<Result<String>>()

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val writeLock = Any()

    /** TCP 连接（非 WebSocket！服务端 2937 是 raw TCP） */
    suspend fun connect(host: String = DEFAULT_HOST, port: Int = DEFAULT_PORT, timeout: Long = 10000L): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            _connectionState.value = ConnectionState.Connecting
            Logger.d(TAG, "TCP connecting to $host:$port")
            this@ConnectionManager.host = host
            val sock = Socket()
            sock.connect(InetSocketAddress(host, port), timeout.toInt())
            sock.soTimeout = SOCKET_READ_TIMEOUT_MS
            socket = sock
            running.set(true)
            startReceiveLoop()
            _connectionState.value = ConnectionState.Connected
            Logger.d(TAG, "TCP connected to $host:$port")
            Result.success(Unit)
        } catch (e: Exception) {
            Logger.e(TAG, "TCP connect failed", e)
            _connectionState.value = ConnectionState.Error(e.message ?: "连接异常")
            Result.failure(e.message ?: "连接失败")
        }
    }

    private fun startReceiveLoop() {
        receiveThread = Thread({ receiveLoop() }, "LingosTcpReceiver").apply {
            isDaemon = true
            start()
        }
    }

    private fun receiveLoop() {
        val sock = socket ?: return
        val input: InputStream = try { sock.getInputStream() } catch (e: Exception) { return }
        val headerBuf = ByteArray(HEADER_SIZE)
        while (running.get()) {
            try {
                // 读 12 字节帧头
                if (!readFully(input, headerBuf)) break
                val header = ByteBuffer.wrap(headerBuf).order(ByteOrder.BIG_ENDIAN)
                val magic = header.int
                val version = header.short.toInt() and 0xFFFF
                val type = header.short.toInt() and 0xFFFF
                val length = header.int
                if (magic != Protocol.MAGIC) {
                    Logger.w(TAG, "Magic mismatch: 0x%08X (ver=%d)", magic, version)
                    continue
                }
                if (length < 0 || length > MAX_PAYLOAD) {
                    Logger.w(TAG, "Bad length: $length")
                    continue
                }
                val payload = ByteArray(length)
                if (!readFully(input, payload)) break
                handleFrame(type, payload)
            } catch (e: SocketTimeoutException) {
                // 读超时：保活心跳
                sendHeartbeat()
            } catch (e: Exception) {
                if (running.get()) Logger.e(TAG, "Receive error", e)
                break
            }
        }
        if (running.getAndSet(false)) {
            _connectionState.value = ConnectionState.Disconnected
        }
    }

    private fun readFully(input: InputStream, buf: ByteArray): Boolean {
        var read = 0
        while (read < buf.size) {
            val n = input.read(buf, read, buf.size - read)
            if (n < 0) return false
            read += n
        }
        return true
    }

    /** 帧分发（与服务端消息类型对齐） */
    private fun handleFrame(type: Int, payload: ByteArray) {
        val text = String(payload, Charsets.UTF_8)
        Logger.d(TAG, "Frame type=0x%04X len=%d payload=%s", type, payload.size, text.take(150))
        when (type) {
            MessageType.AUTH_RESPONSE.value.toInt() -> {
                if (text.contains("\"ok\"")) {
                    _connectionState.value = ConnectionState.Authenticated
                    pendingAuth.complete(Result.success(true))
                } else {
                    pendingAuth.complete(Result.failure(text))
                }
            }
            MessageType.CONNECTION_RESPONSE.value.toInt() -> {
                if (text.contains("\"ok\"")) {
                    sessionId = extractSessionId(text)
                    token = extractToken(text)
                    _connectionState.value = ConnectionState.Connected
                    pendingConnCode.complete(Result.success(true))
                } else {
                    pendingConnCode.complete(Result.failure(text))
                }
            }
            MessageType.COMMAND_RESPONSE.value.toInt() -> {
                pendingCommand.complete(Result.success(text))
            }
            MessageType.HEARTBEAT_ACK.value.toInt() -> {
                // 心跳保活确认
            }
            MessageType.ERROR.value.toInt() -> {
                pendingAuth.complete(Result.failure(text))
                pendingConnCode.complete(Result.failure(text))
                pendingCommand.complete(Result.failure(text))
                _connectionState.value = ConnectionState.Error(text)
            }
            else -> Logger.w(TAG, "Unknown frame type 0x%04X", type)
        }
    }

    private fun extractToken(text: String): String? {
        return try {
            val obj = org.json.JSONObject(text)
            obj.optString("token").takeIf { it.isNotBlank() }
        } catch (e: Exception) { null }
    }

    fun getToken(): String? = token

    private fun extractSessionId(text: String): String? {
        return try {
            val obj = org.json.JSONObject(text)
            obj.optString("session_id").takeIf { it.isNotBlank() }
        } catch (e: Exception) { null }
    }

    // ============ 发送 ============

    fun sendAuthCode(code: String): Boolean {
        authCode = code
        return sendFrame(Protocol.encodeAuthCode(code))
    }

    fun sendConnectionCode(code: String): Boolean {
        connectionCode = code
        return sendFrame(Protocol.encodeConnectionCode(code))
    }

    fun sendHeartbeat(): Boolean {
        return sendFrame(Protocol.encodeHeartbeat())
    }

    fun sendCommand(command: String, params: Map<String, Any> = emptyMap()): Boolean {
        return sendFrame(Protocol.encodeCommand(command, params))
    }

    private fun sendFrame(packet: ByteArray): Boolean {
        val sock = socket ?: return false
        return try {
            synchronized(writeLock) {
                val out = sock.getOutputStream()
                out.write(packet)
                out.flush()
            }
            true
        } catch (e: Exception) {
            Logger.e(TAG, "Send failed", e)
            false
        }
    }

    // ============ 同步等待响应 ============

    /** 验证码校验（等待服务端 AUTH_RESPONSE） */
    suspend fun verifyAuthCode(code: String): Result<Boolean> {
        if (code.isBlank()) return Result.failure("验证码为空")
        pendingAuth = CompletableDeferred()
        if (!sendAuthCode(code)) return Result.failure("发送失败，请确认已连接")
        return withTimeoutOrNull(AUTH_TIMEOUT_MS) { pendingAuth.await() }
            ?: Result.failure("验证码验证超时")
    }

    /** 连接码校验（等待服务端 CONNECTION_RESPONSE） */
    suspend fun verifyConnectionCode(code: String): Result<Boolean> {
        if (code.isBlank()) return Result.failure("连接码为空")
        pendingConnCode = CompletableDeferred()
        if (!sendConnectionCode(code)) return Result.failure("发送失败，请确认已连接")
        return withTimeoutOrNull(AUTH_TIMEOUT_MS) { pendingConnCode.await() }
            ?: Result.failure("连接码验证超时")
    }

    /** 发送命令并等待响应 */
    suspend fun sendCommandAndAwait(command: String, params: Map<String, Any> = emptyMap(), timeoutMs: Long = COMMAND_TIMEOUT_MS): Result<String> {
        pendingCommand = CompletableDeferred()
        if (!sendCommand(command, params)) return Result.failure("命令发送失败")
        return withTimeoutOrNull(timeoutMs) { pendingCommand.await() }
            ?: Result.failure("命令响应超时")
    }

    suspend fun connectViaUSB(device: String?): Result<Unit> {
        return Result.failure("USB 连接暂不支持，请使用局域网连接")
    }

    fun disconnect() {
        running.set(false)
        try { socket?.close() } catch (_: Exception) {}
        socket = null
        _connectionState.value = ConnectionState.Disconnected
    }

    fun getHost(): String? = host
    fun getSessionId(): String? = sessionId
    fun getAuthCode(): String = authCode
    fun getConnectionCode(): String = connectionCode

    sealed class ConnectionState {
        object Disconnected : ConnectionState()
        object Connecting : ConnectionState()
        object Authenticated : ConnectionState()
        object Connected : ConnectionState()
        data class Error(val message: String) : ConnectionState()
    }

    data class Result<T>(
        val isSuccess: Boolean,
        val data: T? = null,
        val errorMessage: String? = null
    ) {
        companion object {
            fun <T> success(data: T): Result<T> = Result(true, data)
            fun <T> failure(message: String): Result<T> = Result(false, null, message)
        }
    }
}
