package com.lingos.app.data.repository

import com.lingos.app.data.local.PreferencesManager
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(
    private val preferencesManager: PreferencesManager
) {

    // 主机地址
    fun getHost(): Flow<String> = preferencesManager.hostFlow
    suspend fun setHost(host: String) = preferencesManager.setHost(host)

    // 端口
    fun getPort(): Flow<Int> = preferencesManager.portFlow
    suspend fun setPort(port: Int) = preferencesManager.setPort(port)

    // 验证码
    suspend fun setAuthCode(code: String) = preferencesManager.setAuthCode(code)
    suspend fun getAuthCode(): String? = preferencesManager.getAuthCode()   // ← 改为 suspend

    // 连接码
    suspend fun setConnectionCode(code: String) = preferencesManager.setConnectionCode(code)

    // Session ID
    fun getSessionId(): Flow<String?> = preferencesManager.sessionIdFlow
    suspend fun setSessionId(sessionId: String) = preferencesManager.setSessionId(sessionId)

    // 最后使用的设备
    fun getLastDeviceId(): Flow<String?> = preferencesManager.lastDeviceIdFlow
    suspend fun setLastDeviceId(deviceId: String) = preferencesManager.setLastDeviceId(deviceId)

    // 用户名
    fun getUserName(): Flow<String> = preferencesManager.userNameFlow
    suspend fun setUserName(name: String) = preferencesManager.setUserName(name)

    // 语言
    fun getLanguage(): Flow<String> = preferencesManager.languageFlow
    suspend fun setLanguage(lang: String) = preferencesManager.setLanguage(lang)

    // 主题
    fun getTheme(): Flow<String> = preferencesManager.themeFlow
    suspend fun setTheme(theme: String) = preferencesManager.setTheme(theme)

    // 清空所有
    suspend fun clearAll() = preferencesManager.clearAll()
}