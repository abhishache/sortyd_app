package com.sortyd.app.data.repository

import android.content.Context
import com.sortyd.app.data.db.SortydDao
import com.sortyd.app.data.db.SortydDatabase
import com.sortyd.app.data.model.*
import com.sortyd.app.data.preferences.UserPreferences
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.first
import com.sortyd.app.services.ReminderManager
import java.util.*

class SortydRepository(
    private val dao: SortydDao,
    val prefs: UserPreferences,
    private val context: Context? = null,
) {
    private suspend fun reconcileReminders() { context?.let { ReminderManager.reconcile(it) } }
    companion object {
        @Volatile
        private var INSTANCE: SortydRepository? = null

        fun getInstance(context: Context): SortydRepository {
            return INSTANCE ?: synchronized(this) {
                val db = SortydDatabase.getInstance(context)
                val prefs = UserPreferences(context)
                val instance = SortydRepository(db.sortydDao(), prefs, context.applicationContext)
                INSTANCE = instance
                instance
            }
        }
    }
    // ── Lists ──
    val allLists: Flow<List<TaskList>> = dao.getAllListsWithTasks().map { lists ->
        lists.map { it.toDomain() }
    }

    val activeLists: Flow<List<TaskList>> = dao.getActiveLists().map { lists ->
        lists.map { it.toDomain() }
    }

    fun getListWithTasks(listId: String): Flow<TaskList?> =
        dao.getListWithTasks(listId).map { it?.toDomain() }

    suspend fun createList(name: String, emoji: String, isTodo: Boolean = false): String {
        val id = UUID.randomUUID().toString()
        createListWithId(id, name, emoji, isTodo)
        return id
    }

    suspend fun createListWithId(id: String, name: String, emoji: String, isTodo: Boolean = false) {
        val maxOrder = dao.getMaxListSortOrder() ?: -1
        dao.insertList(
            TaskListEntity(
                id = id,
                name = name,
                emoji = emoji,
                isTodo = isTodo,
                sortOrder = maxOrder + 1,
            )
        )
    }

    suspend fun renameList(listId: String, name: String, emoji: String) {
        dao.renameList(listId, name, emoji)
    }

    suspend fun archiveList(listId: String) {
        dao.setListArchived(listId, true)
        reconcileReminders()
    }

    suspend fun unarchiveList(listId: String) {
        dao.setListArchived(listId, false)
        reconcileReminders()
    }

    suspend fun deleteList(listId: String) {
        dao.deleteList(TaskListEntity(id = listId, name = ""))
        reconcileReminders()
    }

    suspend fun updateListSortOrders(orderedIds: List<String>) {
        orderedIds.forEachIndexed { index, id ->
            dao.updateListSortOrder(id, index)
        }
    }

    // ── Tasks ──
    suspend fun addTask(
        listId: String,
        title: String,
        reminderTime: Long? = null,
        reminderIsOneTime: Boolean = false,
        notificationLeadMinutes: Int = 0,
        durationMinutes: Int? = null,
        healthType: String? = null,
        healthTarget: Double? = null,
    ): SortydTask {
        val maxOrder = dao.getMaxTaskSortOrder(listId) ?: -1
        val task = TaskEntity(
            listId = listId,
            title = title,
            reminderTime = reminderTime,
            reminderIsOneTime = reminderIsOneTime || notificationLeadMinutes > 0 ||
                dao.getListWithTasks(listId).first()?.list?.isTodo == true,
            notificationLeadMinutes = notificationLeadMinutes,
            durationMinutes = durationMinutes,
            healthType = healthType,
            healthTarget = healthTarget,
            sortOrder = maxOrder + 1,
        )
        dao.insertTask(task)
        recalculateWeights(listId)
        reconcileReminders()
        return task.toDomain()
    }

    suspend fun updateTask(task: SortydTask) {
        dao.updateTask(task.toEntity())
        reconcileReminders()
    }

    suspend fun deleteTask(taskId: String, listId: String? = null) {
        dao.deleteTaskById(taskId)
        if (listId != null) recalculateWeights(listId)
        context?.let { ReminderManager.cancelReminder(it, taskId) }
        reconcileReminders()
    }

    /** Re-inserts a previously deleted task with its original ID and position. */
    suspend fun restoreTask(task: SortydTask) {
        dao.insertTask(task.toEntity())
        recalculateWeights(task.listId)
        reconcileReminders()
    }

    suspend fun setTaskCompleted(taskId: String, completed: Boolean, manual: Boolean = true) {
        dao.setTaskCompleted(taskId, completed, manual)
        reconcileReminders()
    }

    suspend fun reorderTasks(listId: String, orderedTaskIds: List<String>) {
        orderedTaskIds.forEachIndexed { index, taskId ->
            dao.updateTaskSortOrder(taskId, index)
        }
    }

    private suspend fun recalculateWeights(listId: String) {
        val tasks = dao.getTasksForListOnce(listId)
        if (tasks.isEmpty()) return
        val weight = 1.0 / tasks.size
        tasks.forEach { dao.updateTask(it.copy(weight = weight)) }
    }

    // ── Snapshots ──
    fun getSnapshotsForList(listId: String): Flow<List<DailySnapshot>> =
        dao.getSnapshotsForList(listId).map { entities ->
            entities.map { it.toDomain() }
        }

    val allSnapshots: Flow<List<DailySnapshot>> = dao.getAllSnapshots().map { entities ->
        entities.map { it.toDomain() }
    }

    suspend fun saveSnapshot(snapshot: DailySnapshot) {
        // Remove existing snapshot for same date+list
        dao.replaceSnapshotForDate(snapshot.toEntity())
    }

    suspend fun getSnapshotForDate(listId: String, date: Long): DailySnapshot? {
        return dao.getSnapshotForDate(listId, date)?.toDomain()
    }

    // ── Daily Reset ──
    suspend fun resetTasksForList(listId: String) {
        dao.resetTasksForList(listId)
        reconcileReminders()
    }

    // ── Batch insert (for AI-generated tasks) ──
    suspend fun addTasks(listId: String, titles: List<String>) {
        val maxOrder = dao.getMaxTaskSortOrder(listId) ?: -1
        val tasks = titles.mapIndexed { index, title ->
            TaskEntity(
                listId = listId,
                title = title,
                sortOrder = maxOrder + 1 + index,
            )
        }
        dao.insertTasks(tasks)
        recalculateWeights(listId)
    }

    suspend fun clearAllSnapshots() = dao.deleteAllSnapshots()

    suspend fun pruneOldSnapshots(cutoffMs: Long) = dao.deleteSnapshotsOlderThan(cutoffMs)

    suspend fun permanentlyDeleteList(listId: String) {
        deleteList(listId)
    }

    // ── Widget Support ──
    fun getAllTasks(): Flow<List<SortydTask>> = dao.getAllListsWithTasks().map { lists ->
        lists.flatMap { it.tasks }.map { it.toDomain() }
    }

    // ── Cloud Sync API ──
    val authService = com.sortyd.app.data.AuthService()

    private fun parseCrossPlatformTimestampMs(obj: org.json.JSONObject, key: String, fallbackMs: Long = System.currentTimeMillis()): Long {
        if (!obj.has(key) || obj.isNull(key)) return fallbackMs
        val raw = obj.opt(key)
        when (raw) {
            is Number -> {
                val d = raw.toDouble()
                return when {
                    d > 100_000_000_000.0 -> d.toLong() // Epoch milliseconds (Android)
                    d > 1_200_000_000.0 && d < 4_100_000_000.0 -> (d * 1000.0).toLong() // Epoch seconds
                    else -> ((d + 978_307_200.0) * 1000.0).toLong() // Apple reference date seconds (since 2001-01-01)
                }
            }
            is String -> {
                val trimmed = raw.trim()
                trimmed.toDoubleOrNull()?.let { d ->
                    return when {
                        d > 100_000_000_000.0 -> d.toLong()
                        d > 1_200_000_000.0 && d < 4_100_000_000.0 -> (d * 1000.0).toLong()
                        else -> ((d + 978_307_200.0) * 1000.0).toLong()
                    }
                }
                return try {
                    java.time.Instant.parse(trimmed).toEpochMilli()
                } catch (_: Exception) {
                    try {
                        java.time.LocalDate.parse(trimmed.take(10))
                            .atStartOfDay(java.time.ZoneOffset.UTC)
                            .toInstant()
                            .toEpochMilli()
                    } catch (_: Exception) {
                        fallbackMs
                    }
                }
            }
            else -> return fallbackMs
        }
    }

    suspend fun exportAppDataJson(): org.json.JSONObject {
        val listsWithTasks = dao.getAllListsWithTasks().first()
        val allSnaps = dao.getAllSnapshots().first()
        val activeId = prefs.activeListId.first()

        val root = org.json.JSONObject()
        if (!activeId.isNullOrBlank()) {
            root.put("activeListID", activeId)
        }

        val listsArray = org.json.JSONArray()
        for (item in listsWithTasks) {
            val listObj = org.json.JSONObject().apply {
                put("id", item.list.id)
                put("name", item.list.name)
                put("emoji", item.list.emoji)
                put("isArchived", item.list.isArchived)
                put("isTodo", item.list.isTodo)
                put("sortOrder", item.list.sortOrder)
                put("createdAt", item.list.createdAt)
            }
            val tasksArray = org.json.JSONArray()
            for (t in item.tasks) {
                val tObj = org.json.JSONObject().apply {
                    put("id", t.id)
                    put("listId", t.listId)
                    put("title", t.title)
                    put("isCompleted", t.isCompleted)
                    put("manuallyCompleted", t.manuallyCompleted)
                    put("weight", t.weight)
                    put("sortOrder", t.sortOrder)
                    put("createdAt", t.createdAt)
                    put("reminderIsOneTime", t.reminderIsOneTime)
                    put("notificationLeadMinutes", t.notificationLeadMinutes)
                    if (t.reminderTime != null) put("reminderTime", t.reminderTime)
                    if (t.durationMinutes != null) put("durationMinutes", t.durationMinutes)
                    if (t.healthType != null) put("healthType", t.healthType)
                    if (t.healthTarget != null) put("healthTarget", t.healthTarget)
                }
                tasksArray.put(tObj)
            }
            listObj.put("tasks", tasksArray)
            listsArray.put(listObj)
        }
        root.put("lists", listsArray)

        val snapArray = org.json.JSONArray()
        for (s in allSnaps) {
            val parsedTaskIds = try {
                org.json.JSONArray(s.completedTaskIds)
            } catch (_: Exception) {
                org.json.JSONArray()
            }
            val sObj = org.json.JSONObject().apply {
                put("id", s.id)
                put("date", s.date)
                put("listID", s.listId)
                put("listId", s.listId)
                put("completionFraction", s.completionFraction)
                put("completedTaskIDs", parsedTaskIds)
                put("completedTaskIds", s.completedTaskIds)
            }
            snapArray.put(sObj)
        }
        root.put("snapshots", snapArray)
        return root
    }

    suspend fun importAppDataJson(json: org.json.JSONObject) {
        val existingListsWithTasks = dao.getAllListsWithTasks().first()
        val listsArr = json.optJSONArray("lists")
        if (listsArr != null) {
            for (i in 0 until listsArr.length()) {
                val lObj = listsArr.optJSONObject(i) ?: continue
                val remoteListId = lObj.optString("id", UUID.randomUUID().toString())
                val name = lObj.optString("name", "List")
                val emoji = lObj.optString("emoji", "📋")
                val isArchived = lObj.optBoolean("isArchived", false)
                val isTodo = lObj.optBoolean("isTodo", false)
                val isWeekly = lObj.optBoolean("isWeekly", false)
                if (isWeekly) continue

                val sortOrder = lObj.optInt("sortOrder", i)
                val createdAt = parseCrossPlatformTimestampMs(lObj, "createdAt")

                // Match existing local list by ID, isTodo, or normalized name+emoji so zero local lists are lost or duplicated
                val matchedLocal = existingListsWithTasks.firstOrNull { local ->
                    local.list.id.equals(remoteListId, ignoreCase = true) ||
                        (local.list.isTodo && isTodo) ||
                        (!local.list.isTodo && !isTodo &&
                            local.list.name.trim().equals(name.trim(), ignoreCase = true) &&
                            local.list.emoji == emoji)
                }

                val targetListId = matchedLocal?.list?.id ?: remoteListId

                dao.insertList(
                    TaskListEntity(
                        id = targetListId,
                        name = matchedLocal?.list?.name ?: name,
                        emoji = matchedLocal?.list?.emoji ?: emoji,
                        createdAt = matchedLocal?.list?.createdAt ?: createdAt,
                        isArchived = isArchived,
                        isTodo = isTodo,
                        sortOrder = matchedLocal?.list?.sortOrder ?: sortOrder
                    )
                )

                val tasksArr = lObj.optJSONArray("tasks")
                if (tasksArr != null) {
                    val existingTasks = dao.getTasksForListOnce(targetListId)
                    val taskEntities = mutableListOf<TaskEntity>()
                    for (j in 0 until tasksArr.length()) {
                        val tObj = tasksArr.optJSONObject(j) ?: continue
                        val remoteTaskId = tObj.optString("id", UUID.randomUUID().toString())
                        val title = tObj.optString("title", "")
                        val matchedTask = existingTasks.firstOrNull { lt ->
                            lt.id.equals(remoteTaskId, ignoreCase = true) ||
                                lt.title.trim().equals(title.trim(), ignoreCase = true)
                        }
                        val targetTaskId = matchedTask?.id ?: remoteTaskId
                        val parsedReminder = if (tObj.has("reminderTime") && !tObj.isNull("reminderTime")) {
                            parseCrossPlatformTimestampMs(tObj, "reminderTime")
                        } else {
                            matchedTask?.reminderTime
                        }
                        taskEntities.add(
                            TaskEntity(
                                id = targetTaskId,
                                listId = targetListId,
                                title = matchedTask?.title ?: title,
                                isCompleted = (matchedTask?.isCompleted == true) || tObj.optBoolean("isCompleted", false),
                                manuallyCompleted = (matchedTask?.manuallyCompleted == true) || tObj.optBoolean("manuallyCompleted", false),
                                createdAt = matchedTask?.createdAt ?: parseCrossPlatformTimestampMs(tObj, "createdAt"),
                                weight = tObj.optDouble("weight", 0.0),
                                reminderTime = parsedReminder,
                                reminderIsOneTime = tObj.optBoolean("reminderIsOneTime", matchedTask?.reminderIsOneTime ?: false),
                                notificationLeadMinutes = tObj.optInt("notificationLeadMinutes", matchedTask?.notificationLeadMinutes ?: 0),
                                durationMinutes = if (tObj.has("durationMinutes") && !tObj.isNull("durationMinutes")) tObj.optInt("durationMinutes") else matchedTask?.durationMinutes,
                                healthType = if (tObj.has("healthType") && !tObj.isNull("healthType")) tObj.optString("healthType") else matchedTask?.healthType,
                                healthTarget = if (tObj.has("healthTarget") && !tObj.isNull("healthTarget")) tObj.optDouble("healthTarget") else matchedTask?.healthTarget,
                                sortOrder = matchedTask?.sortOrder ?: tObj.optInt("sortOrder", j)
                            )
                        )
                    }
                    if (taskEntities.isNotEmpty()) {
                        dao.insertTasks(taskEntities)
                        recalculateWeights(targetListId)
                    }
                }
            }
        }

        val snapsArr = json.optJSONArray("snapshots")
        if (snapsArr != null) {
            for (i in 0 until snapsArr.length()) {
                val sObj = snapsArr.optJSONObject(i) ?: continue
                val completedJsonStr = when {
                    sObj.optJSONArray("completedTaskIDs") != null -> sObj.getJSONArray("completedTaskIDs").toString()
                    sObj.optJSONArray("completedTaskIds") != null -> sObj.getJSONArray("completedTaskIds").toString()
                    else -> sObj.optString("completedTaskIds", sObj.optString("completedTaskIDs", "[]"))
                }
                dao.insertSnapshot(
                    SnapshotEntity(
                        id = sObj.optString("id", UUID.randomUUID().toString()),
                        date = parseCrossPlatformTimestampMs(sObj, "date"),
                        listId = sObj.optString("listId", sObj.optString("listID", "")),
                        completionFraction = sObj.optDouble("completionFraction", 0.0),
                        completedTaskIds = completedJsonStr
                    )
                )
            }
        }

        val currentActive = prefs.activeListId.first()
        val remoteActiveId = json.optString("activeListID")
        if (currentActive.isNullOrBlank() && !remoteActiveId.isNullOrBlank()) {
            prefs.setActiveListId(remoteActiveId)
        }
    }

    suspend fun pushToCloud(allowDelete: Boolean = true): Result<Boolean> {
        val token = prefs.authToken.first() ?: return Result.failure(Exception("Not signed in"))
        val dataJson = exportAppDataJson()
        val res = authService.pushData(dataJson, token, allowDelete = allowDelete)
        if (res.isSuccess) {
            prefs.setLastSyncTime(System.currentTimeMillis())
        }
        return res
    }

    suspend fun syncWithCloud(): Result<Boolean> {
        val token = prefs.authToken.first() ?: return Result.failure(Exception("Not signed in"))
        val pullRes = authService.pullData(token)
        if (pullRes.isFailure) return Result.failure(pullRes.exceptionOrNull() ?: Exception("Sync error"))
        val remoteData = pullRes.getOrNull()
        if (remoteData != null) {
            importAppDataJson(remoteData)
        }
        // Always push the union-merged workspace back to Supabase so pre-existing local lists are preserved in the cloud
        pushToCloud(allowDelete = false)
        prefs.setLastSyncTime(System.currentTimeMillis())
        return Result.success(true)
    }
}
