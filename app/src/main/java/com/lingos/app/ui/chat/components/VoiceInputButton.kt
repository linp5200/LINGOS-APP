package com.lingos.app.ui.chat.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lingos.app.ui.theme.LINGOSColors

@Composable
fun VoiceInputButton(isRecording: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier = modifier.size(48.dp).clip(CircleShape).background(if (isRecording) LINGOSColors.AccentRed.copy(alpha=0.3f) else LINGOSColors.Surface).clickable { onClick() }, contentAlignment = Alignment.Center) {
        Icon(imageVector = if (isRecording) Icons.Default.MicOff else Icons.Default.Mic, contentDescription = if (isRecording) "Stop recording" else "Voice input", tint = if (isRecording) LINGOSColors.AccentRed else Color.White, modifier = Modifier.size(24.dp))
    }
}
