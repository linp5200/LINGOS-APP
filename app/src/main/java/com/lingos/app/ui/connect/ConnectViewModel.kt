package com.lingos.app.ui.connect

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

@HiltViewModel
class ConnectViewModel @Inject constructor(@ApplicationContext private val context: Context, private val connectionManager: ConnectionManager) : ViewModel() {
    companion object { private const val TAG = "ConnectVM"; private const val SCAN_TIMEOUT = 5000L; private const val CONNECT_TIMEOUT = 10000L }
    private val _state = MutableStateFlow<ConnectState>(ConnectState.Idle); val state: StateFlow<ConnectState> = _state.asStateFlow()
    private val _selectedMethod = MutableStateFlow(ConnectionMethod.LAN); val selectedMethod: StateFlow<ConnectionMethod> = _selectedMethod.asStateFlow()
    private val _address = MutableStateFlow("127.0.0.1"); val address: StateFlow<String> = _address.asStateFlow()
    private val _port = MutableStateFlow("2937"); val port: StateFlow<String> = _port.asStateFlow()
    private val _authCode = MutableStateFlow(""); val authCode: StateFlow<String> = _authCode.asStateFlow()
    private val _connectionCode = MutableStateFlow(""); val connectionCode: StateFlow<String> = _connectionCode.asStateFlow()
    private val _usbDevice = MutableStateFlow<String?>(null); val usbDevice: StateFlow<String?> = _usbDevice.asStateFlow()
    private val _isUsbConnected = MutableStateFlow(false); val isUsbConnected: StateFlow<Boolean> = _isUsbConnected.asStateFlow()

    fun selectMethod(method: ConnectionMethod) { _selectedMethod.value = method; _state.value = ConnectState.Idle; Logger.d(TAG, "Method selected: $method") }
    fun updateAddress(address: String) { _address.value = address }
    fun updatePort(port: String) { _port.value = port }
    fun updateAuthCode(code: String) { _authCode.value = code }
    fun updateConnectionCode(code: String) { _connectionCode.value = code }

    fun startScan() { viewModelScope.launch {
        _state.value = ConnectState.Scanning(foundDevices=emptyList(), progress=0)
        try { val devices = mutableListOf<DetectedDevice>(); for (i in 1..10) { val progress = (i * 10); val ip = "192.168.1.$i"; val reachable = i % 3 == 0; if (reachable) { devices.add(DetectedDevice(ip=ip, hostname=if (i==7) "LINGOS-HOST" else null, port=2937, isReachable=true)) }; _state.value = ConnectState.Scanning(foundDevices=devices.toList(), progress=progress); delay(300L) }; val lingosDevice = devices.find { it.hostname?.contains("LINGOS") == true }; if (lingosDevice != null) { _address.value = lingosDevice.ip; _state.value = ConnectState.Idle; Logger.d(TAG, "Auto-selected LINGOS host: ${lingosDevice.ip}") } else { _state.value = ConnectState.Idle } } catch (e: Exception) { Logger.e(TAG, "Scan error", e); _state.value = ConnectState.Idle } } }

    fun startConnect() { viewModelScope.launch {
        val method = _selectedMethod.value; _state.value = ConnectState.Connecting(method=method, progress=0, message=context.getString(R.string.connect_status_connecting))
        try { when (method) { ConnectionMethod.LAN -> connectViaLAN(); ConnectionMethod.PUBLIC -> connectViaPublic(); ConnectionMethod.USB -> connectViaUSB() } } catch (e: Exception) { Logger.e(TAG, "Connect error", e); _state.value = ConnectState.Failed(message=e.message ?: context.getString(R.string.connect_status_error), canRetry=true) } } }

    fun retry() { _state.value = ConnectState.Idle; startConnect() }
    fun reset() { _state.value = ConnectState.Idle }
    fun checkUsbStatus() { viewModelScope.launch { val connected = kotlin.random.Random.nextBoolean(); _isUsbConnected.value = connected; if (connected) { _usbDevice.value = "/dev/ttyUSB0" } else { _usbDevice.value = null } } }

    private suspend fun connectViaLAN() { val host = _address.value; val port = _port.value.toIntOrNull() ?: 2937; _state.value = ConnectState.Connecting(method=ConnectionMethod.LAN, progress=30, message="Connecting to $host:$port..."); val result = connectionManager.connect(host, port, CONNECT_TIMEOUT); _state.value = ConnectState.Connecting(method=ConnectionMethod.LAN, progress=70, message="Verifying connection..."); if (result.isSuccess) { _state.value = ConnectState.Connected; Logger.d(TAG, "LAN connection success") } else { _state.value = ConnectState.Connecting(method=ConnectionMethod.LAN, progress=50, message="Trying backup port 2938..."); val backupResult = connectionManager.connect(host, 2938, CONNECT_TIMEOUT); if (backupResult.isSuccess) { _state.value = ConnectState.Connected; Logger.d(TAG, "LAN connection via backup port success") } else { _state.value = ConnectState.Failed(message=context.getString(R.string.connect_status_error), canRetry=true) } } }
    private suspend fun connectViaPublic() { val authCode = _authCode.value; val connectionCode = _connectionCode.value; if (authCode.isEmpty()) { _state.value = ConnectState.WaitingAuth(step=AuthStep.AUTH_CODE, code=""); return }; _state.value = ConnectState.Connecting(method=ConnectionMethod.PUBLIC, progress=20, message="Verifying auth code..."); val authResult = connectionManager.verifyAuthCode(authCode); if (!authResult.isSuccess) { _state.value = ConnectState.Failed(message="Invalid auth code: ${authResult.errorMessage}", canRetry=true); return }; _state.value = ConnectState.WaitingAuth(step=AuthStep.CONNECTION_CODE, code="") }
    private suspend fun connectViaUSB() { if (!_isUsbConnected.value) { _state.value = ConnectState.Failed(message="No USB device detected", canRetry=true); return }; _state.value = ConnectState.Connecting(method=ConnectionMethod.USB, progress=50, message="Connecting via USB..."); val result = connectionManager.connectViaUSB(_usbDevice.value); if (result.isSuccess) { _state.value = ConnectState.Connected } else { _state.value = ConnectState.Failed(message="USB connection failed: ${result.errorMessage}", canRetry=true) } }
    fun submitConnectionCode(code: String) { viewModelScope.launch { _state.value = ConnectState.Connecting(method=ConnectionMethod.PUBLIC, progress=50, message="Verifying connection code..."); val result = connectionManager.verifyConnectionCode(code); if (result.isSuccess) { _state.value = ConnectState.Connected; Logger.d(TAG, "Public connection success") } else { _state.value = ConnectState.WaitingAuth(step=AuthStep.CONNECTION_CODE, code="") } } }
}
