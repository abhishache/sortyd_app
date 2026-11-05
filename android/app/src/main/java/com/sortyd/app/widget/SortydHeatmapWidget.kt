package com.sortyd.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
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
import com.sortyd.app.data.model.WidgetData
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import android.content.Intent
import android.net.Uri
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity

// ─────────────────────────────────────────────────────────────
// MARK: - SortydHeatmapWidget
// Full month bubble calendar — mirrors iOS WidgetMonthly
// ─────────────────────────────────────────────────────────────

object SortydHeatmapWidget : GlanceAppWidget() {
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
            HeatmapWidgetContent(data)
        }
    }
}

@Composable
fun HeatmapWidgetContent(data: WidgetData) {
    val bg0     = Color(WidgetUtils.COLOR_BG0)
    val accent  = Color(WidgetUtils.COLOR_PRIMARY)
    val text0   = Color(WidgetUtils.COLOR_TEXT0)

    val now       = LocalDate.now()
    val monthLabel = now.month.name.lowercase().replaceFirstChar { it.uppercase() } +
        " ${now.year}"

    val heatBitmap = WidgetUtils.drawHeatmapCalendar(
        year       = now.year,
        month      = now.monthValue,
        snapshots  = data.monthlySnapshots,
        todayFraction = data.completionFraction.toFloat()
    )

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(bg0))
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://analytics"))))
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().clickable(actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sortyd://lists/${data.listId}")))),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "${data.listEmoji}  $monthLabel",
                style   = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(text0)),
                maxLines = 1
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(
                "${data.completionPercentage}% done",
                style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(accent))
            )
        }

        Spacer(GlanceModifier.height(4.dp))

        val divider = WidgetUtils.drawDivider(w = 1000, h = 2, colorArgb = WidgetUtils.COLOR_BG3)
        Image(ImageProvider(divider), null, modifier = GlanceModifier.fillMaxWidth().height(1.dp))

        Spacer(GlanceModifier.height(6.dp))

        Image(
            provider           = ImageProvider(heatBitmap),
            contentDescription = "Monthly heatmap",
            modifier           = GlanceModifier.fillMaxSize(),
            contentScale       = ContentScale.Fit
        )
    }
}

class SortydHeatmapWidgetReceiver : androidx.glance.appwidget.GlanceAppWidgetReceiver() {
    override val glanceAppWidget = SortydHeatmapWidget
}
