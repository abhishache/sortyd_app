package com.sortyd.app.data.local

import androidx.room.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.sortyd.app.model.AppData
import com.sortyd.app.model.DailySnapshot
import com.sortyd.app.model.SortydTask
import com.sortyd.app.model.TaskList

// ─── Room Entity for persisting entire AppData as JSON ───────────────────────
// We mirror iOS's single-blob JSON approach for simplicity and exact parity.

@Entity(tableName = "app_state")
data class AppStateEntity(
    @PrimaryKey val id: Int = 1,
    val json: String,
    val lastResetDate: Long = 0L
)

// ─── Type Converters ──────────────────────────────────────────────────────────

class Converters {
    private val gson = Gson()

    @TypeConverter fun fromStringList(v: List<String>): String = gson.toJson(v)
    @TypeConverter fun toStringList(v: String): List<String> =
        gson.fromJson(v, object : TypeToken<List<String>>() {}.type)
}

// ─── DAO ─────────────────────────────────────────────────────────────────────

@Dao
interface AppStateDao {
    @Query("SELECT * FROM app_state WHERE id = 1")
    suspend fun get(): AppStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: AppStateEntity)

    @Query("UPDATE app_state SET lastResetDate = :date WHERE id = 1")
    suspend fun updateLastResetDate(date: Long)
}

// ─── Database ────────────────────────────────────────────────────────────────

@Database(entities = [AppStateEntity::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun appStateDao(): AppStateDao
}
