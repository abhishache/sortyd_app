package com.sortyd.app.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.data.model.DailySnapshot
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.components.dualGlow
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.ui.theme.glow
import com.sortyd.app.viewmodel.SortydViewModel
import java.time.*
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.*

enum class AnalyticsPeriod(val label: String, val days: Int) { WEEK("7D", 7), MONTH("30D", 30), ALL("ALL", 365) }

@Composable
fun AnalyticsScreen(viewModel: SortydViewModel) {
    val colors = SortydColors.current
    val allSnapshots by viewModel.allSnapshots.collectAsState()
    val activeList by viewModel.activeList.collectAsState()
    val allLists by viewModel.activeLists.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val regularLists = allLists.filter { !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
    val todoList = allLists.firstOrNull { it.isTodo }

    var period by remember { mutableStateOf(AnalyticsPeriod.MONTH) }

    // Local analytics list selection — doesn't affect the home screen's active list
    var analyticsListId by remember { mutableStateOf("") }
    LaunchedEffect(activeList?.id) {
        if (analyticsListId.isEmpty() && activeList != null) analyticsListId = activeList!!.id
    }
    val analyticsList = (regularLists + listOfNotNull(todoList)).firstOrNull { it.id == analyticsListId } ?: activeList

    val listId = analyticsList?.id ?: ""
    val snapshots = allSnapshots.filter { it.listId == listId }
    val now = LocalDate.now()
    val installDate by viewModel.installDate.collectAsState()
    val installLocalDate = Instant.ofEpochMilli(installDate).atZone(ZoneId.systemDefault()).toLocalDate()

    val daysSinceInstall = ChronoUnit.DAYS.between(installLocalDate, now).toInt() + 1
    val periodDays = if (period == AnalyticsPeriod.ALL) maxOf(daysSinceInstall, 7) else period.days
    val cutoffDate = now.minusDays(periodDays.toLong() - 1)

    val filtered = snapshots.filter {
        val date = Instant.ofEpochMilli(it.date).atZone(ZoneId.systemDefault()).toLocalDate()
        !date.isBefore(cutoffDate) && !date.isAfter(now)
    }.sortedBy { it.date }

    val avg = if (filtered.isEmpty()) 0.0 else filtered.map { it.completionFraction }.average()
    val avgPct = (avg * 100).toInt()
    val grade = when {
        avgPct >= 90 -> "A"; avgPct >= 80 -> "A-"; avgPct >= 75 -> "B+"
        avgPct >= 70 -> "B"; avgPct >= 65 -> "B-"; avgPct >= 60 -> "C+"
        avgPct >= 50 -> "C"; else -> "D"
    }
    val gradeLabel = when {
        avgPct >= 90 -> SortydStrings.t(language, "Exceptional"); avgPct >= 80 -> SortydStrings.t(language, "Great work")
        avgPct >= 75 -> SortydStrings.t(language, "Almost there"); avgPct >= 70 -> SortydStrings.t(language, "On track")
        avgPct >= 60 -> SortydStrings.t(language, "Room to grow"); avgPct >= 50 -> SortydStrings.t(language, "Keep pushing")
        else -> SortydStrings.t(language, "Just starting")
    }

    // Best streak within the selected period (mirrors iOS bestStreakForPeriod)
    val bestStreakForPeriod = run {
        var best = 0; var current = 0
        for (snap in filtered) {
            if (snap.completionFraction >= 0.8) { current++; best = maxOf(best, current) } else current = 0
        }
        best
    }

    val weekdayAvg = (1..7).map { dow ->
        val ds = filtered.filter {
            val dt = Instant.ofEpochMilli(it.date).atZone(ZoneId.systemDefault()).toLocalDate()
            dt.dayOfWeek.value == dow
        }
        if (ds.isEmpty()) 0.0 else ds.map { it.completionFraction }.average()
    }
    val bestIdx = weekdayAvg.indexOf(weekdayAvg.maxOrNull() ?: 0.0)

    val tasks = analyticsList?.tasks ?: emptyList()

    Column(Modifier.fillMaxSize().background(colors.bg0).verticalScroll(rememberScrollState()).padding(bottom = 32.dp)) {
        // ── Header ──
        Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
            Column(Modifier.align(Alignment.BottomStart)) {
                Text(SortydStrings.t(language, "ANALYTICS"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.sp, letterSpacing = 2.sp, fontWeight = FontWeight.Black).glow(colors.accent, 4f), color = colors.accent)
                Text(SortydStrings.t(language, "Report"), style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black, fontSize = 28.sp), color = colors.text0)
            }
            
            // Period Pill - Centered in header
            Row(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 2.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(colors.bg1)
                    .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(20.dp))
                    .padding(3.dp)
            ) {
                AnalyticsPeriod.entries.forEach { p ->
                    val sel = p == period
                    Box(
                        Modifier
                            .heightIn(min = 44.dp)
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (sel) colors.accent else Color.Transparent)
                            .clickable { period = p }
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(p.label, style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Black), color = if (sel) colors.bg0 else colors.text2)
                    }
                }
            }

            // Local list picker - Broadened on the right
            var showListMenu by remember { mutableStateOf(false) }
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .padding(bottom = 2.dp)
                    .heightIn(min = 44.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(colors.bg1)
                    .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(18.dp))
                    .clickable { showListMenu = true }
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(analyticsList?.emoji ?: "📋", fontSize = 12.sp)
                    Spacer(Modifier.width(6.dp))
                    Text(analyticsList?.cleanName?.take(16) ?: "", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, fontSize = 10.sp), color = colors.text0)
                    Icon(Icons.Default.ChevronRight, null, tint = colors.text2, modifier = Modifier.size(10.dp))
                }
                DropdownMenu(expanded = showListMenu, onDismissRequest = { showListMenu = false }, modifier = Modifier.background(colors.bg1)) {
                    regularLists.forEach { l ->
                        DropdownMenuItem(
                            text = { Text("${l.emoji} ${l.cleanName}", color = colors.text0) },
                            onClick = { analyticsListId = l.id; showListMenu = false }
                        )
                    }
                    if (todoList != null) {
                        Divider(color = colors.borderSubtle)
                        DropdownMenuItem(
                            text = { Text("${todoList.emoji} ${SortydStrings.t(language, "Adhoc TO DO")}", color = colors.text0) },
                            onClick = { analyticsListId = todoList.id; showListMenu = false }
                        )
                    }
                }
            }
        }

        // ── Banner ──
        BannerBlock(daysSinceInstall, filtered)

        Spacer(Modifier.height(8.dp))

        // ── Hero Block ──
        HeroBlock(grade, gradeLabel, avgPct, bestStreakForPeriod)

        Spacer(Modifier.height(8.dp))

        // ── Needs Attention Queue ──
        val overdueItems = tasks.mapNotNull { task ->
            val lastSnap = snapshots.lastOrNull { it.completedTaskIds.contains(task.id) }
            val daysAgo = if (lastSnap != null) {
                val lastDate = Instant.ofEpochMilli(lastSnap.date).atZone(ZoneId.systemDefault()).toLocalDate()
                ChronoUnit.DAYS.between(lastDate, now).toInt()
            } else {
                ChronoUnit.DAYS.between(installLocalDate, now).toInt() + 1
            }
            val neverDone = lastSnap == null
            if (daysAgo >= 3) TaskRecencyItem(task.id, task.title, daysAgo, neverDone) else null
        }.sortedByDescending { it.daysAgo }

        if (overdueItems.isNotEmpty()) {
            TaskRecencyCard(overdueItems)
            Spacer(Modifier.height(8.dp))
        }

        // ── Insight Chips ──
        InsightSection(bestIdx, weekdayAvg, snapshots, filtered.size)

        Spacer(Modifier.height(8.dp))

        // ── Trend Chart ──
        TrendSection(filtered, period, periodDays)

        Spacer(Modifier.height(8.dp))

        // ── Day-of-Week Pattern ──
        PatternSection(weekdayAvg, bestIdx)

        Spacer(Modifier.height(8.dp))

        // ── Task DNA ──
        DNASection(analyticsList?.tasks ?: emptyList(), snapshots, language)

        Spacer(Modifier.height(8.dp))

        // ── Weak Areas (at the bottom, matching iOS layout) ──
        WeakAreasSection(analyticsList?.tasks ?: emptyList(), filtered)
    }
}

@Composable
private fun BannerBlock(days: Int, snapshots: List<DailySnapshot>) {
    val colors = SortydColors.current
    if (days > 7) return

    val daysClocked = snapshots.count { it.completionFraction > 0 }
    val messages = listOf(
        "🌱 Day $days of 7 — your journey just started with Sortyd",
        "Give Sortyd time to learn how you work",
        if (daysClocked > 0) "$daysClocked day${if (daysClocked > 1) "s" else ""} clocked in so far — keep it up!"
        else "Complete tasks today to start tracking your progress",
        "Better insights unlock as more data builds",
        "Track consistently and your grade will reflect it ✨"
    )

    var msgIndex by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(3500)
            msgIndex = (msgIndex + 1) % messages.size
        }
    }

    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(colors.accent.copy(0.07f))
            .border(0.5.dp, colors.accent.copy(0.20f), RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                modifier = Modifier.size(10.dp),
                tint = colors.accent
            )
            Spacer(Modifier.width(8.dp))
            Text(
                messages[msgIndex],
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Medium,
                    color = colors.accent,
                    fontSize = 11.sp
                ),
                modifier = Modifier.weight(1f),
                maxLines = 1
            )
            Text(
                "${7 - days}d left",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 9.sp,
                    fontWeight = FontWeight.SemiBold
                ),
                color = colors.text2
            )
        }
    }
}

@Composable
private fun HeroBlock(grade: String, label: String, avg: Int, streak: Int) {
    val colors = SortydColors.current
    val gradeColor = when {
        avg >= 80 -> colors.accent
        avg >= 60 -> colors.warning
        else -> colors.coral
    }

    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(colors.bg1)
            .border(0.75.dp, gradeColor.copy(0.1f), RoundedCornerShape(24.dp))
            .dualGlow(violetIntensity = 0.14f, cyanIntensity = 0.08f)
    ) {
        Canvas(Modifier.matchParentSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(gradeColor.copy(0.10f), Color.Transparent),
                    center = Offset(0f, 0f),
                    radius = 220.dp.toPx()
                )
            )
        }
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    grade,
                    style = TextStyle(
                        fontSize = 72.sp,
                        fontWeight = FontWeight.Black,
                        color = gradeColor
                    ).glow(gradeColor, 8f)
                )
                Text(
                    label.uppercase(),
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.SemiBold,
                        color = gradeColor.copy(0.6f),
                        fontSize = 10.sp
                    )
                )
            }

            Box(
                Modifier
                    .width(0.5.dp)
                    .height(56.dp)
                    .background(colors.borderSubtle)
            )

            Row(
                Modifier.padding(start = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                StatCol("AVG", "$avg", "%", colors.text0)
                StatCol("STREAK", "$streak", "d", colors.coral)
            }
        }
    }
}

@Composable
private fun StatCol(label: String, value: String, unit: String, color: Color) {
    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 8.sp,
                letterSpacing = 1.8.sp,
                fontWeight = FontWeight.Bold
            ),
            color = SortydColors.current.text2
        )
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(
                value,
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontWeight = FontWeight.Black,
                    fontSize = 28.sp
                ),
                color = color
            )
            Text(
                unit,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                ),
                color = color.copy(0.5f),
                modifier = Modifier.padding(bottom = 2.dp)
            )
        }
    }
}

@Composable
private fun InsightSection(bestIdx: Int, weekdayAvg: List<Double>, allSnaps: List<DailySnapshot>, n: Int) {
    val dayNames = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    val colors = SortydColors.current
    val nonZeroMin = weekdayAvg.filter { it > 0.0 }.minOrNull()
    val worstIdx = if (nonZeroMin != null) weekdayAvg.indexOf(nonZeroMin) else -1

    val vsLast: Int? = if (n > 0) {
        val currentSnaps = allSnaps.takeLast(n)
        val prevSnaps = allSnaps.dropLast(n).takeLast(n)
        if (prevSnaps.isNotEmpty()) {
            val currentAvg = currentSnaps.map { it.completionFraction }.average() * 100
            val prevAvg = prevSnaps.map { it.completionFraction }.average() * 100
            (currentAvg - prevAvg).toInt()
        } else null
    } else null

    Row(Modifier.padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val vsLabel = "VS LAST"
        if (vsLast != null) {
            val isPos = vsLast >= 0
            InsightChip(
                icon = if (isPos) "arrow_up_right" else "arrow_down_right",
                value = if (isPos) "+$vsLast%" else "$vsLast%",
                label = vsLabel,
                modifier = Modifier.weight(1f),
                valueColor = if (isPos) colors.accent else colors.coral,
                iconColor = if (isPos) colors.accent else colors.coral
            )
        } else {
            InsightChip("—", "N/A", vsLabel, Modifier.weight(1f))
        }

        InsightChip(
            icon = "★",
            value = dayNames.getOrElse(bestIdx) { "—" },
            label = "BEST DAY",
            modifier = Modifier.weight(1f),
            iconColor = colors.accent
        )
        InsightChip(
            icon = "🌙",
            value = if (worstIdx >= 0) dayNames.getOrElse(worstIdx) { "—" } else "—",
            label = "WEAKEST",
            modifier = Modifier.weight(1f),
            iconColor = colors.coral
        )
    }
}

@Composable
private fun InsightChip(
    icon: String,
    value: String,
    label: String,
    modifier: Modifier,
    valueColor: Color = SortydColors.current.text0,
    iconColor: Color = SortydColors.current.text2
) {
    val colors = SortydColors.current
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(colors.bg1)
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(16.dp))
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (icon.length > 1) {
            // Placeholder for vector icons if needed, but using text/emoji for parity with simple icons
            Text(
                if (icon == "arrow_up_right") "↗" else "↘",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = iconColor
            )
        } else {
            Text(icon, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = iconColor)
        }
        Text(
            value,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = FontWeight.Black,
                fontSize = 14.sp
            ),
            color = valueColor,
            maxLines = 1
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 7.5.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.6.sp
            ),
            color = colors.text2
        )
    }
}

@Composable
private fun WeakAreasSection(tasks: List<SortydTask>, snaps: List<DailySnapshot>) {
    val colors = SortydColors.current
    val weakTasks = tasks.map { task ->
        val hits = snaps.count { it.completedTaskIds.contains(task.id) }
        val rate = if (snaps.isEmpty()) 0f else hits.toFloat() / snaps.size
        task to rate
    }.filter { it.second < 0.7f } // Include 0% tasks as they need work the most
        .sortedBy { it.second }
        .take(5)

    if (weakTasks.isEmpty()) return

    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(20.dp))
            .padding(vertical = 12.dp)
    ) {
        Row(
            Modifier
                .padding(horizontal = 14.dp)
                .padding(bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Info,
                null,
                Modifier.size(9.dp),
                tint = colors.coral
            )
            Spacer(Modifier.width(5.dp))
            Text(
                "NEEDS WORK",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.6.sp
                ),
                color = colors.text2
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${weakTasks.size} tasks",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold
                ),
                color = colors.accent
            )
        }

        Row(
            Modifier
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            weakTasks.forEach { (task, rate) ->
                WeakChip(task.title, rate)
            }
        }
    }
}

@Composable
private fun WeakChip(title: String, rate: Float) {
    val colors = SortydColors.current
    val color = when {
        rate < 0.3f -> colors.danger
        rate < 0.5f -> colors.coral
        else -> colors.warning
    }

    Column(
        Modifier
            .width(110.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(0.08f))
            .border(0.75.dp, color.copy(0.20f), RoundedCornerShape(12.dp))
            .padding(horizontal = 11.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            title,
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.SemiBold,
                fontSize = 10.sp
            ),
            color = colors.text0,
            maxLines = 2,
            modifier = Modifier.height(28.dp) // Fixed height to align the bottom parts
        )

        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "${(rate * 100).toInt()}",
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontWeight = FontWeight.Black,
                    fontSize = 20.sp
                ),
                color = color
            )
            Text(
                "%",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 9.sp
                ),
                color = color.copy(0.5f),
                modifier = Modifier.padding(bottom = 2.dp)
            )
        }

        Box(
            Modifier
                .fillMaxWidth()
                .height(3.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(color.copy(0.12f))
        ) {
            Box(
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(rate)
                    .background(
                        Brush.horizontalGradient(listOf(color, color.copy(0.3f)))
                    )
            )
        }
    }
}

@Composable
private fun TrendSection(filtered: List<DailySnapshot>, period: AnalyticsPeriod, periodDays: Int) {
    val colors = SortydColors.current
    val title = when (period) {
        AnalyticsPeriod.WEEK -> "7-DAY TREND"
        AnalyticsPeriod.MONTH -> "30-DAY TREND"
        AnalyticsPeriod.ALL -> "ALL-TIME TREND"
    }
    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(20.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                title,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 9.sp,
                    letterSpacing = 1.8.sp,
                    fontWeight = FontWeight.Bold
                ),
                color = colors.text2
            )
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(
                    Modifier
                        .size(4.dp)
                        .clip(CircleShape)
                        .background(colors.accent)
                )
                Text(
                    "completion",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Medium),
                    color = colors.text2
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        TrendChart(filtered, periodDays, Modifier.fillMaxWidth().height(114.dp))
    }
}

@Composable
private fun PatternSection(averages: List<Double>, bestIdx: Int) {
    val dayFullNames = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    val colors = SortydColors.current
    val dayNames = listOf("M", "T", "W", "T", "F", "S", "S")
    val displayOrder = listOf(0, 1, 2, 3, 4, 5, 6) // Mon to Sun

    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(20.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    "DAY-OF-WEEK PATTERN",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        letterSpacing = 1.8.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = colors.text2
                )
                Text(
                    "When you perform best",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    color = colors.text0.copy(0.45f)
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(
                    "LOW",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 7.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = colors.text2
                )
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    listOf(0.1f, 0.35f, 0.6f, 0.85f, 1f).forEach { a ->
                        Box(
                            Modifier
                                .size(10.dp)
                                .clip(RoundedCornerShape(2.dp))
                                .background(colors.accent.copy(a))
                        )
                    }
                }
                Text(
                    "HIGH",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 7.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = colors.text2
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            displayOrder.forEach { i ->
                val avg = averages.getOrElse(i) { 0.0 }
                val active = i == bestIdx
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(46.dp)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (avg > 0) colors.accent.copy(avg.toFloat()) else Color.Transparent)
                            .then(
                                if (avg > 0) Modifier else Modifier.border(
                                    0.75.dp,
                                    colors.borderSubtle.copy(0.45f),
                                    RoundedCornerShape(9.dp)
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            if (active && avg > 0) Text("👑", fontSize = 7.sp)
                            Text(
                                if (avg > 0) "${(avg * 100).toInt()}%" else "—",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = if (active) FontWeight.Black else FontWeight.Bold,
                                    color = if (avg > 0) Color.White else colors.text2.copy(0.28f),
                                    fontSize = if (avg > 0) 11.sp else 9.sp
                                ),
                                maxLines = 1
                            )
                        }
                    }
                    Text(
                        dayNames[i],
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 9.sp,
                            fontWeight = if (active) FontWeight.Black else FontWeight.Medium
                        ),
                        color = if (active) colors.accent else colors.text2
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        val nonZeroAvgs = averages.mapIndexedNotNull { i, v -> if (v > 0.0) i to v else null }
        val bestVal = nonZeroAvgs.maxByOrNull { it.second }
        val worstVal = nonZeroAvgs.minByOrNull { it.second }
        val insightText = if (bestVal != null && worstVal != null &&
            bestVal.first != worstVal.first &&
            bestVal.second - worstVal.second > 0.08
        ) {
            "${dayFullNames.getOrElse(bestVal.first) { "—" }}s are ${((bestVal.second - worstVal.second) * 100).toInt()}% stronger than ${dayFullNames.getOrElse(worstVal.first) { "—" }}s"
        } else {
            "Your performance is consistent across the week — well done"
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Text("💡", fontSize = 7.5.sp)
            Text(
                insightText,
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, fontWeight = FontWeight.Medium),
                color = colors.text2
            )
        }
    }
}

@Composable
private fun DNASection(tasks: List<SortydTask>, snapshots: List<DailySnapshot>, language: String) {
    val colors = SortydColors.current
    val items = tasks.map { task ->
        val hits = snapshots.count { it.completedTaskIds.contains(task.id) }
        val rate = if (snapshots.isEmpty()) 0f else hits.toFloat() / snapshots.size
        var streak = 0
        for (snap in snapshots.reversed()) {
            if (snap.completedTaskIds.contains(task.id)) streak++ else break
        }
        Triple(task.title, rate, streak)
    }.sortedByDescending { it.second }

    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(20.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    "TASK DNA",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        letterSpacing = 1.8.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = colors.text2
                )
                Text(
                    "Per-task completion breakdown",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    color = colors.text0.copy(0.40f)
                )
            }
            // Inline legend
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LegendItem("≥80%", colors.accent)
                LegendItem("60%+", colors.warning)
                LegendItem("<60%", colors.coral)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text("🔥", fontSize = 7.sp)
                    Text(
                        "3d+",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 7.5.sp,
                            fontWeight = FontWeight.Medium
                        ),
                        color = colors.text2
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))

        if (items.isEmpty()) {
            Box(Modifier.fillMaxWidth().height(60.dp), contentAlignment = Alignment.Center) {
                Text(SortydStrings.t(language, "No task data yet"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 12.sp), color = colors.text2)
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                items.forEach { (title, rate, streak) ->
                    DNABar(title, rate, streak)
                }
            }
        }
    }
}

@Composable
private fun LegendItem(label: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        Box(
            Modifier
                .size(7.dp)
                .clip(RoundedCornerShape(1.5.dp))
                .background(color)
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.5.sp, fontWeight = FontWeight.Medium),
            color = SortydColors.current.text2
        )
    }
}

@Composable
private fun DNABar(title: String, rate: Float, streak: Int) {
    val colors = SortydColors.current
    val barColor = when {
        rate >= 0.8f -> colors.accent
        rate >= 0.6f -> colors.warning
        else -> colors.coral
    }
    Row(
        Modifier
            .fillMaxWidth()
            .height(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            title,
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.SemiBold,
                fontSize = 9.sp
            ),
            color = colors.text0,
            modifier = Modifier.width(90.dp),
            maxLines = 1
        )
        Box(
            Modifier
                .weight(1f)
                .height(16.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(colors.borderSubtle.copy(0.5f))
        ) {
            Box(
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(rate)
                    .background(
                        Brush.horizontalGradient(listOf(barColor, barColor.copy(0.55f)))
                    )
            )
        }
        Text(
            "${(rate * 100).toInt()}%",
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.Bold,
                color = barColor,
                fontSize = 8.5.sp
            ),
            modifier = Modifier.width(26.dp),
            textAlign = TextAlign.End
        )
        if (streak >= 3) {
            Text("🔥", fontSize = 7.5.sp)
        } else {
            Spacer(Modifier.width(8.dp))
        }
    }
}

@Composable
private fun TrendChart(snapshots: List<DailySnapshot>, periodDays: Int, modifier: Modifier) {
    val colors = SortydColors.current
    val textMeasurer = rememberTextMeasurer()
    val now = LocalDate.now()
    val dataPoints = (0 until periodDays).map { d ->
        val date = now.minusDays((periodDays - 1 - d).toLong())
        val snap = snapshots.find { Instant.ofEpochMilli(it.date).atZone(ZoneId.systemDefault()).toLocalDate() == date }
        snap?.completionFraction?.toFloat() ?: 0f
    }

    Canvas(modifier) {
        val bottomPad = 20.dp.toPx()
        val chartW = size.width
        val chartH = size.height - bottomPad
        val usableH = chartH * 0.88f // Mirroring iOS's 88% vertical scaling for the line

        // Dash lines and labels
        val yPcts = listOf(100, 75, 50, 25)
        yPcts.forEach { pct ->
            val y = chartH - (pct.toFloat() / 100f * usableH)
            drawLine(
                colors.borderSubtle,
                Offset(0f, y),
                Offset(size.width, y),
                strokeWidth = 0.5.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 5.dp.toPx()))
            )
            drawText(
                textMeasurer,
                "$pct%",
                Offset(0f, y - 8.sp.toPx()),
                style = TextStyle(
                    color = colors.text2,
                    fontSize = 7.5.sp,
                    fontWeight = FontWeight.Medium
                )
            )
        }

        if (dataPoints.size > 1) {
            val points = dataPoints.mapIndexed { i, f ->
                Offset(
                    i.toFloat() / (periodDays - 1) * chartW,
                    chartH - (f * usableH)
                )
            }

            val path = Path().apply {
                moveTo(points.first().x, points.first().y)
                for (i in 1 until points.size) {
                    val prev = points[i - 1]
                    val curr = points[i]
                    val cp1 = Offset(prev.x + (curr.x - prev.x) / 3f, prev.y)
                    val cp2 = Offset(curr.x - (curr.x - prev.x) / 3f, curr.y)
                    cubicTo(cp1.x, cp1.y, cp2.x, cp2.y, curr.x, curr.y)
                }
            }

            // Fill
            val fillPath = Path().apply {
                addPath(path)
                lineTo(points.last().x, chartH)
                lineTo(points.first().x, chartH)
                close()
            }
            drawPath(
                fillPath,
                Brush.verticalGradient(
                    listOf(colors.accent.copy(0.18f), Color.Transparent),
                    startY = chartH - usableH,
                    endY = chartH
                )
            )

            // Stroke
            drawPath(
                path,
                Brush.horizontalGradient(listOf(colors.coral, colors.accent)),
                style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
            )

            // Last point glow
            val lp = points.last()
            drawCircle(colors.accent.copy(0.22f), 6.dp.toPx(), lp)
            drawCircle(colors.accent, 2.5.dp.toPx(), lp)
        }

        // X-Axis Labels
        val formatter = DateTimeFormatter.ofPattern("MMM d")
        val startDate = now.minusDays(periodDays.toLong() - 1)
        drawText(
            textMeasurer, startDate.format(formatter),
            Offset(0f, chartH + 4.dp.toPx()),
            style = TextStyle(color = colors.text2, fontSize = 7.5.sp, fontWeight = FontWeight.Medium)
        )
        if (periodDays >= 7) {
            val midDate = startDate.plusDays((periodDays / 2).toLong())
            val midLabel = midDate.format(formatter)
            val midResult = textMeasurer.measure(midLabel, TextStyle(fontSize = 7.5.sp, fontWeight = FontWeight.Medium))
            drawText(
                textMeasurer, midLabel,
                Offset(size.width / 2f - midResult.size.width / 2f, chartH + 4.dp.toPx()),
                style = TextStyle(color = colors.text2, fontSize = 7.5.sp, fontWeight = FontWeight.Medium)
            )
        }
        drawText(
            textMeasurer, "Today",
            Offset(size.width - 30.dp.toPx(), chartH + 4.dp.toPx()),
            style = TextStyle(color = colors.accent, fontSize = 7.5.sp, fontWeight = FontWeight.SemiBold)
        )
    }
}

// MARK: - Needs Attention Dashboard

data class TaskRecencyItem(val taskId: String, val title: String, val daysAgo: Int, val wasNeverDone: Boolean)

private fun recencyColor(daysAgo: Int?): Color {
    if (daysAgo == null) return Color(0xFFFF3B30) // Red
    return when (daysAgo) {
        in 0..2 -> Color(0xFF00D9FF) // Accent (shouldn't be shown, but for safety)
        3 -> Color(0xFFFFCC00) // Yellow
        4 -> Color(0xFFFF9500) // Orange
        5 -> Color(0xFFFF3B30) // Red
        6 -> Color(0xFFD70015) // Deep Red
        else -> Color(0xFFAF0000) // Dark Red
    }
}

private fun recencyHeatFraction(daysAgo: Int?): Float {
    if (daysAgo == null) return 1f
    val adjustedDays = maxOf(0, daysAgo - 2).toFloat()
    return minOf(1f, 0.4f + (adjustedDays * 0.15f))
}

@Composable
private fun TaskRecencyCard(items: List<TaskRecencyItem>) {
    val colors = SortydColors.current
    val leadColor = recencyColor(items.firstOrNull()?.daysAgo)
    val displayItems = items.take(5)

    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.8.dp, leadColor.copy(0.30f), RoundedCornerShape(20.dp))
            .padding(horizontal = 13.dp, vertical = 12.dp)
            .shadow(10.dp, ambientColor = leadColor.copy(0.12f), spotColor = leadColor.copy(0.12f))
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val isSevere = (items.firstOrNull()?.daysAgo ?: 0) >= 5
            Icon(
                if (isSevere) Icons.Default.Info else Icons.Default.Info, // Use Info icon for both for simplicity
                null,
                Modifier.size(8.dp),
                tint = leadColor
            )
            Text(
                "NEEDS ATTENTION",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.8.sp
                ),
                color = colors.text2
            )
            val itemCount = items.size
            val countLabel = if (itemCount == 1) "1 thing" else "$itemCount things"
            Box(
                Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (isSevere) leadColor else leadColor.copy(0.12f))
                    .border(0.5.dp, leadColor.copy(0.30f), RoundedCornerShape(50))
                    .padding(horizontal = 7.dp, vertical = 3.dp)
            ) {
                Text(
                    countLabel,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Black
                    ),
                    color = if (isSevere) Color.White else leadColor
                )
            }
            Spacer(Modifier.weight(1f))
            items.firstOrNull()?.let { lead ->
                Text(
                    if (lead.wasNeverDone) "New" else "${lead.daysAgo}d",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Black
                    ),
                    color = leadColor
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        // Rows
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            displayItems.forEach { item ->
                DormancyRow(item)
            }
            if (items.size > 5) {
                val extra = items.size - 5
                Text(
                    if (extra == 1) "+1 more thing" else "+$extra more things",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 8.5.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = colors.text2
                )
            }
        }
    }
}

@Composable
private fun DormancyRow(item: TaskRecencyItem) {
    val colors = SortydColors.current
    val color = recencyColor(item.daysAgo)
    val frac = recencyHeatFraction(item.daysAgo)

    Row(
        Modifier.fillMaxWidth().height(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            item.title,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            ),
            color = colors.text0,
            maxLines = 1,
            modifier = Modifier.weight(1f)
        )

        Box(
            Modifier
                .width(70.dp)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(colors.bg3.copy(0.40f))
        ) {
            Box(
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(frac)
                    .background(
                        Brush.horizontalGradient(listOf(color.copy(0.70f), color, color.copy(0.80f)))
                    )
            )
        }

        Text(
            if (item.wasNeverDone) "New" else "${item.daysAgo}d",
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 10.sp,
                fontWeight = FontWeight.Black
            ),
            color = color,
            modifier = Modifier.width(28.dp),
            textAlign = TextAlign.End
        )
    }
}
