package com.sortyd.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import java.time.format.DateTimeFormatter
import java.time.ZoneId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.*

@Composable
fun HeatmapCalendar(
    snapshots: Map<Long, Double>, // dateMillis -> fraction
    installDate: Long,
    currentMonth: YearMonth = YearMonth.now(),
    onDayTap: (LocalDate) -> Unit,
    onMonthPickerTap: () -> Unit,
    onGoToToday: () -> Unit,
    modifier: Modifier = Modifier,
    language: String = "en",
) {
    val colors = SortydColors.current
    val today = LocalDate.now()
    val isCurrentMonth = currentMonth == YearMonth.now()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(colors.bg1.copy(alpha = 0.6f))
            .border(0.5.dp, colors.text2.copy(alpha = 0.1f), RoundedCornerShape(18.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        // Header: Month + (Today Button or Legend)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().height(20.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable { onMonthPickerTap() }
            ) {
                val monthLabel = currentMonth.month.getDisplayName(TextStyle.FULL, localeForLanguage(language))
                Text(
                    text = "$monthLabel ${currentMonth.year}",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold, fontSize = 11.sp),
                    color = colors.text1,
                )
                Icon(
                    Icons.Default.KeyboardArrowDown,
                    contentDescription = SortydStrings.t(language, "Change Month"),
                    tint = colors.accent,
                    modifier = Modifier.size(12.dp).padding(start = 2.dp)
                )
            }
            Spacer(Modifier.weight(1f))

            if (!isCurrentMonth) {
                // Today button
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(colors.accent.copy(alpha = 0.12f))
                        .clickable { onGoToToday() }
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                ) {
                    Text(
                        SortydStrings.t(language, "Today"),
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold),
                        color = colors.accent
                    )
                }
            } else {
                // Legend: Low [][][][][] Best
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(SortydStrings.t(language, "Low"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, letterSpacing = 0.sp), color = colors.text2)
                    Spacer(Modifier.width(4.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) {
                        (1..6).forEach { i ->
                            val frac = i.toDouble() / 6.0
                            Box(
                                Modifier
                                    .size(7.dp)
                                    .background(
                                        getHeatColor(frac, isDark = true), // Forcing dark for now as per theme
                                        RoundedCornerShape(1.dp)
                                    )
                            )
                        }
                    }
                    Spacer(Modifier.width(4.dp))
                    Text(SortydStrings.t(language, "Best"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, letterSpacing = 0.sp), color = colors.text2)
                }
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // Day-of-week headers (S, M, T, W, T, F, S)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            val daysOfWeek = localizedWeekdayInitials(language)
            daysOfWeek.forEach { day ->
                Text(
                    text = day,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Medium),
                    color = colors.text2,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        Spacer(modifier = Modifier.height(2.dp))

        // Calendar grid
        val firstDay = currentMonth.atDay(1)
        val firstDayOfWeek = firstDay.dayOfWeek.value % 7 // Sunday=0
        val daysInMonth = currentMonth.lengthOfMonth()

        val cells = mutableListOf<LocalDate?>()
        repeat(firstDayOfWeek) { cells.add(null) }
        for (d in 1..daysInMonth) cells.add(currentMonth.atDay(d))
        // No extra empty rows logic in iOS code, but we need to complete the last week
        while (cells.size % 7 != 0) cells.add(null)

        cells.chunked(7).forEach { week ->
            Spacer(modifier = Modifier.height(2.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                week.forEach { date ->
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .weight(1f)
                            .height(22.dp)
                            .padding(1.dp),
                    ) {
                        if (date != null) {
                            val isToday = date == today
                            val isFuture = date.isAfter(today)
                            val isInstallDay = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() == installDate
                            val isGhost = !isFuture && date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() < installDate
                            
                            val dateMillis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                            val fraction = snapshots[dateMillis]

                            HeatCell(
                                date = date,
                                fraction = fraction,
                                isToday = isToday,
                                isFuture = isFuture,
                                isInstallDay = isInstallDay,
                                isGhost = isGhost,
                                onClick = { onDayTap(date) },
                            )
                        }
                    }
                }
            }
        }
    }
}

fun getHeatColor(fraction: Double, isDark: Boolean): Color {
    if (fraction <= 0) return if (isDark) Color(0xFF1E1E1E) else Color(0xFFF0EEF8)
    
    val t = fraction.coerceIn(0.0, 1.0)
    return if (isDark) {
        val g = 196.0 + (217.0 - 196.0) * t
        val b = 180.0 + (255.0 - 180.0) * t
        Color(red = 0f, green = (g / 255.0).toFloat(), blue = (b / 255.0).toFloat(), alpha = (0.30 + t * 0.70).toFloat())
    } else {
        val r = 90.0 + (0.0 - 90.0) * t
        val g = 78.0 + (153.0 - 78.0) * t
        val b = 204.0 + (200.0 - 204.0) * t
        Color(red = (r / 255.0).toFloat(), green = (g / 255.0).toFloat(), blue = (b / 255.0).toFloat(), alpha = (0.25 + t * 0.75).toFloat())
    }
}

@Composable
private fun HeatCell(
    date: LocalDate,
    fraction: Double?,
    isToday: Boolean,
    isFuture: Boolean,
    isInstallDay: Boolean,
    isGhost: Boolean,
    onClick: () -> Unit,
) {
    val colors = SortydColors.current
    val isDark = true // Assuming dark mode for now as per theme logic

    val cellColor = when {
        isFuture -> colors.text0.copy(alpha = 0.05f)
        isGhost -> Color.Transparent
        fraction == null || fraction <= 0 -> colors.text0.copy(alpha = 0.15f)
        else -> getHeatColor(fraction, isDark)
    }

    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val glowPulse by infiniteTransition.animateFloat(
        initialValue = 0.06f,
        targetValue = 0.16f,
        animationSpec = infiniteRepeatable(
            animation = tween(1600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowPulse"
    )
    
    val sparkRotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(4500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "sparkRotation"
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .fillMaxSize()
            .clickable(enabled = !isFuture) { onClick() }
    ) {
        if (isToday) {
            // Glow and rings
            Canvas(Modifier.fillMaxSize()) {
                val baseSize = this.size.minDimension
                val arcSize = baseSize * 1.32f
                
                // Outer glow
                drawCircle(
                    color = colors.accent.copy(alpha = glowPulse),
                    radius = baseSize * 0.95f,
                    center = center
                )
                
                // Rotating dashed arc
                rotate(sparkRotation, center) {
                    drawArc(
                        brush = Brush.sweepGradient(
                            listOf(colors.accent.copy(alpha = 0f), colors.accent.copy(alpha = 0.9f), colors.accent.copy(alpha = 0f))
                        ),
                        startAngle = 0f,
                        sweepAngle = 260f,
                        useCenter = false,
                        style = Stroke(
                            width = 1.2.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.5.dp.toPx(), 4.0.dp.toPx()))
                        ),
                        size = Size(arcSize, arcSize),
                        topLeft = Offset(center.x - arcSize / 2, center.y - arcSize / 2)
                    )
                }

                // Inner circle
                drawCircle(
                    color = cellColor,
                    radius = baseSize / 2,
                    center = center
                )
                
                // Border ring
                drawCircle(
                    brush = Brush.sweepGradient(
                        listOf(colors.accent, colors.coral.copy(alpha = 0.7f), colors.accent.copy(alpha = 0.5f), colors.accent)
                    ),
                    radius = baseSize / 2,
                    center = center,
                    style = Stroke(width = 1.5.dp.toPx())
                )
            }
        } else {
            Canvas(Modifier.fillMaxSize()) {
                val baseSize = this.size.minDimension
                if (isGhost) {
                    drawCircle(
                        color = colors.text0.copy(alpha = 0.15f),
                        radius = baseSize / 2,
                        center = center,
                        style = Stroke(
                            width = 0.5.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx()))
                        )
                    )
                } else {
                    drawCircle(
                        color = cellColor,
                        radius = baseSize / 2,
                        center = center
                    )
                }
            }
        }
        
        if (isInstallDay && !isToday && !isFuture) {
             InstallDayRingOverlay()
        }

        Text(
            text = "${date.dayOfMonth}",
            style = TextStyle(
                fontSize = 8.sp,
                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                fontFamily = FontFamily.Default
            ),
            color = when {
                isFuture -> colors.text0.copy(alpha = 0.18f)
                fraction != null && fraction >= 0.75 -> Color.White
                fraction != null && fraction > 0 -> colors.text0
                else -> colors.text0.copy(alpha = 0.6f)
            }
        )
    }
}

@Composable
private fun InstallDayRingOverlay() {
    val colors = SortydColors.current
    val green = Color(0xFF22C55E)
    val infiniteTransition = rememberInfiniteTransition(label = "install_ring")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(7000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    val textMeasurer = rememberTextMeasurer()
    val label = "· FIRST DAY "
    
    Canvas(Modifier.fillMaxSize()) {
        val baseSize = this.size.minDimension
        val ringR = baseSize * 0.60f
        
        // Faint ring
        drawCircle(
            color = green.copy(alpha = 0.25f),
            radius = ringR,
            center = center,
            style = Stroke(width = 0.75.dp.toPx())
        )
        
        rotate(rotation, center) {
            val step = 360f / label.length
            val fSize = maxOf(4.5f, (baseSize * 0.18f).toDp().toPx())
            
            label.forEachIndexed { i, char ->
                val angleDeg = i * step
                val angleRad = (angleDeg - 90) * Math.PI / 180
                
                val x = center.x + ringR * Math.cos(angleRad).toFloat()
                val y = center.y + ringR * Math.sin(angleRad).toFloat()
                
                rotate(angleDeg, Offset(x, y)) {
                    drawText(
                        textMeasurer = textMeasurer,
                        text = char.toString(),
                        topLeft = Offset(x - (fSize / 2), y - (fSize / 2)),
                        style = TextStyle(
                            color = green,
                            fontSize = (fSize / density).sp, // Convert px back to sp for style
                            fontWeight = FontWeight.Black
                        )
                    )
                }
            }
        }
    }
}
@Composable
fun MonthPickerSheet(
    selectedMonth: YearMonth,
    language: String = "en",
    onMonthSelected: (YearMonth) -> Unit,
    onDismiss: () -> Unit
) {
    val colors = SortydColors.current
    val months = remember {
        val now = YearMonth.now()
        (0..24).map { now.minusMonths(it.toLong()) }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.bg0)
            .padding(bottom = 24.dp)
    ) {
        // Handle bar
        Box(
            modifier = Modifier
                .padding(top = 12.dp, bottom = 16.dp)
                .size(36.dp, 4.dp)
                .clip(CircleShape)
                .background(colors.bg3)
                .align(Alignment.CenterHorizontally)
        )

        Text(
            text = SortydStrings.t(language, "SELECT MONTH"),
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp),
            color = colors.text2,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp)
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
        ) {
            months.forEach { month ->
                val isSelected = month == selectedMonth
                val isCurrent = month == YearMonth.now()
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (isSelected) colors.accent.copy(alpha = 0.08f) else Color.Transparent)
                        .border(
                            0.5.dp,
                            if (isSelected) colors.accent.copy(alpha = 0.25f) else Color.Transparent,
                            RoundedCornerShape(14.dp)
                        )
                        .clickable { 
                            onMonthSelected(month)
                            onDismiss()
                        }
                        .padding(horizontal = 20.dp, vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val monthLabel = month.month.getDisplayName(TextStyle.FULL, localeForLanguage(language))
                    Text(
                        text = "$monthLabel ${month.year}",
                        style = MaterialTheme.typography.bodyLarge.copy(
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                        ),
                        color = if (isSelected) colors.accent else colors.text0,
                        modifier = Modifier.weight(1f)
                    )

                    if (isCurrent) {
                        Box(
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(colors.bg3)
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        ) {
                            Text(
                                SortydStrings.t(language, "current"),
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, fontWeight = FontWeight.Medium),
                                color = colors.text2
                            )
                        }
                    }

                    if (isSelected) {
                        Spacer(Modifier.width(8.dp))
                        Icon(
                            androidx.compose.material.icons.Icons.Default.Check,
                            contentDescription = null,
                            tint = colors.accent,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

private fun localeForLanguage(language: String): Locale = when {
    language.startsWith("zh", ignoreCase = true) -> Locale.SIMPLIFIED_CHINESE
    language.startsWith("ar", ignoreCase = true) -> Locale("ar")
    language.startsWith("es", ignoreCase = true) -> Locale("es")
    else -> Locale.ENGLISH
}

private fun localizedWeekdayInitials(language: String): List<String> {
    val locale = localeForLanguage(language)
    val symbols = java.text.DateFormatSymbols(locale).shortWeekdays
    return listOf(1, 2, 3, 4, 5, 6, 7).map { symbols[it].take(1).ifBlank { " " } }
}
