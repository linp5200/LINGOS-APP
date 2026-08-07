package com.lingos.app.ui.memory

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

/** 【R8】记忆管理：查看/删除 AI 记忆 */
data class MemItem(val id: String, val content: String, val type: String = "")

@HiltViewModel
class MemoryViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "MemVM" }
    private val _items = MutableStateFlow<List<MemItem>>(emptyList())
    val items: StateFlow<List<MemItem>> = _items.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            _loading.value = true
            val result = connectionManager.sendCommandAndAwait("memory_index", emptyMap(), 6000L)
            if (result.isSuccess) {
                _items.value = parseItems(result.data ?: "")
            } else {
                Logger.w(TAG, "memory_index 失败: ${result.errorMessage}")
                _items.value = emptyList()
            }
            _loading.value = false
        }
    }

    fun delete(id: String) {
        viewModelScope.launch {
            connectionManager.sendCommandAndAwait("memory_delete", mapOf("id" to id), 6000L)
            _items.value = _items.value.filter { it.id != id }
        }
    }

    private fun parseItems(json: String): List<MemItem> {
        return try {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                MemItem(
                    id = o.optString("id", o.optString("key", "m$i")),
                    content = o.optString("content", o.optString("text", "记忆")),
                    type = o.optString("type", "")
                )
            }
        } catch (e: Exception) { emptyList() }
    }
}

@Composable
fun MemoryScreen(viewModel: MemoryViewModel = hiltViewModel()) {
    val items by viewModel.items.collectAsStateWithLifecycle()
    val loading by viewModel.loading.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background).padding(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(text = "记忆管理", style = LINGOSTypography.headlineSmall, color = Color.White, modifier = Modifier.weight(1f))
            TextButton(onClick = viewModel::refresh) { Text("刷新", color = LINGOSColors.AccentRed) }
        }
        if (loading && items.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = LINGOSColors.AccentRed)
            }
        } else if (items.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "暂无记忆\n（AI 保存的用户信息将显示于此）", style = LINGOSTypography.bodyLarge, color = LINGOSColors.TextSecondary)
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(items) { item ->
                    Surface(modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)), color = LINGOSColors.Surface) {
                        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(text = item.content, style = LINGOSTypography.bodySmall, color = Color.White, modifier = Modifier.weight(1f))
                            TextButton(onClick = { viewModel.delete(item.id) }) {
                                Text("删除", color = LINGOSColors.Disconnected)
                            }
                        }
                    }
                }
            }
        }
    }
}
