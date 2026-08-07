package com.lingos.app.ui.chat.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lingos.app.ui.chat.ChatMessage
import com.lingos.app.ui.chat.MessageSender
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun MessageBubble(message: ChatMessage, modifier: Modifier = Modifier) {
    val isUser = message.sender == MessageSender.USER; val isSystem = message.sender == MessageSender.SYSTEM
    Row(modifier = modifier.fillMaxWidth(), horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start) {
        Surface(shape = RoundedCornerShape(topStart = if (isUser) 16.dp else 4.dp, topEnd = if (isUser) 4.dp else 16.dp, bottomStart = 16.dp, bottomEnd = 16.dp), color = when { isSystem -> LINGOSColors.Surface; isUser -> LINGOSColors.AccentRed.copy(alpha=0.2f); else -> LINGOSColors.Surface.copy(alpha=0.6f) }, modifier = Modifier.widthIn(max=300.dp).padding(horizontal=4.dp)) {
            Column(modifier = Modifier.padding(horizontal=16.dp, vertical=12.dp)) {
                if (!isUser) { Text(text = when (message.sender) { MessageSender.NOOK -> "Nook"; MessageSender.SYSTEM -> "⚙ 系统"; else -> "" }, style = LINGOSTypography.labelSmall, color = if (message.isHighlight) LINGOSColors.AccentRed else LINGOSColors.TextSecondary, fontWeight = if (message.isHighlight) FontWeight.Bold else FontWeight.Normal, modifier = Modifier.padding(bottom=4.dp)) }
                Text(text=message.content, style=LINGOSTypography.bodyMedium, color = when { message.isHighlight -> LINGOSColors.AccentRed; isUser -> Color.White; else -> Color.White }, fontWeight = if (message.isHighlight) FontWeight.Bold else FontWeight.Normal)
                Text(text=java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(message.timestamp), style=LINGOSTypography.labelSmall, color=LINGOSColors.TextHint.copy(alpha=0.5f), modifier=Modifier.align(Alignment.End).padding(top=4.dp))
            }
        }
    }
}
