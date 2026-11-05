package com.sortyd.app.data.model

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.Relation
import java.util.UUID

@Entity(tableName = "lists")
data class TaskListEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    val emoji: String = "📋",
    val createdAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false,
    val isTodo: Boolean = false,
    val sortOrder: Int = 0,
)

data class TaskListWithTasks(
    @Embedded val list: TaskListEntity,
    @Relation(parentColumn = "id", entityColumn = "listId")
    val tasks: List<TaskEntity>,
)

// Domain model for UI
data class TaskList(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val emoji: String = "📋",
    val tasks: List<SortydTask> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false,
    val isTodo: Boolean = false,
    val sortOrder: Int = 0,
) {
    val cleanName: String
        get() {
            var n = name.trim()
            while (n.isNotEmpty() && isEmojiCodePoint(n.codePointAt(0))) {
                n = n.substring(Character.charCount(n.codePointAt(0))).trim()
            }
            return n
        }

    fun completionFraction(healthValues: Map<String, Double> = emptyMap()): Double {
        if (tasks.isEmpty()) return 0.0
        val totalWeight = tasks.sumOf { it.weight }
        return if (totalWeight > 0) {
            tasks.sumOf { task ->
                if (task.isHealthTask) {
                    if (task.isCompleted) task.weight
                    else (healthValues[task.id] ?: 0.0) * task.weight
                } else if (task.isCompleted) {
                    task.weight
                } else 0.0
            }
        } else {
            tasks.count { it.isCompleted }.toDouble() / tasks.size
        }
    }

    val completionFraction: Double get() = completionFraction()
    val completionPercentage: Int get() = (completionFraction * 100).toInt()

    companion object {
        /** Recalculate equal weights for all tasks. */
        fun withRecalculatedWeights(list: TaskList): TaskList {
            if (list.tasks.isEmpty()) return list
            val w = 1.0 / list.tasks.size
            return list.copy(tasks = list.tasks.map { it.copy(weight = w) })
        }
    }
}

fun TaskListWithTasks.toDomain(): TaskList {
    val sortedTasks = tasks.sortedBy { it.sortOrder }.map { it.toDomain() }
    return TaskList(
        id = list.id,
        name = list.name,
        emoji = list.emoji,
        tasks = sortedTasks,
        createdAt = list.createdAt,
        isArchived = list.isArchived,
        isTodo = list.isTodo,
        sortOrder = list.sortOrder,
    )
}

// Helper to check if a codepoint is an emoji
private fun isEmojiCodePoint(codePoint: Int): Boolean {
    return codePoint in 0x1F600..0x1F64F ||
            codePoint in 0x1F300..0x1F5FF ||
            codePoint in 0x1F680..0x1F6FF ||
            codePoint in 0x1F1E0..0x1F1FF ||
            codePoint in 0x2600..0x26FF ||
            codePoint in 0x2700..0x27BF ||
            codePoint in 0xFE00..0xFE0F ||
            codePoint in 0x1F900..0x1F9FF ||
            codePoint in 0x1FA00..0x1FA6F ||
            codePoint in 0x1FA70..0x1FAFF ||
            codePoint in 0x200D..0x200D ||
            codePoint in 0xE0020..0xE007F
}
