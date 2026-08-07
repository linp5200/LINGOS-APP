package com.lingos.app.ui.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.R
import com.lingos.app.ui.chat.components.MessageBubble
import com.lingos.app.ui.chat.components.VoiceInputButton
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun ChatScreen(viewModel: ChatViewModel = hiltViewModel()) {
    val messages by viewModel.messages.collectAsStateWithLifecycle(); val inputText by viewModel.inputText.collectAsStateWithLifecycle(); val chatState by viewModel.chatState.collectAsStateWithLifecycle(); val isVoiceRecording by viewModel.isVoiceRecording.collectAsStateWithLifecycle()
    val listState = rememberLazyListState(); val focusManager = LocalFocusManager.current
    LaunchedEffect(messages.size) { if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1) }
    Column(modifier = Modifier.fillMaxSize().background(LINGOSColors.Background)) {
        LazyColumn(state=listState, modifier=Modifier.weight(1f).fillMaxWidth().padding(horizontal=16.dp, vertical=8.dp), reverseLayout=false) {
            items(messages) { message -> MessageBubble(message=message); Spacer(modifier=Modifier.height(8.dp)) }
            when (val state = chatState) { is ChatState.Thinking -> item { ThinkingIndicator() }; is ChatState.Streaming -> item { StreamingMessage(content=state.content) }; is ChatState.ToolCall -> item { ToolCallIndicator(toolName=state.toolName, args=state.args) }; is ChatState.Error -> item { ErrorIndicator(message=state.message) }; else -> {} }
        }
        InputArea(inputText=inputText, onInputChange=viewModel::updateInputText, onSend=viewModel::sendMessage, isVoiceRecording=isVoiceRecording, onVoiceToggle={ if (isVoiceRecording) viewModel.stopVoiceRecording() else viewModel.startVoiceRecording() }, isProcessing=chatState is ChatState.Thinking)
    }
}

@Composable
private fun ThinkingIndicator() { Row(modifier=Modifier.fillMaxWidth().padding(vertical=8.dp), horizontalArrangement=Arrangement.Start) { Surface(shape=RoundedCornerShape(12.dp), color=LINGOSColors.Surface) { Row(modifier=Modifier.padding(horizontal=16.dp, vertical=12.dp), verticalAlignment=Alignment.CenterVertically) { CircularProgressIndicator(modifier=Modifier.size(16.dp), color=LINGOSColors.AccentRed, strokeWidth=2.dp); Spacer(modifier=Modifier.width(12.dp)); Text(text="Nook 思考中...", style=LINGOSTypography.bodySmall, color=LINGOSColors.TextSecondary) } } } }

@Composable
private fun StreamingMessage(content: String) { Row(modifier=Modifier.fillMaxWidth().padding(vertical=4.dp), horizontalArrangement=Arrangement.Start) { Surface(shape=RoundedCornerShape(12.dp), color=LINGOSColors.Surface.copy(alpha=0.8f)) { Text(text=content, style=LINGOSTypography.bodyMedium, color=Color.White, modifier=Modifier.padding(horizontal=16.dp, vertical=12.dp)) } } }

@Composable
private fun ToolCallIndicator(toolName: String, args: String) { Row(modifier=Modifier.fillMaxWidth().padding(vertical=4.dp), horizontalArrangement=Arrangement.Center) { Surface(shape=RoundedCornerShape(8.dp), color=LINGOSColors.AccentRed.copy(alpha=0.15f)) { Row(modifier=Modifier.padding(horizontal=12.dp, vertical=6.dp), verticalAlignment=Alignment.CenterVertically) { Text(text="🔧", style=LINGOSTypography.labelMedium); Spacer(modifier=Modifier.width(8.dp)); Text(text="调用工具: $toolName", style=LINGOSTypography.labelSmall, color=LINGOSColors.AccentRed) } } } }

@Composable
private fun ErrorIndicator(message: String) { Row(modifier=Modifier.fillMaxWidth().padding(vertical=4.dp), horizontalArrangement=Arrangement.Center) { Surface(shape=RoundedCornerShape(8.dp), color=LINGOSColors.Disconnected.copy(alpha=0.15f)) { Row(modifier=Modifier.padding(horizontal=12.dp, vertical=6.dp), verticalAlignment=Alignment.CenterVertically) { Text(text="⚠️ $message", style=LINGOSTypography.labelSmall, color=LINGOSColors.Disconnected) } } } }

@Composable
private fun InputArea(inputText: String, onInputChange: (String) -> Unit, onSend: () -> Unit, isVoiceRecording: Boolean, onVoiceToggle: () -> Unit, isProcessing: Boolean) {
    Surface(modifier=Modifier.fillMaxWidth().background(LINGOSColors.Surface).padding(horizontal=12.dp, vertical=8.dp)) {
        Row(modifier=Modifier.fillMaxWidth(), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            VoiceInputButton(isRecording=isVoiceRecording, onClick=onVoiceToggle)
            OutlinedTextField(value=inputText, onValueChange=onInputChange, placeholder={ Text(text=stringResource(R.string.chat_placeholder), style=LINGOSTypography.bodyMedium, color=LINGOSColors.TextHint) }, modifier=Modifier.weight(1f), shape=RoundedCornerShape(24.dp), colors=OutlinedTextFieldDefaults.colors(focusedBorderColor=LINGOSColors.AccentRed, unfocusedBorderColor=LINGOSColors.TextHint.copy(alpha=0.3f), focusedTextColor=Color.White, unfocusedTextColor=Color.White, cursorColor=LINGOSColors.AccentRed, focusedContainerColor=LINGOSColors.Background, unfocusedContainerColor=LINGOSColors.Background), textStyle=LINGOSTypography.bodyMedium, singleLine=true, enabled=!isProcessing)
            IconButton(onClick=onSend, enabled=inputText.isNotBlank() && !isProcessing) { Icon(Icons.Default.Send, contentDescription=stringResource(R.string.chat_send), tint=if (inputText.isNotBlank() && !isProcessing) LINGOSColors.AccentRed else LINGOSColors.TextHint) }
            if (inputText.isNotBlank()) { IconButton(onClick={ onInputChange("") }) { Icon(Icons.Default.Clear, contentDescription="Clear", tint=LINGOSColors.TextHint, modifier=Modifier.size(18.dp)) } }
        }
    }
}
