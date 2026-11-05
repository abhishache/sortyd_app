package com.sortyd.app.data.db

import androidx.room.*
import com.sortyd.app.data.model.*
import kotlinx.coroutines.flow.Flow

@Dao
interface SortydDao {

    // ── Lists ──
    @Transaction
    @Query("SELECT * FROM lists ORDER BY sortOrder ASC")
    fun getAllListsWithTasks(): Flow<List<TaskListWithTasks>>

    @Transaction
    @Query("SELECT * FROM lists WHERE id = :listId")
    fun getListWithTasks(listId: String): Flow<TaskListWithTasks?>

    @Transaction
    @Query("SELECT * FROM lists WHERE isArchived = 0 ORDER BY sortOrder ASC")
    fun getActiveLists(): Flow<List<TaskListWithTasks>>

    @Transaction
    @Query("SELECT * FROM lists WHERE isArchived = 0 ORDER BY sortOrder ASC")
    suspend fun getActiveListsSync(): List<TaskListWithTasks>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertList(list: TaskListEntity)

    @Update
    suspend fun updateList(list: TaskListEntity)

    @Delete
    suspend fun deleteList(list: TaskListEntity)

    @Query("UPDATE lists SET isArchived = :archived WHERE id = :listId")
    suspend fun setListArchived(listId: String, archived: Boolean)

    @Query("UPDATE lists SET name = :name, emoji = :emoji WHERE id = :listId")
    suspend fun renameList(listId: String, name: String, emoji: String)

    @Query("SELECT MAX(sortOrder) FROM lists")
    suspend fun getMaxListSortOrder(): Int?

    @Query("UPDATE lists SET sortOrder = :order WHERE id = :listId")
    suspend fun updateListSortOrder(listId: String, order: Int)

    // ── Tasks ──
    @Query("SELECT * FROM tasks WHERE listId = :listId ORDER BY sortOrder ASC")
    fun getTasksForList(listId: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE listId = :listId ORDER BY sortOrder ASC")
    suspend fun getTasksForListOnce(listId: String): List<TaskEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTask(task: TaskEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTasks(tasks: List<TaskEntity>)

    @Update
    suspend fun updateTask(task: TaskEntity)

    @Delete
    suspend fun deleteTask(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteTaskById(taskId: String)

    @Query("UPDATE tasks SET isCompleted = :completed, manuallyCompleted = :manuallyCompleted WHERE id = :taskId")
    suspend fun setTaskCompleted(taskId: String, completed: Boolean, manuallyCompleted: Boolean)

    @Query("UPDATE tasks SET sortOrder = :order WHERE id = :taskId")
    suspend fun updateTaskSortOrder(taskId: String, order: Int)

    @Query("SELECT MAX(sortOrder) FROM tasks WHERE listId = :listId")
    suspend fun getMaxTaskSortOrder(listId: String): Int?

    @Query("UPDATE tasks SET isCompleted = 0, manuallyCompleted = 0 WHERE listId = :listId AND notificationLeadMinutes = 0 AND reminderIsOneTime = 0")
    suspend fun resetTasksForList(listId: String)

    @Query("SELECT * FROM tasks WHERE healthType IS NOT NULL AND isCompleted = 0")
    suspend fun getIncompleteHealthTasks(): List<TaskEntity>

    // ── Snapshots ──
    @Query("SELECT * FROM snapshots WHERE listId = :listId ORDER BY date ASC")
    fun getSnapshotsForList(listId: String): Flow<List<SnapshotEntity>>

    @Query("SELECT * FROM snapshots ORDER BY date ASC")
    fun getAllSnapshots(): Flow<List<SnapshotEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSnapshot(snapshot: SnapshotEntity)

    @Query("SELECT * FROM snapshots WHERE listId = :listId AND date = :date LIMIT 1")
    suspend fun getSnapshotForDate(listId: String, date: Long): SnapshotEntity?

    @Query("DELETE FROM snapshots WHERE listId = :listId AND date = :date")
    suspend fun deleteSnapshotForDate(listId: String, date: Long)

    @Transaction
    suspend fun replaceSnapshotForDate(snapshot: SnapshotEntity) {
        deleteSnapshotForDate(snapshot.listId, snapshot.date)
        insertSnapshot(snapshot)
    }

    @Query("DELETE FROM snapshots")
    suspend fun deleteAllSnapshots()

    @Query("DELETE FROM snapshots WHERE date < :cutoffDate")
    suspend fun deleteSnapshotsOlderThan(cutoffDate: Long)
}
