package com.lingos.app.ui.alert

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
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

/** 【B7】预警中心 - 预警列表（分级颜色）+ 处置入口 */
data class AlertItem(
    val id: String,
    val title: String,
    val level: AlertLevel,
    val time: String,
    val message: String = ""
)

enum class AlertLevel { CRITICAL, IMPORTANT, NORMAL }

@HiltViewModel
class AlertCenterViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "AlertVM" }
    private val _alerts = MutableStateFlow<List<AlertItem>>(emptyList())
    val alerts: StateFlow<List<AlertItem>> = _alerts.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            _loading.value = true
            val result = connectionManager.sendCommandAndAwait("alert_query", emptyMap(), 6000L)
            if (result.isSuccess) {
                _alerts.value = parseAlerts(result.data ?: "")
            } else {
                Logger.w(TAG, "预警查询失败（未连接/服务端未实现）: ${result.errorMessage}")
                _alerts.value = emptyList()
            }
            _loading.value = false
        }
    }

    private fun parseAlerts(json: String): List<AlertItem> {
        return try {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                val level = when (o.optString("level", "normal").lowercase()) {
                    "critical", "紧急" -> AlertLevel.CRITICAL
                    "important", "重要" -> AlertLevel.IMPORTANT
                    else -> AlertLevel.NORMAL
                }
                AlertItem(
                    id = o.optString("id", "a$i"),
                    title = o.optString("title", o.optString("name", "预警")),
                    level = level,
                    time = o.optString("time", "--:--"),
                    message = o.optString("message", "")
                )
            }
        } catch (e: Exception) {
            // 非数组或解析失败 → 空
            emptyList()
        }
    }
}

@Composable
fun AlertCenterScreen(viewModel: AlertCenterViewModel = hiltViewModel()) {
    val alerts by viewModel.alerts.collectAsStateWithLifecycle()
    val loading by viewModel.loading.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background).padding(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(text = "预警中心", style = LINGOSTypography.headlineSmall, color = Color.White, modifier = Modifier.weight(1f))
            TextButton(onClick = viewModel::refresh) {
                Text(text = "刷新", color = LINGOSColors.AccentRed)
            }
        }

        if (loading && alerts.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = LINGOSColors.AccentRed)
            }
        } else if (alerts.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    text = "暂无预警\n（系统健康/安全/环境预警将在此显示）",
                    style = LINGOSTypography.bodyLarge,
                    color = LINGOSColors.TextSecondary
                )
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(alerts) { alert ->
                    AlertCard(alert)
                }
            }
        }
    }
}

@Composable
private fun AlertCard(alert: AlertItem) {
    val levelColor = when (alert.level) {
        AlertLevel.CRITICAL -> LINGOSColors.Disconnected
        AlertLevel.IMPORTANT -> LINGOSColors.Warning
        AlertLevel.NORMAL -> LINGOSColors.AccentCyan
    }
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)),
        color = LINGOSColors.Surface
    ) {
        Row(modifier = Modifier.padding(12.dp)) {
            Box(
                modifier = Modifier.width(4.dp).height(48.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(levelColor)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = alert.title,
                    style = LINGOSTypography.bodyMedium,
                    color = Color.White
                )
                if (alert.message.isNotBlank()) {
                    Text(
                        text = alert.message,
                        style = LINGOSTypography.labelSmall,
                        color = LINGOSColors.TextSecondary
                    )
                }
                Text(
                    text = alert.time,
                    style = LINGOSTypography.labelSmall,
                    color = LINGOSColors.TextHint
                )
            }
        }
    }
}
