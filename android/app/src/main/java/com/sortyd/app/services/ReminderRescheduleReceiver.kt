package com.sortyd.app.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.sortyd.app.data.db.SortydDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Restores reminders after a device restart or an app update clears scheduled alarms. */
class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                ReminderManager.reconcile(context)
                ReminderManager.scheduleCoachSummary(context)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
