package com.lingos.app.ui.device

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.data.model.Device
import com.lingos.app.data.model.DeviceHistory
import com.lingos.app.data.model.DeviceStatus
import com.lingos.app.data.repository.DeviceRepository
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
class DeviceDetailViewModel @Inject constructor(private val repository: DeviceRepository) : ViewModel() {
    companion object { private const val TAG = "DeviceDetailVM" }
    private val _state = MutableStateFlow<DeviceDetailState>(DeviceDetailState.Loading); val state: StateFlow<DeviceDetailState> = _state.asStateFlow()
    private var deviceId: String? = null
    fun loadDevice(deviceId: String) { this.deviceId = deviceId; viewModelScope.launch { _state.value = DeviceDetailState.Loading; try { val device = repository.getDevice(deviceId); if (device != null) { val history = repository.getDeviceHistory(deviceId, limit=24); _state.value = DeviceDetailState.Loaded(device=device, history=history); Logger.d(TAG, "Device loaded: ${device.name}") } else { _state.value = DeviceDetailState.Error("设备未找到") } } catch (e: Exception) { Logger.e(TAG, "Failed to load device", e); _state.value = DeviceDetailState.Error(e.message ?: "加载失败") } } }
    fun sendControlEvent(event: DeviceControlEvent) { val currentState = _state.value; if (currentState !is DeviceDetailState.Loaded) return; viewModelScope.launch { val updatedDevice = when (event) { is DeviceControlEvent.PowerToggle -> { val newStatus = if (currentState.device.status == DeviceStatus.ONLINE) DeviceStatus.OFFLINE else DeviceStatus.ONLINE; currentState.device.copy(status=newStatus) }; is DeviceControlEvent.SetBrightness -> currentState.device.copy(properties=currentState.device.properties.toMutableMap().apply { this["brightness"] = event.level }); is DeviceControlEvent.SetTemperature -> currentState.device.copy(properties=currentState.device.properties.toMutableMap().apply { this["temperature"] = event.value }); is DeviceControlEvent.SendCommand -> currentState.device.copy(properties=currentState.device.properties.toMutableMap().apply { this["last_command"] = event.command; this["last_command_time"] = System.currentTimeMillis() }) }; _state.update { (it as? DeviceDetailState.Loaded)?.copy(device=updatedDevice, isControlling=true) ?: it }; delay(500); val historyEntry = DeviceHistory(deviceId=currentState.device.id, timestamp=System.currentTimeMillis(), event=when (event) { is DeviceControlEvent.PowerToggle -> "电源切换"; is DeviceControlEvent.SetBrightness -> "亮度设置: ${event.level}%"; is DeviceControlEvent.SetTemperature -> "温度设置: ${event.value}°C"; is DeviceControlEvent.SendCommand -> "命令: ${event.command}" }, success=true); repository.addHistory(historyEntry); val updatedHistory = repository.getDeviceHistory(currentState.device.id, limit=24); _state.update { (it as? DeviceDetailState.Loaded)?.copy(device=updatedDevice, history=updatedHistory, isControlling=false) ?: it } } }
    fun refresh() { deviceId?.let { loadDevice(it) } }
}
