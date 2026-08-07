package com.lingos.app.ui.dashboard.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lingos.app.ui.dashboard.DeviceItem
import com.lingos.app.ui.dashboard.DeviceStatus
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun DeviceList(devices: List<DeviceItem>, onDeviceToggle: (String) -> Unit, modifier: Modifier = Modifier) {
    LazyColumn(modifier=modifier.fillMaxWidth(), verticalArrangement=Arrangement.spacedBy(4.dp)) {
        items(devices) { device -> DeviceItemRow(device=device, onToggle={ onDeviceToggle(device.id) }) }
    }
}

@Composable
private fun DeviceItemRow(device: DeviceItem, onToggle: () -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)), color=LINGOSColors.Surface) {
        Row(modifier=Modifier.fillMaxWidth().padding(horizontal=12.dp, vertical=10.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.SpaceBetween) {
            Row(verticalAlignment=Alignment.CenterVertically) {
                Box(modifier=Modifier.size(8.dp).clip(RoundedCornerShape(50)).background(when (device.status) { DeviceStatus.ONLINE -> LINGOSColors.Success; DeviceStatus.OFFLINE -> LINGOSColors.Disconnected; else -> LINGOSColors.Warning })); Spacer(modifier=Modifier.width(10.dp))
                Text(text=device.icon, style=LINGOSTypography.titleMedium, modifier=Modifier.padding(end=8.dp))
                Column { Text(text=device.name, style=LINGOSTypography.bodyMedium, color=Color.White); if (device.ip != null) { Text(text=device.ip, style=LINGOSTypography.labelSmall, color=LINGOSColors.TextHint) } }
            }
            Icon(imageVector=Icons.Default.PowerSettingsNew, contentDescription="Toggle device", tint=if (device.status == DeviceStatus.ONLINE) LINGOSColors.Success else LINGOSColors.TextHint, modifier=Modifier.size(20.dp).clickable { onToggle() })
        }
    }
}
