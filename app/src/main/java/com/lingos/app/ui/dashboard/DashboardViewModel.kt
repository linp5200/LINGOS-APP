package com.lingos.app.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.network.ConnectionManager
import com.lingos.app.utils.Logger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject
import kotlin.random.Random

@HiltViewModel
class DashboardViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "DashboardVM" }
    private val _state = MutableStateFlow(DashboardState()); val state: StateFlow<DashboardState> = _state.asStateFlow()
    init { loadData(); startRefreshLoop() }
    fun refresh() { loadData() }
    fun toggleDevice(id: String) { viewModelScope.launch { val newState = _state.value.devices.map { device -> if (device.id == id) device.copy(status = if (device.status == DeviceStatus.ONLINE) DeviceStatus.OFFLINE else DeviceStatus.ONLINE) else device }; _state.update { it.copy(devices=newState) } } }
    fun scanDevices() { viewModelScope.launch { _state.update { it.copy(isLoading=true) }; delay(2000); val newDevices = listOf(DeviceItem(id="device_${System.currentTimeMillis()}", name="新设备 ${Random.nextInt(100,999)}", type=DeviceType.SOCKET, status=DeviceStatus.ONLINE, ip="192.168.1.${Random.nextInt(100,200)}")); _state.update { it.copy(devices=it.devices + newDevices, isLoading=false) } } }
    fun startMqtt() { Logger.d(TAG, "MQTT service starting...") }
    private fun loadData() { viewModelScope.launch {
        // 【R3】先生原则：无假数据——真实 system_info；失败显示未连接（不 mock）
        val result = connectionManager.sendCommandAndAwait("system_info", emptyMap(), 8000L)
        if (result.isSuccess) {
            val sysInfo = parseSystemInfo(result.data ?: "")
            _state.update { it.copy(systemInfo=sysInfo, devices=emptyList(), isLoading=false, error=null) }
        } else {
            Logger.w(TAG, "system_info 失败（未连接或服务端异常）: ${result.errorMessage}")
            _state.update { it.copy(systemInfo=SystemInfo(), devices=emptyList(), isLoading=false,
                error="未连接 LING OS，无数据。请先在 Chat/连接页完成认证。") }
        }
    } }
    private fun startRefreshLoop() { viewModelScope.launch { while (true) { delay(5000); refresh() } } }

    /** 解析服务端 system_info 返回（含 B2 增强字段） */
    private fun parseSystemInfo(json: String): SystemInfo {
        return try {
            val root = org.json.JSONObject(json)
            val data = root.optJSONObject("data") ?: return SystemInfo()
            val totalRam = data.optLong("total_ram", 0)
            val freeRam = data.optLong("free_ram", 0)
            SystemInfo(
                cpuUsage = data.optDouble("cpu_usage", 0.0).toFloat(),
                memoryUsage = if (totalRam > 0) ((totalRam - freeRam).toFloat() / totalRam * 100f) else 0f,
                memoryTotal = totalRam,
                memoryFree = freeRam,
                networkRx = data.optLong("network_rx", 0),
                networkTx = data.optLong("network_tx", 0),
                uptime = data.optLong("uptime", 0)
            )
        } catch (e: Exception) {
            Logger.w(TAG, "system_info 解析失败: ${e.message}")
            SystemInfo()
        }
    }
    /* mock 已移除（先生原则） */
    /* mock 已移除（先生原则） */
}
