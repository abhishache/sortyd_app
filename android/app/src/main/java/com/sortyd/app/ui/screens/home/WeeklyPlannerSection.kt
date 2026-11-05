package com.sortyd.app.ui.screens.home

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.ui.theme.glow
import com.sortyd.app.viewmodel.SortydViewModel
import java.text.DateFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable
fun WeeklyPlannerSection(
    viewModel: SortydViewModel,
    language: String,
    targetListId: String,
    tasks: List<SortydTask>,
    modifier: Modifier = Modifier,
) {
    val colors = SortydColors.current
    var weekOffset by remember { mutableIntStateOf(0) }
    var selectedSlot by remember { mutableStateOf<Long?>(null) }
    val weekStart = remember(weekOffset) { startOfWeek(weekOffset) }
    val weekDays = remember(weekStart) { (0..6).map { addDays(weekStart, it) } }
    val plannedTasks = remember(tasks, weekStart) {
        tasks.filter { task ->
            val reminder = task.reminderTime ?: return@filter false
            reminder >= weekStart.timeInMillis && reminder < addDays(weekStart, 7).timeInMillis
        }
    }

    Column(modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        WeeklyHeader(
            language = language,
            weekStart = weekStart,
            weekEnd = addDays(weekStart, 6),
            onPrevious = { weekOffset -= 1 },
            onNext = { weekOffset += 1 }
        )

        Spacer(Modifier.height(10.dp))
        WeekRhythmStrip(language)
        Spacer(Modifier.height(12.dp))

        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(colors.bg1)
                .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(16.dp))
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.AccessTime, null, tint = colors.accent, modifier = Modifier.size(15.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                SortydStrings.t(language, "Tap a time slot to add a task"),
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                color = colors.text1
            )
        }

        Spacer(Modifier.height(12.dp))

        WeekGrid(
            language = language,
            days = weekDays,
            tasks = plannedTasks,
            onSlotTap = { selectedSlot = it }
        )
    }

    selectedSlot?.let { slot ->
        PlannedTaskSheet(
            language = language,
            slotMillis = slot,
            onDismiss = { selectedSlot = null },
            onSave = { title, duration, color ->
                viewModel.addTask(
                    listId = targetListId,
                    title = title,
                    reminderTime = slot,
                    reminderIsOneTime = true,
                    notificationLeadMinutes = 10,
                    durationMinutes = duration,
                    healthType = null,
                    healthTarget = null
                )
                selectedSlot = null
            }
        )
    }
}

@Composable
private fun WeeklyHeader(language: String, weekStart: Calendar, weekEnd: Calendar, onPrevious: () -> Unit, onNext: () -> Unit) {
    val colors = SortydColors.current
    val locale = localeFor(language)
    val month = SimpleDateFormat("MMMM yyyy", locale).format(weekStart.time)
    val range = "${SimpleDateFormat("MMM d", locale).format(weekStart.time)} – ${SimpleDateFormat("MMM d", locale).format(weekEnd.time)}"

    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onPrevious, modifier = Modifier.size(42.dp).clip(CircleShape).background(colors.bg1)) {
            Icon(Icons.Default.ChevronLeft, null, tint = colors.text1)
        }
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.CalendarMonth, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Text(month, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Black), color = colors.text0)
            }
            Text(range, style = MaterialTheme.typography.labelMedium, color = colors.text2)
        }
        IconButton(onClick = onNext, modifier = Modifier.size(42.dp).clip(CircleShape).background(colors.bg1)) {
            Icon(Icons.Default.ChevronRight, null, tint = colors.text1)
        }
    }
}

@Composable
private fun WeekRhythmStrip(language: String) {
    val colors = SortydColors.current
    val chips = listOf(
        SortydStrings.t(language, "Peak") to colors.accent,
        SortydStrings.t(language, "Deep work") to Color(0xFF7C6FFF),
        SortydStrings.t(language, "Reset") to colors.success,
        SortydStrings.t(language, "Social") to colors.coral
    )
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.linearGradient(listOf(colors.bg1, colors.bg2.copy(0.65f))))
            .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(18.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Flag, null, tint = colors.accent, modifier = Modifier.size(15.dp))
            Spacer(Modifier.width(8.dp))
            Text(SortydStrings.t(language, "Week focus"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Black), color = colors.text0)
        }
        Spacer(Modifier.height(4.dp))
        Text(SortydStrings.t(language, "Plan the week around energy, not just dates."), style = MaterialTheme.typography.bodySmall, color = colors.text2)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
            chips.forEach { (label, color) ->
                Box(Modifier.clip(RoundedCornerShape(14.dp)).background(color.copy(0.12f)).border(0.5.dp, color.copy(0.28f), RoundedCornerShape(14.dp)).padding(horizontal = 10.dp, vertical = 6.dp)) {
                    Text(label, style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold), color = color)
                }
            }
        }
    }
}

@Composable
private fun WeekGrid(language: String, days: List<Calendar>, tasks: List<SortydTask>, onSlotTap: (Long) -> Unit) {
    val colors = SortydColors.current
    val locale = localeFor(language)
    val today = Calendar.getInstance()
    val now = Calendar.getInstance()
    val dayWidth = 58.dp
    val hourHeight = 56.dp
    val hours = 6..22

    Row(Modifier.horizontalScroll(rememberScrollState())) {
        Column(Modifier.width(48.dp)) {
            Spacer(Modifier.height(52.dp))
            hours.forEach { hour ->
                Box(Modifier.height(hourHeight).fillMaxWidth(), contentAlignment = Alignment.TopEnd) {
                    Text(hourLabel(hour), style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = colors.text2)
                }
            }
        }
        Column {
            Row {
                days.forEach { day ->
                    val isToday = sameDay(day, today)
                    Column(Modifier.width(dayWidth).height(52.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        Text(DateFormatSymbols(locale).shortWeekdays[day.get(Calendar.DAY_OF_WEEK)].uppercase(locale), style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.sp, fontWeight = FontWeight.Black), color = if (isToday) colors.accent else colors.text2)
                        Text("${day.get(Calendar.DAY_OF_MONTH)}", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Black), color = if (isToday) colors.accent else colors.text0)
                    }
                }
            }
            Box {
                Row {
                    days.forEach { day ->
                        Column(Modifier.width(dayWidth)) {
                            hours.forEach { hour ->
                                val slot = day.clone() as Calendar
                                slot.set(Calendar.HOUR_OF_DAY, hour)
                                slot.set(Calendar.MINUTE, 0)
                                slot.set(Calendar.SECOND, 0)
                                slot.set(Calendar.MILLISECOND, 0)
                                Box(
                                    Modifier
                                        .height(hourHeight)
                                        .fillMaxWidth()
                                        .background(if (sameDay(day, today)) colors.accent.copy(0.035f) else Color.Transparent)
                                        .border(0.35.dp, colors.borderSubtle.copy(alpha = 0.55f))
                                        .clickable { onSlotTap(slot.timeInMillis) }
                                )
                            }
                        }
                    }
                }

                if (sameWeek(days.first(), now)) {
                    val dayIndex = days.indexOfFirst { sameDay(it, now) }
                    if (dayIndex >= 0 && now.get(Calendar.HOUR_OF_DAY) in hours) {
                        val y = ((now.get(Calendar.HOUR_OF_DAY) - hours.first) * 56 + now.get(Calendar.MINUTE) / 60f * 56).dp
                        Row(Modifier.offset(x = (dayWidth * dayIndex) + 1.dp, y = y).width(dayWidth - 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.height(2.dp).weight(1f).background(colors.accent))
                            Text(SortydStrings.t(language, "Current time"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp), color = colors.accent, modifier = Modifier.background(colors.bg0, RoundedCornerShape(8.dp)).padding(horizontal = 4.dp, vertical = 1.dp))
                        }
                    }
                }

                tasks.forEach { task ->
                    val reminder = task.reminderTime ?: return@forEach
                    val cal = Calendar.getInstance().apply { timeInMillis = reminder }
                    val dayIndex = days.indexOfFirst { sameDay(it, cal) }
                    val hour = cal.get(Calendar.HOUR_OF_DAY)
                    if (dayIndex >= 0 && hour in hours) {
                        val minute = cal.get(Calendar.MINUTE)
                        val duration = (task.durationMinutes ?: 30).coerceIn(15, 120)
                        PlannedTaskTile(
                            task = task,
                            modifier = Modifier
                                .offset(x = dayWidth * dayIndex + 4.dp, y = ((hour - hours.first) * 56 + minute / 60f * 56 + 3).dp)
                                .width(dayWidth - 8.dp)
                                .height((duration / 60f * 56).dp.coerceAtLeast(28.dp))
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PlannedTaskTile(task: SortydTask, modifier: Modifier = Modifier) {
    val colors = SortydColors.current
    val lift by animateFloatAsState(1f, spring(dampingRatio = 0.72f), label = "tileLift")
    Box(
        modifier
            .graphicsLayer {
                shadowElevation = 14f * lift
                rotationX = 4f
                cameraDistance = 16f * density
            }
            .clip(RoundedCornerShape(10.dp))
            .background(Brush.verticalGradient(listOf(colors.accent.copy(0.96f), colors.accent.copy(0.72f))))
            .border(0.8.dp, Color.White.copy(0.34f), RoundedCornerShape(10.dp))
            .padding(7.dp)
    ) {
        Text(task.title, style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Black), color = colors.bg0, maxLines = 2)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlannedTaskSheet(language: String, slotMillis: Long, onDismiss: () -> Unit, onSave: (String, Int, Color) -> Unit) {
    val colors = SortydColors.current
    var title by remember { mutableStateOf("") }
    var selectedDuration by remember { mutableIntStateOf(30) }
    val durationOptions = listOf(15, 30, 60)
    val slotLabel = remember(slotMillis, language) {
        SimpleDateFormat("d MMM yyyy 'at' h:mm a", localeFor(language)).format(java.util.Date(slotMillis))
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = colors.bg1,
        dragHandle = null,
        shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 22.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onDismiss, modifier = Modifier.size(42.dp).clip(CircleShape).background(colors.bg2)) {
                    Icon(Icons.Default.Close, null, tint = colors.accent)
                }
                Text(SortydStrings.t(language, "New planned task"), modifier = Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black), color = colors.text0)
                Spacer(Modifier.size(42.dp))
            }
            Spacer(Modifier.height(10.dp))
            Text(slotLabel, modifier = Modifier.align(Alignment.CenterHorizontally).clip(RoundedCornerShape(18.dp)).background(colors.bg2).padding(horizontal = 12.dp, vertical = 6.dp), style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold), color = colors.text2)
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text(SortydStrings.t(language, "Task")) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.accent, unfocusedBorderColor = colors.bg3, cursorColor = colors.accent)
            )
            Spacer(Modifier.height(16.dp))
            Text(SortydStrings.t(language, "Task timer").uppercase(localeFor(language)), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.4.sp, fontWeight = FontWeight.Black), color = colors.text2)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                durationOptions.forEach { minutes ->
                    val selected = selectedDuration == minutes
                    val bg by animateColorAsState(if (selected) colors.accent else colors.bg2, label = "durationBg")
                    Box(Modifier.clip(RoundedCornerShape(14.dp)).background(bg).clickable { selectedDuration = minutes }.padding(horizontal = 14.dp, vertical = 9.dp)) {
                        Text("${minutes}m", style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Black), color = if (selected) colors.bg0 else colors.text1)
                    }
                }
            }
            Spacer(Modifier.height(22.dp))
            Button(
                onClick = { onSave(title.trim(), selectedDuration, colors.accent) },
                enabled = title.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0)
            ) {
                Icon(Icons.Default.Add, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text(SortydStrings.t(language, "Save task"), style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Black))
            }
        }
    }
}

private fun localeFor(language: String): Locale = when {
    language.startsWith("zh", ignoreCase = true) -> Locale.SIMPLIFIED_CHINESE
    language.startsWith("ar", ignoreCase = true) -> Locale("ar")
    language.startsWith("es", ignoreCase = true) -> Locale("es")
    else -> Locale.ENGLISH
}

private fun startOfWeek(offset: Int): Calendar {
    val cal = Calendar.getInstance()
    cal.firstDayOfWeek = Calendar.SUNDAY
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.SUNDAY) cal.add(Calendar.DAY_OF_YEAR, -1)
    cal.add(Calendar.WEEK_OF_YEAR, offset)
    return cal
}

private fun addDays(source: Calendar, days: Int): Calendar = (source.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, days) }
private fun sameDay(a: Calendar, b: Calendar): Boolean = a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
private fun sameWeek(firstDay: Calendar, date: Calendar): Boolean = date.timeInMillis >= firstDay.timeInMillis && date.timeInMillis < addDays(firstDay, 7).timeInMillis
private fun hourLabel(hour: Int): String {
    val suffix = if (hour < 12) "AM" else "PM"
    val h = when {
        hour == 0 -> 12
        hour > 12 -> hour - 12
        else -> hour
    }
    return "$h $suffix"
}
