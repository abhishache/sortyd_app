package com.sortyd.app.services

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.sortyd.app.data.model.HealthSnapshot
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

class HealthConnectManager(private val context: Context) {

    private val client by lazy { HealthConnectClient.getOrCreate(context) }

    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
    )

    suspend fun hasPermissions(): Boolean {
        return try {
            client.permissionController.getGrantedPermissions().containsAll(permissions)
        } catch (_: Exception) {
            false
        }
    }

    suspend fun fetchToday(): HealthSnapshot {
        return try {
            val startOfDay = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS)
                .atZone(ZoneId.systemDefault()).toInstant()
            val now = Instant.now()
            val timeRange = TimeRangeFilter.between(startOfDay, now)

            val steps = client.aggregate(
                AggregateRequest(setOf(StepsRecord.COUNT_TOTAL), timeRange)
            )[StepsRecord.COUNT_TOTAL] ?: 0L

            val calories = client.aggregate(
                AggregateRequest(setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL), timeRange)
            )[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0

            val distanceM = client.aggregate(
                AggregateRequest(setOf(DistanceRecord.DISTANCE_TOTAL), timeRange)
            )[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0

            val screenTime = DeviceUsageManager.getTodayScreenTimeHours(context)

            HealthSnapshot(steps.toDouble(), calories, distanceM / 1000.0, screenTime)
        } catch (_: Exception) {
            HealthSnapshot()
        }
    }

    companion object {
        const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"

        fun getAvailabilityStatus(context: Context): Int {
            return try {
                HealthConnectClient.getSdkStatus(context)
            } catch (_: Exception) {
                HealthConnectClient.SDK_UNAVAILABLE
            }
        }

        fun isAvailable(context: Context): Boolean {
            return getAvailabilityStatus(context) == HealthConnectClient.SDK_AVAILABLE
        }

        fun startHealthConnectSettings(context: Context) {
            // Android 14+ (API 34) uses a new action; older versions use the legacy one.
            val newAction = "android.health.connect.action.HEALTH_CONNECT_SETTINGS"
            val legacyAction = "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"
            val preferredAction = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                newAction else legacyAction

            // Try preferred action first, then the other, then Play Store fallback
            val actionsToTry = listOf(preferredAction, if (preferredAction == newAction) legacyAction else newAction)
            for (action in actionsToTry) {
                try {
                    context.startActivity(android.content.Intent(action).apply {
                        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    return
                } catch (_: Exception) { /* try next */ }
            }
            // Final fallback: Play Store
            val playIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                data = android.net.Uri.parse("market://details?id=$HEALTH_CONNECT_PACKAGE")
                setPackage("com.android.vending")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(playIntent)
            } catch (_: Exception) {
                val webIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                    data = android.net.Uri.parse("https://play.google.com/store/apps/details?id=$HEALTH_CONNECT_PACKAGE")
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(webIntent)
            }
        }
    }
}
