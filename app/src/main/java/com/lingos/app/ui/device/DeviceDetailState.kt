package com.lingos.app.ui.device

import com.lingos.app.data.model.Device
import com.lingos.app.data.model.DeviceHistory

sealed class DeviceDetailState { object Loading : DeviceDetailState(); data class Loaded(val device: Device, val history: List<DeviceHistory> = emptyList(), val isControlling: Boolean = false) : DeviceDetailState(); data class Error(val message: String) : DeviceDetailState() }
sealed class DeviceControlEvent { object PowerToggle : DeviceControlEvent(); data class SetBrightness(val level: Int) : DeviceControlEvent(); data class SetTemperature(val value: Int) : DeviceControlEvent(); data class SendCommand(val command: String, val params: Map<String, Any> = emptyMap()) : DeviceControlEvent() }
