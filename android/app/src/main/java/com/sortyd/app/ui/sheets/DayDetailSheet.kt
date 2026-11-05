package com.sortyd.app.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.data.model.DailySnapshot
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.components.DonutChart
import com.sortyd.app.ui.components.SectionLabel
import com.sortyd.app.ui.components.TaskRow
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayDetailSheet(
    date: LocalDate,
    language: String = "en",
    snapshot: DailySnapshot?,
    tasks: List<SortydTask>,
    onToggleTask: (SortydTask) -> Unit,
    onDismiss: () -> Unit
) {
    val colors = SortydColors.current
    val sheetState = rememberModalBottomSheetState()
    
    val completedTasks = tasks.filter { task -> 
        snapshot?.completedTaskIds?.contains(task.id) == true
    }
    val missedTasks = tasks.filter { task -> 
        snapshot != null && !snapshot.completedTaskIds.contains(task.id)
    }
    
    val fraction = snapshot?.completionFraction ?: 0.0
    val locale = when {
        language.startsWith("zh", ignoreCase = true) -> java.util.Locale.SIMPLIFIED_CHINESE
        language.startsWith("ar", ignoreCase = true) -> java.util.Locale("ar")
        language.startsWith("es", ignoreCase = true) -> java.util.Locale("es")
        else -> java.util.Locale.ENGLISH
    }
    val formattedDate = date.format(DateTimeFormatter.ofPattern("EEEE, MMMM d", locale))

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.bg0,
        dragHandle = { BottomSheetDefaults.DragHandle(color = colors.text2.copy(alpha = 0.3f)) }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 40.dp)
        ) {
            // Header
            Text(
                text = formattedDate,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = colors.text1,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Score Section
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                DonutChart(
                    fraction = fraction.toFloat(),
                    size = 140,
                    lineWidth = 12f
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "${(fraction * 100).toInt()}%",
                        style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black),
                        color = colors.text0
                    )
                    Text(
                        text = SortydStrings.t(language, "SCORE"),
                        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 2.sp, fontWeight = FontWeight.Bold),
                        color = colors.text2
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(32.dp))
            
            // Tasks List
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (completedTasks.isNotEmpty()) {
                    item {
                        SectionLabel(title = SortydStrings.t(language, "Completed"), badge = "${completedTasks.size}")
                    }
                    items(completedTasks) { task ->
                        TaskRow(
                            task = task.copy(isCompleted = true),
                            onToggle = { onToggleTask(task) }
                        )
                    }
                }
                
                if (missedTasks.isNotEmpty()) {
                    item {
                        SectionLabel(title = SortydStrings.t(language, "Missed"), badge = "${missedTasks.size}")
                    }
                    items(missedTasks) { task ->
                        TaskRow(
                            task = task.copy(isCompleted = false),
                            onToggle = { onToggleTask(task) }
                        )
                    }
                }
                
                if (completedTasks.isEmpty() && missedTasks.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 40.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                SortydStrings.t(language, "No tasks recorded for this day."),
                                style = MaterialTheme.typography.bodyMedium,
                                color = colors.text2
                            )
                        }
                    }
                }
            }
        }
    }
}
