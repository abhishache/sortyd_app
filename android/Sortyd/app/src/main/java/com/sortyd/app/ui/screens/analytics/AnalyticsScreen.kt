package com.sortyd.app.ui.screens.analytics

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sortyd.app.model.*
import com.sortyd.app.ui.components.*
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel
import java.text.SimpleDateFormat
import java.util.*

enum class AnalyticsPeriod(val label: String, val days: Int) {
    WEEK("7D", 7), MONTH("30D", 30), ALL("ALL", Int.MAX_VALUE)
}

@Composable
fun AnalyticsScreen(vm: AppViewModel = hiltViewModel()) {
    val c = sortydColors
    val lists by vm.lists.collectAsStateWithLifecycle()
    val snapshots by vm.snapshots.collectAsStateWithLifecycle()
    val installDate by vm.installDate.collectAsStateWithLifecycle()

    var period by remember { mutableStateOf(AnalyticsPeriod.WEEK) }
    var selectedListId by remember { mutableStateOf<String?>(null) }
    var showListPicker by remember { mutableStateOf(false) }

    val regularLists = lists.filter { !it.isArchived && !it.isTodo }

    // Auto-select on first composition
    LaunchedEffect(regularLists) {
        if (selectedListId == null && regularLists.isNotEmpty()) {
            selectedListId = regularLists.first().id
        }
    }

    val listId = selectedListId ?: regularLists.firstOrNull()?.id
    val selectedList = regularLists.firstOrNull { it.id == listId }
    val listSnaps = snapshots.filter { it.listId == listId }

    // Computed analytics
    val cutoff = System.currentTimeMillis() - when (period) {
        AnalyticsPeriod.WEEK -> 7L * 86400000
        AnalyticsPeriod.MONTH -> 30L * 86400000
        AnalyticsPeriod.ALL -> Long.MAX_VALUE / 2
    }
    val periodSnaps = listSnaps.filter { it.date >= cutoff }.sortedBy { it.date }
    val avg = if (periodSnaps.isEmpty()) 0.0 else periodSnaps.map { it.completionFraction }.average()
    val grade = vm.gradeFor(avg)
    val streak = vm.computeCurrentStreak(listId ?: "")

    // VS Last period
    val prevCutoff = cutoff - when (period) {
        AnalyticsPeriod.WEEK -> 7L * 86400000
        AnalyticsPeriod.MONTH -> 30L * 86400000
        AnalyticsPeriod.ALL -> 0L
    }
    val prevSnaps = listSnaps.filter { it.date >= prevCutoff && it.date < cutoff }
    val prevAvg = if (prevSnaps.isEmpty()) 0.0 else prevSnaps.map { it.completionFraction }.average()
    val vsPrev = if (prevAvg == 0.0) null else ((avg - prevAvg) / prevAvg) * 100

    // Weekday averages (Mon=0..Sun=6 for pattern)
    // Calendar.DAY_OF_WEEK returns 1=Sun, 2=Mon...
    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
    val weekdayAvgs = (0..6).map { dayIdx ->
        val calendarDay = if (dayIdx == 6) Calendar.SUNDAY else dayIdx + 2 
        val snapsForDay = periodSnaps.filter {
            Calendar.getInstance().apply { timeInMillis = it.date }.get(Calendar.DAY_OF_WEEK) == calendarDay
        }
        if (snapsForDay.isEmpty()) 0.0 else snapsForDay.map { it.completionFraction }.average()
    }
    
    val bestDayIdx = weekdayAvgs.indexOfMax()
    val weakDayIdx = weekdayAvgs.indexOfMin()

    // Task DNA
    val taskDNA: List<Triple<String, Double, Boolean>> = selectedList?.tasks?.map { task ->
        val taskSnaps = periodSnaps.filter { task.id in it.completedTaskIds }
        val rate = if (periodSnaps.isEmpty()) 0.0 else taskSnaps.size.toDouble() / periodSnaps.size
        val hasStreak = vm.computeTaskStreak(listId ?: "", task.id) >= 3
        Triple(task.title, rate, hasStreak)
    }?.sortedByDescending { it.second } ?: emptyList()

    val needsWorkTasks = taskDNA.filter { it.second < 0.4 }.take(5)

    // Days since install
    val daysSinceInstall = ((System.currentTimeMillis() - installDate) / 86400000).toInt()
    val showNewUserBanner = daysSinceInstall < 7

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(c.bg0)
            .verticalScroll(rememberScrollState())
    ) {
        // Header
        AnalyticsHeader(
            period = period,
            onPeriodChange = { period = it },
            selectedList = selectedList,
            onPickList = { showListPicker = true }
        )

        if (selectedList == null || listSnaps.isEmpty()) {
            if (showNewUserBanner) {
                NewUserBanner(daysLeft = 7 - daysSinceInstall)
            } else {
                EmptyAnalyticsState()
            }
        } else {
            // Hero card
            HeroGradeCard(grade = grade, avg = avg, streak = streak)

            // Small Insight row
            InsightTripleRow(
                vsPrev = vsPrev,
                bestDay = if (bestDayIdx >= 0) dayLabels[bestDayIdx] else "N/A",
                weakDay = if (weakDayIdx >= 0) dayLabels[weakDayIdx] else "N/A"
            )

            // Trend chart
            TrendChartCard(snaps = periodSnaps, period = period)

            // Day Pattern
            DayPatternCard(
                avgs = weekdayAvgs, 
                labels = dayLabels, 
                bestIdx = bestDayIdx,
                weakIdx = weakDayIdx
            )

            // Task DNA
            if (taskDNA.isNotEmpty()) {
                TaskDNACard(items = taskDNA)
            }

            // Needs Work
            if (needsWorkTasks.isNotEmpty()) {
                NeedsWorkSection(tasks = needsWorkTasks)
            }
        }
        Spacer(Modifier.height(140.dp))
    }

    if (showListPicker) {
        AnalyticsListPicker(
            lists = regularLists,
            selectedId = listId,
            onSelect = { selectedListId = it; showListPicker = false },
            onDismiss = { showListPicker = false }
        )
    }
}

@Composable
private fun AnalyticsHeader(
    period: AnalyticsPeriod,
    onPeriodChange: (AnalyticsPeriod) -> Unit,
    selectedList: TaskList?,
    onPickList: () -> Unit
) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 24.dp, vertical = 24.dp)
    ) {
        Text(
            "ANALYTICS",
            style = MaterialTheme.typography.labelSmall.copy(
                color = c.teal,
                fontWeight = FontWeight.Black,
                letterSpacing = 1.5.sp
            )
        )
        
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                "Report",
                style = MaterialTheme.typography.displayLarge.copy(
                    color = Color.White,
                    fontWeight = FontWeight.Black,
                    fontSize = 38.sp,
                    letterSpacing = (-1.5).sp
                )
            )

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                // Period selector
                Row(
                    modifier = Modifier
                        .background(Color.White.copy(alpha = 0.05f), CircleShape)
                        .padding(2.dp),
                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    AnalyticsPeriod.entries.forEach { p ->
                        val isSelected = period == p
                        Box(
                            modifier = Modifier
                                .background(
                                    if (isSelected) c.teal else Color.Transparent,
                                    CircleShape
                                )
                                .clickable { onPeriodChange(p) }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                p.label,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    color = if (isSelected) Color.Black else Color.White.copy(alpha = 0.4f),
                                    fontWeight = FontWeight.Black,
                                    fontSize = 10.sp
                                )
                            )
                        }
                    }
                }

                // List picker
                selectedList?.let { list ->
                    Box(
                        modifier = Modifier
                            .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(12.dp))
                            .clickable(onClick = onPickList)
                            .padding(horizontal = 10.dp, vertical = 8.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(list.emoji, fontSize = 14.sp)
                            Text(
                                list.cleanName.take(8),
                                style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.6f)),
                                maxLines = 1
                            )
                            Icon(Icons.Default.ExpandMore, null, tint = Color.White.copy(alpha = 0.3f), modifier = Modifier.size(14.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroGradeCard(grade: String, avg: Double, streak: Int) {
    val c = sortydColors
    val gradeColor = when {
        grade.startsWith("A") -> c.success
        grade.startsWith("B") -> c.teal
        grade.startsWith("C") -> c.warning
        else -> c.danger
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(32.dp))
    ) {
        // Subtle teal glow behind grade
        Box(
            modifier = Modifier
                .size(120.dp)
                .offset(x = (-20).dp, y = (-20).dp)
                .blur(40.dp)
                .background(gradeColor.copy(alpha = 0.1f), CircleShape)
        )

        Row(
            modifier = Modifier.padding(32.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    grade,
                    style = MaterialTheme.typography.displayLarge.copy(
                        color = gradeColor,
                        fontWeight = FontWeight.Black,
                        fontSize = 90.sp,
                        letterSpacing = (-5).sp
                    )
                )
                Text(
                    if (avg < 0.2) "Just starting" else if (avg < 0.5) "Making progress" else "On fire",
                    style = MaterialTheme.typography.bodyMedium.copy(color = gradeColor, fontWeight = FontWeight.Bold)
                )
            }

            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(horizontalAlignment = Alignment.End) {
                    Text("AVG", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Bold))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("${(avg * 100).toInt()}", style = MaterialTheme.typography.headlineLarge.copy(color = Color.White, fontWeight = FontWeight.Black, fontSize = 34.sp))
                        Text("%", style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.4f)), modifier = Modifier.padding(bottom = 6.dp, start = 2.dp))
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("STREAK", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Bold))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("$streak", style = MaterialTheme.typography.headlineLarge.copy(color = c.teal, fontWeight = FontWeight.Black, fontSize = 34.sp))
                        Text("d", style = MaterialTheme.typography.bodySmall.copy(color = c.teal.copy(alpha = 0.6f)), modifier = Modifier.padding(bottom = 6.dp, start = 2.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun InsightTripleRow(vsPrev: Double?, bestDay: String, weakDay: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        InsightSmallCard(
            label = "VS LAST",
            value = if (vsPrev == null) "N/A" else "${if (vsPrev > 0) "+" else ""}${vsPrev.toInt()}%",
            modifier = Modifier.weight(1f),
            valueColor = if (vsPrev == null) Color.White.copy(alpha = 0.4f) else if (vsPrev > 0) Color(0xFF4CAF50) else Color(0xFFFF5252)
        )
        InsightSmallCard(
            label = "BEST DAY",
            value = bestDay,
            modifier = Modifier.weight(1f),
            icon = Icons.Default.Star,
            iconColor = Color(0xFFFFD700)
        )
        InsightSmallCard(
            label = "WEAKEST",
            value = weakDay,
            modifier = Modifier.weight(1f),
            icon = Icons.Default.NightsStay,
            iconColor = Color(0xFF9FA8DA)
        )
    }
}

@Composable
private fun InsightSmallCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconColor: Color = Color.White,
    valueColor: Color = Color.White
) {
    Box(
        modifier = modifier
            .background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(20.dp))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(20.dp))
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            if (icon != null) {
                Icon(icon, null, tint = iconColor, modifier = Modifier.size(16.dp))
                Spacer(Modifier.height(4.dp))
            }
            Text(value, style = MaterialTheme.typography.headlineSmall.copy(color = valueColor, fontWeight = FontWeight.Black))
            Text(label, style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.2f), fontWeight = FontWeight.Bold, fontSize = 8.sp, letterSpacing = 0.5.sp))
        }
    }
}

@Composable
private fun TrendChartCard(snaps: List<DailySnapshot>, period: AnalyticsPeriod) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(32.dp))
            .padding(24.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("${period.label} TREND", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(modifier = Modifier.size(6.dp).background(c.teal, CircleShape))
                Text("completion", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f)))
            }
        }
        
        Spacer(Modifier.height(32.dp))

        Box(modifier = Modifier.fillMaxWidth().height(160.dp)) {
            // Background grid lines (very subtle)
            Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.SpaceBetween) {
                repeat(4) { 
                    HorizontalDivider(color = Color.White.copy(alpha = 0.03f), thickness = 1.dp)
                }
            }

            Canvas(modifier = Modifier.fillMaxSize()) {
                if (snaps.isEmpty()) return@Canvas
                val w = size.width
                val h = size.height

                val pts = snaps.mapIndexed { i, snap ->
                    Offset(
                        w * i / (snaps.size - 1).coerceAtLeast(1),
                        h * (1f - snap.completionFraction.toFloat())
                    )
                }
                
                if (pts.size > 1) {
                    val path = Path().apply {
                        pts.forEachIndexed { i, pt ->
                            if (i == 0) moveTo(pt.x, pt.y)
                            else {
                                val prev = pts[i - 1]
                                val midX = (prev.x + pt.x) / 2
                                cubicTo(midX, prev.y, midX, pt.y, pt.x, pt.y)
                            }
                        }
                    }

                    // Gradient fill
                    val fillPath = Path().apply {
                        addPath(path)
                        lineTo(pts.last().x, h)
                        lineTo(pts.first().x, h)
                        close()
                    }
                    drawPath(
                        fillPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(c.teal.copy(alpha = 0.15f), Color.Transparent),
                            startY = 0f,
                            endY = h
                        )
                    )

                    drawPath(
                        path,
                        c.teal,
                        style = Stroke(4f, cap = StrokeCap.Round)
                    )
                    
                    // Current day dot
                    drawCircle(c.teal, radius = 6f, center = pts.last())
                    drawCircle(c.teal.copy(alpha = 0.2f), radius = 14f, center = pts.last())
                }
            }
        }
        
        Spacer(Modifier.height(12.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            val dateStr = if (snaps.isNotEmpty()) {
                val sdf = SimpleDateFormat("MMM d", Locale.getDefault())
                sdf.format(Date(snaps.first().date))
            } else ""
            Text(dateStr, style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.2f)))
            Text("Today", style = MaterialTheme.typography.labelSmall.copy(color = c.teal, fontWeight = FontWeight.Bold))
        }
    }
}

@Composable
private fun DayPatternCard(avgs: List<Double>, labels: List<String>, bestIdx: Int, weakIdx: Int) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp)
            .background(Color.White.copy(alpha = 0.03f), RoundedCornerShape(24.dp))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(24.dp))
            .padding(20.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("DAY-OF-WEEK PATTERN", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
                Text("When you perform best", style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.2f)))
            }
            
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("LOW", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.2f), fontSize = 8.sp))
                repeat(4) { idx ->
                    Box(modifier = Modifier.size(10.dp, 6.dp).background(c.teal.copy(alpha = 0.1f + 0.25f * idx), RoundedCornerShape(1.dp)))
                }
                Text("HIGH", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.2f), fontSize = 8.sp))
            }
        }
        
        Spacer(Modifier.height(24.dp))

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            avgs.forEachIndexed { idx, avg ->
                val isBest = idx == bestIdx && avg > 0
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(
                        modifier = Modifier
                            .width(42.dp)
                            .height(60.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isBest) c.teal else Color.White.copy(alpha = 0.05f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            if (isBest) {
                                Icon(Icons.Default.EmojiEvents, null, tint = Color.Black.copy(alpha = 0.4f), modifier = Modifier.size(14.dp))
                            }
                            Text("${(avg * 100).toInt()}%", style = MaterialTheme.typography.labelSmall.copy(color = if (isBest) Color.Black else Color.White, fontWeight = FontWeight.Black))
                        }
                    }
                    Text(labels[idx], style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.2f), fontWeight = FontWeight.Bold))
                }
            }
        }

        if (bestIdx != -1 && weakIdx != -1 && bestIdx != weakIdx) {
            Spacer(Modifier.height(20.dp))
            val diff = ((avgs[bestIdx] - avgs[weakIdx]) * 100).toInt()
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.Lightbulb, null, tint = c.teal, modifier = Modifier.size(14.dp))
                Text(
                    "${labels[bestIdx]}s are $diff% stronger than ${labels[weakIdx]}s",
                    style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.4f))
                )
            }
        }
    }
}

@Composable
private fun TaskDNACard(items: List<Triple<String, Double, Boolean>>) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(32.dp))
            .padding(24.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("TASK DNA", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
                Text("Efficiency by task", style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.2f)))
            }
            
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DNAPill("≥80%", c.teal)
                DNAPill("60%+", Color(0xFFFFBC55))
            }
        }

        Spacer(Modifier.height(24.dp))
        
        items.take(10).forEach { (title, rate, hasStreak) ->
            val barColor = when {
                rate >= 0.8 -> c.teal
                rate >= 0.6 -> Color(0xFFFFBC55)
                else -> Color.White.copy(alpha = 0.2f)
            }
            
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(modifier = Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        title, 
                        style = MaterialTheme.typography.bodySmall.copy(color = Color.White.copy(alpha = 0.7f)),
                        maxLines = 1, 
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    if (hasStreak) {
                        Icon(
                            Icons.Default.Whatshot, 
                            contentDescription = "Streak",
                            tint = Color(0xFFFF5722),
                            modifier = Modifier.size(12.dp)
                        )
                    }
                }
                
                Box(modifier = Modifier.weight(1f).height(8.dp).background(Color.White.copy(alpha = 0.05f), CircleShape)) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(rate.toFloat())
                            .background(
                                Brush.horizontalGradient(listOf(barColor.copy(alpha = 0.4f), barColor)),
                                CircleShape
                            )
                    )
                }
                
                Text("${(rate * 100).toInt()}%", style = MaterialTheme.typography.labelSmall.copy(color = barColor, fontWeight = FontWeight.Black), modifier = Modifier.width(36.dp), textAlign = TextAlign.End)
            }
        }
    }
}

@Composable
private fun DNAPill(label: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(modifier = Modifier.size(8.dp).background(color, RoundedCornerShape(2.dp)))
        Text(label, style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontSize = 8.sp))
    }
}

@Composable
private fun NeedsWorkSection(tasks: List<Triple<String, Double, Boolean>>) {
    val c = sortydColors
    Column(modifier = Modifier.padding(vertical = 12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.Warning, null, tint = c.teal, modifier = Modifier.size(16.dp))
                Text("NEEDS WORK", style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
            }
            Text("${tasks.size} tasks", style = MaterialTheme.typography.labelSmall.copy(color = c.teal, fontWeight = FontWeight.Bold))
        }

        Spacer(Modifier.height(16.dp))

        LazyRow(
            contentPadding = PaddingValues(horizontal = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(tasks) { (title, rate, _) ->
                Box(
                    modifier = Modifier
                        .size(width = 130.dp, height = 110.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(Color.White.copy(alpha = 0.03f))
                        .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(24.dp))
                        .padding(16.dp)
                ) {
                    // Subtle red glow
                    Box(modifier = Modifier.size(40.dp).offset(y = 60.dp).blur(20.dp).background(c.danger.copy(alpha = 0.1f), CircleShape))

                    Column(verticalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize()) {
                        Text(title, style = MaterialTheme.typography.bodySmall.copy(color = Color.White, fontWeight = FontWeight.SemiBold), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        
                        Column {
                            Row(verticalAlignment = Alignment.Bottom) {
                                Text("${(rate * 100).toInt()}", style = MaterialTheme.typography.headlineSmall.copy(color = c.danger, fontWeight = FontWeight.Black, fontSize = 24.sp))
                                Text("%", style = MaterialTheme.typography.labelSmall.copy(color = c.danger.copy(alpha = 0.4f)), modifier = Modifier.padding(bottom = 4.dp, start = 1.dp))
                            }
                            Spacer(Modifier.height(4.dp))
                            Box(modifier = Modifier.fillMaxWidth().height(4.dp).background(Color.White.copy(alpha = 0.05f), CircleShape)) {
                                Box(modifier = Modifier.fillMaxHeight().fillMaxWidth(rate.toFloat()).background(c.danger, CircleShape))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NewUserBanner(daysLeft: Int) {
    val c = sortydColors
    val messages = listOf(
        "You're just getting started. Keep showing up! 🌱",
        "Building streaks takes consistency. You've got this!",
        "Your analytics will fill in as you track more days.",
        "Every task completed is data for your insights."
    )
    val msg = messages[(daysLeft % messages.size)]

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp)
            .background(c.accent.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(1.dp, c.accent.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Analytics filling in… ($daysLeft days left)",
                style = MaterialTheme.typography.headlineSmall.copy(color = c.accent))
            Text(msg, style = MaterialTheme.typography.bodyMedium.copy(color = c.text1))
        }
    }
}

@Composable
private fun EmptyAnalyticsState() {
    val c = sortydColors
    Column(
        modifier = Modifier.fillMaxWidth().padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("No data yet", style = MaterialTheme.typography.headlineMedium.copy(color = c.text2),
            textAlign = TextAlign.Center)
        Text("Complete tasks to see your analytics",
            style = MaterialTheme.typography.bodyMedium.copy(color = c.text2),
            textAlign = TextAlign.Center)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AnalyticsListPicker(
    lists: List<TaskList>,
    selectedId: String?,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val c = sortydColors
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = c.bg1) {
        Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Select List", style = MaterialTheme.typography.headlineMedium.copy(color = c.text0))
            lists.forEach { list ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(if (list.id == selectedId) c.accent.copy(alpha = 0.1f) else Color.Transparent, RoundedCornerShape(10.dp))
                        .clickable { onSelect(list.id) }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(list.emoji)
                    Text(list.cleanName, style = MaterialTheme.typography.bodyMedium.copy(color = c.text0), modifier = Modifier.weight(1f))
                    if (list.id == selectedId) Icon(Icons.Default.Check, null, tint = c.accent, modifier = Modifier.size(16.dp))
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

// ─── Helper Extensions ────────────────────────────────────────────────────────

private fun List<Double>.indexOfMax(): Int {
    if (isEmpty()) return -1
    return indices.maxByOrNull { get(it) } ?: -1
}

private fun List<Double>.indexOfMin(): Int {
    if (isEmpty()) return -1
    return indices.filter { get(it) > 0 }.minByOrNull { get(it) } ?: -1
}
