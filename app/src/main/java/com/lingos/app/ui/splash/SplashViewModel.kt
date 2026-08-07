package com.lingos.app.ui.splash

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.R
import com.lingos.app.network.ConnectionManager
import com.lingos.app.utils.Logger
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject
import kotlin.math.cos

@HiltViewModel
class SplashViewModel @Inject constructor(@ApplicationContext private val context: Context, private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "SplashVM"; private val GLITCH_CHARS = listOf('#','%','@','*','!','&','?','+'); private const val DOT_COUNT = 6 }
    private val _state = MutableStateFlow<SplashState>(SplashState.Welcome())
    val state: StateFlow<SplashState> = _state.asStateFlow()
    private val _isConnecting = MutableStateFlow(false)
    val isConnecting: StateFlow<Boolean> = _isConnecting.asStateFlow()
    private val _connectionStatus = MutableStateFlow<ConnectionStatus?>(null)
    val connectionStatus: StateFlow<ConnectionStatus?> = _connectionStatus.asStateFlow()
    private fun getString(id: Int): String = context.getString(id)
    private fun isZh(): Boolean = context.resources.configuration.locales[0].language == "zh"
    private fun getWelcomeText(): String = getString(R.string.splash_welcome)
    private fun getLoadingText(): String = getString(R.string.splash_loading)
    private fun getLog1(): String = getString(R.string.splash_log_1)
    private fun getLog2(): String = getString(R.string.splash_log_2)
    private fun getLog3(): String = getString(R.string.splash_log_3)

    fun startAnimation() { viewModelScope.launch { runWelcomePhase(); runGlitchAndLingPhase(); runLoadingPhase(); runLogsPhase(); _state.value = SplashState.Complete; Logger.d(TAG, "Splash animation complete") } }
    fun attemptAutoConnect() { if (_isConnecting.value) return; _isConnecting.value = true; viewModelScope.launch { try { _connectionStatus.value = ConnectionStatus.Connecting; val result = connectionManager.connect(host="127.0.0.1", port=2937, timeout=3000L); if (result.isSuccess) { _connectionStatus.value = ConnectionStatus.Connected; Logger.d(TAG, "Auto-connect success") } else { val backupResult = connectionManager.connect(host="127.0.0.1", port=2938, timeout=2000L); if (backupResult.isSuccess) { _connectionStatus.value = ConnectionStatus.Connected; Logger.d(TAG, "Auto-connect via backup port success") } else { _connectionStatus.value = ConnectionStatus.Disconnected; Logger.w(TAG, "Auto-connect failed") } }; _isConnecting.value = false } catch (e: Exception) { Logger.e(TAG, "Auto-connect error", e); _connectionStatus.value = ConnectionStatus.Error(e.message ?: "Unknown error"); _isConnecting.value = false } } }
    fun shouldShowConnectScreen(): Boolean = _connectionStatus.value == ConnectionStatus.Disconnected || _connectionStatus.value is ConnectionStatus.Error
    fun resetConnection() { _connectionStatus.value = null; _isConnecting.value = false }

    private suspend fun runWelcomePhase() {
        for (i in 0..50) { val alpha = i / 50f; _state.value = SplashState.Welcome(alpha=alpha, offsetY=0f); delay(10L) }
        delay(500L)
        for (i in 0..50) { val progress = i / 50f; _state.value = SplashState.Welcome(alpha=1f-progress, offsetY=progress*100f); delay(10L) }
        _state.value = SplashState.Welcome(alpha=0f, offsetY=100f)
    }
    private suspend fun runGlitchAndLingPhase() {
        val startTime = System.currentTimeMillis(); var glitchText = ""
        while (System.currentTimeMillis() - startTime < 600L) { glitchText = generateGlitchText(); val color = if (System.currentTimeMillis() % 100 < 50) Color.White else LINGOSColors.AccentRed; _state.value = SplashState.Glitch(chars=glitchText, color=color); delay(50L) }
        _state.value = SplashState.Glitch(chars=glitchText, color=Color.White); delay(100L)
        val lingText = "Ling"; for (i in 1..lingText.length) { _state.value = SplashState.LingTyping(text=lingText.substring(0,i), cursorVisible=true); delay(100L) }
        var cursorVisible = true; for (i in 0..5) { cursorVisible = !cursorVisible; _state.value = SplashState.LingTyping(text=lingText, cursorVisible=cursorVisible); delay(200L) }
        _state.value = SplashState.LingTyping(text="Ling", cursorVisible=true)
    }
    private suspend fun runLoadingPhase() {
        val totalDuration = 2000L; val startTime = System.currentTimeMillis()
        while (System.currentTimeMillis() - startTime < totalDuration) {
            val elapsed = System.currentTimeMillis() - startTime; val progress = elapsed / totalDuration.toFloat()
            val dotAlphas = calculateDotAlphas(progress); val text = getLoadingText()
            _state.value = SplashState.Loading(dotAlphas=dotAlphas, progress=progress, text=text); delay(16L)
        }
        _state.value = SplashState.Loading(dotAlphas=listOf(0f,0f,0f,0f,0f,0f), progress=1f, text=getLoadingText())
    }
    private suspend fun runLogsPhase() {
        val logs = listOf(LogEntry(text=getLog1(), isHighlight=false), LogEntry(text=getLog2(), isHighlight=false), LogEntry(text=getLog3(), isHighlight=true))
        val displayedLogs = mutableListOf<LogEntry>()
        for (i in logs.indices) { displayedLogs.add(logs[i]); _state.value = SplashState.Logs(logs=displayedLogs.toList(), currentLine=i); delay(800L); if (i == logs.size - 1) { delay(500L); attemptAutoConnect() } }
        var waitCount = 0
        while (waitCount < 30) { delay(100L); waitCount++; val status = _connectionStatus.value; if (status == ConnectionStatus.Connected) { _state.value = SplashState.Complete; return } }
        _state.value = SplashState.Complete
    }
    private fun generateGlitchText(): String { val length = (3..8).random(); return (1..length).map { GLITCH_CHARS.random() }.joinToString("") }
    private fun calculateDotAlphas(progress: Float): List<Float> { return (0 until DOT_COUNT).map { i -> val phase = (progress * DOT_COUNT - i).mod(1f); val value = (cos(phase * 2 * Math.PI) + 1) / 2; value.toFloat().coerceIn(0f,1f) } }
}

sealed class ConnectionStatus { object Connecting : ConnectionStatus(); object Connected : ConnectionStatus(); object Disconnected : ConnectionStatus(); data class Error(val message: String) : ConnectionStatus() }
