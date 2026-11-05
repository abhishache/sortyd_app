package com.sortyd.app.ui.screens.home

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.PersonOutline
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.ui.draw.rotate
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.zIndex
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontWeight.Companion.W600
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.sortyd.app.data.model.TaskList
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.components.*
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.screens.lists.AddTaskSheet
import com.sortyd.app.ui.screens.lists.TaskEditBottomSheet
import com.sortyd.app.ui.sheets.DayDetailSheet
import com.sortyd.app.ui.theme.HeroPercentageStyle
import com.sortyd.app.ui.theme.LoraFamily
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.ui.theme.glow
import com.sortyd.app.viewmodel.SortydViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import java.time.YearMonth
import java.time.temporal.WeekFields
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: SortydViewModel,
    navController: NavHostController,
    initialShowAddTask: Boolean = false
) {
    val allLists by viewModel.activeLists.collectAsState()
    val activeList by viewModel.activeList.collectAsState()
    val isDark by viewModel.isDarkMode.collectAsState()
    val allSnapshots by viewModel.allSnapshots.collectAsState()
    val healthProgress by viewModel.healthProgress.collectAsState()
    val installDate by viewModel.installDate.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val healthPermissionsGranted by viewModel.healthPermissionsGranted.collectAsState()

    HomeScreenContent(
        allLists = allLists,
        activeList = activeList,
        isDark = isDark,
        allSnapshots = allSnapshots,
        healthProgress = healthProgress,
        installDate = installDate,
        language = language,
        healthPermissionsGranted = healthPermissionsGranted,
        initialShowAddTask = initialShowAddTask,
        onToggleDarkMode = { viewModel.toggleDarkMode() },
        onSetActiveList = { viewModel.setActiveList(it) },
        onToggleTask = { taskId, listId -> viewModel.toggleTask(taskId, listId) },
        onDeleteTask = { taskId, listId -> viewModel.deleteTask(taskId, listId) },
        onUpdateTask = { taskId, listId, title, healthType, healthTarget, reminderTime ->
            viewModel.updateTask(taskId, listId, title, healthType, healthTarget, reminderTime)
        },
        onAddTask = { listId, title, reminder, healthType, healthTarget ->
            // Use defaults for leadMinutes and durationMinutes as they aren't provided by the AddTaskSheet callback
            viewModel.addTask(listId, title, reminder, false, 0, null, healthType, healthTarget)
        },
        onCheckHealthPermissions = { viewModel.checkHealthPermissions() },
        onNavigateToLists = { navController.navigate("lists") },
        onCalculateStreak = { listId, snapshots -> viewModel.calculateStreak(listId, snapshots) },
        viewModel = viewModel // Still needed for WeeklyPlannerSection for now
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreenContent(
    allLists: List<TaskList>,
    activeList: TaskList?,
    isDark: Boolean,
    allSnapshots: List<com.sortyd.app.data.model.DailySnapshot>,
    healthProgress: Map<String, Double>,
    installDate: Long,
    language: String,
    healthPermissionsGranted: Boolean,
    initialShowAddTask: Boolean = false,
    onToggleDarkMode: () -> Unit = {},
    onSetActiveList: (String) -> Unit = {},
    onToggleTask: (String, String) -> Unit = { _, _ -> },
    onDeleteTask: (String, String) -> Unit = { _, _ -> },
    onUpdateTask: (String, String, String, String?, Double?, Long?) -> Unit = { _, _, _, _, _, _ -> },
    onAddTask: (String, String, Long?, String?, Double?) -> Unit = { _, _, _, _, _ -> },
    onCheckHealthPermissions: () -> Unit = {},
    onNavigateToLists: () -> Unit = {},
    onCalculateStreak: (String, List<com.sortyd.app.data.model.DailySnapshot>) -> Int = { _, _ -> 0 },
    viewModel: SortydViewModel? = null // Optional for preview
) {
    val colors = SortydColors.current
    val hasRealLists = remember(allLists) { allLists.any { !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) } }
    
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    val list = activeList
    val tasks = list?.tasks ?: emptyList()
    val fraction = list?.completionFraction(healthProgress) ?: 0.0
    val percentage = (fraction * 100).toInt()
    val doneTasks = tasks.count { it.isCompleted }
    val totalTasks = tasks.size

    val snapshotMap = remember(allSnapshots, list?.id, fraction) {
        val map = allSnapshots.filter { it.listId == (list?.id ?: "") }
            .associate { it.date to it.completionFraction }
            .toMutableMap()
        
        // Ensure today's live progress is reflected in the heatmap
        val todayStart = com.sortyd.app.services.ReminderPolicy.dayStart(System.currentTimeMillis())
        map[todayStart] = fraction
        map
    }
    val streak = remember(allSnapshots, list?.id) {
        if (list != null) onCalculateStreak(list.id, allSnapshots) else 0
    }

    val scrollState = rememberScrollState()

    var selectedDay by remember { mutableStateOf<LocalDate?>(null) }
    var showCheatPopup by remember { mutableStateOf(false) }
    var showMonthPicker by remember { mutableStateOf(false) }
    var showAddTask by remember { mutableStateOf(initialShowAddTask) }
    var showWeeklyPlanner by remember { mutableStateOf(false) }
    var editingTodoTask by remember { mutableStateOf<SortydTask?>(null) }
    var showAccountSheet by remember { mutableStateOf(false) }
    
    val context = LocalContext.current
    val permissionLauncher = rememberLauncherForActivityResult(
        androidx.health.connect.client.PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        onCheckHealthPermissions()
    }

    val isTodoActive = activeList?.isTodo == true

    if (showAddTask && activeList != null) {
        val targetListId = if (isTodoActive) activeList.id else (allLists.firstOrNull { it.isTodo }?.id ?: activeList.id)
        AddTaskSheet(
            listId = targetListId,
            language = language,
            onDismiss = { showAddTask = false },
            onAdd = { title, reminder, healthType, healthTarget ->
                onAddTask(targetListId, title, reminder, healthType, healthTarget)
                showAddTask = false
                if (healthType != null && !healthPermissionsGranted) {
                    try {
                        permissionLauncher.launch(com.sortyd.app.services.HealthConnectManager(context).permissions)
                    } catch (_: Exception) {
                        com.sortyd.app.services.HealthConnectManager.startHealthConnectSettings(context)
                    }
                }
            }
        )
    }

    if (editingTodoTask != null && list != null) {
        TaskEditBottomSheet(
            task = editingTodoTask!!,
            language = language,
            onDismiss = { editingTodoTask = null },
            onSave = { title, healthType, healthTarget, reminderTime ->
                onUpdateTask(editingTodoTask!!.id, list.id, title, healthType, healthTarget, reminderTime)
                editingTodoTask = null
            }
        )
    }

    val selectedDayMillis = selectedDay?.atStartOfDay(ZoneId.systemDefault())?.toInstant()?.toEpochMilli()
    val selectedSnapshot = selectedDayMillis?.let { millis ->
        allSnapshots.find { it.date == millis && it.listId == list?.id }
    }

    if (showCheatPopup) {
        CheatBlockPopup(onDismiss = { showCheatPopup = false })
    }

    if (showMonthPicker) {
        ModalBottomSheet(
            onDismissRequest = { showMonthPicker = false },
            containerColor = colors.bg0,
            dragHandle = null,
            shape = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp)
        ) {
            MonthPickerSheet(
                selectedMonth = currentMonth,
                language = language,
                onMonthSelected = { currentMonth = it },
                onDismiss = { showMonthPicker = false }
            )
        }
    }

    if (showAccountSheet && viewModel != null) {
        com.sortyd.app.ui.sheets.AccountSheet(
            viewModel = viewModel,
            onDismiss = { showAccountSheet = false }
        )
    }

    if (selectedDay != null) {
        DayDetailSheet(
            date = selectedDay!!,
            language = language,
            snapshot = selectedSnapshot,
            tasks = tasks,
            onToggleTask = { task ->
                if (selectedDay == LocalDate.now()) {
                    onToggleTask(task.id, list?.id ?: "")
                } else {
                    showCheatPopup = true
                }
            },
            onDismiss = { selectedDay = null }
        )
    }

    val rightScrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.bg0),
    ) {
        // ── Pinned Top Header: Theme toggle & Account + List pills (Content scrolls underneath) ──
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.bg0)
                .zIndex(10f)
                .padding(start = 16.dp, end = 0.dp)
                .padding(top = 2.dp, bottom = 2.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                ThemeToggle(isDark = isDark, onToggle = onToggleDarkMode)

                val currentUser by (viewModel?.currentUser?.collectAsState() ?: remember { mutableStateOf(null) })
                val isSyncing by (viewModel?.isSyncing?.collectAsState() ?: remember { mutableStateOf(false) })

                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(colors.bg1)
                        .border(
                            1.dp,
                            if (currentUser != null) colors.accent.copy(alpha = 0.5f) else colors.borderSubtle,
                            CircleShape
                        )
                        .clickable { showAccountSheet = true },
                    contentAlignment = Alignment.Center
                ) {
                    if (currentUser != null) {
                        val rotation = remember { Animatable(0f) }
                        LaunchedEffect(isSyncing) {
                            if (isSyncing) {
                                rotation.animateTo(
                                    360f,
                                    infiniteRepeatable(tween(1000, easing = LinearEasing), RepeatMode.Restart)
                                )
                            } else {
                                rotation.snapTo(0f)
                            }
                        }
                        Icon(
                            imageVector = if (isSyncing) Icons.Default.Refresh else Icons.Default.CloudDone,
                            contentDescription = "Cloud Account",
                            tint = colors.accent,
                            modifier = Modifier
                                .size(16.dp)
                                .rotate(if (isSyncing) rotation.value else 0f)
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.PersonOutline,
                            contentDescription = "Sign In",
                            tint = colors.text2,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }
            
            Box(modifier = Modifier.weight(1f)) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    val regularLists = allLists.filter { !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
                    items(regularLists) { l ->
                        OrbitalDonutPill(
                            l, 
                            l.id == list?.id, 
                            l.completionFraction(healthProgress).toFloat()
                        ) { onSetActiveList(l.id) }
                    }
                }
                
                Box(modifier = Modifier.align(Alignment.CenterStart).height(44.dp).width(12.dp).background(Brush.horizontalGradient(listOf(colors.bg0, Color.Transparent))))
                Box(modifier = Modifier.align(Alignment.CenterEnd).height(44.dp).width(12.dp).background(Brush.horizontalGradient(listOf(Color.Transparent, colors.bg0))))
            }

            val todoList = allLists.firstOrNull { it.isTodo }
            if (hasRealLists) {
                Box(
                    modifier = Modifier
                        .width(1.2.dp)
                        .height(22.dp)
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    colors.accent.copy(alpha = 0.08f),
                                    colors.accent.copy(alpha = 0.42f),
                                    colors.accent.copy(alpha = 0.08f)
                                )
                            )
                        )
                )
                Spacer(Modifier.width(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (todoList != null) {
                        TodoPill(todoList.id == list?.id && !showWeeklyPlanner, todoList.completionFraction.toFloat(), language) {
                            showWeeklyPlanner = false
                            onSetActiveList(todoList.id)
                        }
                    }
                    WeekCalendarPill(
                        weekNumber = currentWeekNumber(),
                        isActive = showWeeklyPlanner,
                        onTap = { showWeeklyPlanner = !showWeeklyPlanner }
                    )
                }
                Spacer(Modifier.width(2.dp))
            }
        }

        // ── Adaptive Scrollable Body Underneath Pinned Top Header (Supports Foldables / Duo / Split-Screen) ──
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clipToBounds()
        ) {
            val isWideFoldable = maxWidth >= 600.dp && !showWeeklyPlanner && !isTodoActive

            if (showWeeklyPlanner) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState)
                        .padding(bottom = 80.dp)
                ) {
                    val plannerListId = allLists.firstOrNull { it.isTodo }?.id ?: list?.id
                    if (plannerListId != null && viewModel != null) {
                        WeeklyPlannerSection(
                            viewModel = viewModel,
                            language = language,
                            targetListId = plannerListId,
                            tasks = allLists.flatMap { it.tasks },
                            modifier = Modifier.padding(bottom = 24.dp)
                        )
                    }
                }
            } else if (isTodoActive) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState)
                        .padding(bottom = 80.dp)
                ) {
                    TodoModeSection(
                        tasks = tasks,
                        onToggleTask = { taskId -> onToggleTask(taskId, list?.id ?: "") },
                        onEditTask = { task -> editingTodoTask = task },
                        onDeleteTask = { taskId -> onDeleteTask(taskId, list?.id ?: "") },
                        onAddTask = { showAddTask = true },
                        healthProgress = healthProgress,
                        language = language,
                        modifier = Modifier.padding(horizontal = 16.dp).padding(top = 12.dp)
                    )
                }
            } else if (isWideFoldable) {
                // 2-Column Foldable / Dual-Screen / Landscape Layout (Left & Right scroll independently underneath header)
                val heroTitle = if (!hasRealLists) "" else (list?.cleanName ?: "GET TRACKING")
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .weight(0.46f)
                            .fillMaxHeight()
                            .clipToBounds()
                            .verticalScroll(scrollState)
                            .padding(top = 4.dp, bottom = 80.dp)
                    ) {
                        Column(modifier = Modifier.padding(horizontal = 4.dp).padding(bottom = 4.dp)) {
                            Text(
                                heroTitle.uppercase(),
                                color = colors.accent,
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp, fontSize = 10.sp).glow(colors.accent, 4f),
                                modifier = Modifier.padding(bottom = 4.dp)
                            )
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(
                                        "$percentage%",
                                        style = HeroPercentageStyle.copy(fontSize = 76.sp, fontFamily = MaterialTheme.typography.displaySmall.fontFamily, letterSpacing = (-2).sp).glow(colors.accent, 12f),
                                        color = colors.accent,
                                    )
                                    Text(SortydStrings.t(language, "Done Today"), style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium, fontSize = 12.sp), color = colors.text2, modifier = Modifier.offset(y = (-8).dp))
                                }
                                Column(horizontalAlignment = Alignment.End) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("🔥", fontSize = 16.sp)
                                        Spacer(Modifier.width(2.dp))
                                        Text("$streak", style = MaterialTheme.typography.displayLarge.copy(fontSize = 48.sp, fontWeight = FontWeight.Black, letterSpacing = (-1).sp), color = colors.text0)
                                    }
                                    Text(SortydStrings.t(language, "DAY STREAK"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, letterSpacing = 1.0.sp, fontWeight = FontWeight.Bold), color = colors.text2, modifier = Modifier.offset(y = (-4).dp))
                                }
                            }
                        }

                        HeatmapCalendar(
                            snapshots = snapshotMap,
                            installDate = installDate,
                            currentMonth = currentMonth,
                            onDayTap = { selectedDay = it },
                            onMonthPickerTap = { showMonthPicker = true },
                            onGoToToday = { currentMonth = YearMonth.now() },
                            modifier = Modifier.padding(horizontal = 4.dp).padding(bottom = 8.dp),
                            language = language
                        )
                    }

                    Column(
                        modifier = Modifier
                            .weight(0.54f)
                            .fillMaxHeight()
                            .clipToBounds()
                            .verticalScroll(rightScrollState)
                            .padding(top = 4.dp, bottom = 80.dp)
                    ) {
                        SectionLabel(
                            SortydStrings.t(language, "Tasks"),
                            badge = if (totalTasks > 0) "$doneTasks ${SortydStrings.t(language, "done")} · ${totalTasks - doneTasks} ${SortydStrings.t(language, "left")}" else null,
                            actionContent = {}
                        )

                        if (!hasRealLists) {
                            HomeEmptyState(language = language, onCreateList = { onNavigateToLists() })
                        } else if (tasks.isEmpty()) {
                            EmptyState(icon = "📋", title = SortydStrings.t(language, "Nothing here yet"), subtitle = SortydStrings.t(language, "Add today's tasks for a fresh start."))
                        } else {
                            Column(modifier = Modifier.padding(horizontal = 8.dp)) {
                                tasks.forEach { task ->
                                    TaskRow(task, healthProgress[task.id] ?: 0.0, { onToggleTask(task.id, list?.id ?: "") }, modifier = Modifier.padding(vertical = 5.dp), language = language)
                                }
                            }
                        }
                    }
                }
            } else {
                // Standard Single-Column Scroll Underneath Pinned Top Header
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .clipToBounds()
                        .verticalScroll(scrollState)
                        .padding(bottom = 80.dp)
                ) {
                    val heroTitle = if (!hasRealLists) "" else (list?.cleanName ?: "GET TRACKING")
                    Column(modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 4.dp)) {
                        Text(
                            heroTitle.uppercase(),
                            color = colors.accent,
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp, fontSize = 10.sp).glow(colors.accent, 4f),
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(
                                    "$percentage%",
                                    style = HeroPercentageStyle.copy(fontSize = 92.sp, fontFamily = MaterialTheme.typography.displaySmall.fontFamily, letterSpacing = (-2).sp).glow(colors.accent, 12f),
                                    color = colors.accent,
                                )
                                Text(SortydStrings.t(language, "Done Today"), style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium, fontSize = 12.sp), color = colors.text2, modifier = Modifier.offset(y = (-10).dp))
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text("🔥", fontSize = 18.sp)
                                    Spacer(Modifier.width(2.dp))
                                    Text("$streak", style = MaterialTheme.typography.displayLarge.copy(fontSize = 56.sp, fontWeight = FontWeight.Black, letterSpacing = (-1).sp), color = colors.text0)
                                }
                                Text(SortydStrings.t(language, "DAY STREAK"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, letterSpacing = 1.0.sp, fontWeight = FontWeight.Bold), color = colors.text2, modifier = Modifier.offset(y = (-6).dp))
                            }
                        }
                    }

                    HeatmapCalendar(
                        snapshots = snapshotMap,
                        installDate = installDate,
                        currentMonth = currentMonth,
                        onDayTap = { selectedDay = it },
                        onMonthPickerTap = { showMonthPicker = true },
                        onGoToToday = { currentMonth = YearMonth.now() },
                        modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 8.dp),
                        language = language
                    )

                    SectionLabel(
                        SortydStrings.t(language, "Tasks"),
                        badge = if (totalTasks > 0) "$doneTasks ${SortydStrings.t(language, "done")} · ${totalTasks - doneTasks} ${SortydStrings.t(language, "left")}" else null,
                        actionContent = {
                            if (isTodoActive && hasRealLists) {
                                Button(
                                    onClick = { showAddTask = true },
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color(0xFF4CAF50).copy(alpha = 0.12f),
                                        contentColor = Color(0xFF4CAF50)
                                    ),
                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 5.dp),
                                    modifier = Modifier.height(28.dp),
                                    shape = CircleShape
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(12.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text(SortydStrings.t(language, "Add Task"), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold, fontSize = 11.sp))
                                }
                            }
                        }
                    )

                    if (!hasRealLists) {
                        HomeEmptyState(language = language, onCreateList = { onNavigateToLists() })
                    } else if (tasks.isEmpty()) {
                        if (isTodoActive) {
                            TodoEmptyState(language = language, onAddTask = { showAddTask = true })
                        } else {
                            EmptyState(icon = "📋", title = SortydStrings.t(language, "Nothing here yet"), subtitle = SortydStrings.t(language, "Add today's tasks for a fresh start."))
                        }
                    } else {
                        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                            tasks.forEach { task ->
                                TaskRow(task, healthProgress[task.id] ?: 0.0, { onToggleTask(task.id, list?.id ?: "") }, modifier = Modifier.padding(vertical = 5.dp), language = language)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TodoEmptyState(language: String, onAddTask: () -> Unit) {
    val colors = SortydColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .background(Color(0xFF4CAF50).copy(alpha = 0.1f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text("📋", fontSize = 28.sp)
        }
        Spacer(Modifier.height(16.dp))
        Text(
            SortydStrings.t(language, "Nothing here yet"),
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
            color = colors.text1
        )
        Spacer(Modifier.height(6.dp))
        Text(
            SortydStrings.t(language, "Add today's tasks — they reset at 4 AM for a fresh start."),
            style = MaterialTheme.typography.bodySmall,
            color = colors.text2,
            modifier = Modifier.padding(horizontal = 32.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onAddTask,
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50)),
            shape = CircleShape
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text(SortydStrings.t(language, "Add Task"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold))
        }
    }
}

@Composable
private fun TodoModeSection(
    tasks: List<com.sortyd.app.data.model.SortydTask>,
    onToggleTask: (String) -> Unit,
    onEditTask: (com.sortyd.app.data.model.SortydTask) -> Unit,
    onDeleteTask: (String) -> Unit,
    onAddTask: () -> Unit,
    healthProgress: Map<String, Double>,
    language: String,
    modifier: Modifier = Modifier,
) {
    val colors = SortydColors.current
    Column(modifier = modifier.padding(bottom = 100.dp)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp)
                .shadow(
                    elevation = 12.dp,
                    shape = RoundedCornerShape(20.dp),
                    spotColor = Color.Black.copy(alpha = 0.35f),
                    ambientColor = Color(0xFF4CAF50).copy(alpha = 0.12f)
                )
                .clip(RoundedCornerShape(20.dp))
                .background(colors.bg1)
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF4CAF50).copy(alpha = 0.06f),
                            colors.bg1.copy(alpha = 0.5f),
                            Color(0xFF7C6FFF).copy(alpha = 0.06f)
                        )
                    )
                )
                .border(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(Color.White.copy(alpha = 0.12f), Color.White.copy(alpha = 0.01f), Color.White.copy(alpha = 0.04f))
                    ),
                    shape = RoundedCornerShape(20.dp)
                )
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Left Icon with Glow
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(38.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(
                                colors = listOf(Color(0xFF4CAF50), Color(0xFF2E7D32))
                            )
                        )
                        .border(0.5.dp, Color.White.copy(alpha = 0.25f), CircleShape)
                ) {
                    Text("📥", fontSize = 14.sp)
                }
                
                Spacer(Modifier.width(10.dp))
                
                Column {
                    Text(
                        SortydStrings.t(language, "TO DO"),
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Black, letterSpacing = 1.5.sp),
                        color = colors.text0
                    )
                    Spacer(Modifier.height(1.dp))
                    Text(
                        SortydStrings.t(language, "Stress-Free Zone"),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, fontSize = 10.sp),
                        color = Color(0xFF4CAF50).copy(alpha = 0.9f)
                    )
                }

                Spacer(Modifier.weight(1f))

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(colors.bg0.copy(alpha = 0.7f))
                        .border(0.5.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text("🌙", fontSize = 10.sp)
                    Spacer(Modifier.height(2.dp))
                    Text(
                        SortydStrings.t(language, "Resets 4 AM"),
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.sp, fontWeight = FontWeight.Bold),
                        color = colors.text1
                    )
                }
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(Color(0xFF4CAF50), CircleShape)
                    .glow(Color(0xFF4CAF50), 6f)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                SortydStrings.t(language, "TASKS"),
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black, letterSpacing = 1.5.sp),
                color = colors.text2
            )
        }

        if (tasks.isEmpty()) {
            TodoPlaceholderTaskCard(language = language)
            Spacer(Modifier.height(10.dp))
            TodoInlineAddButton(language = language, onAddTask = onAddTask)
        } else {
            Column {
                tasks.forEach { task ->
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = {
                            if (it == SwipeToDismissBoxValue.EndToStart) {
                                onDeleteTask(task.id)
                                true
                            } else false
                        }
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(vertical = 5.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(colors.danger)
                                    .padding(end = 24.dp),
                                contentAlignment = Alignment.CenterEnd
                            ) {
                                Icon(Icons.Default.Delete, contentDescription = SortydStrings.t(language, "Delete"), tint = Color.White)
                            }
                        },
                        content = {
                            TaskRow(
                                task = task,
                                healthProgress = healthProgress[task.id] ?: 0.0,
                                onToggle = { onToggleTask(task.id) },
                                onTap = { onEditTask(task) },
                                modifier = Modifier.padding(vertical = 5.dp),
                                language = language,
                                isTodoStyle = true,
                                trailingContent = {
                                    IconButton(
                                        onClick = { onEditTask(task) },
                                        modifier = Modifier.size(40.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.Edit,
                                            contentDescription = SortydStrings.t(language, "Edit Task"),
                                            tint = Color(0xFF4CAF50),
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                }
                            )
                        }
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            TodoInlineAddButton(language = language, onAddTask = onAddTask)
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 10.dp)
        ) {
            Text(
                SortydStrings.t(language, "Resets at 4 AM daily"),
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                color = colors.text2.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
private fun TodoPlaceholderTaskCard(language: String) {
    val colors = SortydColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.bg1)
            .border(0.5.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 16.dp)
    ) {
        Text(
            "Task 1",
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = Color(0xFF4CAF50).copy(alpha = 0.8f)
        )
        Spacer(Modifier.height(4.dp))
        Text(
            SortydStrings.t(language, "Anytime"),
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp, fontWeight = FontWeight.Medium),
            color = Color(0xFF4CAF50).copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun TodoInlineAddButton(language: String, onAddTask: () -> Unit) {
    Button(
        onClick = onAddTask,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF4CAF50),
            contentColor = Color.White
        ),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(20.dp),
                spotColor = Color(0xFF4CAF50).copy(alpha = 0.6f),
                ambientColor = Color(0xFF4CAF50).copy(alpha = 0.4f)
            ),
        shape = RoundedCornerShape(20.dp)
    ) {
        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(
            SortydStrings.t(language, "Add Task"),
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold, fontSize = 14.sp)
        )
    }
}

@Composable
private fun HomeEmptyState(language: String, onCreateList: () -> Unit) {
    val colors = SortydColors.current
    
    // Animation States
    val line1 = SortydStrings.t(language, "Let's get")
    val line2 = SortydStrings.t(language, "Tracking")
    var line1Count by remember { mutableStateOf(0) }
    var line2Count by remember { mutableStateOf(0) }
    var typingLine by remember { mutableStateOf(1) }
    var cursorVisible by remember { mutableStateOf(true) }
    var isHandPressing by remember { mutableStateOf(false) }
    var showFinger by remember { mutableStateOf(false) }

    val btnScale by animateFloatAsState(
        targetValue = if (isHandPressing) 0.94f else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow), label = "btnScale"
    )
    val btnRotation by animateFloatAsState(
        targetValue = if (isHandPressing) -4f else 0f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow), label = "btnRot"
    )

    LaunchedEffect(Unit) {
        // Cursor blink
        launch {
            while (true) {
                cursorVisible = !cursorVisible
                delay(500)
            }
        }
        // Type Line 1
        delay(500)
        for (i in 0..line1.length) {
            line1Count = i
            delay(60)
        }
        typingLine = 2
        delay(200)
        // Type Line 2
        for (i in 0..line2.length) {
            line2Count = i
            delay(100)
        }
        typingLine = 3
        delay(800)
        showFinger = true
    }

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
    ) {
        // Decorative background elements
        Box(modifier = Modifier.height(0.dp)) {
            Canvas(modifier = Modifier.fillMaxWidth().height(60.dp)) {
                val cols = 9; val rows = 3
                val spacingX = size.width / cols
                val spacingY = 60.dp.toPx() / rows
                for (r in 0..rows) {
                    for (c in 0..cols) {
                        drawCircle(color = colors.accent.copy(alpha = 0.08f), radius = 1.dp.toPx(), center = Offset(c * spacingX, r * spacingY))
                    }
                }
            }
        }

        // Typing Headline 1
        Row(verticalAlignment = Alignment.CenterVertically) {
            val revealed1 = line1.substring(0, line1Count)
            if (line1Count > 0) {
                Text(
                    text = if (revealed1.length <= 6) revealed1 else "Let's ",
                    style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black, fontSize = 38.sp, fontFamily = LoraFamily, letterSpacing = (-1).sp),
                    color = colors.text0
                )
                if (revealed1.length > 6) {
                    Text(
                        text = revealed1.substring(6),
                        style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black, fontSize = 38.sp, fontFamily = LoraFamily, fontStyle = FontStyle.Italic, letterSpacing = (-1).sp),
                        color = colors.text0
                    )
                }
            }
            if (typingLine == 1 && cursorVisible) {
                Box(Modifier.width(3.dp).height(30.dp).background(colors.accent).glow(colors.accent, 8f).padding(start = 4.dp))
            }
        }

        // Typing Headline 2
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (line2Count > 0) {
                Text(
                    text = line2.substring(0, line2Count),
                    style = MaterialTheme.typography.displaySmall.copy(
                        fontWeight = FontWeight.Black,
                        fontSize = 54.sp,
                        fontFamily = LoraFamily,
                        letterSpacing = (-1.5).sp,
                        brush = Brush.horizontalGradient(listOf(Color(0xFF3ECFFF), Color(0xFF7C6FFF)))
                    ),
                    modifier = Modifier.padding(bottom = 6.dp)
                )
            }
            if (typingLine == 2 && cursorVisible) {
                Box(Modifier.width(3.dp).height(40.dp).background(colors.accent).glow(colors.accent, 8f).padding(start = 4.dp))
            }
        }
        
        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Brush.horizontalGradient(listOf(colors.accent.copy(0.7f), Color(0xFF7C6FFF).copy(0.5f), Color.Transparent))))
        
        Spacer(Modifier.height(10.dp))
        Text(
            SortydStrings.t(language, "Build momentum, one habit at a time."),
            style = MaterialTheme.typography.bodyMedium.copy(fontStyle = FontStyle.Italic, fontWeight = FontWeight.Medium), 
            color = colors.text0
        )
        
        Spacer(Modifier.height(12.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("✅" to "Track tasks", "🔥" to "Build streaks", "📊" to "See progress").forEach { (icon, label) ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(colors.bg2).border(0.8.dp, colors.accent.copy(0.25f), RoundedCornerShape(20.dp)).padding(horizontal = 10.dp, vertical = 7.dp),
                ) {
                    Text(icon, fontSize = 10.sp)
                    Spacer(Modifier.width(5.dp))
                    Text(SortydStrings.t(language, label), style = MaterialTheme.typography.labelSmall, color = colors.text1)
                }
            }
        }
        
        Spacer(Modifier.height(20.dp))

        // Premium CTA with 3D animation
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp)
                .graphicsLayer {
                    scaleX = btnScale
                    scaleY = btnScale
                    rotationX = btnRotation
                    clip = false
                }
                .clip(RoundedCornerShape(20.dp))
                .background(Brush.linearGradient(listOf(colors.accent, Color(0xFF7C6FFF))))
                .clickable { onCreateList() }
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(32.dp).background(Color.Black.copy(0.25f), CircleShape)) {
                    Icon(Icons.Default.Add, "Add", tint = Color.Black, modifier = Modifier.size(13.dp))
                }
                Spacer(Modifier.width(12.dp))
                Text(SortydStrings.t(language, "Create your first list"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold), color = Color.Black)
                Spacer(Modifier.weight(1f))
                Icon(Icons.AutoMirrored.Filled.ArrowForward, "Go", tint = Color.Black.copy(0.55f), modifier = Modifier.size(13.dp).padding(end = 8.dp))
            }
        }

        // Finger Animation Overlay - Moved outside to prevent clipping
        if (showFinger) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                FingerTapOverlay(onPressState = { isHandPressing = it })
            }
        }
    }
}

@Composable
fun OrbitalDonutPill(list: TaskList, isActive: Boolean, fraction: Float, onTap: () -> Unit) {
    val colors = SortydColors.current
    val infinite = rememberInfiniteTransition(label = "orbPulse")
    val glowAlpha by infinite.animateFloat(0f, if (isActive) 0.3f else 0f,
        infiniteRepeatable(tween(2000, easing = EaseInOut), RepeatMode.Reverse), label = "orbGlow")

    var showName by remember(isActive) { mutableStateOf(isActive) }

    LaunchedEffect(showName) {
        if (showName) {
            delay(3000)
            showName = false
        }
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .animateContentSize()
            .clip(RoundedCornerShape(24.dp))
            .background(if (isActive) colors.bg1 else colors.bg2)
            .then(if (isActive) Modifier.border(0.8.dp, Brush.linearGradient(listOf(colors.accent, colors.coral)), RoundedCornerShape(24.dp))
            else Modifier.border(0.5.dp, colors.bg3, RoundedCornerShape(24.dp)))
            .clickable { 
                showName = true
                onTap() 
            }
            .padding(6.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(32.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                if (isActive) drawCircle(color = colors.accent.copy(alpha = glowAlpha), radius = size.minDimension / 2 + 2.5.dp.toPx())
                drawArc(color = colors.bg3, 0f, 360f, false, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
                drawArc(brush = Brush.sweepGradient(listOf(colors.accent, colors.coral, colors.accent)), -90f, 360f * fraction, false, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
            }
            Text(list.emoji, fontSize = 14.sp)
        }
        if (showName) {
            Spacer(Modifier.width(6.dp))
            Text(list.cleanName, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold), color = colors.text0, modifier = Modifier.padding(end = 8.dp))
        }
    }
}

@Composable
fun TodoPill(isActive: Boolean, fraction: Float, language: String, onTap: () -> Unit) {
    val colors = SortydColors.current
    val infiniteTransition = rememberInfiniteTransition(label = "todoPulse")
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.88f,
        targetValue = 1.02f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = EaseInOut),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .scale(if (isActive) 1.05f else 1f)
            .clip(RoundedCornerShape(12.dp))
            .background(if (isActive) colors.bg1 else colors.bg2.copy(0.4f))
            .border(
                if (isActive) 1.dp else 0.5.dp, 
                if (isActive) colors.todoGreen.copy(0.5f) else colors.bg3, 
                RoundedCornerShape(12.dp)
            )
            .clickable { onTap() }
            .padding(horizontal = 7.dp, vertical = 5.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(34.dp)) {
            if (isActive) {
                Canvas(Modifier.size(34.dp)) {
                    drawCircle(color = colors.todoGreen.copy(0.18f), radius = (size.minDimension / 2) * pulse)
                }
            }
            Canvas(Modifier.size(26.dp)) {
                drawCircle(color = colors.bg3.copy(0.5f), style = Stroke(3.2.dp.toPx()))
                drawArc(color = colors.todoGreen, startAngle = -90f, sweepAngle = 360f * fraction.coerceAtLeast(0.001f), useCenter = false, style = Stroke(3.2.dp.toPx(), cap = StrokeCap.Round))
            }
            Text("📋", fontSize = 11.sp)
        }
        Text(SortydStrings.t(language, "TO DO"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.4.sp), color = if (isActive) colors.todoGreen else colors.text2)
    }
}

@Composable
fun WeekCalendarPill(weekNumber: Int, isActive: Boolean, onTap: () -> Unit) {
    val colors = SortydColors.current
    val infiniteTransition = rememberInfiniteTransition(label = "weekPulse")
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.04f,
        animationSpec = infiniteRepeatable(
            animation = tween(2200, easing = EaseInOut),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .scale(if (isActive) 1.05f else 1f)
            .clip(RoundedCornerShape(12.dp))
            .background(if (isActive) colors.bg1 else colors.bg2.copy(0.4f))
            .border(
                if (isActive) 1.dp else 0.5.dp,
                if (isActive) colors.accent.copy(0.55f) else colors.bg3,
                RoundedCornerShape(12.dp)
            )
            .clickable { onTap() }
            .padding(horizontal = 7.dp, vertical = 5.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(width = 40.dp, height = 36.dp)) {
            if (isActive) {
                Box(
                    Modifier
                        .size(width = 40.dp, height = 36.dp)
                        .scale(pulse)
                        .background(
                            Brush.linearGradient(
                                listOf(colors.accent.copy(0.2f), colors.coral.copy(0.16f))
                            ),
                            RoundedCornerShape(12.dp)
                        )
                )
            }

            Box(
                Modifier
                    .size(width = 40.dp, height = 36.dp)
                    .background(
                        if (isActive) {
                            Brush.linearGradient(listOf(colors.accent, Color(0xFF7C6FFF), colors.coral))
                        } else {
                            Brush.linearGradient(listOf(colors.bg1, colors.bg2))
                        },
                        RoundedCornerShape(11.dp)
                    )
                    .border(
                        if (isActive) 1.dp else 0.5.dp,
                        if (isActive) Color.White.copy(alpha = 0.42f) else colors.borderSubtle,
                        RoundedCornerShape(11.dp)
                    )
            )

            Box(
                Modifier
                    .width(24.dp)
                    .height(4.dp)
                    .offset(y = (-11).dp)
                    .background(Color.Black.copy(alpha = if (isActive) 0.18f else 0.08f), CircleShape)
            )

            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(
                    "WK",
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, fontWeight = FontWeight.Black, letterSpacing = 0.4.sp),
                    color = if (isActive) Color.White.copy(alpha = 0.9f) else colors.text2
                )
                Text(
                    "$weekNumber",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Black, fontSize = 14.sp),
                    color = if (isActive) Color.White else colors.text0
                )
            }
        }

        Text(
            "WEEK",
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.4.sp),
            color = if (isActive) colors.accent else colors.text2
        )
    }
}

private fun currentWeekNumber(): Int =
    LocalDate.now().get(WeekFields.of(Locale.getDefault()).weekOfWeekBasedYear())

@androidx.compose.ui.tooling.preview.Preview(showBackground = true)
@Composable
fun HomeScreenPreview() {
    val mockTasks = listOf(
        com.sortyd.app.data.model.SortydTask(id = "1", title = "Drink Water", isCompleted = true, weight = 0.25),
        com.sortyd.app.data.model.SortydTask(id = "2", title = "Read 10 Pages", isCompleted = false, weight = 0.25),
        com.sortyd.app.data.model.SortydTask(id = "3", title = "Morning Walk", isCompleted = true, weight = 0.5)
    )
    val mockList = TaskList(
        id = "list1",
        name = "Daily Habits",
        emoji = "✨",
        tasks = mockTasks
    )
    val mockLists = listOf(mockList)

    com.sortyd.app.ui.theme.SortydTheme(darkTheme = false) {
        HomeScreenContent(
            allLists = mockLists,
            activeList = mockList,
            isDark = false,
            allSnapshots = emptyList(),
            healthProgress = emptyMap(),
            installDate = System.currentTimeMillis(),
            language = "en",
            healthPermissionsGranted = true
        )
    }
}
