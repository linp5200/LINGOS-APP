package com.lingos.app.data.repository

import com.lingos.app.data.local.DatabaseProvider
import com.lingos.app.data.model.Device
import com.lingos.app.data.model.DeviceHistory
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceRepository @Inject constructor(private val databaseProvider: DatabaseProvider) {
    private val deviceDao = databaseProvider.getDatabase().deviceDao()
    fun getAllDevices(): Flow<List<Device>> = deviceDao.getAllDevices()
    fun getOnlineDevices(): Flow<List<Device>> = deviceDao.getOnlineDevices()
    fun getFavoriteDevices(): Flow<List<Device>> = deviceDao.getFavoriteDevices()
    suspend fun getDevice(deviceId: String): Device? = deviceDao.getDevice(deviceId)
    suspend fun saveDevice(device: Device) { deviceDao.insertDevice(device) }
    suspend fun updateDevice(device: Device) { deviceDao.updateDevice(device) }
    suspend fun deleteDevice(device: Device) { deviceDao.deleteDevice(device) }
    suspend fun toggleFavorite(deviceId: String) { val device = deviceDao.getDevice(deviceId); device?.let { deviceDao.insertDevice(it.copy(isFavorite = !it.isFavorite)) } }
    suspend fun getDeviceHistory(deviceId: String, limit: Int = 24): List<DeviceHistory> = (1..limit).map { i -> DeviceHistory(deviceId=deviceId, timestamp=System.currentTimeMillis() - (i * 3600_000L), event=when (i % 3) { 0 -> "设备上线"; 1 -> "设备离线"; else -> "状态更新" }, success=true) }
    suspend fun addHistory(history: DeviceHistory) {}
    suspend fun clearAllDevices() { deviceDao.deleteAllDevices() }
}
