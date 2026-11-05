package com.sortyd.app.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.*
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.layout.*
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.graphics.toArgb
import com.sortyd.app.data.model.WidgetData
import com.sortyd.app.data.model.WidgetTask
import kotlinx.serialization.json.Json

object SortydLargeWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<Preferences>()
            val dataJson = prefs[stringPreferencesKey("widget_data")] ?: ""
            val data = if (dataJson.isNotEmpty()) {
                try { Json.decodeFromString<WidgetData>(dataJson) }
                catch (_: Exception) { WidgetData(listName = "Sortyd", listEmoji = "📋") }
            } else {
                WidgetData(listName = "Sortyd", listEmoji = "📋")
            }
            LargeWidgetContent(data)
        }
    }
}

@Composable
fun LargeWidgetContent(data: WidgetData) {
    val bg0 = Color(WidgetUtils.COLOR_BG0)
    val text0 = Color(WidgetUtils.COLOR_TEXT0)
    val text1 = Color(WidgetUtils.COLOR_TEXT1)
    val accent = Color(WidgetUtils.COLOR_PRIMARY)

    val maxTasks = 4
    val allTasks = data.tasks
    val incomplete = allTasks.filter { !it.isCompleted }
    val completed = allTasks.filter { it.isCompleted }

    val visibleTasks = when {
        incomplete.isEmpty() -> completed.takeLast(maxTasks)
        completed.isEmpty() -> incomplete.take(maxTasks)
        else -> {
            val pinned = data.lastCheckedTaskId?.let { id -> completed.find { it.id == id } } 
                ?: completed.lastOrNull() 
                ?: allTasks.firstOrNull()
            
            if (pinned == null) {
                emptyList()
            } else {
                val result = mutableListOf(pinned)
                val slotsLeft = maxTasks - 1
                result.addAll(incomplete.take(slotsLeft))
                if (result.size < maxTasks) {
                    val remaining = maxTasks - result.size
                    result.addAll(completed.filter { it.id != pinned.id }.takeLast(remaining))
                }
                result
            }
        }
    }

    val extraCount = (allTasks.size - visibleTasks.size).coerceAtLeast(0)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(bg0))
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .padding(16.dp)
    ) {
        // ── TOP ZONE: Analytics ────────────────────────────────
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = GlanceModifier.defaultWeight()
                .clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://quick-add"))))
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(data.listEmoji, style = TextStyle(fontSize = 14.sp))
                    Spacer(GlanceModifier.width(4.dp))
                    Text(
                        data.listName,
                        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = ColorProvider(text0))
                    )
                }
                Text(
                    "${data.completionPercentage}% Complete",
                    style = TextStyle(
                        fontSize = 11.sp, 
                        fontWeight = FontWeight.Bold, 
                        color = ColorProvider(Color(WidgetUtils.statusColor(data.completionFraction.toFloat())))
                    )
                )
            }

            // 7-day Bar Chart Bitmap (Padded to 7 days)
            val rawPoints = data.monthlySnapshots.values.map { it.toFloat() }.takeLast(7)
            val points = if (rawPoints.size < 7) List(7 - rawPoints.size) { 0f } + rawPoints else rawPoints
            
            val chartBmp = WidgetUtils.drawBarChart(
                values = points,
                todayFraction = data.completionFraction.toFloat(),
                w = 160,
                h = 64
            )
            Image(
                provider = ImageProvider(chartBmp),
                contentDescription = null,
                modifier = GlanceModifier.width(80.dp).height(32.dp)
                    .clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://analytics"))))
            )
        }

        Spacer(GlanceModifier.height(16.dp))

        // ── MIDDLE ZONE: Tasks ────────────────────────────────
        Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            for (task in visibleTasks) {
                TaskLargeRow(task)
                Spacer(GlanceModifier.height(8.dp))
            }
            if (extraCount > 0) {
                Text(
                    "+ $extraCount more items",
                    style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium, color = ColorProvider(text1)),
                    modifier = GlanceModifier.padding(start = 14.dp)
                )
            }
        }

        Spacer(GlanceModifier.height(12.dp))

        // ── BOTTOM ZONE: Health Dials ─────────────────────────
        Row(modifier = GlanceModifier.fillMaxWidth()
            .clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://analytics"))))
        ) {
            // Streak
            HealthDialItem(
                label = "Streak",
                value = "${data.streakDays}d",
                progress = (data.streakDays.toFloat() / 30f).coerceIn(0.1f, 1f),
                colorArgb = WidgetUtils.COLOR_YELLOW,
                modifier = GlanceModifier.defaultWeight()
            )
            // Calories
            HealthDialItem(
                label = "Cals",
                value = data.caloriesBurned?.toInt()?.toString() ?: "--",
                progress = ( (data.caloriesBurned ?: 0.0).toFloat() / (data.caloriesGoal ?: 1.0).toFloat() ).coerceIn(0.1f, 1f),
                colorArgb = WidgetUtils.COLOR_ORANGE,
                modifier = GlanceModifier.defaultWeight()
            )
            // Steps
            val stepsValue = data.stepCount ?: 0.0
            val stepsLabel = if (stepsValue >= 1000) {
                "%.1fk".format(stepsValue / 1000.0)
            } else {
                stepsValue.toInt().toString()
            }
            HealthDialItem(
                label = "Steps",
                value = if (data.stepCount == null) "--" else stepsLabel,
                progress = ( stepsValue.toFloat() / (data.stepGoal?.toFloat() ?: 10000f) ).coerceIn(0.1f, 1f),
                colorArgb = WidgetUtils.COLOR_SKY_BLUE,
                modifier = GlanceModifier.defaultWeight()
            )
        }
    }
}

@Composable
fun TaskLargeRow(task: WidgetTask) {
    val bg1 = Color(WidgetUtils.COLOR_BG1)
    val text0 = Color(WidgetUtils.COLOR_TEXT0)
    val text1 = Color(WidgetUtils.COLOR_TEXT1)

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(ColorProvider(bg1.copy(alpha = 0.6f)))
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .cornerRadius(14.dp)
            .clickable(actionRunCallback<ToggleTaskCallback>(
                actionParametersOf(ToggleTaskCallback.TASK_ID_KEY to task.id)
            )),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val checkBmp = WidgetUtils.drawCheckCircle(task.isCompleted, 44, WidgetUtils.COLOR_PRIMARY)
        Image(ImageProvider(checkBmp), null, modifier = GlanceModifier.size(22.dp))

        Spacer(GlanceModifier.width(12.dp))

        Text(
            task.title,
            style = TextStyle(
                fontSize = 13.sp,
                fontWeight = if (task.isCompleted) FontWeight.Medium else FontWeight.Bold,
                color = ColorProvider(if (task.isCompleted) text1 else text0),
                textDecoration = if (task.isCompleted) TextDecoration.LineThrough else TextDecoration.None
            ),
            maxLines = 1
        )
    }
}

@Composable
fun HealthDialItem(
    label: String,
    value: String,
    progress: Float,
    colorArgb: Int,
    modifier: GlanceModifier = GlanceModifier
) {
    val text0 = Color(WidgetUtils.COLOR_TEXT0)
    val text1 = Color(WidgetUtils.COLOR_TEXT1)

    Row(
        modifier = modifier.height(48.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val dialBmp = WidgetUtils.drawHealthDial(progress, colorArgb, 64)
        Image(ImageProvider(dialBmp), null, modifier = GlanceModifier.size(32.dp))
        
        Spacer(GlanceModifier.width(8.dp))
        
        Column {
            Text(value, style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ColorProvider(text0)))
            Text(label, style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = ColorProvider(text1)))
        }
    }
}

class SortydLargeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = SortydLargeWidget
}
