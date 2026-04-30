package com.sortyd.app.data.repository

import android.content.Context
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.sortyd.app.data.local.AppDatabase
import com.sortyd.app.data.local.AppStateEntity
import com.sortyd.app.model.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "sortyd_prefs")

@Singleton
class AppRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val db: AppDatabase
) {
    private val TAG = "AppRepository"
    private val gson: Gson = GsonBuilder().create()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val LANGUAGE_KEY = stringPreferencesKey("app_language")
    private val THEME_KEY = booleanPreferencesKey("is_dark_theme")
    private val INSTALL_DATE_KEY = longPreferencesKey("install_date")

    // ── Preferences ─────────────────────────────────────────────────────────

    val languageFlow: Flow<AppLanguage> = context.dataStore.data
        .map { prefs -> AppLanguage.from(prefs[LANGUAGE_KEY] ?: "en") }
        .catch { emit(AppLanguage.ENGLISH) }

    val isDarkThemeFlow: Flow<Boolean> = context.dataStore.data
        .map { prefs -> prefs[THEME_KEY] ?: true }
        .catch { emit(true) }

    val installDateFlow: Flow<Long> = context.dataStore.data
        .map { prefs ->
            prefs[INSTALL_DATE_KEY] ?: run {
                val now = System.currentTimeMillis()
                context.dataStore.edit { it[INSTALL_DATE_KEY] = now }
                now
            }
        }

    suspend fun setLanguage(lang: AppLanguage) {
        context.dataStore.edit { it[LANGUAGE_KEY] = lang.code }
    }

    suspend fun setDarkTheme(isDark: Boolean) {
        context.dataStore.edit { it[THEME_KEY] = isDark }
    }

    // ── App Data Persistence ─────────────────────────────────────────────────

    suspend fun load(): AppData {
        return try {
            val entity = db.appStateDao().get()
            if (entity != null) {
                gson.fromJson(entity.json, AppDataJson::class.java).toDomain()
            } else {
                AppData()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Load failed", e)
            AppData()
        }
    }

    private var saveJob: Job? = null

    fun save(data: AppData) {
        saveJob?.cancel()
        saveJob = scope.launch {
            delay(400)
            commitToDisk(data)
        }
    }

    suspend fun saveImmediately(data: AppData) {
        saveJob?.cancel()
        commitToDisk(data)
    }

    private suspend fun commitToDisk(data: AppData) {
        try {
            val json = gson.toJson(data.toJson())
            val entity = db.appStateDao().get()
            db.appStateDao().save(
                AppStateEntity(id = 1, json = json, lastResetDate = entity?.lastResetDate ?: 0L)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Save failed", e)
        }
    }

    suspend fun loadLastResetDate(): Long {
        return db.appStateDao().get()?.lastResetDate ?: 0L
    }

    suspend fun saveLastResetDate(date: Long) {
        val entity = db.appStateDao().get()
        if (entity != null) {
            db.appStateDao().save(entity.copy(lastResetDate = date))
        } else {
            db.appStateDao().save(AppStateEntity(json = "{}", lastResetDate = date))
        }
    }

    suspend fun reset() {
        db.appStateDao().save(AppStateEntity(json = "{}"))
    }
}

// ─── JSON Serialization Bridge ────────────────────────────────────────────────

data class AppDataJson(
    val lists: List<TaskListJson> = emptyList(),
    val activeListId: String? = null,
    val snapshots: List<DailySnapshotJson> = emptyList()
) {
    fun toDomain() = AppData(
        lists = lists.map { it.toDomain() },
        activeListId = activeListId,
        snapshots = snapshots.map { it.toDomain() }
    )
}

fun AppData.toJson() = AppDataJson(
    lists = lists.map { it.toJson() },
    activeListId = activeListId,
    snapshots = snapshots.map { it.toJson() }
)

data class TaskListJson(
    val id: String,
    val name: String,
    val emoji: String = "📋",
    val tasks: List<SortydTaskJson> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false,
    val isTodo: Boolean = false
) {
    fun toDomain() = TaskList(
        id = id, name = name, emoji = emoji,
        tasks = tasks.map { it.toDomain() },
        createdAt = createdAt, isArchived = isArchived, isTodo = isTodo
    )
}

fun TaskList.toJson() = TaskListJson(
    id = id, name = name, emoji = emoji,
    tasks = tasks.map { it.toJson() },
    createdAt = createdAt, isArchived = isArchived, isTodo = isTodo
)

data class SortydTaskJson(
    val id: String,
    val title: String,
    val isCompleted: Boolean = false,
    val manuallyCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val weight: Double = 0.0,
    val reminderTime: Long? = null,
    val reminderIsOneTime: Boolean = false,
    val healthType: String? = null,
    val healthTarget: Double? = null
) {
    fun toDomain() = SortydTask(
        id = id, title = title, isCompleted = isCompleted,
        manuallyCompleted = manuallyCompleted, createdAt = createdAt,
        weight = weight, reminderTime = reminderTime,
        reminderIsOneTime = reminderIsOneTime, healthType = healthType,
        healthTarget = healthTarget
    )
}

fun SortydTask.toJson() = SortydTaskJson(
    id = id, title = title, isCompleted = isCompleted,
    manuallyCompleted = manuallyCompleted, createdAt = createdAt,
    weight = weight, reminderTime = reminderTime,
    reminderIsOneTime = reminderIsOneTime, healthType = healthType,
    healthTarget = healthTarget
)

data class DailySnapshotJson(
    val id: String,
    val date: Long,
    val listId: String,
    val completionFraction: Double,
    val completedTaskIds: List<String> = emptyList()
) {
    fun toDomain() = DailySnapshot(
        id = id, date = date, listId = listId,
        completionFraction = completionFraction, completedTaskIds = completedTaskIds
    )
}

fun DailySnapshot.toJson() = DailySnapshotJson(
    id = id, date = date, listId = listId,
    completionFraction = completionFraction, completedTaskIds = completedTaskIds
)
