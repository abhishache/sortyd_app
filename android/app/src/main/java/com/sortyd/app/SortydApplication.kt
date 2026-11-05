package com.sortyd.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import com.microsoft.clarity.Clarity
import com.microsoft.clarity.ClarityConfig

class SortydApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // Recording is masked at the Compose root, keeping task and health content private.
        Clarity.initialize(this, ClarityConfig(projectId = "ybfdycps9e"))
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val soundUri = Uri.parse("android.resource://$packageName/${R.raw.chime}")
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        val reminderChannel = NotificationChannel(
            CHANNEL_REMINDERS,
            "Sortyd Reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Daily task and habit reminders"
            enableVibration(true)
            setSound(soundUri, audioAttributes)
            setBypassDnd(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        val healthChannel = NotificationChannel(
            CHANNEL_HEALTH,
            "Health Goals",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Health goal notifications"
            enableVibration(true)
            setSound(soundUri, audioAttributes)
        }

        val resetChannel = NotificationChannel(
            CHANNEL_RESET,
            "Daily Reset",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Morning TO DO list resets"
            enableVibration(true)
            setSound(soundUri, audioAttributes)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(reminderChannel)
        manager.createNotificationChannel(healthChannel)
        manager.createNotificationChannel(resetChannel)
    }

    companion object {
        const val CHANNEL_REMINDERS = "sortyd_notifications_v10"
        const val CHANNEL_HEALTH = "sortyd_health_v10"
        const val CHANNEL_RESET = "sortyd_reset_v10"
    }
}
