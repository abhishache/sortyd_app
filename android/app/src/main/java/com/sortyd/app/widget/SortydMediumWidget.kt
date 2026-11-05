package com.sortyd.app.widget

import android.content.Context
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
import android.content.Intent
import android.net.Uri
import androidx.glance.appwidget.action.actionStartActivity

// ─────────────────────────────────────────────────────────────
// MARK: - SortydMediumWidget
// Dashboard dual-ring (outer = weighted %, inner = task count)
// + interactive task pills that toggle directly from home screen
// ─────────────────────────────────────────────────────────────

object SortydMediumWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs    = currentState<Preferences>()
            val dataJson = prefs[stringPreferencesKey("widget_data")] ?: ""
            val data = if (dataJson.isNotEmpty()) {
                try { Json.decodeFromString<WidgetData>(dataJson) }
                catch (e: Exception) { WidgetData(listName = "Sortyd", listEmoji = "📋") }
            } else {
                WidgetData(listName = "Sortyd", listEmoji = "📋")
            }
            MediumWidgetContent(data)
        }
    }
}

@Composable
fun MediumWidgetContent(data: WidgetData) {
    val accent        = Color(WidgetUtils.COLOR_PRIMARY)
    val bg0           = Color(WidgetUtils.COLOR_BG0)
    val bg1           = Color(WidgetUtils.COLOR_BG1)
    val textPrimary   = Color(WidgetUtils.COLOR_TEXT0)
    val textSecondary = Color(WidgetUtils.COLOR_TEXT1)

    val maxVisible = 3
    val allTasks   = data.tasks
    val incomplete = allTasks.filter { !it.isCompleted }
    val completed  = allTasks.filter  {  it.isCompleted }

    val visibleTasks = when {
        allTasks.isEmpty() -> emptyList()
        incomplete.isEmpty() -> completed.takeLast(maxVisible)
        else -> {
            val pinned = completed.firstOrNull { it.id == data.lastCheckedTaskId }
                ?: completed.firstOrNull()
            val result = mutableListOf<WidgetTask>()
            if (pinned != null) result.add(pinned)
            val slotsLeft = maxVisible - result.size
            result += incomplete.filter { it.id != pinned?.id }.take(slotsLeft)
            val remainingSlots = maxVisible - result.size
            if (remainingSlots > 0) {
                result += completed.filter { c -> result.none { it.id == c.id } }.takeLast(remainingSlots)
            }
            result
        }
    }
    val extra = maxOf(0, allTasks.size - visibleTasks.size)

    // Outer arc bitmap (weighted %)
    val outerArc = WidgetUtils.drawRingBitmap(
        fraction   = data.completionFraction.toFloat(),
        sizePx     = 280,
        strokePx   = 32f,
        accentArgb = WidgetUtils.COLOR_PRIMARY,
        trackArgb  = WidgetUtils.COLOR_BG3,
        glowArgb   = (WidgetUtils.COLOR_PRIMARY and 0x00FFFFFF) or 0x60000000
    )

    // Inner arc bitmap (task count %)
    val taskFrac = if (data.tasksTotal > 0) data.tasksDone.toFloat() / data.tasksTotal else 0f
    val innerArc = WidgetUtils.drawRingBitmap(
        fraction   = taskFrac,
        sizePx     = 280,
        strokePx   = 16f,
        accentArgb = WidgetUtils.COLOR_SECONDARY,
        trackArgb  = (WidgetUtils.COLOR_BG3 and 0x00FFFFFF) or 0x40000000,
        padding    = 56f
    )

    // 5-day bar chart
    val barValues = data.monthlySnapshots.entries
        .sortedBy { it.key }.takeLast(5)
        .map { it.value.toFloat() }
        .let { list ->
            if (list.size < 5) List(5 - list.size) { 0f } + list else list
        }
    val barsBitmap = WidgetUtils.drawBarChart(
        values = barValues,
        w = 100,
        h = 48,
        todayFraction = data.completionFraction.toFloat()
    )

    Row(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(bg0))
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .padding(horizontal = 10.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // ── LEFT COLUMN: Dashboard Rings ──────────────────────
        Column(
            modifier            = GlanceModifier.width(120.dp).fillMaxHeight()
                .clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://analytics")))),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment   = Alignment.CenterVertically
        ) {
            Box(contentAlignment = Alignment.Center) {
                Image(ImageProvider(outerArc), null, modifier = GlanceModifier.size(80.dp))
                Image(ImageProvider(innerArc), null, modifier = GlanceModifier.size(80.dp))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "${data.completionPercentage}%",
                        style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary))
                    )
                }
            }

            Spacer(GlanceModifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically,
                modifier = GlanceModifier.clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://quick-add"))))
            ) {
                Text(data.listEmoji, style = TextStyle(fontSize = 11.sp))
                Spacer(GlanceModifier.width(4.dp))
                Text(
                    data.listName,
                    style   = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)),
                    maxLines = 1
                )
            }

            Spacer(GlanceModifier.height(6.dp))

            Image(
                ImageProvider(barsBitmap),
                contentDescription = null,
                modifier           = GlanceModifier.fillMaxWidth().height(20.dp),
                contentScale       = ContentScale.FillBounds
            )

            if (data.streakDays > 0) {
                Spacer(GlanceModifier.height(4.dp))
                Text("🔥 ${data.streakDays}d streak", style = TextStyle(fontSize = 9.sp, color = ColorProvider(accent)))
            }
        }

        Spacer(GlanceModifier.width(8.dp))

        // ── RIGHT COLUMN: Interactive Task Pills ─────────────
        Column(
            modifier            = GlanceModifier.fillMaxHeight().defaultWeight(),
            verticalAlignment   = Alignment.CenterVertically
        ) {
            if (visibleTasks.isEmpty()) {
                Text(
                    "All done! ✅",
                    style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ColorProvider(accent))
                )
            } else {
                for (task in visibleTasks) {
                    InteractiveTaskPill(task, bg1, accent, textPrimary, textSecondary)
                    Spacer(GlanceModifier.height(6.dp))
                }
                if (extra > 0) {
                    Text(
                        "+ $extra more",
                        style   = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = ColorProvider(accent)),
                        modifier = GlanceModifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun InteractiveTaskPill(
    task: WidgetTask,
    bg1:           Color,
    accent:        Color,
    textPrimary:   Color,
    textSecondary: Color
) {
    val checkBmp = WidgetUtils.drawCheckCircle(
        checked    = task.isCompleted,
        sizePx     = 60,
        accentArgb = WidgetUtils.COLOR_PRIMARY
    )

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(ColorProvider(bg1.copy(alpha = 0.7f)))
            .cornerRadius(12.dp)
            .padding(horizontal = 10.dp, vertical = 8.dp)
            .clickable(
                actionRunCallback<ToggleTaskCallback>(
                    actionParametersOf(ToggleTaskCallback.TASK_ID_KEY to task.id)
                )
            ),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            provider           = ImageProvider(checkBmp),
            contentDescription = if (task.isCompleted) "Done" else "Not done",
            modifier           = GlanceModifier.size(20.dp)
        )
        Spacer(GlanceModifier.width(10.dp))
        Text(
            task.title,
            style = TextStyle(
                fontSize         = 12.sp,
                fontWeight       = if (task.isCompleted) FontWeight.Normal else FontWeight.Bold,
                color            = ColorProvider(if (task.isCompleted) textSecondary else textPrimary),
                textDecoration   = if (task.isCompleted) TextDecoration.LineThrough else TextDecoration.None
            ),
            maxLines = 1
        )
    }
}

class SortydMediumWidgetReceiver : androidx.glance.appwidget.GlanceAppWidgetReceiver() {
    override val glanceAppWidget = SortydMediumWidget
}
