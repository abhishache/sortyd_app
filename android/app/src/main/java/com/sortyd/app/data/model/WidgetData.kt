package com.sortyd.app.data.model

import kotlinx.serialization.Serializable

@Serializable
data class WidgetData(
    val listId: String = "",
    val listName: String = "",
    val listEmoji: String = "",
    val completionFraction: Double = 0.0,
    val completionPercentage: Int = 0,
    val tasksDone: Int = 0,
    val tasksTotal: Int = 0,
    val streakDays: Int = 0,
    val tasks: List<WidgetTask> = emptyList(),
    val monthlySnapshots: Map<String, Double> = emptyMap(), // date string -> completion fraction
    val stepCount: Double? = null,
    val stepGoal: Double? = null,
    val caloriesBurned: Double? = null,
    val caloriesGoal: Double? = null,
    val lastCheckedTaskId: String? = null
)

@Serializable
data class WidgetTask(
    val id: String,
    val title: String,
    val isCompleted: Boolean,
    val weight: Double
)
