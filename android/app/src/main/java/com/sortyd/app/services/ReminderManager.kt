package com.sortyd.app.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.sortyd.app.data.db.SortydDatabase
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

object ReminderManager {
    private val reconciliationLock = Mutex()

    suspend fun reconcile(context: Context) = reconciliationLock.withLock {
        val lists = SortydDatabase.getInstance(context).sortydDao().getActiveListsSync()
        val prefs = context.getSharedPreferences("reminder_registry", Context.MODE_PRIVATE)
        val previous = prefs.getStringSet("task_ids", emptySet()).orEmpty().toSet()
        val current = lists.flatMap { it.tasks }.map { it.id }.toSet()
        (previous - current).forEach { cancelReminder(context, it) }
        lists.forEach { list ->
            list.tasks.forEach { task ->
                val once = task.reminderIsOneTime || list.list.isTodo || task.notificationLeadMinutes > 0
                val fireAt = ReminderPolicy.fireTime(task.reminderTime, once,
                    task.notificationLeadMinutes, completed = task.isCompleted)
                if (fireAt == null) cancelReminder(context, task.id)
                else scheduleReminder(context, task.id, task.title, task.reminderTime!!,
                    task.notificationLeadMinutes, once)
            }
        }
        prefs.edit().putStringSet("task_ids", current).apply()
    }

    fun scheduleReminder(
        context: Context,
        taskId: String,
        taskTitle: String,
        timeInMillis: Long,
        notificationLeadMinutes: Int = 0,
        isOneTime: Boolean = false,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val notificationTimeInMillis = ReminderPolicy.fireTime(timeInMillis, isOneTime, notificationLeadMinutes)
        if (notificationTimeInMillis == null) {
            cancelReminder(context, taskId)
            return
        }

        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra("task_id", taskId)
            putExtra("task_title", taskTitle)
            putExtra("reminder_time", timeInMillis)
            putExtra("notification_lead_minutes", notificationLeadMinutes)
            putExtra("reminder_is_one_time", isOneTime)
            putExtra("notification_fire_time", notificationTimeInMillis)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            taskId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, notificationTimeInMillis, pendingIntent)
                } else {
                    // Fallback to inexact alarm if permission is denied, to prevent crash
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, notificationTimeInMillis, pendingIntent)
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, notificationTimeInMillis, pendingIntent)
            }
        } catch (e: SecurityException) {
            // Fallback for any edge case SecurityExceptions
            try {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, notificationTimeInMillis, pendingIntent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }

    fun scheduleCoachSummary(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra("task_id", "COACH_SUMMARY")
            putExtra("task_title", "Daily AI Insight")
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, "COACH_SUMMARY".hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 20) // 8 PM
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (before(java.util.Calendar.getInstance())) add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
            }
        } catch (_: SecurityException) {}
    }

    fun cancelReminder(context: Context, taskId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            taskId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager)
            .cancel(taskId.hashCode())
    }

    // Cancel the previously-scheduled 4 AM TO DO reset notification (feature removed).
    fun cancelTodoResetNotification(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, "TODO_RESET".hashCode(), intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
}
