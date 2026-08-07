@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lingos.app.ui.device

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.data.model.DeviceStatus
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun DeviceDetailScreen(deviceId: String, viewModel: DeviceDetailViewModel = hiltViewModel(), onBack: () -> Unit) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(deviceId) { viewModel.loadDevice(deviceId) }
    Scaffold(topBar = { TopAppBar(title={ Text("设备详情", style=LINGOSTypography.titleMedium, color=Color.White) }, navigationIcon={ IconButton(onClick=onBack) { Icon(Icons.Default.ArrowBack, contentDescription="返回", tint=Color.White) } }, actions={ IconButton(onClick=viewModel::refresh) { Icon(Icons.Default.Refresh, contentDescription="刷新", tint=Color.White) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor=LINGOSColors.Background, scrolledContainerColor=LINGOSColors.Background)) }, containerColor = LINGOSColors.Background) { paddingValues ->
        when (state) {
            is DeviceDetailState.Loading -> Box(modifier=Modifier.fillMaxSize().padding(paddingValues), contentAlignment=Alignment.Center) { CircularProgressIndicator(color=LINGOSColors.AccentRed) }
            is DeviceDetailState.Loaded -> DeviceDetailContent(state=state, onControl=viewModel::sendControlEvent, modifier=Modifier.padding(paddingValues))
            is DeviceDetailState.Error -> Box(modifier=Modifier.fillMaxSize().padding(paddingValues), contentAlignment=Alignment.Center) { Column(horizontalAlignment=Alignment.CenterHorizontally) { Text(text="⚠️ ${state.message}", style=LINGOSTypography.bodyLarge, color=LINGOSColors.Disconnected); Spacer(modifier=Modifier.height(16.dp)); Button(onClick=viewModel::refresh, colors=ButtonDefaults.buttonColors(containerColor=LINGOSColors.AccentRed)) { Text("重试") } } }
        }
    }
}

@Composable
private fun DeviceDetailContent(state: DeviceDetailState.Loaded, onControl: (DeviceControlEvent) -> Unit, modifier: Modifier = Modifier) {
    val device = state.device
    LazyColumn(modifier = modifier.fillMaxSize().padding(horizontal=16.dp, vertical=12.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item { DeviceHeader(device=device, onControl=onControl) }
        if (device.properties.isNotEmpty()) { item { Text("属性", style=LINGOSTypography.titleSmall, color=Color.White, modifier=Modifier.padding(bottom=8.dp)) }; item { DeviceProperties(properties=device.properties) } }
        item { Text("控制", style=LINGOSTypography.titleSmall, color=Color.White, modifier=Modifier.padding(bottom=8.dp)) }; item { ControlPanel(device=device, onControl=onControl) }
        if (state.history.isNotEmpty()) { item { Text("历史记录", style=LINGOSTypography.titleSmall, color=Color.White, modifier=Modifier.padding(top=8.dp, bottom=8.dp)) }; items(state.history) { history -> HistoryItem(history=history) } }
    }
}

@Composable
private fun DeviceHeader(device: com.lingos.app.data.model.Device, onControl: (DeviceControlEvent) -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(12.dp), color=LINGOSColors.Surface) {
        Row(modifier=Modifier.fillMaxWidth().padding(16.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.SpaceBetween) {
            Row(verticalAlignment=Alignment.CenterVertically) {
                Box(modifier=Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)).background(LINGOSColors.Background), contentAlignment=Alignment.Center) { Text(text=device.icon, fontSize=28.sp) }; Spacer(modifier=Modifier.width(16.dp))
                Column { Text(text=device.name, style=LINGOSTypography.titleMedium, color=Color.White, fontWeight=FontWeight.Bold); Text(text=device.type, style=LINGOSTypography.bodySmall, color=LINGOSColors.TextSecondary); Row(verticalAlignment=Alignment.CenterVertically, modifier=Modifier.padding(top=4.dp)) { Box(modifier=Modifier.size(6.dp).clip(RoundedCornerShape(50)).background(if (device.status == DeviceStatus.ONLINE) LINGOSColors.Success else LINGOSColors.Disconnected)); Spacer(modifier=Modifier.width(6.dp)); Text(text=if (device.status == DeviceStatus.ONLINE) "在线" else "离线", style=LINGOSTypography.labelSmall, color=if (device.status == DeviceStatus.ONLINE) LINGOSColors.Success else LINGOSColors.TextSecondary) } }
            }
            IconButton(onClick={ onControl(DeviceControlEvent.PowerToggle) }, modifier=Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(if (device.status == DeviceStatus.ONLINE) LINGOSColors.Success.copy(alpha=0.15f) else LINGOSColors.Disconnected.copy(alpha=0.15f))) { Icon(Icons.Default.PowerSettingsNew, contentDescription="切换电源", tint=if (device.status == DeviceStatus.ONLINE) LINGOSColors.Success else LINGOSColors.TextHint) }
        }
    }
}

@Composable
private fun DeviceProperties(properties: Map<String, Any>) {
    Surface(modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(8.dp), color=LINGOSColors.Surface) {
        Column(modifier=Modifier.fillMaxWidth().padding(12.dp)) { properties.forEach { (key, value) -> Row(modifier=Modifier.fillMaxWidth().padding(vertical=4.dp), horizontalArrangement=Arrangement.SpaceBetween) { Text(text=key, style=LINGOSTypography.bodySmall, color=LINGOSColors.TextSecondary); Text(text=value.toString(), style=LINGOSTypography.bodySmall, color=Color.White) } } }
    }
}

@Composable
private fun ControlPanel(device: com.lingos.app.data.model.Device, onControl: (DeviceControlEvent) -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(8.dp), color=LINGOSColors.Surface) {
        Column(modifier=Modifier.fillMaxWidth().padding(16.dp)) {
            Row(modifier=Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                if (device.type.contains("灯") || device.type.contains("light")) {
                    OutlinedButton(onClick={ onControl(DeviceControlEvent.SetBrightness(50)) }, modifier=Modifier.weight(1f), colors=OutlinedButtonDefaults.outlinedButtonColors(contentColor=LINGOSColors.AccentRed)) { Text("50% 亮度") }
                    OutlinedButton(onClick={ onControl(DeviceControlEvent.SetBrightness(100)) }, modifier=Modifier.weight(1f), colors=OutlinedButtonDefaults.outlinedButtonColors(contentColor=LINGOSColors.AccentRed)) { Text("100% 亮度") }
                } else {
                    OutlinedButton(onClick={ onControl(DeviceControlEvent.SendCommand("reboot", emptyMap())) }, modifier=Modifier.weight(1f), colors=OutlinedButtonDefaults.outlinedButtonColors(contentColor=LINGOSColors.AccentRed)) { Text("重启") }
                    OutlinedButton(onClick={ onControl(DeviceControlEvent.SendCommand("status", emptyMap())) }, modifier=Modifier.weight(1f), colors=OutlinedButtonDefaults.outlinedButtonColors(contentColor=LINGOSColors.AccentRed)) { Text("状态") }
                }
            }
        }
    }
}

@Composable
private fun HistoryItem(history: com.lingos.app.data.model.DeviceHistory) {
    Surface(modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(6.dp), color=LINGOSColors.Surface.copy(alpha=0.5f)) {
        Row(modifier=Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement=Arrangement.SpaceBetween) {
            Text(text=history.event, style=LINGOSTypography.bodySmall, color=Color.White)
            Text(text=java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(history.timestamp), style=LINGOSTypography.labelSmall, color=LINGOSColors.TextHint)
        }
    }
}
