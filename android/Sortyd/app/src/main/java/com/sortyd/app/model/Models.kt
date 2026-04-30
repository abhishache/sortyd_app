package com.sortyd.app.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

// ─── Enums ───────────────────────────────────────────────────────────────────

enum class AppLanguage(val code: String, val displayName: String, val isRTL: Boolean) {
    ENGLISH("en", "English", false),
    SPANISH("es", "Español", false),
    ARABIC("ar", "العربية", true);

    companion object {
        fun from(code: String) = entries.firstOrNull { it.code == code } ?: ENGLISH
    }
}

enum class HealthTaskType(
    val rawValue: String,
    val unit: String,
    val icon: String,
    val defaultTarget: Double
) {
    STEPS("steps", "steps", "directions_walk", 10000.0),
    CALORIES("calories", "kcal", "local_fire_department", 500.0),
    DISTANCE("distance", "km", "directions_run", 5.0),
    NONE("none", "", "", 0.0);

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.rawValue == raw } ?: NONE

        private val stepKeywords = listOf(
            "steps", "walk", "walking", "10k", "pasos", "caminar", "خطوات", "مشي"
        )
        private val calorieKeywords = listOf(
            "calorie", "calories", "burn", "workout", "gym", "kcal",
            "سعرات", "حرق", "calorías", "quemar"
        )
        private val distanceKeywords = listOf(
            "run", "jog", "5km", "km", "kilometer", "كم", "كيلومتر", "correr", "corr"
        )
        private val exclusions = listOf(
            "energy drink", "energy bill", "step by step", "next step",
            "walk through", "cake walk", "burn out", "burnish"
        )

        fun detect(title: String): HealthTaskType {
            val lower = title.lowercase()
            if (exclusions.any { lower.contains(it) }) return NONE
            return when {
                distanceKeywords.any { lower.contains(it) } -> DISTANCE
                calorieKeywords.any { lower.contains(it) } -> CALORIES
                stepKeywords.any { lower.contains(it) } -> STEPS
                else -> NONE
            }
        }
    }
}

// ─── Domain Models (plain data classes, not Room entities) ───────────────────

data class SortydTask(
    val id: String = UUID.randomUUID().toString(),
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
    val isHealthTask: Boolean get() = healthType != null && healthType != HealthTaskType.NONE.rawValue
    val resolvedHealthType: HealthTaskType get() = HealthTaskType.from(healthType)
}

data class TaskList(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val emoji: String = "📋",
    val tasks: List<SortydTask> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val isArchived: Boolean = false,
    val isTodo: Boolean = false
) {
    val cleanName: String get() = name.trimStart { it.code > 127 || it == ' ' }

    fun recalculateWeights(): TaskList {
        val count = tasks.size
        if (count == 0) return this
        val weight = 1.0 / count
        return copy(tasks = tasks.map { it.copy(weight = weight) })
    }

    fun completionFraction(healthValues: Map<String, Double> = emptyMap()): Double {
        if (tasks.isEmpty()) return 0.0
        var total = 0.0
        for (task in tasks) {
            val w = task.weight
            if (task.isCompleted || task.manuallyCompleted) {
                total += w
            } else if (task.isHealthTask) {
                val progress = healthValues[task.id] ?: 0.0
                total += w * progress.coerceIn(0.0, 1.0)
            }
        }
        return total.coerceIn(0.0, 1.0)
    }

    fun completionPercentage(healthValues: Map<String, Double> = emptyMap()): Int =
        (completionFraction(healthValues) * 100).toInt()
}

data class DailySnapshot(
    val id: String = UUID.randomUUID().toString(),
    val date: Long,
    val listId: String,
    val completionFraction: Double,
    val completedTaskIds: List<String> = emptyList()
) {
    val completionPercentage: Int get() = (completionFraction * 100).toInt()
}

data class AppData(
    val lists: List<TaskList> = emptyList(),
    val activeListId: String? = null,
    val snapshots: List<DailySnapshot> = emptyList()
) {
    val activeList: TaskList?
        get() {
            val live = lists.filter { !it.isArchived }
            return live.firstOrNull { it.id == activeListId } ?: live.firstOrNull()
        }

    val activeRegularList: TaskList?
        get() {
            val live = lists.filter { !it.isArchived && !it.isTodo }
            return live.firstOrNull { it.id == activeListId } ?: live.firstOrNull()
        }
}

// ─── AI Models ───────────────────────────────────────────────────────────────

data class WeeklyRecap(
    val headline: String,
    val summary: String,
    val highlight: String,
    val nudge: String,
    val grade: String,
    val gradeReason: String
)

data class ProcrastinationFlag(
    val taskTitle: String,
    val diagnosis: String,
    val suggestion: String,
    val completionRate: Int
)

data class ListHealthReport(
    val score: Int,
    val label: String,
    val insight: String,
    val tips: List<String>
)

data class BehaviouralPillar(
    val name: String,
    val score: Int,
    val status: String,
    val tasks: List<String>,
    val insight: String,
    val advice: String
)

data class BehaviouralAnalysis(
    val pillars: List<BehaviouralPillar>,
    val overallInsight: String,
    val criticalPillar: String
)

data class ParsedTask(
    val title: String,
    val hasReminder: Boolean,
    val reminderHour: Int?,
    val reminderMinute: Int?
)

data class StarterListTask(
    val title: String,
    val healthType: String = HealthTaskType.NONE.rawValue,
    val healthTarget: Double? = null,
    val reminderHour: Int? = null,
    val reminderMinute: Int? = null
)

data class StarterList(
    val emoji: String,
    val listName: String,
    val tasks: List<StarterListTask>
)

// ─── Reminder Conflict ────────────────────────────────────────────────────────

data class ReminderConflictInfo(
    val conflictingTaskTitle: String,
    val hour: Int,
    val minute: Int
)
