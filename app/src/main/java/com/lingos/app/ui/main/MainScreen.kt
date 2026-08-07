@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lingos.app.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.R
import com.lingos.app.ui.chat.ChatScreen
import com.lingos.app.ui.dashboard.DashboardScreen
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun MainScreen(viewModel: MainViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val connState by viewModel.connectionState.collectAsStateWithLifecycle()
    Scaffold(topBar = { MainTopBar(mode=uiState.currentMode, onModeToggle=viewModel::toggleMode, onMenuClick={}) }, bottomBar = { MainBottomBar(currentTab=uiState.currentTab, onTabSelected=viewModel::selectTab) }, containerColor = LINGOSColors.Background) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) { when (uiState.currentTab) { MainTab.CHAT -> ChatScreen(); MainTab.DASHBOARD -> DashboardScreen() } }
    }
}

@Composable
private fun MainTopBar(mode: MainMode, onModeToggle: () -> Unit, onMenuClick: () -> Unit) {
    TopAppBar(
        title = {
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                // 【B3】连接状态指示（绿=已连接 / 红=离线）
                Box(modifier = Modifier.size(8.dp).clip(androidx.compose.foundation.shape.CircleShape)
                    .background(if (connState == ConnectionManager.ConnectionState.Connected) LINGOSColors.Success else LINGOSColors.Disconnected))
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "LING OS", style = LINGOSTypography.titleMedium, color = Color.White)
            }
        },
        navigationIcon = {
            IconButton(onClick = onMenuClick) {
                Icon(Icons.Default.Menu, contentDescription = stringResource(R.string.settings_title), tint = Color.White)
            }
        },
        actions = {
            IconButton(onClick = onModeToggle) {
                Icon(
                    Icons.Default.SwapHoriz,
                    contentDescription = "Toggle mode",
                    tint = if (mode == MainMode.AI) LINGOSColors.AccentRed else Color.White
                )
            }
            Surface(
                modifier = Modifier.padding(end = 8.dp).size(28.dp),
                shape = MaterialTheme.shapes.small,
                color = if (mode == MainMode.AI) LINGOSColors.AccentRed.copy(alpha = 0.2f)
                        else LINGOSColors.Success.copy(alpha = 0.2f)
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = androidx.compose.ui.Alignment.Center
                ) {
                    Text(
                        text = if (mode == MainMode.AI) "AI" else "SYS",
                        style = LINGOSTypography.labelSmall,
                        color = if (mode == MainMode.AI) LINGOSColors.AccentRed else LINGOSColors.Success
                    )
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = LINGOSColors.Background,
            scrolledContainerColor = LINGOSColors.Background
        )
    )
}

@Composable
private fun MainBottomBar(currentTab: MainTab, onTabSelected: (MainTab) -> Unit) {
    NavigationBar(containerColor=LINGOSColors.Background, tonalElevation=0.dp) {
        MainTab.entries.forEach { tab ->
            NavigationBarItem(icon = { Icon(imageVector=tab.icon, contentDescription=tab.label, modifier=Modifier.size(24.dp)) }, label={ Text(text=tab.label, style=LINGOSTypography.labelSmall) }, selected=currentTab == tab, onClick={ onTabSelected(tab) }, colors = NavigationBarItemDefaults.colors(selectedIconColor=LINGOSColors.AccentRed, selectedTextColor=LINGOSColors.AccentRed, unselectedIconColor=LINGOSColors.TextHint, unselectedTextColor=LINGOSColors.TextHint, indicatorColor=LINGOSColors.AccentRed.copy(alpha=0.15f)))
        }
    }
}
