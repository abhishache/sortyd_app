package com.sortyd.app.services

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import java.time.LocalDate
import java.time.ZoneId

/**
 * Utility to fetch device usage statistics (screen time).
 * Requires PACKAGE_USAGE_STATS permission and user grant in Settings.
 */
object DeviceUsageManager {

    /** Checks if the user has granted the "Usage Access" permission. */
    fun hasPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Opens the system settings screen where the user can grant Usage Access. */
    fun openSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings if specific action fails
            context.startActivity(Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
    }

    /**
     * Fetches total screen time for the current day in decimal hours.
     * Returns 0.0 if permission is not granted or an error occurs.
     */
    fun getTodayScreenTimeHours(context: Context): Double {
        if (!hasPermission(context)) return 0.0

        return try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            
            // Start of today in milliseconds
            val startOfDay = LocalDate.now()
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()
            val now = System.currentTimeMillis()

            // queryAndAggregateUsageStats returns a map of package name to UsageStats
            val stats = usageStatsManager.queryAndAggregateUsageStats(startOfDay, now)
            
            // Sum up totalTimeInForeground for all packages
            val totalTimeMs = stats.values.sumOf { it.totalTimeInForeground }
            
            // Convert milliseconds to hours
            totalTimeMs.toDouble() / (1000.0 * 60.0 * 60.0)
        } catch (e: Exception) {
            0.0
        }
    }
}
