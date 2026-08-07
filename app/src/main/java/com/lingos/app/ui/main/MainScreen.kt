@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lingos.app.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.network.ConnectionManager
import com.lingos.app.ui.alert.AlertCenterScreen
import com.lingos.app.ui.chat.ChatScreen
import com.lingos.app.ui.dashboard.DashboardScreen
import com.lingos.app.ui.files.FileBrowserScreen
import com.lingos.app.ui.ha.HAScreen
import com.lingos.app.ui.settings.SettingsScreen
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography
import kotlinx.coroutines.launch

/** 【B6】UI 定稿：单聊天流（主界面）+ 侧滑抽屉（控制台/HA/预警/设置） */
@Composable
fun MainScreen(viewModel: MainViewModel = hiltViewModel()) {
    val connState by viewModel.connectionState.collectAsStateWithLifecycle()
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var currentPage by rememberSaveable { mutableStateOf("chat") }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet(drawerContainerColor = LINGOSColors.Background) {
                Column(modifier = Modifier.fillMaxSize()) {
                    // 抽屉头部：品牌 + 连接状态
                    Column(modifier = Modifier.fillMaxWidth().padding(20.dp, 24.dp)) {
                        Text(text = "LING OS", style = LINGOSTypography.titleLarge, color = Color.White)
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                            Box(modifier = Modifier.size(8.dp).clip(CircleShape)
                                .background(if (connState == ConnectionManager.ConnectionState.Connected) LINGOSColors.Success else LINGOSColors.Disconnected))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = when (connState) {
                                    ConnectionManager.ConnectionState.Connected -> "已连接"
                                    ConnectionManager.ConnectionState.Connecting -> "连接中..."
                                    is ConnectionManager.ConnectionState.Error -> "连接异常"
                                    else -> "离线"
                                },
                                style = LINGOSTypography.labelMedium,
                                color = LINGOSColors.TextSecondary
                            )
                        }
                    }
                    HorizontalDivider(color = LINGOSColors.TextHint.copy(alpha = 0.2f))
                    DrawerItem("Chat", Icons.Default.Chat, currentPage == "chat") {
                        currentPage = "chat"; scope.launch { drawerState.close() }
                    }
                    DrawerItem("控制台", Icons.Default.Dashboard, currentPage == "dash") {
                        currentPage = "dash"; scope.launch { drawerState.close() }
                    }
                    DrawerItem("HA 智能联动", Icons.Default.Home, currentPage == "ha") {
                        currentPage = "ha"; scope.launch { drawerState.close() }
                    }
                    DrawerItem("预警中心", Icons.Default.Warning, currentPage == "alert") {
                        currentPage = "alert"; scope.launch { drawerState.close() }
                    }
                    DrawerItem("文件管理", Icons.Default.Folder, currentPage == "files") {
                        currentPage = "files"; scope.launch { drawerState.close() }
                    }
                    DrawerItem("设置", Icons.Default.Settings, currentPage == "settings") {
                        currentPage = "settings"; scope.launch { drawerState.close() }
                    }
                }
            }
        }
    ) {
        Scaffold(
            topBar = {
                MainTopBar(
                    connState = connState,
                    onMenuClick = { scope.launch { drawerState.open() } }
                )
            },
            containerColor = LINGOSColors.Background
        ) { paddingValues ->
            Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) {
                when (currentPage) {
                    "chat" -> ChatScreen()
                    "dash" -> DashboardScreen()
                    "ha" -> HAScreen()
                    "alert" -> AlertCenterScreen()
                    "files" -> FileBrowserScreen()
                    else -> SettingsScreen()
                }
            }
        }
    }
}

@Composable
private fun DrawerItem(label: String, icon: ImageVector, selected: Boolean, onClick: () -> Unit) {
    NavigationDrawerItem(
        label = { Text(text = label, style = LINGOSTypography.bodyMedium) },
        icon = { Icon(imageVector = icon, contentDescription = label) },
        selected = selected,
        onClick = onClick,
        colors = NavigationDrawerItemDefaults.colors(
            selectedContainerColor = LINGOSColors.AccentRed.copy(alpha = 0.15f),
            selectedIconColor = LINGOSColors.AccentRed,
            selectedTextColor = LINGOSColors.AccentRed,
            unselectedIconColor = LINGOSColors.TextSecondary,
            unselectedTextColor = LINGOSColors.TextSecondary
        ),
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 2.dp)
    )
}

@Composable
private fun PlaceholderPage(text: String) {
    Box(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background), contentAlignment = Alignment.Center) {
        Text(text = text, style = LINGOSTypography.bodyLarge, color = LINGOSColors.TextSecondary)
    }
}

@Composable
private fun MainTopBar(connState: ConnectionManager.ConnectionState, onMenuClick: () -> Unit) {
    TopAppBar(
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape)
                    .background(if (connState == ConnectionManager.ConnectionState.Connected) LINGOSColors.Success else LINGOSColors.Disconnected))
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "LING OS", style = LINGOSTypography.titleMedium, color = Color.White)
            }
        },
        navigationIcon = {
            IconButton(onClick = onMenuClick) {
                Icon(Icons.Default.Menu, contentDescription = "Menu", tint = Color.White)
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = LINGOSColors.Background,
            scrolledContainerColor = LINGOSColors.Background
        )
    )
}
