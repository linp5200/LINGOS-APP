package com.lingos.app

import android.app.Application
import android.util.Log
import dagger.hilt.android.HiltAndroidApp
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

@HiltAndroidApp
class LINGOSApp : Application() {

    override fun onCreate() {
        super.onCreate()
        // 【B15】崩溃捕获：写入本地文件（下次启动可上报主机）
        val handler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val dir = File(filesDir, "crash")
                if (!dir.exists()) dir.mkdirs()
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val file = File(dir, "crash_${System.currentTimeMillis()}.log")
                file.writeText("thread=${thread.name}\n$sw")
                Log.e("LINGOSApp", "Crash captured: ${file.absolutePath}")
            } catch (_: Exception) {}
            handler?.uncaughtException(thread, throwable)
        }
    }
}
