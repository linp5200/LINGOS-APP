package com.lingos.app.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class DeviceStatus { ONLINE, OFFLINE, UNKNOWN }
enum class DeviceType { ROUTER, COMPUTER, SMARTPHONE, CAMERA, LIGHT, SOCKET, SENSOR, SPEAKER, TV, SMART_PLUG, OTHER }
@Entity(tableName = "devices")
data class Device(@PrimaryKey val id: String, val name: String, val type: String, val status: DeviceStatus, val ip: String? = null, val mac: String? = null, val icon: String = "📡", val properties: Map<String, Any> = emptyMap(), val lastSeen: Long = System.currentTimeMillis(), val createdAt: Long = System.currentTimeMillis(), val updatedAt: Long = System.currentTimeMillis(), val isFavorite: Boolean = false)
data class DeviceHistory(val deviceId: String, val timestamp: Long, val event: String, val success: Boolean = true, val details: Map<String, Any> = emptyMap())
data class DiscoveredDevice(val ip: String, val mac: String? = null, val hostname: String? = null, val port: Int = 2937, val status: DeviceStatus = DeviceStatus.UNKNOWN)
