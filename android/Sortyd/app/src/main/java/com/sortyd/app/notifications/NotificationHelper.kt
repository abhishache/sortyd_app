package com.sortyd.app.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.sortyd.app.MainActivity
import com.sortyd.app.R
import com.sortyd.app.model.SortydTask
import com.sortyd.app.model.TaskList
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NotificationHelper @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val TAG = "NotificationHelper"

    companion object {
        const val CHANNEL_REMINDERS = "sortyd_reminders"
        const val CHANNEL_DAILY = "sortyd_daily"
        const val CHANNEL_RESET = "sortyd_reset"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_NOTIF_ID = "notif_id"
    }

    init {
        createChannels()
    }

    private fun createChannels() {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        listOf(
            NotificationChannel(CHANNEL_REMINDERS, "Task Reminders", NotificationManager.IMPORTANCE_HIGH),
            NotificationChannel(CHANNEL_DAILY, "Daily Summary", NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel(CHANNEL_RESET, "List Reset", NotificationManager.IMPORTANCE_LOW)
        ).forEach { nm.createNotificationChannel(it) }
    }

    fun scheduleTaskReminder(task: SortydTask, list: TaskList) {
        val reminderTime = task.reminderTime ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_TASK_ID, task.id)
            putExtra("list_name", "${list.emoji} ${list.cleanName}")
            putExtra("task_title", task.title)
            putExtra("notif_id", task.id.hashCode())
        }
        val pending = PendingIntent.getBroadcast(
            context, task.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (task.reminderIsOneTime) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminderTime, pending)
            } catch (e: SecurityException) {
                Log.e(TAG, "Exact alarm permission denied", e)
                alarmManager.set(AlarmManager.RTC_WAKEUP, reminderTime, pending)
            }
        } else {
            // Daily repeating — fire at the time portion of reminderTime each day
            val cal = Calendar.getInstance().apply {
                timeInMillis = reminderTime
                val now = Calendar.getInstance()
                set(Calendar.YEAR, now.get(Calendar.YEAR))
                set(Calendar.MONTH, now.get(Calendar.MONTH))
                set(Calendar.DAY_OF_MONTH, now.get(Calendar.DAY_OF_MONTH))
                if (before(now)) add(Calendar.DAY_OF_MONTH, 1)
            }
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                cal.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pending
            )
        }
    }

    fun cancelTaskReminder(taskId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context, taskId.hashCode(), intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        alarmManager.cancel(pending)
        pending.cancel()
    }

    fun scheduleDailyReset() {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailyResetReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 9999, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 4)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            if (before(Calendar.getInstance())) add(Calendar.DAY_OF_MONTH, 1)
        }
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            cal.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending
        )
    }

    fun scheduleDailySummary(pct: Int, listName: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailySummaryReceiver::class.java).apply {
            putExtra("pct", pct)
            putExtra("list_name", listName)
        }
        val pending = PendingIntent.getBroadcast(
            context, 8888, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 22)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            if (before(Calendar.getInstance())) add(Calendar.DAY_OF_MONTH, 1)
        }
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            cal.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending
        )
    }

    fun showNotification(id: Int, channelId: String, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(id, notif)
    }
}

// ─── Receivers ───────────────────────────────────────────────────────────────

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("list_name") ?: "Sortyd"
        val body = intent.getStringExtra("task_title") ?: ""
        val notifId = intent.getIntExtra(NotificationHelper.EXTRA_NOTIF_ID, 0)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val mainIntent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, notifId, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, NotificationHelper.CHANNEL_REMINDERS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(notifId, notif)
    }
}

class DailyResetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val mainIntent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 9999, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, NotificationHelper.CHANNEL_RESET)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Fresh start 🌅")
            .setContentText("Your To-Do list has been reset. New day, new goals.")
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(9999, notif)
    }
}

class DailySummaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pct = intent.getIntExtra("pct", 0)
        val listName = intent.getStringExtra("list_name") ?: ""

        val title = when {
            pct >= 100 -> "Fully locked in today 🏆"
            pct >= 85 -> "$pct% clocked in 💪"
            pct >= 70 -> "$pct% on track ⚡"
            pct >= 50 -> "$pct% in. Room to grow 📈"
            pct > 0 -> "$pct% checked off today 🌱"
            else -> "Fresh slate tomorrow 🔄"
        }
        val body = if (pct >= 100) "Clean sweep. Everything ticked off. ✅"
        else "You showed up. Build on that tomorrow."

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val mainIntent = Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 8888, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, NotificationHelper.CHANNEL_DAILY)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(8888, notif)
    }
}
