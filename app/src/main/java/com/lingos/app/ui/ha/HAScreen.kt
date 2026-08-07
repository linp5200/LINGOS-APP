package com.lingos.app.ui.ha

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Power
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.network.ConnectionManager
import com.lingos.app.utils.Logger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

/** 【B13】HA 智能联动 - 设备卡片 + 场景模板 */
data class HaDevice(
    val id: String,
    val name: String,
    val type: String,
    val state: Boolean = false
)

@HiltViewModel
class HAViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "HAVM" }
    private val _devices = MutableStateFlow<List<HaDevice>>(emptyList())
    val devices: StateFlow<List<HaDevice>> = _devices.asStateFlow()
    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    init { loadDevices() }

    fun loadDevices() {
        viewModelScope.launch {
            // 双模式：后端中转（ha_search）优先，失败显示引导配置直连
            val result = connectionManager.sendCommandAndAwait("ha_search", emptyMap(), 6000L)
            if (result.isSuccess) {
                _devices.value = parseDevices(result.data ?: "")
                _connected.value = true
            } else {
                Logger.w(TAG, "HA 查询失败（需配置 HA 数据源）: ${result.errorMessage}")
                _devices.value = emptyList()
                _connected.value = false
            }
        }
    }

    fun toggle(device: HaDevice) {
        viewModelScope.launch {
            connectionManager.sendCommandAndAwait("ha_write", mapOf(
                "entity" to device.id,
                "action" to (if (device.state) "off" else "on")
            ), 6000L)
            _devices.value = _devices.value.map {
                if (it.id == device.id) it.copy(state = !it.state) else it
            }
        }
    }

    fun applyScene(scene: String) {
        viewModelScope.launch {
            Logger.i(TAG, "场景 $scene")
            connectionManager.sendCommandAndAwait("ha_write", mapOf(
                "scene" to scene,
                "action" to "apply"
            ), 6000L)
        }
    }

    private fun parseDevices(json: String): List<HaDevice> {
        return try {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                HaDevice(
                    id = o.optString("entity_id", o.optString("id", "d$i")),
                    name = o.optString("name", o.optString("entity_id", "设备 $i")),
                    type = o.optString("type", o.optString("domain", "switch")),
                    state = o.optString("state", "off") == "on"
                )
            }
        } catch (e: Exception) { emptyList() }
    }
}

@Composable
fun HAScreen(viewModel: HAViewModel = hiltViewModel()) {
    val devices by viewModel.devices.collectAsStateWithLifecycle()
    val connected by viewModel.connected.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background).padding(16.dp)) {
        Text(text = "HA 智能联动", style = LINGOSTypography.headlineSmall, color = Color.White)
        Text(
            text = if (connected) "已连接 HA 数据源" else "未连接（请配置 HA 数据源：后端中转或直连）",
            style = LINGOSTypography.labelMedium,
            color = if (connected) LINGOSColors.Success else LINGOSColors.Warning,
            modifier = Modifier.padding(top = 4.dp, bottom = 12.dp)
        )

        // 场景模板
        Text(text = "场景", style = LINGOSTypography.titleMedium, color = Color.White, modifier = Modifier.padding(bottom = 8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            item { SceneButton("回家", LINGOSColors.Success) { viewModel.applyScene("home") } }
            item { SceneButton("离家", LINGOSColors.Warning) { viewModel.applyScene("away") } }
            item { SceneButton("睡眠", LINGOSColors.AccentCyan) { viewModel.applyScene("sleep") } }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 设备卡片
        Text(text = "设备", style = LINGOSTypography.titleMedium, color = Color.White, modifier = Modifier.padding(bottom = 8.dp))
        if (devices.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "暂无设备\n（接入 HA 后设备将显示于此）", style = LINGOSTypography.bodyLarge, color = LINGOSColors.TextSecondary)
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(devices) { device ->
                    Surface(
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)),
                        color = if (device.state) LINGOSColors.Success.copy(alpha = 0.15f) else LINGOSColors.Surface,
                        onClick = { viewModel.toggle(device) }
                    ) {
                        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(imageVector = when (device.type) { "light" -> Icons.Default.Lightbulb; "switch" -> Icons.Default.Power; "climate" -> Icons.Default.Thermostat; else -> Icons.Default.PhoneAndroid }, contentDescription = device.type, tint = LINGOSColors.AccentCyan, modifier = Modifier.size(24.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = device.name, style = LINGOSTypography.bodyMedium, color = Color.White)
                                Text(text = device.type, style = LINGOSTypography.labelSmall, color = LINGOSColors.TextHint)
                            }
                            Text(
                                text = if (device.state) "开" else "关",
                                style = LINGOSTypography.titleMedium,
                                color = if (device.state) LINGOSColors.Success else LINGOSColors.TextHint
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SceneButton(label: String, color: Color, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(10.dp),
        color = color.copy(alpha = 0.15f),
        onClick = onClick
    ) {
        Text(text = label, style = LINGOSTypography.bodyMedium, color = color, modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp))
    }
}
