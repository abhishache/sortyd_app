package com.sortyd.app.data.model

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(
    tableName = "tasks",
    foreignKeys = [
        ForeignKey(
            entity = TaskListEntity::class,
            parentColumns = ["id"],
            childColumns = ["listId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("listId")]
)
data class TaskEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val listId: String,
    val title: String,
    val isCompleted: Boolean = false,
    val manuallyCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val weight: Double = 0.0,
    val reminderTime: Long? = null,
    val reminderIsOneTime: Boolean = false,
    @ColumnInfo(defaultValue = "0")
    val notificationLeadMinutes: Int = 0,
    val durationMinutes: Int? = null,
    val healthType: String? = null,
    val healthTarget: Double? = null,
    val sortOrder: Int = 0,
) {
    val isHealthTask: Boolean get() = healthType != null
}

// Domain model for UI consumption
data class SortydTask(
    val id: String = UUID.randomUUID().toString(),
    val listId: String = "",
    val title: String = "",
    val isCompleted: Boolean = false,
    val manuallyCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val weight: Double = 0.0,
    val reminderTime: Long? = null,
    val reminderIsOneTime: Boolean = false,
    val notificationLeadMinutes: Int = 0,
    val durationMinutes: Int? = null,
    val healthType: String? = null,
    val healthTarget: Double? = null,
    val sortOrder: Int = 0,
) {
    val isHealthTask: Boolean get() = healthType != null
}

fun TaskEntity.toDomain() = SortydTask(
    id = id, listId = listId, title = title,
    isCompleted = isCompleted, manuallyCompleted = manuallyCompleted,
    createdAt = createdAt, weight = weight,
    reminderTime = reminderTime, reminderIsOneTime = reminderIsOneTime,
    notificationLeadMinutes = notificationLeadMinutes,
    durationMinutes = durationMinutes,
    healthType = healthType, healthTarget = healthTarget,
    sortOrder = sortOrder,
)

fun SortydTask.toEntity() = TaskEntity(
    id = id, listId = listId, title = title,
    isCompleted = isCompleted, manuallyCompleted = manuallyCompleted,
    createdAt = createdAt, weight = weight,
    reminderTime = reminderTime, reminderIsOneTime = reminderIsOneTime,
    notificationLeadMinutes = notificationLeadMinutes,
    durationMinutes = durationMinutes,
    healthType = healthType, healthTarget = healthTarget,
    sortOrder = sortOrder,
)
