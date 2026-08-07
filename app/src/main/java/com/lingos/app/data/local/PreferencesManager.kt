package com.lingos.app.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore("lingos_settings")

@Singleton
class PreferencesManager @Inject constructor(
    @ApplicationContext private val context: Context
) {

    companion object {
        private val KEY_HOST = stringPreferencesKey("host")
        private val KEY_PORT = stringPreferencesKey("port")
        private val KEY_AUTH_CODE = stringPreferencesKey("auth_code")
        private val KEY_CONNECTION_CODE = stringPreferencesKey("connection_code")
        private val KEY_SESSION_ID = stringPreferencesKey("session_id")
        private val KEY_LAST_DEVICE_ID = stringPreferencesKey("last_device_id")
        private val KEY_USER_NAME = stringPreferencesKey("user_name")
        private val KEY_LANGUAGE = stringPreferencesKey("language")
        private val KEY_THEME = stringPreferencesKey("theme")
    }

    // 主机
    val hostFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_HOST] ?: "127.0.0.1"
    }

    suspend fun setHost(host: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_HOST] = host
        }
    }

    // 端口
    val portFlow: Flow<Int> = context.dataStore.data.map { preferences ->
        preferences[KEY_PORT]?.toIntOrNull() ?: 2937
    }

    suspend fun setPort(port: Int) {
        context.dataStore.edit { preferences ->
            preferences[KEY_PORT] = port.toString()
        }
    }

    suspend fun setAuthCode(code: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_AUTH_CODE] = code
        }
    }

    suspend fun getAuthCode(): String? {
        return context.dataStore.data.map { preferences ->
            preferences[KEY_AUTH_CODE]
        }.first()
    }

    suspend fun setConnectionCode(code: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_CONNECTION_CODE] = code
        }
    }

    suspend fun setSessionId(sessionId: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_SESSION_ID] = sessionId
        }
    }

    val sessionIdFlow: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[KEY_SESSION_ID]
    }

    suspend fun setLastDeviceId(deviceId: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_LAST_DEVICE_ID] = deviceId
        }
    }

    val lastDeviceIdFlow: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[KEY_LAST_DEVICE_ID]
    }

    suspend fun setUserName(name: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_USER_NAME] = name
        }
    }

    val userNameFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_USER_NAME] ?: "Sir"
    }

    suspend fun setLanguage(lang: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_LANGUAGE] = lang
        }
    }

    val languageFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_LANGUAGE] ?: "en"
    }

    suspend fun setTheme(theme: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_THEME] = theme
        }
    }

    val themeFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_THEME] ?: "dark"
    }

    suspend fun clearAll() {
        context.dataStore.edit { preferences ->
            preferences.clear()
        }
    }
}