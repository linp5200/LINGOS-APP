package com.lingos.app.utils

import android.util.Log
import com.lingos.app.BuildConfig

object Logger {
    private val isEnabled: Boolean = BuildConfig.DEBUG
    private var isVerbose: Boolean = BuildConfig.DEBUG
    private const val LOG_FORMAT = "[%s] %s"
    fun setVerbose(verbose: Boolean) { isVerbose = verbose }
    fun d(tag: String, message: String) { if (isEnabled) Log.d(tag, message) }
    fun d(tag: String, format: String, vararg args: Any) { if (isEnabled) { val msg = String.format(format, *args); Log.d(tag, msg) } }
    fun i(tag: String, message: String) { if (isEnabled) Log.i(tag, message) }
    fun i(tag: String, format: String, vararg args: Any) { if (isEnabled) { val msg = String.format(format, *args); Log.i(tag, msg) } }
    fun w(tag: String, message: String) { if (isEnabled) Log.w(tag, message) }
    fun w(tag: String, format: String, vararg args: Any) { if (isEnabled) { val msg = String.format(format, *args); Log.w(tag, msg) } }
    fun e(tag: String, message: String, throwable: Throwable? = null) { if (isEnabled) { if (throwable != null) Log.e(tag, message, throwable) else Log.e(tag, message) } }
    fun e(tag: String, throwable: Throwable? = null, format: String, vararg args: Any) { if (isEnabled) { val msg = String.format(format, *args); if (throwable != null) Log.e(tag, msg, throwable) else Log.e(tag, msg) } }
    fun v(tag: String, message: String) { if (isEnabled && isVerbose) Log.v(tag, message) }
    fun enter(tag: String, methodName: String = Thread.currentThread().stackTrace[2].methodName) { if (isEnabled && isVerbose) Log.d(tag, "▶ Enter: $methodName") }
    fun exit(tag: String, methodName: String = Thread.currentThread().stackTrace[2].methodName) { if (isEnabled && isVerbose) Log.d(tag, "◀ Exit: $methodName") }
    fun json(tag: String, json: String) { if (isEnabled) { try { val prettyJson = org.json.JSONObject(json).toString(2); Log.d(tag, "JSON:\n$prettyJson") } catch (e: Exception) { try { val prettyJson = org.json.JSONArray(json).toString(2); Log.d(tag, "JSON Array:\n$prettyJson") } catch (e2: Exception) { Log.d(tag, "Raw: $json") } } } }
    fun long(tag: String, message: String) { if (isEnabled) { val maxLogSize = 4000; if (message.length <= maxLogSize) { Log.d(tag, message) } else { var start = 0; while (start < message.length) { val end = (start + maxLogSize).coerceAtMost(message.length); Log.d(tag, message.substring(start, end)); start = end } } } }
    fun time(tag: String, block: () -> Unit): Long { if (isEnabled) { val start = System.currentTimeMillis(); block(); val elapsed = System.currentTimeMillis() - start; Log.d(tag, "⏱ Elapsed: ${elapsed}ms"); return elapsed }; block(); return 0L }
    fun cond(tag: String, condition: Boolean, message: String) { if (isEnabled && condition) Log.d(tag, message) }
}
