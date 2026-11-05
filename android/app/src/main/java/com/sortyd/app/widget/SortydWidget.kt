package com.sortyd.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.graphics.toArgb
import android.content.Intent
import android.net.Uri
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import com.sortyd.app.data.model.WidgetData
import kotlinx.serialization.json.Json

// ─────────────────────────────────────────────────────────────
// MARK: - SortydWidget (Small 2x2)
// ─────────────────────────────────────────────────────────────

object SortydWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(DpSize(100.dp, 100.dp))
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs   = currentState<Preferences>()
            val dataJson = prefs[stringPreferencesKey("widget_data")] ?: ""
            val data = if (dataJson.isNotEmpty()) {
                try { Json.decodeFromString<WidgetData>(dataJson) }
                catch (e: Exception) { WidgetData(listName = "Sortyd", listEmoji = "📋") }
            } else {
                WidgetData(listName = "Sortyd", listEmoji = "📋")
            }
            SmallWidgetContent(data)
        }
    }
}

@Composable
fun SmallWidgetContent(data: WidgetData) {
    val showTanks = (data.stepGoal ?: 0.0) > 0 || (data.caloriesGoal ?: 0.0) > 0

    val bg0 = Color(WidgetUtils.COLOR_BG0)
    val textPrimary = Color(WidgetUtils.COLOR_TEXT0)
    val textSecondary = Color(WidgetUtils.COLOR_TEXT1)
    val accent = Color(WidgetUtils.COLOR_PRIMARY)

    // 1. Arc Bitmap (Completion Ring)
    val arcBitmap = WidgetUtils.drawSegmentedArc(
        fraction = data.completionFraction.toFloat(),
        sizePx = 180,
        accentArgb = WidgetUtils.COLOR_PRIMARY,
        trackArgb = WidgetUtils.COLOR_BG3
    )

    // 2. Sparkline Bitmap
    val sparkValues = data.monthlySnapshots.values.map { it.toFloat() }.takeLast(7)
    val sparkBitmap = WidgetUtils.drawSparkline(
        points = sparkValues,
        w = 300,
        h = 100,
        accentArgb = WidgetUtils.COLOR_SECONDARY
    )

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(bg0))
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .padding(12.dp),
        contentAlignment = Alignment.TopStart
    ) {
        // Sparkline Background
        Image(
            provider = ImageProvider(sparkBitmap),
            contentDescription = null,
            modifier = GlanceModifier.fillMaxWidth().height(40.dp),
            contentScale = ContentScale.FillBounds
        )

        Column(
            modifier = GlanceModifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header: Emoji + List Name
            Row(
                modifier = GlanceModifier.fillMaxWidth().clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://quick-add")))),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(data.listEmoji, style = TextStyle(fontSize = 12.sp))
                Spacer(GlanceModifier.width(4.dp))
                Text(
                    data.listName,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(textPrimary)
                    ),
                    maxLines = 1
                )
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Center: Completion Percentage Ring
            Box(contentAlignment = Alignment.Center) {
                Image(
                    provider = ImageProvider(arcBitmap),
                    contentDescription = null,
                    modifier = GlanceModifier.size(72.dp)
                )
                Text(
                    "${data.completionPercentage}%",
                    style = TextStyle(
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(textPrimary)
                    )
                )
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            // Footer: Health Tanks OR Task Progress
            if (showTanks) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.Bottom
                ) {
                    if ((data.stepGoal ?: 0.0) > 0) {
                        val stepProg = ((data.stepCount ?: 0.0) / (data.stepGoal ?: 1.0)).toFloat()
                        val tankBmp = WidgetUtils.drawTank(stepProg, WidgetUtils.COLOR_YELLOW, 56, 72)
                        Image(
                            provider = ImageProvider(tankBmp),
                            contentDescription = "Steps",
                            modifier = GlanceModifier.size(28.dp, 36.dp)
                        )
                    }
                    if ((data.stepGoal ?: 0.0) > 0 && (data.caloriesGoal ?: 0.0) > 0) {
                        Spacer(GlanceModifier.width(8.dp))
                    }
                    if ((data.caloriesGoal ?: 0.0) > 0) {
                        val calProg = ((data.caloriesBurned ?: 0.0) / (data.caloriesGoal ?: 1.0)).toFloat()
                        val tankBmp = WidgetUtils.drawTank(calProg, WidgetUtils.COLOR_ORANGE, 56, 72)
                        Image(
                            provider = ImageProvider(tankBmp),
                            contentDescription = "Calories",
                            modifier = GlanceModifier.size(28.dp, 36.dp)
                        )
                    }
                }
            } else {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "${data.tasksDone}/${data.tasksTotal}",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(textSecondary)
                        )
                    )
                    Spacer(modifier = GlanceModifier.defaultWeight())
                    if (data.streakDays > 0) {
                        Text(
                            "🔥 ${data.streakDays}d",
                            style = TextStyle(fontSize = 11.sp, color = ColorProvider(accent))
                        )
                    }
                }
            }
        }
    }
}

// Remove redeclared SortydWidgetReceiver
