package com.lingos.app.ui.splash

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.offset
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.R
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.SplashTypography
import kotlinx.coroutines.delay

@Composable
fun SplashScreen(viewModel: SplashViewModel = hiltViewModel(), onComplete: () -> Unit, onConnectFailed: () -> Unit) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val connectionStatus by viewModel.connectionStatus.collectAsStateWithLifecycle()
    LaunchedEffect(state) {
        if (state is SplashState.Complete) {
            if (connectionStatus == ConnectionStatus.Connected) { delay(300L); onComplete() }
            else if (connectionStatus == ConnectionStatus.Disconnected || connectionStatus is ConnectionStatus.Error) { delay(300L); onConnectFailed() }
            else { delay(2000L); if (viewModel.shouldShowConnectScreen()) onConnectFailed() else onComplete() }
        }
    }
    Box(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background), contentAlignment = Alignment.Center) {
        when (state) {
            is SplashState.Welcome -> WelcomePhase(state as SplashState.Welcome)
            is SplashState.Glitch -> GlitchPhase(state as SplashState.Glitch)
            is SplashState.LingTyping -> LingTypingPhase(state as SplashState.LingTyping)
            is SplashState.Loading -> LoadingPhase(state as SplashState.Loading)
            is SplashState.Logs -> LogsPhase(state as SplashState.Logs)
            is SplashState.Complete -> CompletePhase()
            is SplashState.Error -> ErrorPhase(state as SplashState.Error)
        }
    }
}

@Composable
private fun WelcomePhase(state: SplashState.Welcome) {
    val density = LocalDensity.current; val offsetPx = with(density) { state.offsetY.dp.toPx() }
    Text(text = stringResource(R.string.splash_welcome), style = SplashTypography.Welcome, color = Color.White, modifier = Modifier.alpha(state.alpha).offset(y = with(density) { (offsetPx * state.offsetY).dp }).align(Alignment.Center))
}

@Composable
private fun GlitchPhase(state: SplashState.Glitch) {
    val configuration = LocalConfiguration.current; val density = LocalDensity.current
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(text = state.chars, style = SplashTypography.Ling.copy(fontSize=28.sp, fontWeight=FontWeight.Bold), color = state.color, modifier = Modifier.offset(y = with(density) { 60.dp }))
    }
}

@Composable
private fun LingTypingPhase(state: SplashState.LingTyping) {
    val density = LocalDensity.current
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Row(modifier = Modifier.offset(y = with(density) { 60.dp }), verticalAlignment = Alignment.CenterVertically) {
            Text(text = state.text, style = SplashTypography.Ling, color = Color.White)
            if (state.cursorVisible) Text(text = "_", style = SplashTypography.Cursor, color = LINGOSColors.AccentRed)
            else Text(text = " ", style = SplashTypography.Cursor, color = Color.Transparent)
        }
    }
}

@Composable
private fun LoadingPhase(state: SplashState.Loading) {
    val configuration = LocalConfiguration.current; val density = LocalDensity.current
    val radius = 60f; val dotRadius = 8f; val dotCount = 6
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(200.dp).offset(y = with(density) { 20.dp })) {
            val canvasCenter = Offset(size.width / 2, size.height / 2)
            for (i in 0 until dotCount) {
                val angle = (i / dotCount.toFloat()) * 2 * Math.PI.toFloat()
                val x = canvasCenter.x + radius * kotlin.math.cos(angle); val y = canvasCenter.y + radius * kotlin.math.sin(angle)
                val alpha = state.dotAlphas.getOrElse(i) { 0f }
                drawCircle(color = Color.White.copy(alpha = alpha), radius = dotRadius, center = Offset(x, y))
            }
        }
        Text(text = state.text, style = SplashTypography.Loading, color = Color.White.copy(alpha = 0.8f), modifier = Modifier.offset(y = with(density) { 60.dp }))
    }
}

@Composable
private fun LogsPhase(state: SplashState.Logs) {
    val density = LocalDensity.current; val bottomPadding = 40f
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
        Box(modifier = Modifier.fillMaxWidth().height(120.dp).padding(bottom = with(density) { bottomPadding.dp }).background(LINGOSColors.StatusBarBackground).padding(horizontal=20.dp, vertical=16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxSize()) {
                state.logs.forEach { log ->
                    Row {
                        Text(text = log.timestamp, style = SplashTypography.Log, color = LINGOSColors.TextHint, modifier = Modifier.padding(end=8.dp))
                        Text(text = log.text, style = SplashTypography.Log, color = if (log.isHighlight) LINGOSColors.AccentRed else LINGOSColors.TextSecondary, fontWeight = if (log.isHighlight) FontWeight.Bold else FontWeight.Normal)
                    }
                }
                if (state.logs.size < 3 && state.logs.isNotEmpty()) { Box(modifier = Modifier.size(8.dp, 2.dp).background(LINGOSColors.AccentRed)) }
            }
        }
    }
}

@Composable
private fun CompletePhase() { Box(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background)) }
@Composable
private fun ErrorPhase(state: SplashState.Error) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text(text="Error: ${state.message}", style=SplashTypography.Loading, color=LINGOSColors.AccentRed) } }
