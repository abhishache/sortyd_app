package com.sortyd.app.widget

import android.content.Context
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import com.sortyd.app.data.model.TaskList
import com.sortyd.app.data.model.WidgetData
import com.sortyd.app.data.model.WidgetTask
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object WidgetManager {

    /**
     * Build a WidgetData snapshot from a TaskList + daily snapshots.
     * Called both from the app (on any task change) and from WidgetToggleHelper.
     */
    fun buildWidgetData(
        list:           TaskList,
        snapshots:      Map<String, Double>,
        lastCheckedId:  String? = null,
        stepCount:      Double? = null,
        stepGoal:       Double? = null,
        caloriesBurned: Double? = null,
        caloriesGoal:   Double? = null
    ): WidgetData {
        val tasks   = list.tasks
        val done    = tasks.count { it.isCompleted }
        val total   = tasks.size
        val frac    = if (total > 0) done.toDouble() / total else 0.0
        val pct     = (frac * 100).toInt()

        // Best-streak from snapshots (consecutive 80%+ days)
        val sortedSnaps = snapshots.entries.sortedBy { it.key }
        var streak = 0; var best = 0; var cur = 0
        for (entry in sortedSnaps.reversed()) {
            if (entry.value >= 0.8) { cur++; best = maxOf(best, cur) } else { cur = 0 }
        }
        streak = best

        return WidgetData(
            listId               = list.id,
            listName             = list.cleanName,
            listEmoji            = list.emoji,
            completionFraction   = frac,
            completionPercentage = pct,
            tasksDone            = done,
            tasksTotal           = total,
            streakDays           = streak,
            tasks                = tasks.map { WidgetTask(it.id, it.title, it.isCompleted, it.weight) },
            monthlySnapshots     = snapshots,
            stepCount            = stepCount,
            stepGoal             = stepGoal,
            caloriesBurned       = caloriesBurned,
            caloriesGoal         = caloriesGoal,
            lastCheckedTaskId    = lastCheckedId
        )
    }

    /**
     * Push WidgetData to all three widget classes.
     */
    suspend fun updateAllWidgets(context: Context, data: WidgetData) {
        val json = Json.encodeToString(data)
        val key  = stringPreferencesKey("widget_data")

        // Small widget
        GlanceAppWidgetManager(context)
            .getGlanceIds(SortydWidget::class.java)
            .forEach { id ->
                updateAppWidgetState(context, id) { it[key] = json }
                SortydWidget.update(context, id)
            }

        // Medium interactive widget
        GlanceAppWidgetManager(context)
            .getGlanceIds(SortydMediumWidget::class.java)
            .forEach { id ->
                updateAppWidgetState(context, id) { it[key] = json }
                SortydMediumWidget.update(context, id)
            }

        // Heatmap calendar widget
        GlanceAppWidgetManager(context)
            .getGlanceIds(SortydHeatmapWidget::class.java)
            .forEach { id ->
                updateAppWidgetState(context, id) { it[key] = json }
                SortydHeatmapWidget.update(context, id)
            }

        // Large analytics widget
        GlanceAppWidgetManager(context)
            .getGlanceIds(SortydLargeWidget::class.java)
            .forEach { id ->
                updateAppWidgetState(context, id) { it[key] = json }
                SortydLargeWidget.update(context, id)
            }
    }

    // Legacy helper — kept for callers that pass a TaskList directly
    suspend fun updateWidget(context: Context, list: TaskList, snapshots: Map<String, Double>) {
        updateAllWidgets(context, buildWidgetData(list, snapshots))
    }
}
