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
}
