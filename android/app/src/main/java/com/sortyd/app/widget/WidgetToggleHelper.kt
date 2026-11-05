package com.sortyd.app.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import com.sortyd.app.data.repository.SortydRepository
import com.sortyd.app.data.model.WidgetData
import com.sortyd.app.data.model.WidgetTask
import kotlinx.coroutines.flow.first
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import androidx.glance.appwidget.updateAll
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.MutablePreferences
import java.time.LocalDate
import java.time.format.DateTimeFormatter
object WidgetToggleHelper {

    suspend fun toggle(context: Context, taskId: String) {
        val repository = SortydRepository.getInstance(context)
        
        // Find which list the task belongs to
        val allTasks = repository.getAllTasks().first()
        val task = allTasks.find { it.id == taskId } ?: return
        
        // 1. Toggle in Database
        repository.setTaskCompleted(taskId, !task.isCompleted, true)
        
        // 2. Synchronize Widget Data
        sync(context, repository)
    }

    suspend fun sync(context: Context, repository: SortydRepository) {
        
        // 1. Get the active list
        val activeListId = repository.prefs.activeListId.first()
        val lists = repository.activeLists.first()
        val list = if (activeListId != null) {
            lists.find { it.id == activeListId } ?: lists.firstOrNull()
        } else {
            lists.firstOrNull()
        } ?: return

        // 2. Get snapshots for this specific list
        val snapshots = repository.getSnapshotsForList(list.id).first()
        val snapshotsMap = snapshots.associate { it.date.toString() to it.completionFraction }

        // 3. Build data and update
        val data = WidgetManager.buildWidgetData(
            list = list,
            snapshots = snapshotsMap
            // health metrics would ideally be fetched here too if available
        )
        
        WidgetManager.updateAllWidgets(context, data)

    }

    suspend fun refreshAll(context: Context) {
        SortydWidget.updateAll(context)
        SortydMediumWidget.updateAll(context)
        SortydLargeWidget.updateAll(context)
        SortydHeatmapWidget.updateAll(context)
    }
}

class ToggleTaskCallback : ActionCallback {
    companion object {
        val TASK_ID_KEY = ActionParameters.Key<String>("taskId")
    }

    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val taskId = parameters[TASK_ID_KEY] ?: return
        
        // 1. Update DB & Refresh internal state via Helper
        WidgetToggleHelper.toggle(context, taskId)
        
        // 2. Explicitly refresh the calling widget instance
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { it }
    }
}
