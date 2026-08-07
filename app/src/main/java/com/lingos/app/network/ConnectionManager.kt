package com.lingos.app.network

import android.content.Context
import com.lingos.app.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.*
import okhttp3.logging.HttpLoggingInterceptor
import okio.ByteString
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class ConnectionManager(private val context: Context) {

    companion object {
        private const val TAG = "ConnectionManager"
        private const val DEFAULT_HOST = "127.0.0.1"
        private const val DEFAULT_PORT = 2937
        private const val BACKUP_PORT = 2938
        private const val HEARTBEAT_INTERVAL = 30000L
        private const val RECONNECT_DELAY = 5000L
        private const val MAX_RECONNECT_ATTEMPTS = 5
    }

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private var webSocket: WebSocket? = null
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private var sessionId: String? = null
    private var authCode: String? = null
    private var connectionCode: String? = null

    private val okHttpClient: OkHttpClient by lazy {
        val builder = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .pingInterval(HEARTBEAT_INTERVAL, TimeUnit.MILLISECONDS)
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            })
        try {
            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })
            val sslContext = SSLContext.getInstance("SSL")
            sslContext.init(null, trustAllCerts, SecureRandom())
            builder.sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
            builder.hostnameVerifier { _, _ -> true }
        } catch (e: Exception) {
            Logger.e(TAG, "SSL setup failed", e)
        }
        builder.build()
    }

    private val webSocketListener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            Logger.d(TAG, "WebSocket opened")
            _connectionState.value = ConnectionState.Connected
            isReconnecting = false
            reconnectAttempts = 0
            authCode?.let { sendAuthCode(it) }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            Logger.d(TAG, "Message received: $text")
            handleMessage(text)
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            Logger.d(TAG, "Binary message received: ${bytes.size} bytes")
            handleBinaryMessage(bytes)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            Logger.d(TAG, "WebSocket closing: $code $reason")
            webSocket.close(1000, null)
            _connectionState.value = ConnectionState.Disconnected
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            Logger.d(TAG, "WebSocket closed: $code $reason")
            _connectionState.value = ConnectionState.Disconnected
            attemptReconnect()
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            Logger.e(TAG, "WebSocket failure", t)
            _connectionState.value = ConnectionState.Error(t.message ?: "连接失败")
            attemptReconnect()
        }
    }

    suspend fun connect(host: String = DEFAULT_HOST, port: Int = DEFAULT_PORT, timeout: Long = 10000L): Result<Unit> {
        return try {
            val url = "ws://$host:$port"
            Logger.d(TAG, "Connecting to $url")
            _connectionState.value = ConnectionState.Connecting

            val request = Request.Builder()
                .url(url)
                .addHeader("Origin", "android://com.lingos.app")
                .build()

            webSocket = okHttpClient.newWebSocket(request, webSocketListener)

            var attempts = 0
            while (attempts < timeout / 100) {
                delay(100)
                attempts++
                when (_connectionState.value) {
                    ConnectionState.Connected -> return Result.success(Unit)
                    is ConnectionState.Error -> return Result.failure("连接失败")
                    else -> {}
                }
            }
            Result.failure("连接超时")
        } catch (e: Exception) {
            Logger.e(TAG, "Connect failed", e)
            _connectionState.value = ConnectionState.Error(e.message ?: "连接异常")
            Result.failure(e.message ?: "未知错误")
        }
    }

    fun sendAuthCode(code: String): Boolean {
        val ws = webSocket ?: return false
        authCode = code
        val packet = Protocol.encodeAuthCode(code)
        return ws.send(packet)
    }

    fun sendConnectionCode(code: String): Boolean {
        val ws = webSocket ?: return false
        connectionCode = code
        val packet = Protocol.encodeConnectionCode(code)
        return ws.send(packet)
    }

    fun sendHeartbeat(): Boolean {
        val ws = webSocket ?: return false
        val packet = Protocol.encodeHeartbeat()
        return ws.send(packet)
    }

    fun sendCommand(command: String, params: Map<String, Any> = emptyMap()): Boolean {
        val ws = webSocket ?: return false
        val packet = Protocol.encodeCommand(command, params)
        return ws.send(packet)
    }

    fun disconnect() {
        webSocket?.close(1000, "正常断开")
        webSocket = null
        _connectionState.value = ConnectionState.Disconnected
        isReconnecting = false
        reconnectAttempts = 0
    }

    fun getSessionId(): String? = sessionId

    private fun handleMessage(text: String) {
        try {
            val json = org.json.JSONObject(text)
            val type = json.optString("type")
            when (type) {
                "auth_response" -> {
                    val status = json.optString("status")
                    if (status == "ok") {
                        _connectionState.value = ConnectionState.Authenticated
                        Logger.d(TAG, "Auth verified")
                    } else {
                        _connectionState.value = ConnectionState.Error("验证码错误")
                    }
                }
                "connection_response" -> {
                    val status = json.optString("status")
                    if (status == "ok") {
                        sessionId = json.optString("session_id")
                        _connectionState.value = ConnectionState.Connected
                        Logger.d(TAG, "Connection established, session: $sessionId")
                    } else {
                        _connectionState.value = ConnectionState.Error("连接码错误")
                    }
                }
                "heartbeat" -> sendHeartbeat()
            }
        } catch (e: Exception) {
            Logger.w(TAG, "Failed to parse JSON message: $text")
        }
    }

    private fun handleBinaryMessage(bytes: ByteString) {
        try {
            val (type, payload) = Protocol.decode(bytes.toByteArray()) ?: return
            when (type) {
                MessageType.AUTH_RESPONSE -> {
                    val result = payload.decodeToString()
                    if (result.contains("ok")) {
                        _connectionState.value = ConnectionState.Authenticated
                        Logger.d(TAG, "Auth verified (binary)")
                    } else {
                        _connectionState.value = ConnectionState.Error("验证码错误")
                    }
                }
                MessageType.CONNECTION_RESPONSE -> {
                    val result = payload.decodeToString()
                    try {
                        val json = org.json.JSONObject(result)
                        sessionId = json.optString("session_id")
                        _connectionState.value = ConnectionState.Connected
                        Logger.d(TAG, "Connection established (binary), session: $sessionId")
                    } catch (e: Exception) {
                        _connectionState.value = ConnectionState.Error("连接码错误")
                    }
                }
                MessageType.STATUS -> Logger.d(TAG, "Status message received")
                MessageType.COMMAND -> Logger.d(TAG, "Command response received")
                else -> Logger.d(TAG, "Unknown message type: $type")
            }
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to decode binary message", e)
        }
    }

    private fun attemptReconnect() {
        if (isReconnecting) return
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            Logger.w(TAG, "Max reconnect attempts reached")
            return
        }
        isReconnecting = true
        reconnectAttempts++
        CoroutineScope(Dispatchers.IO).launch {
            delay(RECONNECT_DELAY)
            Logger.d(TAG, "Attempting reconnect #$reconnectAttempts")
            connect()
            isReconnecting = false
        }
    }

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

    fun verifyAuthCode(code: String): Result<Boolean> {
        return try {
            if (code.length >= 6) Result.success(true)
            else Result.failure("验证码长度不足")
        } catch (e: Exception) {
            Result.failure(e.message ?: "验证失败")
        }
    }

    fun verifyConnectionCode(code: String): Result<Boolean> {
        return try {
            if (code.length >= 10) Result.success(true)
            else Result.failure("连接码长度不足")
        } catch (e: Exception) {
            Result.failure(e.message ?: "验证失败")
        }
    }

    suspend fun connectViaUSB(device: String?): Result<Unit> {
        return if (device != null) {
            delay(1000)
            if (device.startsWith("/dev/tty")) {
                _connectionState.value = ConnectionState.Connected
                Result.success(Unit)
            } else {
                Result.failure("无效的 USB 设备")
            }
        } else {
            Result.failure("未检测到 USB 设备")
        }
    }
}