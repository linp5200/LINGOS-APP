package com.lingos.app.utils

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.*

fun Context.showToast(message: String, duration: Int = Toast.LENGTH_SHORT) { Toast.makeText(this, message, duration).show() }
fun Context.showToast(messageResId: Int, duration: Int = Toast.LENGTH_SHORT) { Toast.makeText(this, messageResId, duration).show() }
fun Context.getScreenWidth(): Int { val displayMetrics = this.resources.displayMetrics; return displayMetrics.widthPixels }
fun Context.getScreenHeight(): Int { val displayMetrics = this.resources.displayMetrics; return displayMetrics.heightPixels }
fun Context.isNetworkAvailable(): Boolean { val connectivityManager = this.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager; val networkInfo = connectivityManager.activeNetworkInfo; return networkInfo != null && networkInfo.isConnected }

fun View.toBitmap(): Bitmap { val bitmap = Bitmap.createBitmap(this.width, this.height, Bitmap.Config.ARGB_8888); val canvas = Canvas(bitmap); this.draw(canvas); return bitmap }
fun View.visible(visible: Boolean) { this.visibility = if (visible) View.VISIBLE else View.GONE }
fun View.invisible(invisible: Boolean) { this.visibility = if (invisible) View.INVISIBLE else View.VISIBLE }

fun String?.isNullOrEmpty(): Boolean = this == null || this.isEmpty()
fun String?.isNullOrBlank(): Boolean = this == null || this.isBlank()
fun String.abbreviate(): String { return if (this.isNotEmpty()) { this.split(" ").mapNotNull { it.firstOrNull()?.toString() }.joinToString("") } else { "" } }
fun String.ellipsize(maxLength: Int): String { return if (this.length > maxLength) { this.substring(0, maxLength - 1) + "…" } else { this } }
fun String.isValidIPv4(): Boolean { return try { val parts = this.split("."); if (parts.size != 4) return false; parts.all { part -> val num = part.toIntOrNull(); num != null && num in 0..255 } } catch (e: Exception) { false } }
fun String.isValidPort(): Boolean { val port = this.toIntOrNull(); return port != null && port in 1..65535 }

fun Long.formatDate(pattern: String = "yyyy-MM-dd HH:mm:ss"): String { val formatter = SimpleDateFormat(pattern, Locale.getDefault()); return formatter.format(Date(this)) }
fun Long.toRelativeTime(): String { val now = System.currentTimeMillis(); val diff = now - this; return when { diff < 60000 -> "刚刚"; diff < 3600000 -> "${diff / 60000}分钟前"; diff < 86400000 -> "${diff / 3600000}小时前"; diff < 172800000 -> "昨天"; diff < 259200000 -> "前天"; else -> "${diff / 86400000}天前" } }

fun Int.dpToPx(context: Context): Int = (this * context.resources.displayMetrics.density).toInt()
fun Int.spToPx(context: Context): Int = (this * context.resources.displayMetrics.scaledDensity).toInt()
fun Int.pxToDp(context: Context): Int = (this / context.resources.displayMetrics.density).toInt()
fun Float.dpToPx(context: Context): Float = this * context.resources.displayMetrics.density
fun Float.spToPx(context: Context): Float = this * context.resources.displayMetrics.scaledDensity

fun <K, V> Map<K, V>.getOrDefault(key: K, defaultValue: V): V = this.get(key) ?: defaultValue
fun Map<String, Any>.toJson(): String { val json = org.json.JSONObject(); this.forEach { (key, value) -> when (value) { is String -> json.put(key, value); is Int -> json.put(key, value); is Long -> json.put(key, value); is Boolean -> json.put(key, value); is Double -> json.put(key, value); is Float -> json.put(key, value); is Map<*, *> -> json.put(key, org.json.JSONObject(value as Map<String, Any>)); is List<*> -> json.put(key, org.json.JSONArray(value)); else -> json.put(key, value.toString()) } }; return json.toString() }

fun <T> List<T>.chunkedSafe(size: Int): List<List<T>> = if (this.isEmpty()) emptyList() else this.chunked(size)
fun <T> List<T>?.isNullOrEmpty(): Boolean = this == null || this.isEmpty()

@Composable fun getScreenWidthDp(): Dp { val configuration = LocalConfiguration.current; return configuration.screenWidthDp.dp }
@Composable fun getScreenHeightDp(): Dp { val configuration = LocalConfiguration.current; return configuration.screenHeightDp.dp }
@Composable fun isDarkTheme(): Boolean { val configuration = LocalConfiguration.current; return configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES }
@Composable fun getAppContext(): Context = LocalContext.current
fun Color.toArgb(): Int = this.toArgb()
fun Color.withAlpha(alpha: Float): Color = this.copy(alpha = alpha.coerceIn(0f, 1f))
fun Color.toHexString(): String { val argb = this.toArgb(); return String.format("#%08X", argb) }

fun String.tryParseJson(): Map<String, Any>? { return try { val json = org.json.JSONObject(this); json.keys().asSequence().associateWith { key -> val value = json.get(key); when (value) { is org.json.JSONObject -> value.toString(); is org.json.JSONArray -> value.toString(); else -> value } } } catch (e: Exception) { null } }
fun ByteArray.sha256(): String { val digest = java.security.MessageDigest.getInstance("SHA-256"); val hash = digest.digest(this); return hash.joinToString("") { "%02x".format(it) } }
fun generateUniqueId(): String = UUID.randomUUID().toString()
fun Double.safeRound(): Int = (this + 0.5).toInt()
