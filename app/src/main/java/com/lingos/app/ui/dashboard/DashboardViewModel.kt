package com.lingos.app.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
class DashboardViewModel @Inject constructor() : ViewModel() {
    companion object { private const val TAG = "DashboardVM" }
    private val _state = MutableStateFlow(DashboardState()); val state: StateFlow<DashboardState> = _state.asStateFlow()
    init { loadData(); startRefreshLoop() }
    fun refresh() { loadData() }
    fun toggleDevice(id: String) { viewModelScope.launch { val newState = _state.value.devices.map { device -> if (device.id == id) device.copy(status = if (device.status == DeviceStatus.ONLINE) DeviceStatus.OFFLINE else DeviceStatus.ONLINE) else device }; _state.update { it.copy(devices=newState) } } }
    fun scanDevices() { viewModelScope.launch { _state.update { it.copy(isLoading=true) }; delay(2000); val newDevices = listOf(DeviceItem(id="device_${System.currentTimeMillis()}", name="新设备 ${Random.nextInt(100,999)}", type=DeviceType.SOCKET, status=DeviceStatus.ONLINE, ip="192.168.1.${Random.nextInt(100,200)}")); _state.update { it.copy(devices=it.devices + newDevices, isLoading=false) } } }
    fun startMqtt() { Logger.d(TAG, "MQTT service starting...") }
    private fun loadData() { viewModelScope.launch { _state.update { it.copy(systemInfo=generateSystemInfo(), devices=generateDevices()) } } }
    private fun startRefreshLoop() { viewModelScope.launch { while (true) { delay(5000); _state.update { it.copy(systemInfo=generateSystemInfo()) } } } }
    private fun generateSystemInfo(): SystemInfo = SystemInfo(cpuUsage=Random.nextInt(5,60).toFloat(), memoryUsage=Random.nextInt(20,75).toFloat(), memoryTotal=16000000000, memoryFree=Random.nextLong(4000000000,12000000000), networkRx=Random.nextLong(100000,10000000), networkTx=Random.nextLong(50000,5000000), uptime=System.currentTimeMillis()/1000)
    private fun generateDevices(): List<DeviceItem> = listOf(DeviceItem(id="1", name="路由器", type=DeviceType.ROUTER, status=DeviceStatus.ONLINE, ip="192.168.1.1", icon="📶"), DeviceItem(id="2", name="智能插座-客厅", type=DeviceType.SOCKET, status=DeviceStatus.ONLINE, ip="192.168.1.102", icon="🔌"), DeviceItem(id="3", name="摄像头-门口", type=DeviceType.CAMERA, status=DeviceStatus.OFFLINE, ip="192.168.1.103", icon="📷"), DeviceItem(id="4", name="台灯", type=DeviceType.LIGHT, status=DeviceStatus.ONLINE, ip="192.168.1.104", icon="💡"), DeviceItem(id="5", name="智能音箱", type=DeviceType.SPEAKER, status=DeviceStatus.ONLINE, ip="192.168.1.105", icon="🔊"))
}
