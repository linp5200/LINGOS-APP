package com.lingos.app.ui.files

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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

/** 【B12】文件浏览器（白名单目录 /LINGOS 与用户目录） */
data class FileEntry(val name: String, val isDir: Boolean, val size: Long = 0)

@HiltViewModel
class FileBrowserViewModel @Inject constructor(private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "FileVM" }
    private val _path = MutableStateFlow("/LINGOS")
    val path: StateFlow<String> = _path.asStateFlow()
    private val _entries = MutableStateFlow<List<FileEntry>>(emptyList())
    val entries: StateFlow<List<FileEntry>> = _entries.asStateFlow()
    private val _content = MutableStateFlow<String?>(null)
    val content: StateFlow<String?> = _content.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    init { navigate("/LINGOS") }

    fun navigate(dir: String) {
        viewModelScope.launch {
            _loading.value = true
            _content.value = null
            val result = connectionManager.sendCommandAndAwait("file_list", mapOf("path" to dir), 6000L)
            if (result.isSuccess) {
                _path.value = dir
                _entries.value = parseEntries(result.data ?: "")
            } else {
                Logger.w(TAG, "file_list 失败: ${result.errorMessage}")
                _entries.value = emptyList()
            }
            _loading.value = false
        }
    }

    fun goUp() {
        val p = _path.value.trimEnd('/')
        if (p.isEmpty() || p == "/") return
        val parent = p.substringBeforeLast('/', "/")
        if (parent.isNotEmpty()) navigate(parent)
    }

    fun open(entry: FileEntry) {
        if (entry.isDir) {
            val p = _path.value.trimEnd('/') + "/" + entry.name
            navigate(p)
        } else {
            viewModelScope.launch {
                _loading.value = true
                val result = connectionManager.sendCommandAndAwait("file_read", mapOf("path" to (_path.value.trimEnd('/') + "/" + entry.name)), 6000L)
                _content.value = if (result.isSuccess) result.data else "读取失败: ${result.errorMessage}"
                _loading.value = false
            }
        }
    }

    private fun parseEntries(json: String): List<FileEntry> {
        return try {
            val root = org.json.JSONObject(json)
            val data = root.optJSONObject("data") ?: root
            val arr = data.optJSONArray("entries") ?: data.optJSONArray("files") ?: return emptyList()
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                FileEntry(
                    name = o.optString("name", o.optString("path", "?")),
                    isDir = o.optBoolean("is_dir", o.optString("type", "") == "dir"),
                    size = o.optLong("size", 0)
                )
            }
        } catch (e: Exception) { emptyList() }
    }
}

@Composable
fun FileBrowserScreen(viewModel: FileBrowserViewModel = hiltViewModel()) {
    val path by viewModel.path.collectAsStateWithLifecycle()
    val entries by viewModel.entries.collectAsStateWithLifecycle()
    val content by viewModel.content.collectAsStateWithLifecycle()
    val loading by viewModel.loading.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background)) {
        // 路径栏
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = viewModel::goUp) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "上级", tint = Color.White)
            }
            Text(
                text = path,
                style = LINGOSTypography.bodyMedium,
                color = LINGOSColors.AccentCyan,
                modifier = Modifier.weight(1f)
            )
        }
        HorizontalDivider(color = LINGOSColors.TextHint.copy(alpha = 0.2f))

        if (content != null) {
            // 文件内容查看
            Text(
                text = content ?: "",
                style = LINGOSTypography.bodySmall,
                color = Color.White,
                modifier = Modifier.fillMaxSize().padding(16.dp)
            )
        } else if (loading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = LINGOSColors.AccentRed)
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp)) {
                items(entries) { entry ->
                    Surface(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp).clip(RoundedCornerShape(8.dp)),
                        color = LINGOSColors.Surface,
                        onClick = { viewModel.open(entry) }
                    ) {
                        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(text = if (entry.isDir) "📁" else "📄", style = LINGOSTypography.titleMedium)
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = entry.name,
                                style = LINGOSTypography.bodyMedium,
                                color = Color.White,
                                modifier = Modifier.weight(1f)
                            )
                            if (!entry.isDir && entry.size > 0) {
                                Text(text = formatSize(entry.size), style = LINGOSTypography.labelSmall, color = LINGOSColors.TextHint)
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun formatSize(size: Long): String {
    return when {
        size >= 1024 * 1024 -> String.format("%.1f MB", size / 1024f / 1024f)
        size >= 1024 -> String.format("%.1f KB", size / 1024f)
        else -> "$size B"
    }
}
