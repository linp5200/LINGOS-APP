package com.lingos.app.ui.dashboard.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun ResourceCard(title: String, value: String, icon: String, color: Color = LINGOSColors.Success, modifier: Modifier = Modifier) {
    Surface(modifier = modifier.height(80.dp).clip(RoundedCornerShape(8.dp)), color = LINGOSColors.Surface) {
        Row(modifier=Modifier.fillMaxSize().padding(12.dp), verticalAlignment=Alignment.CenterVertically) {
            Box(modifier=Modifier.size(36.dp).clip(RoundedCornerShape(8.dp)).background(LINGOSColors.Background), contentAlignment=Alignment.Center) { Text(text=icon, style=LINGOSTypography.titleMedium) }
            Spacer(modifier=Modifier.width(12.dp))
            Column { Text(text=title, style=LINGOSTypography.labelSmall, color=LINGOSColors.TextSecondary); Text(text=value, style=LINGOSTypography.titleMedium, color=color, fontWeight=androidx.compose.ui.text.font.FontWeight.Bold) }
        }
    }
}
