package com.lingos.app.ui.splash

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color

sealed class SplashState {
    data class Welcome(val alpha: Float = 0f, val offsetY: Float = 0f) : SplashState()
    data class Glitch(val chars: String = "", val color: Color = Color.White) : SplashState()
    data class LingTyping(val text: String = "", val cursorVisible: Boolean = true) : SplashState()
    data class Loading(val dotAlphas: List<Float> = listOf(0f,0f,0f,0f,0f,0f), val progress: Float = 0f, val text: String = "LING OS is loading...") : SplashState()
    data class Logs(val logs: List<LogEntry> = emptyList(), val currentLine: Int = 0) : SplashState()
    object Complete : SplashState()
    data class Error(val message: String) : SplashState()
}

data class LogEntry(val text: String, val isHighlight: Boolean = false, val timestamp: String = "")
sealed class SplashEvent { object AnimationComplete : SplashEvent(); object AutoConnectSuccess : SplashEvent(); object AutoConnectFailed : SplashEvent(); object OnTimeout : SplashEvent() }
