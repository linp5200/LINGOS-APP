package com.lingos.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lingos.app.BuildConfig
import com.lingos.app.network.ConnectionManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

/** 【B14】设置页：连接信息 / 安全（白名单·审计入口）/ 版本 */
@HiltViewModel
class SettingsViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    private val _host = MutableStateFlow<String?>(null)
    val host: StateFlow<String?> = _host.asStateFlow()
    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    init {
        viewModelScope.launch {
            _host.value = connectionManager.getHost()
            connectionManager.connectionState.collect { st ->
                _connected.value = st == ConnectionManager.ConnectionState.Connected
            }
        }
    }

    fun disconnect() { connectionManager.disconnect() }
}

@Composable
fun SettingsScreen(viewModel: SettingsViewModel = hiltViewModel()) {
    val host by viewModel.host.collectAsStateWithLifecycle()
    val connected by viewModel.connected.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background).padding(16.dp)) {
        Text(text = "设置", style = LINGOSTypography.headlineSmall, color = Color.White, modifier = Modifier.padding(bottom = 16.dp))

        // 连接信息
        SettingCard {
            SettingRow("连接状态", if (connected) "已连接" else "离线")
            SettingRow("主机地址", host ?: "未连接")
            SettingRow("端口", "2937 / 2939")
            TextButton(onClick = viewModel::disconnect, modifier = Modifier.fillMaxWidth()) {
                Text(text = "断开连接", color = LINGOSColors.Disconnected)
            }
        }
        Spacer(modifier = Modifier.height(12.dp))

        // 安全
        Text(text = "安全", style = LINGOSTypography.titleMedium, color = Color.White, modifier = Modifier.padding(bottom = 8.dp))
        SettingCard {
            SettingRow("设备白名单", "启用（防陌生设备）")
            SettingRow("权限级别", "命令 / 技能 / 资源")
            SettingRow("审计日志", "命令 / 登录 / 权限 / 预警")
            Text(
                text = "审计与权限详情将在 B14 服务端批次完成后可用",
                style = LINGOSTypography.labelSmall,
                color = LINGOSColors.TextHint,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
        Spacer(modifier = Modifier.height(12.dp))

        // 生态与部署
        Text(text = "生态", style = LINGOSTypography.titleMedium, color = Color.White, modifier = Modifier.padding(bottom = 8.dp))
        SettingCard {
            SettingRow("技能市场", "B16（官方仓库 + GitHub 拉取 + 沙箱）")
            SettingRow("MCP 协议", "B16（服务器优先）")
            SettingRow("桌面端", "B16（Web 壳，三平台 CI）")
            SettingRow("远程访问", "B17（Tailscale/ZeroTier）")
            SettingRow("备份恢复", "B17（每周 × 4 周，App 操作）")
        }
        Spacer(modifier = Modifier.height(12.dp))

        // 关于
        Text(text = "关于", style = LINGOSTypography.titleMedium, color = Color.White, modifier = Modifier.padding(bottom = 8.dp))
        SettingCard {
            SettingRow("版本", BuildConfig.VERSION_NAME + " (${BuildConfig.VERSION_CODE})")
            SettingRow("协议", "TLV 2937 + WS 2939 + UDP 发现")
            TextButton(onClick = { /* B17: 检查 GitHub Release 更新 */ }, modifier = Modifier.fillMaxWidth()) {
                Text(text = "检查更新（B17）", color = LINGOSColors.AccentCyan)
            }
        }
    }
}

@Composable
private fun SettingCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)), color = LINGOSColors.Surface) {
        Column(modifier = Modifier.padding(14.dp), content = content)
    }
}

@Composable
private fun SettingRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Text(text = label, style = LINGOSTypography.bodyMedium, color = LINGOSColors.TextSecondary, modifier = Modifier.weight(1f))
        Text(text = value, style = LINGOSTypography.bodyMedium, color = Color.White)
    }
}
