package com.lingos.app.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Scan
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.R
import com.lingos.app.ui.dashboard.components.DeviceList
import com.lingos.app.ui.dashboard.components.ResourceCard
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun DashboardScreen(viewModel: DashboardViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle(); val sysInfo = state.systemInfo
    LazyColumn(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background).padding(horizontal=16.dp, vertical=12.dp)) {
        item { Text(text=stringResource(R.string.dashboard_title), style=LINGOSTypography.headlineSmall, color=Color.White, modifier=Modifier.padding(bottom=16.dp)) }
        item { Row(modifier=Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(8.dp)) { ResourceCard(title=stringResource(R.string.dashboard_cpu), value="${sysInfo.cpuUsage.toInt()}%", icon="⚡", color=if (sysInfo.cpuUsage > 70) LINGOSColors.Disconnected else LINGOSColors.Success, modifier=Modifier.weight(1f)); ResourceCard(title=stringResource(R.string.dashboard_memory), value="${sysInfo.memoryUsage.toInt()}%", icon="🧠", color=if (sysInfo.memoryUsage > 80) LINGOSColors.Disconnected else LINGOSColors.Success, modifier=Modifier.weight(1f)) }; Spacer(modifier=Modifier.height(8.dp)) }
        item { Row(modifier=Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(8.dp)) { ResourceCard(title=stringResource(R.string.dashboard_network), value=formatBytes(sysInfo.networkRx) + " ↓", icon="📥", color=LINGOSColors.AccentCyan, modifier=Modifier.weight(1f)); ResourceCard(title="Uptime", value=formatUptime(sysInfo.uptime), icon="⏱", color=LINGOSColors.TextSecondary, modifier=Modifier.weight(1f)) }; Spacer(modifier=Modifier.height(16.dp)) }
        item { QuickActionBar(onScan=viewModel::scanDevices, onMqtt=viewModel::startMqtt, onRefresh=viewModel::refresh); Spacer(modifier=Modifier.height(16.dp)) }
        item { Text(text=stringResource(R.string.dashboard_devices), style=LINGOSTypography.titleMedium, color=Color.White, modifier=Modifier.padding(bottom=8.dp)) }
        items(state.devices) { device -> DeviceList(devices=listOf(device), onDeviceToggle=viewModel::toggleDevice); Spacer(modifier=Modifier.height(4.dp)) }
    }
}

@Composable
private fun QuickActionBar(onScan: () -> Unit, onMqtt: () -> Unit, onRefresh: () -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth(), shape=RoundedCornerShape(8.dp), color=LINGOSColors.Surface) {
        Row(modifier=Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            ActionButton(icon=Icons.Default.Scan, label=stringResource(R.string.dashboard_scan), onClick=onScan)
            ActionButton(icon=Icons.Default.Settings, label=stringResource(R.string.dashboard_mqtt), onClick=onMqtt)
            ActionButton(icon=Icons.Default.Refresh, label="Refresh", onClick=onRefresh)
        }
    }
}

@Composable
private fun ActionButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    Column(horizontalAlignment=Alignment.CenterHorizontally, modifier=Modifier.weight(1f)) {
        IconButton(onClick=onClick, modifier=Modifier.size(40.dp).clip(RoundedCornerShape(8.dp)).background(LINGOSColors.Background)) { Icon(imageVector=icon, contentDescription=label, tint=LINGOSColors.AccentRed, modifier=Modifier.size(20.dp)) }
        Text(text=label, style=LINGOSTypography.labelSmall, color=LINGOSColors.TextSecondary)
    }
}

private fun formatBytes(bytes: Long): String = when { bytes < 1024 -> "$bytes B"; bytes < 1048576 -> "${bytes / 1024} KB"; bytes < 1073741824 -> "${bytes / (1024 * 1024)} MB"; else -> "${bytes / (1024 * 1024 * 1024)} GB" }
private fun formatUptime(seconds: Long): String { val days = seconds / 86400; val hours = (seconds % 86400) / 3600; val minutes = (seconds % 3600) / 60; return when { days > 0 -> "${days}d ${hours}h"; hours > 0 -> "${hours}h ${minutes}m"; else -> "${minutes}m" } }
