package com.sortyd.app.services

import android.content.Context
import androidx.work.*
import com.sortyd.app.data.db.SortydDatabase
import com.sortyd.app.data.model.HealthTaskType
import java.util.concurrent.TimeUnit

class HealthSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            val manager = HealthConnectManager(applicationContext)
            if (!manager.hasPermissions()) return Result.success()

            val snapshot = manager.fetchToday()

            val dao = SortydDatabase.getInstance(applicationContext).sortydDao()
            val repo = com.sortyd.app.data.repository.SortydRepository.getInstance(applicationContext)
            val incompleteTasks = dao.getIncompleteHealthTasks()
            var anyCompleted = false

            for (task in incompleteTasks) {
                val target = task.healthTarget ?: continue
                val current = when (task.healthType) {
                    HealthTaskType.STEPS.rawValue    -> snapshot.steps
                    HealthTaskType.CALORIES.rawValue -> snapshot.calories
                    HealthTaskType.DISTANCE.rawValue -> snapshot.distanceKm
                    else -> continue
                }
                if (current >= target) {
                    repo.setTaskCompleted(task.id, completed = true, manual = false)
                    anyCompleted = true
                }
            }

            if (anyCompleted) {
                // Refresh snapshots for affected lists to ensure AI/Analytics are up to date
                val activeLists = dao.getActiveListsSync()
                val today = ReminderPolicy.dayStart(System.currentTimeMillis())
                
                activeLists.forEach { listWithTasks ->
                    val tasks = listWithTasks.tasks
                    val completedIds = tasks.filter { it.isCompleted }.map { it.id }
                    val fraction = if (tasks.isNotEmpty()) completedIds.size.toDouble() / tasks.size else 0.0
                    
                    val snapshot = com.sortyd.app.data.model.DailySnapshot(
                        date = today,
                        listId = listWithTasks.list.id,
                        completionFraction = fraction,
                        completedTaskIds = completedIds
                    )
                    repo.saveSnapshot(snapshot)
                }
                
                // Note: Full widget update with health stats is best handled when the app is foregrounded 
                // or via a dedicated widget update flow that has access to the full HealthSnapshot.
                // For now, we've ensured the DB and Snapshots are consistent.
            }

            Result.success()
        } catch (_: Exception) {
            Result.retry()
        }
    }

    companion object {
        private const val WORK_NAME = "sortyd_health_sync"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<HealthSyncWorker>(
                15, TimeUnit.MINUTES,
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
