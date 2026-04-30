package com.sortyd.app.ui.screens.home

import androidx.compose.animation.*
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sortyd.app.model.*
import com.sortyd.app.ui.components.*
import com.sortyd.app.ui.screens.lists.AddTaskSheet
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun HomeScreen(vm: AppViewModel = hiltViewModel()) {
    val c = sortydColors
    val lists by vm.lists.collectAsStateWithLifecycle()
    val activeListId by vm.activeListId.collectAsStateWithLifecycle()
    val activeList by vm.activeList.collectAsStateWithLifecycle()
    val activeRegularList by vm.activeRegularList.collectAsStateWithLifecycle()
    val todoList by vm.todoList.collectAsStateWithLifecycle()
    val snapshots by vm.snapshots.collectAsStateWithLifecycle()
    val healthSteps by vm.healthConnect.todaySteps.collectAsStateWithLifecycle()
    val healthCal by vm.healthConnect.todayCalories.collectAsStateWithLifecycle()
    val healthDist by vm.healthConnect.todayDistance.collectAsStateWithLifecycle()

    var showAddTask by remember { mutableStateOf(false) }
    var showHealthConfirm by remember { mutableStateOf<SortydTask?>(null) }
    var showTodoSheet by remember { mutableStateOf(false) }

    val isTodoActive = false // todo list never takes over the main view
    val currentList = activeList

    val healthValues = remember(lists, healthSteps, healthCal, healthDist) {
        currentList?.let { vm.healthConnect.healthValues(it.tasks) } ?: emptyMap()
    }

    val liveCompletion = currentList?.completionFraction(healthValues) ?: 0.0
    val streak = activeRegularList?.let { vm.computeCurrentStreak(it.id) } ?: 0

    DisposableEffect(Unit) {
        vm.refreshHealthData()
        onDispose { }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A)) // Deep iOS black
    ) {
        // ── Header: list switcher ───────────────────────────────────────────
        HeaderSection(
            lists = lists,
            activeListId = activeListId,
            todoList = todoList,
            onSelectList = { vm.setActiveList(it) },
            onSelectTodo = { showTodoSheet = true }
        )

        if (currentList == null) {
            // ── No regular lists → full-screen "Let's Get Tracking" ───────────────
            EmptyHomeState(onAddList = { vm.setTab(1) })
        } else {
            // ── Normal home: hero + calendar + tasks ──────────────────────────────
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
            ) {
                HeroSection(
                    completionPct = (liveCompletion * 100).toInt(),
                    streak = streak,
                    isTodo = isTodoActive,
                    listName = currentList.cleanName
                )

                if (activeRegularList != null) {
                    CalendarGridSection(
                        listId = activeRegularList!!.id,
                        snapshots = snapshots
                    )
                }

                TaskSection(
                    list = currentList,
                    healthValues = healthValues,
                    onToggle = { taskId ->
                        val task = currentList.tasks.find { it.id == taskId }
                        val needsConfirm = task?.isHealthTask == true &&
                                !task.isCompleted &&
                                (healthValues[taskId] ?: 0.0) < 1.0 &&
                                vm.healthConnect.isAuthorized.value
                        if (needsConfirm) showHealthConfirm = task
                        else vm.toggleTask(taskId, currentList.id)
                    },
                    onAddTask = { showAddTask = true },
                    snapshots = snapshots,
                    vm = vm
                )

                Spacer(Modifier.height(100.dp))
            }
        }
    }

    if (showAddTask && currentList != null) {
        AddTaskSheet(
            listId = currentList.id,
            vm = vm,
            onDismiss = { showAddTask = false }
        )
    }

    // ── TO DO Quick Sheet ─────────────────────────────────────────────────────
    if (showTodoSheet && todoList != null) {
        TodoQuickSheet(
            todoList = todoList!!,
            vm = vm,
            onDismiss = { showTodoSheet = false }
        )
    }
}


@Composable
private fun HeaderSection(
    lists: List<TaskList>,
    activeListId: String?,
    todoList: TaskList?,
    onSelectList: (String) -> Unit,
    onSelectTodo: () -> Unit
) {
    val c = sortydColors
    val regularLists = lists.filter { !it.isArchived && !it.isTodo }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(top = 24.dp, bottom = 12.dp, start = 24.dp, end = 24.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        LazyRow(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            items(regularLists) { list ->
                val isActive = list.id == activeListId
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .background(
                            if (isActive) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.03f),
                            CircleShape
                        )
                        .border(
                            1.5.dp,
                            if (isActive) c.teal else Color.White.copy(alpha = 0.05f),
                            CircleShape
                        )
                        .clickable { onSelectList(list.id) },
                    contentAlignment = Alignment.Center
                ) {
                    Text(list.emoji, fontSize = 22.sp)
                }
            }
        }

        if (todoList != null) {
            TodoListButton(todoList = todoList, onClick = onSelectTodo)
        }
    }
}

// ─── To Do List Button (top-right pill in header) ────────────────────────────

@Composable
private fun TodoListButton(todoList: TaskList, onClick: () -> Unit) {
    val green = Color(0xFF4CAF50)
    val done = todoList.tasks.count { it.isCompleted }
    val total = todoList.tasks.size

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(green.copy(alpha = 0.12f))
            .border(1.dp, green.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Checklist icon using stacked lines (using Text emoji so no icon dependency)
        Text("✅", fontSize = 14.sp)
        Column {
            Text(
                "To Do List",
                style = MaterialTheme.typography.labelSmall.copy(
                    color = green,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp
                )
            )
            if (total > 0) {
                Text(
                    "$done / $total done",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = green.copy(alpha = 0.6f),
                        fontSize = 9.sp
                    )
                )
            } else {
                Text(
                    "No tasks yet",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = green.copy(alpha = 0.4f),
                        fontSize = 9.sp
                    )
                )
            }
        }
    }
}

@Composable
private fun HeroSection(
    completionPct: Int,
    streak: Int,
    isTodo: Boolean,
    listName: String
) {
    val c = sortydColors
    val accentColor = if (isTodo) Color(0xFF4CAF50) else c.teal

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp)
    ) {
        if (listName.isNotBlank()) {
            Text(
                listName.uppercase(),
                style = MaterialTheme.typography.labelSmall.copy(
                    color = accentColor,
                    fontWeight = FontWeight.Black,
                    letterSpacing = 1.5.sp
                )
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    "$completionPct%",
                    style = MaterialTheme.typography.displayLarge.copy(
                        color = accentColor,
                        fontSize = 90.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = (-5).sp
                    )
                )
                Text(
                    "DONE TODAY",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = Color.White.copy(alpha = 0.3f),
                        fontWeight = FontWeight.Black,
                        letterSpacing = 2.sp
                    ),
                    modifier = Modifier.offset(y = (-14).dp)
                )
            }

            if (!isTodo) {
                Column(
                    horizontalAlignment = Alignment.End,
                    modifier = Modifier.padding(bottom = 12.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (streak >= 3) {
                        Icon(
                            Icons.Default.Whatshot, 
                            null, 
                            tint = Color(0xFFFF5722), 
                            modifier = Modifier.size(32.dp).offset(y = 4.dp)
                        )
                    }
                    Text(
                        "$streak",
                        style = MaterialTheme.typography.displayLarge.copy(
                            color = Color.White,
                            fontSize = 54.sp,
                            fontWeight = FontWeight.Black,
                            letterSpacing = (-2).sp
                        )
                    )
                }
                    Text(
                        "DAY STREAK",
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = Color.White.copy(alpha = 0.3f),
                            fontWeight = FontWeight.Black,
                            letterSpacing = 2.sp
                        ),
                        modifier = Modifier.offset(y = (-10).dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun CalendarGridSection(listId: String, snapshots: List<DailySnapshot>) {
    val c = sortydColors
    val todayCal = Calendar.getInstance()
    val calendar = Calendar.getInstance()
    
    val currentMonth = calendar.get(Calendar.MONTH)
    val currentYear = calendar.get(Calendar.YEAR)
    val today = todayCal.get(Calendar.DAY_OF_MONTH)
    val isCurrentMonth = todayCal.get(Calendar.MONTH) == currentMonth && todayCal.get(Calendar.YEAR) == currentYear

    // Find start day and length
    calendar.set(Calendar.DAY_OF_MONTH, 1)
    val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
    val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

    val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    val snapMap = snapshots.filter { it.listId == listId }.associate {
        sdf.format(Date(it.date)) to it.completionFraction
    }

    Box(
        modifier = Modifier
            .padding(horizontal = 24.dp, vertical = 8.dp)
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.03f), RoundedCornerShape(24.dp))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(24.dp))
            .padding(20.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(Date()).uppercase(),
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = c.teal, 
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.sp
                        )
                    )
                    Icon(Icons.Default.ExpandMore, null, tint = c.teal, modifier = Modifier.size(14.dp))
                }
                
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        repeat(5) { idx ->
                            Box(modifier = Modifier.size(10.dp, 4.dp).background(c.teal.copy(alpha = 0.1f + 0.2f * idx), RoundedCornerShape(2.dp)))
                        }
                    }
                }
            }
            
            Spacer(Modifier.height(20.dp))
            
            val days = listOf("S", "M", "T", "W", "T", "F", "S")
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                days.forEach { day ->
                    Text(
                        day, 
                        style = MaterialTheme.typography.labelSmall.copy(
                            color = Color.White.copy(alpha = 0.2f),
                            fontWeight = FontWeight.Bold
                        ), 
                        modifier = Modifier.width(32.dp), 
                        textAlign = TextAlign.Center
                    )
                }
            }
            
            Spacer(Modifier.height(12.dp))
            
            val totalCells = ((daysInMonth + firstDayOfWeek - 2) / 7 + 1) * 7
            for (i in 0 until totalCells step 7) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    for (j in 0 until 7) {
                        val dayIndex = i + j
                        val dayNum = dayIndex - (firstDayOfWeek - 2)
                        
                        if (dayNum in 1..daysInMonth) {
                            val isToday = isCurrentMonth && dayNum == today
                            val cellCal = Calendar.getInstance().apply {
                                set(currentYear, currentMonth, dayNum)
                            }
                            val dateKey = sdf.format(cellCal.time)
                            val completion = snapMap[dateKey] ?: 0.0
                            
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
                                    .then(
                                        if (isToday) Modifier.border(1.5.dp, c.teal, CircleShape)
                                        else if (completion > 0) Modifier.background(c.teal.copy(alpha = (0.1f + 0.6f * completion).toFloat()), CircleShape)
                                        else Modifier
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    "$dayNum",
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        color = if (isToday) c.teal 
                                               else if (completion > 0.8) Color.Black
                                               else if (completion > 0) Color.White
                                               else Color.White.copy(alpha = 0.15f),
                                        fontWeight = if (isToday || completion > 0) FontWeight.Bold else FontWeight.Normal
                                    )
                                )
                            }
                        } else {
                            Spacer(Modifier.size(32.dp))
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun TaskSection(
    list: TaskList,
    healthValues: Map<String, Double>,
    snapshots: List<DailySnapshot>,
    onToggle: (String) -> Unit,
    onAddTask: () -> Unit,
    vm: AppViewModel
) {
    val doneCount = list.tasks.count { it.isCompleted }
    val leftCount = list.tasks.size - doneCount

    Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "TASKS",
                style = MaterialTheme.typography.labelSmall.copy(
                    color = Color.White.copy(alpha = 0.4f),
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
            )
            Text(
                "$doneCount done · $leftCount left",
                style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.4f))
            )
        }

        list.tasks.forEach { task ->
            val taskStreak = vm.computeTaskStreak(list.id, task.id)
            val hasStreak = taskStreak >= 3

            TaskCheckboxRow(
                task = task,
                healthProgress = healthValues[task.id] ?: 0.0,
                onToggle = { onToggle(task.id) },
                hasStreak = hasStreak,
                modifier = Modifier
                    .padding(vertical = 4.dp)
                    .background(Color.White.copy(alpha = 0.03f), RoundedCornerShape(16.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
            )
        }

        TextButton(
            onClick = onAddTask,
            modifier = Modifier.align(Alignment.CenterHorizontally)
        ) {
            Icon(Icons.Default.Add, null, tint = Color.White.copy(alpha = 0.3f), modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(4.dp))
            Text("Add Task", color = Color.White.copy(alpha = 0.3f))
        }
    }
}



@Composable
private fun EmptyHomeState(onAddList: () -> Unit, vm: AppViewModel = androidx.hilt.navigation.compose.hiltViewModel()) {
    val c = sortydColors
    val lang by vm.appLanguage.collectAsStateWithLifecycle()

    val headline = when (lang) {
        com.sortyd.app.model.AppLanguage.ARABIC -> "هيا نبدأ التتبع"
        com.sortyd.app.model.AppLanguage.SPANISH -> "¡Empecemos a Seguir!"
        else -> "Let's Get Tracking"
    }
    val sub = when (lang) {
        com.sortyd.app.model.AppLanguage.ARABIC -> "أنشئ قائمة عاداتك الأولى وابدأ في بناء السلاسل"
        com.sortyd.app.model.AppLanguage.SPANISH -> "Crea tu primera lista de hábitos y empieza a construir rachas"
        else -> "Create your first habit list and start building streaks"
    }
    val cta = when (lang) {
        com.sortyd.app.model.AppLanguage.ARABIC -> "إنشاء قائمة"
        com.sortyd.app.model.AppLanguage.SPANISH -> "Crear una Lista"
        else -> "Create a List"
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Glowing target icon
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .background(
                        Brush.radialGradient(listOf(c.teal.copy(alpha = 0.15f), Color.Transparent)),
                        CircleShape
                    )
            )
            Text("🎯", style = MaterialTheme.typography.displayLarge.copy(fontSize = 64.sp))
        }

        Spacer(Modifier.height(28.dp))

        Text(
            headline,
            style = MaterialTheme.typography.headlineLarge.copy(
                color = Color.White,
                fontWeight = FontWeight.Black,
                letterSpacing = (-0.5).sp
            ),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(10.dp))

        Text(
            sub,
            style = MaterialTheme.typography.bodyMedium.copy(
                color = Color.White.copy(alpha = 0.4f),
                lineHeight = 22.sp
            ),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(36.dp))

        GradientButton(onClick = onAddList, modifier = Modifier.fillMaxWidth()) {
            Text(cta, color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

// ─── TO DO Quick Sheet ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TodoQuickSheet(
    todoList: TaskList,
    vm: AppViewModel,
    onDismiss: () -> Unit
) {
    val c = sortydColors
    var showAddTask by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color(0xFF111111),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 12.dp, bottom = 8.dp)
                    .size(36.dp, 4.dp)
                    .background(Color.White.copy(alpha = 0.15f), RoundedCornerShape(2.dp))
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 40.dp)
                .navigationBarsPadding()
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("✅", style = MaterialTheme.typography.headlineSmall)
                    Column {
                        Text(
                            "TO-DO",
                            style = MaterialTheme.typography.labelSmall.copy(
                                color = Color(0xFF4CAF50),
                                fontWeight = FontWeight.Black,
                                letterSpacing = 1.5.sp
                            )
                        )
                        val done = todoList.tasks.count { it.isCompleted }
                        val total = todoList.tasks.size
                        Text(
                            "$done / $total done · resets at 4 AM",
                            style = MaterialTheme.typography.labelSmall.copy(color = Color.White.copy(alpha = 0.3f))
                        )
                    }
                }
                TextButton(onClick = { showAddTask = true }) {
                    Icon(Icons.Default.Add, null, tint = Color(0xFF4CAF50), modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Add", color = Color(0xFF4CAF50), style = MaterialTheme.typography.labelMedium)
                }
            }

            if (todoList.tasks.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Nothing here — add a quick task",
                        style = MaterialTheme.typography.bodyMedium.copy(color = Color.White.copy(alpha = 0.3f))
                    )
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    todoList.tasks.forEach { task ->
                        TaskCheckboxRow(
                            task = task,
                            onToggle = { vm.toggleTask(task.id, todoList.id) },
                            modifier = Modifier
                                .background(Color.White.copy(alpha = 0.03f), RoundedCornerShape(14.dp))
                                .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(14.dp))
                        )
                    }
                }
            }
        }
    }

    if (showAddTask) {
        AddTaskSheet(listId = todoList.id, vm = vm, onDismiss = { showAddTask = false })
    }
}
