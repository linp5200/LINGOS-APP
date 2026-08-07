package com.lingos.app.data.model

data class SystemInfo(val cpuUsage: Float = 0f, val memoryUsage: Float = 0f, val memoryTotal: Long = 0, val memoryFree: Long = 0, val diskUsage: Float = 0f, val diskTotal: Long = 0, val diskFree: Long = 0, val networkRx: Long = 0, val networkTx: Long = 0, val uptime: Long = 0, val hostname: String = "", val osVersion: String = "", val connectedDevices: Int = 0)
data class SystemHistory(val timestamp: Long, val cpuUsage: Float, val memoryUsage: Float, val networkRx: Long, val networkTx: Long)
