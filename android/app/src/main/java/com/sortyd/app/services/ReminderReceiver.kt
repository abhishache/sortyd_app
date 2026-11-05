package com.sortyd.app.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.sortyd.app.MainActivity
import com.sortyd.app.SortydApplication
import com.sortyd.app.data.AICoach
import com.sortyd.app.data.db.SortydDatabase
import com.sortyd.app.data.model.toDomain
import com.sortyd.app.data.preferences.UserPreferences
import com.sortyd.app.ui.localization.SortydStrings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
        try {
        val language = UserPreferences(context).selectedLanguage.first()
        val taskTitle = intent.getStringExtra("task_title") ?: SortydStrings.t(language, "Task")
        val taskId = intent.getStringExtra("task_id") ?: ""

        if (taskId == "COACH_SUMMARY") {
            ReminderManager.scheduleCoachSummary(context)
            sendCoachSummary(context)
            return@launch
        }

        // Alarms outlive database records and app upgrades. Validate at delivery.
        val list = SortydDatabase.getInstance(context).sortydDao().getActiveListsSync()
            .firstOrNull { entry -> entry.tasks.any { it.id == taskId } }
        val task = list?.tasks?.firstOrNull { it.id == taskId }
        if (task == null || task.isCompleted || task.reminderTime == null ||
            task.reminderTime != intent.getLongExtra("reminder_time", -1)) {
            ReminderManager.cancelReminder(context, taskId)
            ReminderManager.reconcile(context)
            return@launch
        }
        val once = task.reminderIsOneTime || list.list.isTodo || task.notificationLeadMinutes > 0
        val now = System.currentTimeMillis()
        val fireAt = intent.getLongExtra("notification_fire_time", task.reminderTime)
        if (now < fireAt - 1_000L || now > fireAt + 5 * 60_000L ||
            (once && now > task.reminderTime + 60_000L)) {
            ReminderManager.cancelReminder(context, taskId)
            ReminderManager.reconcile(context)
            return@launch
        }

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context, taskId.hashCode(), openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val soundUri = Uri.parse("android.resource://${context.packageName}/${com.sortyd.app.R.raw.chime}")
        val notification = NotificationCompat.Builder(context, SortydApplication.CHANNEL_REMINDERS)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("Sortyd")
            .setContentText("You have a reminder in Sortyd")
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setDefaults(NotificationCompat.DEFAULT_VIBRATE)
            .setAutoCancel(true)
            .setSound(soundUri)
            .setContentIntent(pendingIntent)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(taskId.hashCode(), notification)

        if (!once) {
            ReminderManager.scheduleReminder(
                context = context,
                taskId = taskId,
                taskTitle = task.title,
                timeInMillis = task.reminderTime,
                notificationLeadMinutes = task.notificationLeadMinutes,
                isOneTime = false,
            )
        }
        } finally { pendingResult.finish() }
        }
    }

    private suspend fun sendCoachSummary(context: Context) {
        val db = SortydDatabase.getInstance(context)
        val prefs = UserPreferences(context)
        
        run {
            val language = prefs.selectedLanguage.first()
            val activeListId = prefs.activeListId.first()
            val availableLists = db.sortydDao()
                .getActiveListsSync()
                .filter { !it.list.isTodo }
                .sortedBy { it.list.sortOrder }
            val list = availableLists.firstOrNull { it.list.id == activeListId }
                ?: availableLists.firstOrNull()
                ?: return
            val snapshots = db.sortydDao().getSnapshotsForList(list.list.id).first().map { it.toDomain() }
            
            val result = AICoach.generateBehaviouralAnalysis(
                tasks = list.tasks.map { it.toDomain() },
                snapshots = snapshots,
                listName = list.list.name,
                languageCode = language
            ) ?: return

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("navigate_to", "coach")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, "COACH_SUMMARY".hashCode(), openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val soundUri = Uri.parse("android.resource://${context.packageName}/${com.sortyd.app.R.raw.chime}")
            val notification = NotificationCompat.Builder(context, SortydApplication.CHANNEL_REMINDERS)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle("${list.list.emoji} ${SortydStrings.t(language, "AI COACH")}")
                .setContentText(result.headline)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_EVENT)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE)
                .setAutoCancel(true)
                .setSound(soundUri)
                .setContentIntent(pendingIntent)
                .build()

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify("COACH_SUMMARY".hashCode(), notification)
        }
    }
}
