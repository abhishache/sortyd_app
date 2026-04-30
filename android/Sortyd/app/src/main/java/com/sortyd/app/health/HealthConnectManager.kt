package com.sortyd.app.health

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.sortyd.app.model.HealthTaskType
import com.sortyd.app.model.SortydTask
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class HealthConnectManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val TAG = "HealthConnectManager"

    private val _isAvailable = MutableStateFlow(false)
    val isAvailable: StateFlow<Boolean> = _isAvailable.asStateFlow()

    private val _isAuthorized = MutableStateFlow(false)
    val isAuthorized: StateFlow<Boolean> = _isAuthorized.asStateFlow()

    private val _todaySteps = MutableStateFlow(0.0)
    val todaySteps: StateFlow<Double> = _todaySteps.asStateFlow()

    private val _todayCalories = MutableStateFlow(0.0)
    val todayCalories: StateFlow<Double> = _todayCalories.asStateFlow()

    private val _todayDistance = MutableStateFlow(0.0)
    val todayDistance: StateFlow<Double> = _todayDistance.asStateFlow()

    var onHealthUpdate: (() -> Unit)? = null

    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class)
    )

    private var client: HealthConnectClient? = null

    fun initialize() {
        val status = HealthConnectClient.getSdkStatus(context)
        _isAvailable.value = status == HealthConnectClient.SDK_AVAILABLE
        if (_isAvailable.value) {
            client = HealthConnectClient.getOrCreate(context)
        }
    }

    suspend fun checkPermissions(): Boolean {
        val c = client ?: return false
        return try {
            val granted = c.permissionController.getGrantedPermissions()
            val authorized = granted.containsAll(permissions)
            _isAuthorized.value = authorized
            authorized
        } catch (e: Exception) {
            Log.e(TAG, "Permission check failed", e)
            false
        }
    }

    suspend fun fetchToday() {
        val c = client ?: return
        if (!_isAuthorized.value) return

        val today = LocalDate.now()
        val startOfDay = today.atStartOfDay(ZoneId.systemDefault()).toInstant()
        val now = Instant.now()
        val range = TimeRangeFilter.between(startOfDay, now)

        try {
            // Steps
            val stepsResp = c.readRecords(
                ReadRecordsRequest(StepsRecord::class, range)
            )
            _todaySteps.value = stepsResp.records.sumOf { it.count.toDouble() }

            // Calories
            val calResp = c.readRecords(
                ReadRecordsRequest(ActiveCaloriesBurnedRecord::class, range)
            )
            _todayCalories.value = calResp.records.sumOf { it.energy.inKilocalories }

            // Distance
            val distResp = c.readRecords(
                ReadRecordsRequest(DistanceRecord::class, range)
            )
            _todayDistance.value = distResp.records.sumOf { it.distance.inKilometers }

            onHealthUpdate?.invoke()
        } catch (e: Exception) {
            Log.e(TAG, "Fetch today failed", e)
        }
    }

    fun currentValue(type: HealthTaskType): Double = when (type) {
        HealthTaskType.STEPS -> _todaySteps.value
        HealthTaskType.CALORIES -> _todayCalories.value
        HealthTaskType.DISTANCE -> _todayDistance.value
        HealthTaskType.NONE -> 0.0
    }

    fun progress(type: HealthTaskType, target: Double): Double {
        if (target <= 0.0) return 0.0
        return (currentValue(type) / target).coerceIn(0.0, 1.0)
    }

    fun healthValues(tasks: List<SortydTask>): Map<String, Double> {
        return tasks
            .filter { it.isHealthTask }
            .associate { task ->
                val type = task.resolvedHealthType
                val target = task.healthTarget ?: 0.0
                task.id to progress(type, target)
            }
    }
}
