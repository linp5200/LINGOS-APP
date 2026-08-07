@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lingos.app.ui.connect

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Usb
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.*
import androidx.compose.material3.OutlinedButtonDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lingos.app.R
import com.lingos.app.ui.theme.LINGOSColors
import com.lingos.app.ui.theme.LINGOSTypography

@Composable
fun ConnectScreen(viewModel: ConnectViewModel = hiltViewModel(), onConnected: () -> Unit, onBack: () -> Unit) {
    val state by viewModel.state.collectAsStateWithLifecycle(); val selectedMethod by viewModel.selectedMethod.collectAsStateWithLifecycle(); val address by viewModel.address.collectAsStateWithLifecycle(); val port by viewModel.port.collectAsStateWithLifecycle(); val authCode by viewModel.authCode.collectAsStateWithLifecycle(); val connectionCode by viewModel.connectionCode.collectAsStateWithLifecycle(); val isUsbConnected by viewModel.isUsbConnected.collectAsStateWithLifecycle(); val usbDevice by viewModel.usbDevice.collectAsStateWithLifecycle()
    LaunchedEffect(state) { if (state == ConnectState.Connected) onConnected() }
    Scaffold(topBar = { TopAppBar(title = { Text(text=stringResource(R.string.connect_title), style=LINGOSTypography.titleMedium, color=Color.White) }, navigationIcon = { IconButton(onClick=onBack) { Icon(Icons.Default.ArrowBack, contentDescription=stringResource(R.string.back), tint=Color.White) } }, colors = TopAppBarDefaults.topAppBarColors(containerColor=LINGOSColors.Background, scrolledContainerColor=LINGOSColors.Background)) }) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingValues).background(LINGOSColors.Background).padding(horizontal=20.dp, vertical=16.dp)) {
            ConnectionMethodTabs(selectedMethod=selectedMethod, onMethodSelected=viewModel::selectMethod); Spacer(modifier=Modifier.height(20.dp))
            when (selectedMethod) {
                ConnectionMethod.LAN -> LANConnectionContent(address=address, port=port, state=state, onAddressChange=viewModel::updateAddress, onPortChange=viewModel::updatePort, onScan=viewModel::startScan, onConnect=viewModel::startConnect, onRetry=viewModel::retry)
                ConnectionMethod.PUBLIC -> PublicConnectionContent(authCode=authCode, connectionCode=connectionCode, state=state, onAuthCodeChange=viewModel::updateAuthCode, onConnectionCodeChange=viewModel::updateConnectionCode, onConnect=viewModel::startConnect, onSubmitCode=viewModel::submitConnectionCode, onRetry=viewModel::retry)
                ConnectionMethod.USB -> USBConnectionContent(isConnected=isUsbConnected, device=usbDevice, state=state, onCheck=viewModel::checkUsbStatus, onConnect=viewModel::startConnect, onRetry=viewModel::retry)
            }; Spacer(modifier=Modifier.height(16.dp)); ConnectionStatusDisplay(state=state)
        }
    }
}

@Composable
private fun ConnectionMethodTabs(selectedMethod: ConnectionMethod, onMethodSelected: (ConnectionMethod) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(LINGOSColors.Surface).padding(4.dp)) {
        listOf(ConnectionMethod.LAN to Icons.Default.Wifi, ConnectionMethod.PUBLIC to Icons.Default.Public, ConnectionMethod.USB to Icons.Default.Usb).forEach { (method, icon) ->
            val isSelected = method == selectedMethod
            Surface(modifier = Modifier.weight(1f).clip(RoundedCornerShape(6.dp)).clickable { onMethodSelected(method) }, color = if (isSelected) LINGOSColors.AccentRed.copy(alpha=0.2f) else Color.Transparent) {
                Row(modifier = Modifier.fillMaxWidth().padding(vertical=10.dp), horizontalArrangement=Arrangement.Center, verticalAlignment=Alignment.CenterVertically) {
                    Icon(imageVector=icon, contentDescription=null, tint=if (isSelected) LINGOSColors.AccentRed else LINGOSColors.TextHint, modifier=Modifier.size(18.dp)); Spacer(modifier=Modifier.width(6.dp))
                    Text(text = when (method) { ConnectionMethod.LAN -> stringResource(R.string.connect_lan); ConnectionMethod.PUBLIC -> stringResource(R.string.connect_public); ConnectionMethod.USB -> stringResource(R.string.connect_usb) }, style = LINGOSTypography.labelMedium, color = if (isSelected) Color.White else LINGOSColors.TextHint)
                }
            }
        }
    }
}

@Composable
private fun LANConnectionContent(address: String, port: String, state: ConnectState, onAddressChange: (String) -> Unit, onPortChange: (String) -> Unit, onScan: () -> Unit, onConnect: () -> Unit, onRetry: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(value=address, onValueChange=onAddressChange, label={ Text(stringResource(R.string.connect_address)) }, modifier=Modifier.fillMaxWidth(), colors=textFieldColors(), textStyle=LINGOSTypography.bodyMedium); Spacer(modifier=Modifier.height(12.dp))
        OutlinedTextField(value=port, onValueChange=onPortChange, label={ Text(stringResource(R.string.connect_port)) }, modifier=Modifier.fillMaxWidth(), colors=textFieldColors(), textStyle=LINGOSTypography.bodyMedium); Spacer(modifier=Modifier.height(16.dp))
        Row(modifier=Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick=onScan, modifier=Modifier.weight(1f), colors=outlinedButtonColors()) { Icon(Icons.Default.QrCodeScanner, contentDescription=null, modifier=Modifier.size(18.dp)); Spacer(modifier=Modifier.width(6.dp)); Text(stringResource(R.string.connect_scan)) }
            Button(onClick={ if (state is ConnectState.Failed) onRetry() else onConnect() }, modifier=Modifier.weight(1f), colors=buttonColors(), enabled=state !is ConnectState.Connecting) { Text(if (state is ConnectState.Failed) stringResource(R.string.connect_retry) else stringResource(R.string.confirm)) }
        }
        if (state is ConnectState.Scanning) { Spacer(modifier=Modifier.height(16.dp)); ScanResultList(devices=state.foundDevices, progress=state.progress) }
    }
}

@Composable
private fun PublicConnectionContent(authCode: String, connectionCode: String, state: ConnectState, onAuthCodeChange: (String) -> Unit, onConnectionCodeChange: (String) -> Unit, onConnect: () -> Unit, onSubmitCode: (String) -> Unit, onRetry: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(value=authCode, onValueChange=onAuthCodeChange, label={ Text(stringResource(R.string.connect_auth_code)) }, modifier=Modifier.fillMaxWidth(), colors=textFieldColors(), textStyle=LINGOSTypography.bodyMedium, placeholder={ Text("Enter auth code from host", color=LINGOSColors.TextHint) }); Spacer(modifier=Modifier.height(12.dp))
        OutlinedTextField(value=connectionCode, onValueChange=onConnectionCodeChange, label={ Text(stringResource(R.string.connect_connection_code)) }, modifier=Modifier.fillMaxWidth(), colors=textFieldColors(), textStyle=LINGOSTypography.bodyMedium, placeholder={ Text("Enter connection code from host", color=LINGOSColors.TextHint) }); Spacer(modifier=Modifier.height(12.dp))
        Text(text="⚠ Public network requires WSS and two-step verification", style=LINGOSTypography.bodySmall, color=LINGOSColors.Warning, modifier=Modifier.padding(bottom=8.dp))
        Row(modifier=Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            Button(onClick={ if (state is ConnectState.Failed) onRetry() else onConnect() }, modifier=Modifier.weight(1f), colors=buttonColors(), enabled=state !is ConnectState.Connecting) { Text(if (state is ConnectState.Failed) stringResource(R.string.connect_retry) else stringResource(R.string.confirm)) }
        }
        if (state is ConnectState.WaitingAuth) { Spacer(modifier=Modifier.height(12.dp)); when (state.step) { AuthStep.AUTH_CODE -> Text("⏳ Waiting for auth code...", style=LINGOSTypography.bodySmall, color=LINGOSColors.TextSecondary); AuthStep.CONNECTION_CODE -> Text("✅ Auth code verified! Please enter connection code from host screen.", style=LINGOSTypography.bodySmall, color=LINGOSColors.Success) } }
    }
}

@Composable
private fun USBConnectionContent(isConnected: Boolean, device: String?, state: ConnectState, onCheck: () -> Unit, onConnect: () -> Unit, onRetry: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Surface(modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)), color = if (isConnected) LINGOSColors.Success.copy(alpha=0.15f) else LINGOSColors.Disconnected.copy(alpha=0.15f)) {
            Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.SpaceBetween) {
                Row(verticalAlignment=Alignment.CenterVertically) { Icon(Icons.Default.Usb, contentDescription=null, tint=if (isConnected) LINGOSColors.Success else LINGOSColors.Disconnected); Spacer(modifier=Modifier.width(8.dp)); Text(text=if (isConnected) "USB Connected: $device" else "No USB device detected", style=LINGOSTypography.bodyMedium, color=if (isConnected) Color.White else LINGOSColors.TextSecondary) }
                TextButton(onClick=onCheck) { Text("Refresh", style=LINGOSTypography.labelMedium) }
            }
        }; Spacer(modifier=Modifier.height(16.dp))
        Text("⚠ USB mode is for system debugging and recovery only", style=LINGOSTypography.bodySmall, color=LINGOSColors.Warning, modifier=Modifier.padding(bottom=16.dp))
        Button(onClick={ if (state is ConnectState.Failed) onRetry() else onConnect() }, modifier=Modifier.fillMaxWidth(), colors=buttonColors(), enabled=isConnected && state !is ConnectState.Connecting) { Text(if (state is ConnectState.Failed) stringResource(R.string.connect_retry) else "Connect Debug") }
    }
}

@Composable
private fun ScanResultList(devices: List<DetectedDevice>, progress: Int) {
    Column {
        Text(text="🔍 Scanning... $progress%", style=LINGOSTypography.labelMedium, color=LINGOSColors.TextSecondary, modifier=Modifier.padding(bottom=8.dp))
        if (devices.isNotEmpty()) { LazyColumn(modifier = Modifier.fillMaxWidth().height(120.dp).clip(RoundedCornerShape(8.dp)).background(LINGOSColors.Surface)) { items(devices) { device -> Row(modifier = Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement=Arrangement.SpaceBetween) { Text(text="${device.ip} ${device.hostname ?: ""}", style=LINGOSTypography.bodySmall, color=Color.White); if (device.isReachable) Text(text="✓ Reachable", style=LINGOSTypography.bodySmall, color=LINGOSColors.Success) } } } }
    }
}

@Composable
private fun ConnectionStatusDisplay(state: ConnectState) {
    val (text, color) = when (state) { is ConnectState.Connected -> stringResource(R.string.connect_status_connected) to LINGOSColors.Success; is ConnectState.Connecting -> state.message to LINGOSColors.Connecting; is ConnectState.Failed -> state.message to LINGOSColors.Disconnected; else -> stringResource(R.string.connect_status_disconnected) to LINGOSColors.TextHint }
    Row(modifier = Modifier.fillMaxWidth().padding(12.dp).clip(RoundedCornerShape(6.dp)).background(LINGOSColors.Surface).padding(12.dp), verticalAlignment=Alignment.CenterVertically) {
        Box(modifier = Modifier.size(8.dp).clip(RoundedCornerShape(50)).background(color)); Spacer(modifier=Modifier.width(10.dp)); Text(text=text, style=LINGOSTypography.bodySmall, color=Color.White); if (state is ConnectState.Connecting) { Spacer(modifier=Modifier.width(8.dp)); CircularProgressIndicator(modifier=Modifier.size(16.dp), color=LINGOSColors.AccentRed, strokeWidth=2.dp) }
    }
}

@Composable
private fun textFieldColors() = OutlinedTextFieldDefaults.colors(focusedBorderColor=LINGOSColors.AccentRed, unfocusedBorderColor=LINGOSColors.TextHint.copy(alpha=0.3f), focusedLabelColor=LINGOSColors.AccentRed, unfocusedLabelColor=LINGOSColors.TextHint, focusedTextColor=Color.White, unfocusedTextColor=Color.White, cursorColor=LINGOSColors.AccentRed, focusedContainerColor=LINGOSColors.Surface, unfocusedContainerColor=LINGOSColors.Surface)
@Composable
private fun buttonColors() = ButtonDefaults.buttonColors(containerColor=LINGOSColors.AccentRed, contentColor=Color.White, disabledContainerColor=LINGOSColors.TextHint, disabledContentColor=LINGOSColors.TextSecondary)
@Composable
private fun outlinedButtonColors() = OutlinedButtonDefaults.outlinedButtonColors(contentColor=LINGOSColors.AccentRed)
