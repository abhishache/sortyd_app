package com.sortyd.app.data.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(
    tableName = "snapshots",
    indices = [Index(value = ["listId", "date"], unique = true)],
)
data class SnapshotEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long,
    val listId: String,
    val completionFraction: Double,
    val completedTaskIds: String = "[]", // JSON array of task IDs
)

// Domain model
data class DailySnapshot(
    val id: String = UUID.randomUUID().toString(),
    val date: Long,
    val listId: String,
    val completionFraction: Double,
    val completedTaskIds: List<String> = emptyList(),
) {
    val completionPercentage: Int get() = (completionFraction * 100).toInt()
}

fun SnapshotEntity.toDomain(): DailySnapshot {
    val ids = completedTaskIds
        .removeSurrounding("[", "]")
        .split(",")
        .map { it.trim().removeSurrounding("\"") }
        .filter { it.isNotBlank() }
    return DailySnapshot(
        id = id,
        date = date,
        listId = listId,
        completionFraction = completionFraction,
        completedTaskIds = ids,
    )
}

fun DailySnapshot.toEntity(): SnapshotEntity {
    val idsJson = completedTaskIds.joinToString(",") { "\"$it\"" }
    return SnapshotEntity(
        id = id,
        date = date,
        listId = listId,
        completionFraction = completionFraction,
        completedTaskIds = "[$idsJson]",
    )
}
