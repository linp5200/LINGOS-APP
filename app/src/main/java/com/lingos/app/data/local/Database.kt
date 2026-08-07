package com.lingos.app.data.local

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters
import android.content.Context
import com.lingos.app.data.model.ChatMessage
import com.lingos.app.data.model.Device
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

class Converters {
    @TypeConverter fun fromDeviceStatus(value: String): com.lingos.app.data.model.DeviceStatus = try { com.lingos.app.data.model.DeviceStatus.valueOf(value) } catch (e: Exception) { com.lingos.app.data.model.DeviceStatus.UNKNOWN }
    @TypeConverter fun toDeviceStatus(value: com.lingos.app.data.model.DeviceStatus): String = value.name
    @TypeConverter fun fromStringMap(value: String): Map<String, Any> { return try { val json = org.json.JSONObject(value); json.keys().asSequence().associateWith { key -> val v = json.get(key); when (v) { is org.json.JSONObject -> v.toString(); is org.json.JSONArray -> v.toString(); else -> v } } } catch (e: Exception) { emptyMap() } }
    @TypeConverter fun toStringMap(value: Map<String, Any>): String { val json = org.json.JSONObject(); value.forEach { (key, v) -> when (v) { is String -> json.put(key, v); is Int -> json.put(key, v); is Long -> json.put(key, v); is Boolean -> json.put(key, v); is Double -> json.put(key, v); is Float -> json.put(key, v); else -> json.put(key, v.toString()) } }; return json.toString() }
    @TypeConverter fun fromMessageSender(value: String): com.lingos.app.data.model.MessageSender = com.lingos.app.data.model.MessageSender.valueOf(value)
    @TypeConverter fun toMessageSender(value: com.lingos.app.data.model.MessageSender): String = value.name
    @TypeConverter fun fromStringStringMap(value: String): Map<String, String> { return try { val json = org.json.JSONObject(value); json.keys().asSequence().associateWith { key -> json.getString(key) } } catch (e: Exception) { emptyMap() } }
    @TypeConverter fun toStringStringMap(value: Map<String, String>): String { val json = org.json.JSONObject(); value.forEach { (key, v) -> json.put(key, v) }; return json.toString() }
}

@Database(entities = [Device::class, ChatMessage::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
abstract class LINGOSDatabase : RoomDatabase() { abstract fun deviceDao(): DeviceDao; abstract fun chatDao(): ChatDao }

@androidx.room.Dao
interface DeviceDao {
    @androidx.room.Query("SELECT * FROM devices ORDER BY name ASC") fun getAllDevices(): Flow<List<Device>>
    @androidx.room.Query("SELECT * FROM devices WHERE id = :deviceId") suspend fun getDevice(deviceId: String): Device?
    @androidx.room.Query("SELECT * FROM devices WHERE status = 'ONLINE'") fun getOnlineDevices(): Flow<List<Device>>
    @androidx.room.Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE) suspend fun insertDevice(device: Device)
    @androidx.room.Update suspend fun updateDevice(device: Device)
    @androidx.room.Delete suspend fun deleteDevice(device: Device)
    @androidx.room.Query("DELETE FROM devices") suspend fun deleteAllDevices()
    @androidx.room.Query("SELECT * FROM devices WHERE isFavorite = 1") fun getFavoriteDevices(): Flow<List<Device>>
}

@androidx.room.Dao
interface ChatDao {
    @androidx.room.Query("SELECT * FROM chat_messages WHERE sessionId = :sessionId ORDER BY timestamp DESC") fun getMessages(sessionId: String): Flow<List<ChatMessage>>
    @androidx.room.Query("SELECT * FROM chat_messages WHERE sessionId = :sessionId ORDER BY timestamp DESC LIMIT :limit") suspend fun getRecentMessages(sessionId: String, limit: Int): List<ChatMessage>
    @androidx.room.Insert suspend fun insertMessage(message: ChatMessage)
    @androidx.room.Delete suspend fun deleteMessage(message: ChatMessage)
    @androidx.room.Query("DELETE FROM chat_messages WHERE sessionId = :sessionId") suspend fun clearSession(sessionId: String)
    @androidx.room.Query("DELETE FROM chat_messages WHERE timestamp < :timestamp") suspend fun deleteOldMessages(timestamp: Long)
}

@Singleton
class DatabaseProvider @Inject constructor(@ApplicationContext private val context: Context) {
    private val database: LINGOSDatabase by lazy {
        Room.databaseBuilder(context, LINGOSDatabase::class.java, "lingos_database")
            .fallbackToDestructiveMigration().build()
    }
    fun getDatabase(): LINGOSDatabase = database
}
