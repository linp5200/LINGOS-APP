package com.lingos.app.ui.connect

sealed class ConnectState {
    object Idle : ConnectState()
    data class Connecting(val method: ConnectionMethod = ConnectionMethod.LAN, val progress: Int = 0, val message: String = "") : ConnectState()
    data class WaitingAuth(val step: AuthStep = AuthStep.AUTH_CODE, val code: String = "") : ConnectState()
    object Connected : ConnectState()
    data class Failed(val message: String, val canRetry: Boolean = true) : ConnectState()
    data class Scanning(val foundDevices: List<DetectedDevice> = emptyList(), val progress: Int = 0) : ConnectState()
}
enum class ConnectionMethod { LAN, PUBLIC, USB }
enum class AuthStep { AUTH_CODE, CONNECTION_CODE }
data class DetectedDevice(val ip: String, val hostname: String? = null, val port: Int = 2937, val isReachable: Boolean = false)
sealed class ConnectEvent { data class SelectMethod(val method: ConnectionMethod) : ConnectEvent(); data class UpdateAddress(val address: String) : ConnectEvent(); data class UpdatePort(val port: String) : ConnectEvent(); data class UpdateAuthCode(val code: String) : ConnectEvent(); data class UpdateConnectionCode(val code: String) : ConnectEvent(); object StartScan : ConnectEvent(); object StartConnect : ConnectEvent(); object Retry : ConnectEvent(); object Reset : ConnectEvent(); object GoBack : ConnectEvent() }
