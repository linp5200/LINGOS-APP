package com.lingos.app.ui.dashboard

data class DashboardState(val systemInfo: SystemInfo = SystemInfo(), val devices: List<DeviceItem> = emptyList(), val isLoading: Boolean = false, val error: String? = null)
data class SystemInfo(val cpuUsage: Float = 0f, val memoryUsage: Float = 0f, val memoryTotal: Long = 0, val memoryFree: Long = 0, val networkRx: Long = 0, val networkTx: Long = 0, val uptime: Long = 0)
data class DeviceItem(val id: String, val name: String, val type: DeviceType, val status: DeviceStatus, val ip: String? = null, val mac: String? = null, val icon: String = "📡")
enum class DeviceType { ROUTER, COMPUTER, SMARTPHONE, CAMERA, LIGHT, SOCKET, SENSOR, SPEAKER, TV, OTHER }
enum class DeviceStatus { ONLINE, OFFLINE, UNKNOWN }
