package com.sortyd.app.ui.screens.lists

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sortyd.app.model.*
import com.sortyd.app.ui.components.*
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel
import java.util.*

// ─── Lists Screen ─────────────────────────────────────────────────────────────

@Composable
fun ListsScreen(vm: AppViewModel = hiltViewModel()) {
    val c = sortydColors
    val lists by vm.lists.collectAsStateWithLifecycle()
    val snapshots by vm.snapshots.collectAsStateWithLifecycle()

    var showCreateList by remember { mutableStateOf(false) }
    var showAIStarter by remember { mutableStateOf(false) }
    var showArchivedExpanded by remember { mutableStateOf(false) }

    val regularLists = lists.filter { !it.isArchived && !it.isTodo }
    val archivedLists = lists.filter { it.isArchived }

    // Stats
    val totalDone = regularLists.sumOf { l -> l.tasks.count { it.isCompleted } }
    val totalPending = regularLists.sumOf { l -> l.tasks.count { !it.isCompleted } }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(c.bg0)
    ) {
        // Header
        ListsHeader(
            listCount = regularLists.size,
            totalDone = totalDone,
            totalPending = totalPending,
            onSettingsClick = { /* TODO */ },
            onAIClick = { showAIStarter = true },
            onAddClick = { showCreateList = true }
        )

        if (regularLists.isEmpty()) {
            EmptyListsState(
                onAI = { showAIStarter = true },
                onManual = { showCreateList = true }
            )
        } else {
            LazyColumn(
                contentPadding = PaddingValues(start = 24.dp, end = 24.dp, bottom = 100.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.weight(1f)
            ) {
                items(regularLists, key = { it.id }) { list ->
                    val listSnaps = snapshots.filter { it.listId == list.id }
                    val activeListId by vm.activeListId.collectAsStateWithLifecycle()

                    ObsidianListCard(
                        list = list,
                        streak = vm.computeCurrentStreak(list.id),
                        avgPct = if (listSnaps.isEmpty()) 0
                        else (listSnaps.map { it.completionFraction }.average() * 100).toInt(),
                        isActive = list.id == activeListId,
                        onArchive = { vm.archiveList(list.id) },
                        onDelete = { vm.deleteList(list.id) },
                        onSetActive = { vm.setActiveList(list.id); vm.setTab(0) }
                    )
                }

                // Archived section
                if (archivedLists.isNotEmpty()) {
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { showArchivedExpanded = !showArchivedExpanded }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                "Archived (${archivedLists.size})",
                                style = MaterialTheme.typography.bodySmall.copy(color = c.text2),
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                if (showArchivedExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                                null, tint = c.text2, modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                    if (showArchivedExpanded) {
                        items(archivedLists, key = { "arch_${it.id}" }) { list ->
                            ArchivedListRow(
                                list = list,
                                onRestore = { vm.restoreList(list.id) },
                                onDelete = { vm.deleteList(list.id) }
                            )
                        }
                    }
                }

                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        GradientButton(onClick = { showAIStarter = true }, modifier = Modifier.fillMaxWidth()) {
                            Icon(Icons.Default.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("AI Starter List", color = Color.White, fontWeight = FontWeight.Bold)
                        }
                        OutlinedButton(
                            onClick = { showCreateList = true },
                            modifier = Modifier.fillMaxWidth(),
                            shape = CircleShape,
                            border = BorderStroke(1.dp, c.glassBorder)
                        ) {
                            Icon(Icons.Default.Add, null, tint = c.text2, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Create Manually", color = c.text2)
                        }
                    }
                }
            }
        }
    }

    if (showCreateList) {
        CreateListSheet(vm = vm, onDismiss = { showCreateList = false })
    }
    if (showAIStarter) {
        AIStarterSheet(vm = vm, onDismiss = { showAIStarter = false })
    }
}

@Composable
private fun ListsHeader(
    listCount: Int, 
    totalDone: Int, 
    totalPending: Int,
    onSettingsClick: () -> Unit,
    onAIClick: () -> Unit,
    onAddClick: () -> Unit
) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(start = 24.dp, end = 24.dp, top = 20.dp, bottom = 24.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "LISTS", 
                style = MaterialTheme.typography.displayLarge.copy(
                    color = Color.White,
                    fontWeight = FontWeight.Black,
                    fontSize = 38.sp,
                    letterSpacing = (-1.5).sp
                )
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatPill("${totalDone} DONE", c.teal)
                StatPill("${totalPending} LEFT", Color.White.copy(alpha = 0.4f))
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            // Settings Icon with Glow
            IconButton(onClick = onSettingsClick) {
                Box(contentAlignment = Alignment.Center) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .blur(12.dp)
                            .background(c.violet.copy(alpha = 0.3f), CircleShape)
                    )
                    Icon(
                        Icons.Default.Settings, 
                        null, 
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(22.dp)
                    )
                }
            }
            
            IconButton(onClick = onAIClick) {
                Icon(Icons.Default.AutoAwesome, null, tint = c.teal, modifier = Modifier.size(22.dp))
            }
            
            IconButton(onClick = onAddClick) {
                Icon(Icons.Default.Add, null, tint = Color.White, modifier = Modifier.size(28.dp))
            }
        }
    }
}

@Composable
private fun StatPill(label: String, color: Color) {
    Box(
        modifier = Modifier
            .background(color.copy(alpha = 0.1f), CircleShape)
            .border(0.5.dp, color.copy(alpha = 0.2f), CircleShape)
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(
            label, 
            style = MaterialTheme.typography.labelSmall.copy(
                color = color, 
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp
            )
        )
    }
}

@Composable
fun ObsidianListCard(
    list: TaskList,
    streak: Int,
    avgPct: Int,
    isActive: Boolean = false,
    onArchive: () -> Unit,
    onDelete: () -> Unit,
    onSetActive: () -> Unit
) {
    val c = sortydColors
    val pct = list.completionPercentage()
    val tasks = list.tasks

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(24.dp))
            .clickable(onClick = onSetActive)
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(24.dp))
    ) {
        // Side Accent Bar for Active List
        if (isActive) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .width(4.dp)
                    .fillMaxHeight()
                    .padding(vertical = 16.dp)
                    .background(
                        Brush.verticalGradient(listOf(c.teal, c.violet)),
                        RoundedCornerShape(topEnd = 4.dp, bottomEnd = 4.dp)
                    )
            )
        }

        Row(
            modifier = Modifier.padding(24.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Emoji Container
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(Color.White.copy(alpha = 0.03f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(list.emoji, fontSize = 22.sp)
            }

            Spacer(Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    list.cleanName,
                    style = MaterialTheme.typography.headlineSmall.copy(
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 1, overflow = TextOverflow.Ellipsis
                )
                
                Spacer(Modifier.height(4.dp))

                // Task Progress Dots
                TaskDotStrip(tasks = tasks)
            }

            Spacer(Modifier.width(12.dp))

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (streak > 0) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier
                            .background(if (streak >= 3) Color(0xFFFF5722).copy(alpha = 0.1f) else c.teal.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            if (streak >= 3) Icons.Default.Whatshot else Icons.AutoMirrored.Filled.TrendingUp,
                            null, 
                            tint = if (streak >= 3) Color(0xFFFF5722) else c.teal, 
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            "$streak",
                            style = MaterialTheme.typography.labelMedium.copy(
                                color = if (streak >= 3) Color(0xFFFF5722) else c.teal,
                                fontWeight = FontWeight.Black
                            )
                        )
                    }
                }

                // Count Badge
                Box(
                    modifier = Modifier
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(
                        "${tasks.size}",
                        style = MaterialTheme.typography.labelMedium.copy(
                            color = Color.White.copy(alpha = 0.6f),
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
            }
        }
    }
}

@Composable
fun TaskDotStrip(tasks: List<SortydTask>) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val displayTasks = tasks.take(10) // Limit dots
        displayTasks.forEach { task ->
            Box(
                modifier = Modifier
                    .size(width = 12.dp, height = 3.dp)
                    .clip(CircleShape)
                    .background(
                        if (task.isCompleted) sortydColors.teal 
                        else Color.White.copy(alpha = 0.15f)
                    )
            )
        }
        if (tasks.size > 10) {
            Box(
                modifier = Modifier
                    .size(3.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.15f))
            )
        }
    }
}

@Composable
private fun ArchivedListRow(list: TaskList, onRestore: () -> Unit, onDelete: () -> Unit) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(c.bg2.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(list.emoji, modifier = Modifier.padding(end = 8.dp))
        Text(
            list.cleanName, modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium.copy(color = c.text2),
            maxLines = 1, overflow = TextOverflow.Ellipsis
        )
        TextButton(onClick = onRestore) { Text("Restore", color = c.accent) }
        IconButton(onClick = onDelete) {
            Icon(Icons.Default.Delete, null, tint = c.danger, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun EmptyListsState(onAI: () -> Unit, onManual: () -> Unit) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Ring Cluster Animation with Sparkles
        Box(
            modifier = Modifier.size(240.dp),
            contentAlignment = Alignment.Center
        ) {
            val infiniteTransition = rememberInfiniteTransition(label = "rings")
            val scale1 by infiniteTransition.animateFloat(
                initialValue = 0.8f, targetValue = 1.2f,
                animationSpec = infiniteRepeatable(tween(2000), RepeatMode.Reverse), label = "s1"
            )
            val scale2 by infiniteTransition.animateFloat(
                initialValue = 1.2f, targetValue = 0.8f,
                animationSpec = infiniteRepeatable(tween(2500), RepeatMode.Reverse), label = "s2"
            )

            // Rings
            Box(Modifier.size(120.dp).graphicsLayer { this.scaleX = scale1; this.scaleY = scale1 }.border(1.dp, c.teal.copy(alpha = 0.2f), CircleShape))
            Box(Modifier.size(160.dp).graphicsLayer { this.scaleX = scale2; this.scaleY = scale2 }.border(1.dp, c.violet.copy(alpha = 0.15f), CircleShape))
            Box(Modifier.size(200.dp).graphicsLayer { this.scaleX = scale1 * 0.9f; this.scaleY = scale1 * 0.9f }.border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape))
            
            // Sparkles
            repeat(6) { i ->
                FloatingSparkle(index = i, infiniteTransition = infiniteTransition)
            }

            Icon(
                Icons.Default.AutoAwesome, 
                null, 
                tint = c.teal, 
                modifier = Modifier
                    .size(48.dp)
                    .blur(if (scale1 > 1.1f) 2.dp else 0.dp)
            )
        }

        Spacer(Modifier.height(32.dp))
        
        Text(
            "Your canvas is empty", 
            style = MaterialTheme.typography.headlineMedium.copy(
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Create your first habit list", 
            style = MaterialTheme.typography.bodyMedium.copy(color = Color.White.copy(alpha = 0.4f))
        )
        
        Spacer(Modifier.height(48.dp))

        GradientButton(onClick = onAI, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Icon(Icons.Default.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("AI Starter List", color = Color.White, fontWeight = FontWeight.Bold)
        }
        
        Spacer(Modifier.height(16.dp))
        
        TextButton(onClick = onManual) {
            Text("Create Manually", color = Color.White.copy(alpha = 0.4f), fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun FloatingSparkle(index: Int, infiniteTransition: InfiniteTransition) {
    val c = sortydColors
    val angle = (index * 60f)
    val radius = 80f
    
    val xOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 20f,
        animationSpec = infiniteRepeatable(
            tween(1500 + index * 200, easing = LinearEasing),
            RepeatMode.Reverse
        ), label = "x$index"
    )
    
    val opacity by infiniteTransition.animateFloat(
        initialValue = 0.2f,
        targetValue = 0.8f,
        animationSpec = infiniteRepeatable(
            tween(1000 + index * 300, easing = LinearEasing),
            RepeatMode.Reverse
        ), label = "o$index"
    )

    Box(
        modifier = Modifier
            .offset(
                x = (radius * Math.cos(Math.toRadians(angle.toDouble()))).dp + xOffset.dp,
                y = (radius * Math.sin(Math.toRadians(angle.toDouble()))).dp
            )
            .size(if (index % 2 == 0) 4.dp else 6.dp)
            .graphicsLayer { alpha = opacity }
            .background(if (index % 2 == 0) c.teal else c.violet, CircleShape)
    )
}

// ─── Create List Sheet ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateListSheet(vm: AppViewModel, onDismiss: () -> Unit) {
    val c = sortydColors
    var name by remember { mutableStateOf("") }
    var emoji by remember { mutableStateOf("📋") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color.Transparent,
        dragHandle = null
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .background(
                    Color.White.copy(alpha = 0.03f),
                    RoundedCornerShape(32.dp)
                )
                .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(32.dp))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
                    .imePadding(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text("New List", style = MaterialTheme.typography.headlineMedium.copy(color = c.text0))

                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(emoji, style = MaterialTheme.typography.headlineLarge)
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        modifier = Modifier.weight(1f),
                        label = { Text("List name") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = c.accent,
                            unfocusedBorderColor = c.glassBorder
                        )
                    )
                }

                // Simple emoji picker
                EmojiPicker(selected = emoji, onSelect = { emoji = it })

                GradientButton(
                    onClick = {
                        if (name.isNotBlank()) {
                            vm.addList(name.trim(), emoji)
                            onDismiss()
                        }
                    },
                    enabled = name.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(56.dp)
                ) {
                    Text("Create List", color = Color.White, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun EmojiPicker(selected: String, onSelect: (String) -> Unit) {
    val emojis = listOf("📋","🏃","💪","🧘","📚","🎯","⭐","🔥","💡","🎨","🌱","💊","🍎","🎵","✈️","🏠")
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(emojis) { emoji ->
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        if (emoji == selected) sortydColors.accent.copy(alpha = 0.2f) else sortydColors.bg3,
                        RoundedCornerShape(10.dp)
                    )
                    .clickable { onSelect(emoji) },
                contentAlignment = Alignment.Center
            ) {
                Text(emoji, style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}

// ─── Add Task Sheet ───────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTaskSheet(
    listId: String,
    vm: AppViewModel,
    onDismiss: () -> Unit
) {
    val c = sortydColors
    var title by remember { mutableStateOf("") }
    var selectedHealth by remember { mutableStateOf(HealthTaskType.NONE) }
    var healthTarget by remember { mutableStateOf("") }
    var showTimePicker by remember { mutableStateOf(false) }
    var reminderHour by remember { mutableStateOf<Int?>(null) }
    var reminderMinute by remember { mutableStateOf<Int?>(null) }
    var conflictToast by remember { mutableStateOf<String?>(null) }

    val parsedTask by vm.parsedTask.collectAsStateWithLifecycle()

    LaunchedEffect(parsedTask) {
        parsedTask?.let { p ->
            if (p.title.isNotBlank() && title.isEmpty()) title = p.title
            if (p.hasReminder) {
                reminderHour = p.reminderHour
                reminderMinute = p.reminderMinute
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = { vm.clearParsedTask(); onDismiss() },
        containerColor = Color.Transparent,
        dragHandle = null
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .background(
                    Color.White.copy(alpha = 0.03f),
                    RoundedCornerShape(32.dp)
                )
                .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(32.dp))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
                    .imePadding(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text("Add Task", style = MaterialTheme.typography.headlineMedium.copy(color = c.text0))

            // Title field with AI button
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    modifier = Modifier.weight(1f),
                    label = { Text("Task title") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = c.accent,
                        unfocusedBorderColor = c.glassBorder
                    )
                )
                IconButton(
                    onClick = { if (title.isNotBlank()) vm.parseTask(title) },
                    modifier = Modifier
                        .background(c.accent.copy(alpha = 0.15f), CircleShape)
                ) {
                    Icon(Icons.Default.AutoAwesome, null, tint = c.accent)
                }
            }

            // Parsed reminder preview
            if (reminderHour != null) {
                val h = reminderHour!!
                val m = reminderMinute ?: 0
                val amPm = if (h < 12) "AM" else "PM"
                val h12 = if (h % 12 == 0) 12 else h % 12
                Box(
                    modifier = Modifier
                        .background(c.accent.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                        .padding(8.dp)
                ) {
                    Text("⏰ Reminder at $h12:${"%02d".format(m)} $amPm",
                        style = MaterialTheme.typography.bodySmall.copy(color = c.accent))
                }
            }

            // Health type selector
            Text("Task Type", style = MaterialTheme.typography.labelMedium.copy(color = c.text2))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HealthTypePill(HealthTaskType.NONE, selectedHealth, Color(0xFFFFD700)) { selectedHealth = it }
                HealthTypePill(HealthTaskType.STEPS, selectedHealth, StepsColor) { selectedHealth = it }
                HealthTypePill(HealthTaskType.CALORIES, selectedHealth, CaloriesColor) { selectedHealth = it }
                HealthTypePill(HealthTaskType.DISTANCE, selectedHealth, DistanceColor) { selectedHealth = it }
            }

            if (selectedHealth != HealthTaskType.NONE) {
                OutlinedTextField(
                    value = healthTarget,
                    onValueChange = { healthTarget = it },
                    label = { Text("Target (${selectedHealth.unit})") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = c.accent,
                        unfocusedBorderColor = c.glassBorder
                    )
                )
            }

            // Reminder button
            TextButton(onClick = { showTimePicker = true }) {
                Icon(
                    if (reminderHour != null) Icons.Default.Alarm else Icons.Default.AddAlarm,
                    null, tint = c.accent, modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(4.dp))
                Text(if (reminderHour != null) "Change Reminder" else "Set Reminder", color = c.accent)
            }

            // Conflict toast
            conflictToast?.let { msg ->
                ConflictToast(message = msg, visible = true, color = c.warning)
            }

            GradientButton(
                onClick = {
                    if (title.isBlank()) return@GradientButton
                    // Conflict check
                    if (reminderHour != null) {
                        val conflict = vm.findReminderConflict(reminderHour!!, reminderMinute ?: 0, listId)
                        if (conflict != null) {
                            conflictToast = "\"${conflict.conflictingTaskTitle}\" already has a reminder at this time"
                            return@GradientButton
                        }
                    }
                    val reminderMs = if (reminderHour != null) {
                        val cal = Calendar.getInstance()
                        cal.set(Calendar.HOUR_OF_DAY, reminderHour!!)
                        cal.set(Calendar.MINUTE, reminderMinute ?: 0)
                        cal.set(Calendar.SECOND, 0)
                        if (cal.before(Calendar.getInstance())) cal.add(Calendar.DAY_OF_MONTH, 1)
                        cal.timeInMillis
                    } else null

                    vm.addTask(
                        listId = listId,
                        title = title.trim(),
                        reminderTime = reminderMs,
                        healthType = selectedHealth.rawValue.takeIf { selectedHealth != HealthTaskType.NONE },
                        healthTarget = healthTarget.toDoubleOrNull() ?: selectedHealth.defaultTarget.takeIf { selectedHealth != HealthTaskType.NONE }
                    )
                    vm.clearParsedTask()
                    onDismiss()
                },
                enabled = title.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(56.dp)
            ) {
                Text("Add Task", color = Color.White, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

    if (showTimePicker) {
        TimePickerDialog(
            initialHour = reminderHour ?: 8,
            initialMinute = reminderMinute ?: 0,
            onConfirm = { h, m ->
                reminderHour = h; reminderMinute = m
                showTimePicker = false
            },
            onDismiss = { showTimePicker = false }
        )
    }
}

@Composable
fun HealthTypePill(
    type: HealthTaskType,
    selected: HealthTaskType,
    color: Color,
    onSelect: (HealthTaskType) -> Unit
) {
    val c = sortydColors
    val isSelected = type == selected
    val label = when (type) {
        HealthTaskType.NONE -> "Regular"
        HealthTaskType.STEPS -> "Steps"
        HealthTaskType.CALORIES -> "Calories"
        HealthTaskType.DISTANCE -> "Distance"
    }
    Box(
        modifier = Modifier
            .background(
                if (isSelected) color.copy(alpha = 0.2f) else c.bg3,
                RoundedCornerShape(20.dp)
            )
            .border(1.dp, if (isSelected) color else Color.Transparent, RoundedCornerShape(20.dp))
            .clickable { onSelect(type) }
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall.copy(
                color = if (isSelected) color else c.text2,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
            )
        )
    }
}

// ─── Time Picker Dialog ───────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimePickerDialog(
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (Int, Int) -> Unit,
    onDismiss: () -> Unit
) {
    val c = sortydColors
    val state = rememberTimePickerState(initialHour, initialMinute, false)
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.bg1,
        title = { Text("Set Reminder", color = c.text0) },
        text = { TimePicker(state = state) },
        confirmButton = {
            TextButton(onClick = { onConfirm(state.hour, state.minute) }) {
                Text("Set", color = c.accent)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = c.text2) }
        }
    )
}

// ─── AI Starter Sheet ─────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIStarterSheet(vm: AppViewModel, onDismiss: () -> Unit) {
    val c = sortydColors
    var goal by remember { mutableStateOf("") }
    val starterList by vm.starterList.collectAsStateWithLifecycle()
    val isLoading by vm.isGeneratingList.collectAsStateWithLifecycle()
    var editableTasks by remember { mutableStateOf<List<StarterListTask>>(emptyList()) }
    var editableName by remember { mutableStateOf("") }
    var editableEmoji by remember { mutableStateOf("📋") }
    var conflictToast by remember { mutableStateOf<String?>(null) }

    val prompts = listOf(
        "✨ Routine", "💤 Better Sleep", "💼 Job Hunting", "📸 Grow on Social",
        "🚀 Launch My App", "🧠 Upskilling", "🥗 Eat Healthy", "🎯 Productivity",
        "🇪🇸 Learn Spanish", "💰 Save Money", "🎯 Morning Routine", "🧘 Mindfulness",
        "🏃 Cardio & Fitness", "📚 Read More", "📷 Photography"
    )

    LaunchedEffect(starterList) {
        starterList?.let {
            editableName = it.listName
            editableEmoji = it.emoji
            editableTasks = it.tasks
        }
    }

    ModalBottomSheet(
        onDismissRequest = { vm.clearStarterList(); onDismiss() },
        containerColor = Color(0xFF121212), // iOS Dark Background
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 10.dp)
                    .size(width = 36.dp, height = 5.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape)
            )
        },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Box(modifier = Modifier.fillMaxHeight(0.92f)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp)
                    .imePadding(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Header section
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        "AI Starter List",
                        style = MaterialTheme.typography.displayLarge.copy(
                            color = Color.White,
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Black
                        )
                    )
                    Text(
                        "Describe your goal — AI builds the exact tasks",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = Color.White.copy(alpha = 0.4f)
                        )
                    )
                }

                // Input Field (iOS Style)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
                        .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
                        .padding(horizontal = 16.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    BasicTextField(
                        value = goal,
                        onValueChange = { goal = it },
                        textStyle = MaterialTheme.typography.bodyLarge.copy(color = Color.White),
                        cursorBrush = SolidColor(c.teal),
                        modifier = Modifier.fillMaxWidth(),
                        decorationBox = { innerTextField ->
                            if (goal.isEmpty()) {
                                Text("Describe your goal...", color = Color.White.copy(alpha = 0.2f))
                            }
                            innerTextField()
                        }
                    )
                }

                // Suggestions Section
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "Try one of these",
                        style = MaterialTheme.typography.labelMedium.copy(
                            color = Color.White.copy(alpha = 0.4f),
                            fontWeight = FontWeight.Bold
                        )
                    )

                    // Three rows of marquee for that "dynamic" look
                    PromptMarqueeRow(prompts.shuffled(), speed = 40) { goal = it.substring(2) }
                    PromptMarqueeRow(prompts.shuffled(), speed = 30) { goal = it.substring(2) }
                    PromptMarqueeRow(prompts.shuffled(), speed = 50) { goal = it.substring(2) }
                }

                // Generated list section (if exists)
                if (editableTasks.isNotEmpty()) {
                    GeneratedTasksSection(
                        name = editableName,
                        emoji = editableEmoji,
                        tasks = editableTasks,
                        onNameChange = { editableName = it },
                        onTasksChange = { editableTasks = it },
                        onRefresh = { if (goal.isNotBlank()) vm.generateStarterList(goal) }
                    )
                }
            }

            // Sticky Bottom Button
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 32.dp)
            ) {
                val isButtonEnabled = (goal.isNotBlank() || editableTasks.isNotEmpty()) && !isLoading
                
                Button(
                    onClick = {
                        if (editableTasks.isNotEmpty()) {
                            val selectedTasks = editableTasks.filter { it.title.isNotBlank() }
                            vm.addListWithTasks(editableName.ifBlank { goal }, editableEmoji, selectedTasks)
                            vm.clearStarterList()
                            vm.setTab(0)
                            onDismiss()
                        } else {
                            vm.generateStarterList(goal)
                        }
                    },
                    enabled = isButtonEnabled,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(60.dp),
                    shape = RoundedCornerShape(30.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isButtonEnabled) Color(0xFF1E1E1E) else Color(0xFF1A1A1A),
                        disabledContainerColor = Color(0xFF141414)
                    ),
                    border = BorderStroke(1.dp, Color.White.copy(alpha = 0.05f))
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(12.dp))
                        Text("Building...", color = Color.White.copy(alpha = 0.7f))
                    } else {
                        val icon = if (editableTasks.isNotEmpty()) Icons.Default.Check else Icons.Default.AutoAwesome
                        val text = if (editableTasks.isNotEmpty()) "Create List" else "Generate List"
                        Icon(icon, null, tint = if (isButtonEnabled) c.teal else Color.White.copy(alpha = 0.1f), modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text,
                            style = MaterialTheme.typography.headlineSmall.copy(
                                color = if (isButtonEnabled) Color.White else Color.White.copy(alpha = 0.1f),
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PromptMarqueeRow(prompts: List<String>, speed: Int, onSelect: (String) -> Unit) {
    val scrollState = rememberScrollState()
    
    // Auto-scroll animation
    LaunchedEffect(Unit) {
        while (true) {
            scrollState.animateScrollTo(
                scrollState.maxValue,
                animationSpec = tween(scrollState.maxValue * speed, easing = LinearEasing)
            )
            scrollState.scrollTo(0)
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState, enabled = false),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Double the list for seamless loop
        (prompts + prompts).forEach { prompt ->
            Box(
                modifier = Modifier
                    .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(12.dp))
                    .clickable { onSelect(prompt) }
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    prompt,
                    style = MaterialTheme.typography.bodySmall.copy(
                        color = Color.White.copy(alpha = 0.7f),
                        fontWeight = FontWeight.Medium
                    )
                )
            }
        }
    }
}

@Composable
private fun GeneratedTasksSection(
    name: String,
    emoji: String,
    tasks: List<StarterListTask>,
    onNameChange: (String) -> Unit,
    onTasksChange: (List<StarterListTask>) -> Unit,
    onRefresh: () -> Unit
) {
    val c = sortydColors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        HorizontalDivider(color = Color.White.copy(alpha = 0.05f), modifier = Modifier.padding(vertical = 8.dp))
        
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(emoji, style = MaterialTheme.typography.headlineLarge)
            BasicTextField(
                value = name,
                onValueChange = onNameChange,
                modifier = Modifier.weight(1f),
                textStyle = MaterialTheme.typography.headlineSmall.copy(color = Color.White, fontWeight = FontWeight.Bold),
                cursorBrush = SolidColor(c.teal)
            )
            IconButton(onClick = onRefresh) {
                Icon(Icons.Default.Refresh, null, tint = c.teal)
            }
        }

        tasks.forEachIndexed { idx, task ->
            StarterTaskRow(
                task = task,
                onUpdate = { updated ->
                    onTasksChange(tasks.toMutableList().also { it[idx] = updated })
                },
                onDelete = {
                    onTasksChange(tasks.toMutableList().also { it.removeAt(idx) })
                }
            )
        }
    }
}


@Composable
private fun StarterTaskRow(
    task: StarterListTask,
    onUpdate: (StarterListTask) -> Unit,
    onDelete: () -> Unit
) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(c.bg2.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        OutlinedTextField(
            value = task.title,
            onValueChange = { onUpdate(task.copy(title = it)) },
            modifier = Modifier.weight(1f),
            singleLine = true,
            placeholder = { Text("Task name", color = c.text2) },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = c.accent, unfocusedBorderColor = Color.Transparent
            )
        )
        IconButton(onClick = onDelete) {
            Icon(Icons.Default.Close, null, tint = c.danger, modifier = Modifier.size(18.dp))
        }
    }
}
