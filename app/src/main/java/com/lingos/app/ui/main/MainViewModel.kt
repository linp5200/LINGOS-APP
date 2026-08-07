package com.lingos.app.ui.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.ui.graphics.vector.ImageVector

@HiltViewModel
class MainViewModel @Inject constructor() : ViewModel() {
    private val _uiState = MutableStateFlow(MainUiState()); val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()
    fun selectTab(tab: MainTab) { _uiState.update { it.copy(currentTab=tab) } }
    fun toggleMode() { _uiState.update { state -> state.copy(currentMode=if (state.currentMode == MainMode.AI) MainMode.SYSTEM else MainMode.AI) } }
}
data class MainUiState(val currentTab: MainTab = MainTab.CHAT, val currentMode: MainMode = MainMode.AI)
enum class MainTab(val label: String, val icon: ImageVector) { CHAT("Chat", Icons.Default.Chat), DASHBOARD("System", Icons.Default.Dashboard) }
enum class MainMode { AI, SYSTEM }
