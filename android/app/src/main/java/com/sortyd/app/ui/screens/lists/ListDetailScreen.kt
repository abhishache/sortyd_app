package com.sortyd.app.ui.screens.lists

import android.Manifest
import android.app.TimePickerDialog
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.sortyd.app.data.AICoach
import com.sortyd.app.data.model.HealthTaskType
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.components.EmptyState
import com.sortyd.app.ui.components.TaskRow
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.viewmodel.SortydViewModel
import kotlinx.coroutines.launch
import java.util.Calendar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListDetailScreen(listId: String, viewModel: SortydViewModel, onBack: () -> Unit) {
    val colors = SortydColors.current
    val allLists by viewModel.allLists.collectAsState()
    val healthProgress by viewModel.healthProgress.collectAsState()
    val canUndo by viewModel.canUndo.collectAsState()
    val canRedo by viewModel.canRedo.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val list = allLists.find { it.id == listId }
    val lastResetDate by viewModel.lastResetDate.collectAsState()
    val showResetHeader = list?.isTodo == true && lastResetDate > 0
    
    var showAddTask by remember { mutableStateOf(false) }
    var editingTask by remember { mutableStateOf<com.sortyd.app.data.model.SortydTask?>(null) }
    val healthPermissionsGranted by viewModel.healthPermissionsGranted.collectAsState()
    val context = androidx.compose.ui.platform.LocalContext.current
    val permissionLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.health.connect.client.PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        viewModel.checkHealthPermissions()
    }

    var showDiscoveryGuide by remember { mutableStateOf(false) }
    val prefs = context.getSharedPreferences("sortyd_prefs", android.content.Context.MODE_PRIVATE)
    
    LaunchedEffect(Unit) {
        if (!prefs.getBoolean("has_seen_list_discovery", false)) {
            showDiscoveryGuide = true
        }
    }

    Scaffold(
        containerColor = colors.bg0,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "${list?.emoji ?: ""} ${list?.cleanName ?: ""}",
                        style = MaterialTheme.typography.headlineSmall,
                        color = colors.text0,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.text0)
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.undo() }, enabled = canUndo) {
                        Icon(
                            Icons.Default.Refresh, "Undo",
                            tint = if (canUndo) colors.text0 else colors.text2.copy(0.3f),
                        )
                    }
                    IconButton(onClick = { viewModel.redo() }, enabled = canRedo) {
                        Icon(
                            Icons.Default.Refresh, "Redo",
                            tint = if (canRedo) colors.text0 else colors.text2.copy(0.3f),
                        )
                    }
                    IconButton(onClick = { showAddTask = true }) {
                        Icon(
                            Icons.Default.Add, "Add",
                            tint = colors.accent,
                            modifier = Modifier
                                .size(20.dp)
                                .border(1.dp, colors.accent, CircleShape)
                                .padding(2.dp),
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.bg0),
            )
        },
    ) { padding ->
        val tasks = list?.tasks ?: emptyList()
        if (tasks.isEmpty()) {
            EmptyState(
                "✨", "No tasks yet", "Add your first task to this list",
                Modifier.padding(padding).fillMaxSize(),
            )
        } else {
            LazyColumn(
                contentPadding = PaddingValues(bottom = 32.dp),
                modifier = Modifier.padding(padding).fillMaxSize(),
            ) {
                if (showResetHeader) {
                    item {
                        val date = java.text.SimpleDateFormat("MMM d", java.util.Locale.getDefault()).format(java.util.Date(lastResetDate))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(colors.accent.copy(alpha = 0.05f))
                                .border(0.5.dp, colors.accent.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                                .padding(12.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Info, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(
                                    "This list was last cleared on $date. Focus on today's goals!",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = colors.text1
                                )
                            }
                        }
                    }
                }
                items(tasks, key = { it.id }) { task ->
                    TaskRow(
                        task = task, 
                        healthProgress = healthProgress[task.id] ?: 0.0,
                        onToggle = { viewModel.toggleTask(task.id, listId) },
                        onTap = { editingTask = task },
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                        language = language,
                    )
                }
            }
        }
    }

    if (showAddTask) {
        AddTaskSheet(
            listId = listId,
            language = language,
            onDismiss = { showAddTask = false },
            onAdd = { title, reminder, healthType, healthTarget ->
                viewModel.addTask(
                    listId = listId,
                    title = title,
                    reminderTime = reminder,
                    reminderIsOneTime = false,
                    healthType = healthType,
                    healthTarget = healthTarget
                )
                showAddTask = false
                if (healthType != null && !healthPermissionsGranted) {
                    try {
                        permissionLauncher.launch(com.sortyd.app.services.HealthConnectManager(context).permissions)
                    } catch (_: Exception) {}
                }
            },
        )
    }

    if (editingTask != null) {
        TaskEditBottomSheet(
            task = editingTask!!,
            language = language,
            onDismiss = { editingTask = null },
            onSave = { title, healthType, healthTarget, reminderTime ->
                viewModel.updateTask(editingTask!!.id, listId, title, healthType, healthTarget, reminderTime)
                editingTask = null
                if (healthType != null && !healthPermissionsGranted) {
                    try {
                        permissionLauncher.launch(com.sortyd.app.services.HealthConnectManager(context).permissions)
                    } catch (_: Exception) {}
                }
            }
        )
    }

    if (showDiscoveryGuide) {
        ListDiscoveryOverlay(
            language = language,
            onDismiss = {
                prefs.edit().putBoolean("has_seen_list_discovery", true).apply()
                showDiscoveryGuide = false
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTaskSheet(
    listId: String,
    language: String = "en",
    onDismiss: () -> Unit,
    onAdd: (String, Long?, String?, Double?) -> Unit,
) {
    val colors = SortydColors.current
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf("") }
    var isParsing by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = colors.bg1,
        dragHandle = {
            Box(
                Modifier.padding(top = 12.dp).width(36.dp).height(4.dp)
                    .clip(RoundedCornerShape(2.dp)).background(colors.bg3)
            )
        },
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(SortydStrings.t(language, "New planned task"), style = MaterialTheme.typography.headlineSmall, color = colors.text0)
                if (title.contains("at", ignoreCase = true) || title.contains("pm", ignoreCase = true) || title.contains("am", ignoreCase = true)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clip(CircleShape).background(colors.accent.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(Icons.Default.AutoAwesome, null, tint = colors.accent, modifier = Modifier.size(12.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("AI", style = MaterialTheme.typography.labelSmall, color = colors.accent)
                    }
                }
            }
            
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                title, { title = it },
                label = { Text(SortydStrings.t(language, "Task")) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = colors.accent,
                    unfocusedBorderColor = colors.bg3,
                    cursorColor = colors.accent,
                ),
                trailingIcon = {
                    if (isParsing) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = colors.accent)
                    }
                }
            )
            Spacer(Modifier.height(20.dp))
            Button(
                onClick = {
                    if (title.isNotBlank()) {
                        isParsing = true
                        scope.launch {
                            val parsed = AICoach.parseNaturalLanguageTask(title)
                            if (parsed != null) {
                                var reminderMillis: Long? = null
                                parsed.reminderTime?.let { timeStr ->
                                    try {
                                        val parts = timeStr.split(":")
                                        if (parts.size == 2) {
                                            val hour = parts[0].toInt()
                                            val minute = parts[1].toInt()
                                            val cal = Calendar.getInstance()
                                            cal.set(Calendar.HOUR_OF_DAY, hour)
                                            cal.set(Calendar.MINUTE, minute)
                                            cal.set(Calendar.SECOND, 0)
                                            reminderMillis = cal.timeInMillis
                                        }
                                    } catch (e: Exception) {}
                                }
                                onAdd(parsed.title, reminderMillis, parsed.healthType, parsed.healthTarget)
                            } else {
                                onAdd(title.trim(), null, null, null)
                            }
                            isParsing = false
                        }
                    }
                },
                enabled = title.isNotBlank() && !isParsing,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.accent,
                    contentColor = colors.bg0,
                    disabledContainerColor = colors.bg3,
                ),
            ) {
                if (isParsing) {
                    Text("...", style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.AutoAwesome, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(SortydStrings.t(language, "Add Task"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskEditBottomSheet(
    task: SortydTask,
    language: String = "en",
    onDismiss: () -> Unit,
    onSave: (String, String?, Double?, Long?) -> Unit,
) {
    val colors = SortydColors.current
    val context = LocalContext.current
    
    var title by remember { mutableStateOf(task.title) }
    var healthType by remember { mutableStateOf(task.healthType) }
    var healthTarget by remember { mutableStateOf(task.healthTarget?.toString() ?: "") }
    var reminderTime by remember { mutableStateOf(task.reminderTime) }
    var showTimePicker by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
        if (isGranted) {
            showTimePicker = true
        }
    }

    if (showTimePicker) {
        val cal = Calendar.getInstance()
        reminderTime?.let { cal.timeInMillis = it }
        TimePickerDialog(context, { _, hour, minute ->
            val newCal = Calendar.getInstance()
            newCal.set(Calendar.HOUR_OF_DAY, hour)
            newCal.set(Calendar.MINUTE, minute)
            newCal.set(Calendar.SECOND, 0)
            if (newCal.before(Calendar.getInstance())) {
                newCal.add(Calendar.DAY_OF_YEAR, 1)
            }
            reminderTime = newCal.timeInMillis
            showTimePicker = false
        }, cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE), false).apply {
            setOnCancelListener { showTimePicker = false }
            show()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = colors.bg1,
        dragHandle = {
            Box(Modifier.padding(top = 12.dp).width(36.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(colors.bg3))
        },
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp)) {
            Text(SortydStrings.t(language, "Task"), style = MaterialTheme.typography.headlineSmall, color = colors.text0)
            Spacer(Modifier.height(16.dp))
            
            // Title
            OutlinedTextField(
                value = title, onValueChange = { title = it },
                label = { Text(SortydStrings.t(language, "Task")) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.accent, unfocusedBorderColor = colors.bg3, cursorColor = colors.accent)
            )
            
            Spacer(Modifier.height(20.dp))
            Text(SortydStrings.t(language, "HEALTH"), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.sp), color = colors.text2)
            Spacer(Modifier.height(8.dp))
            
            // Health Type Selector
            Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val types = listOf(
                    null to SortydStrings.t(language, "None"),
                    HealthTaskType.STEPS.rawValue to SortydStrings.t(language, "Steps"),
                    HealthTaskType.CALORIES.rawValue to SortydStrings.t(language, "Calories"),
                    HealthTaskType.DISTANCE.rawValue to SortydStrings.t(language, "Distance"),
                    HealthTaskType.SCREEN_TIME.rawValue to SortydStrings.t(language, "Phone Usage")
                )
                types.forEach { (type, label) ->
                    val isSelected = healthType == type
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isSelected) colors.accent.copy(0.15f) else colors.bg2)
                            .then(if (isSelected) Modifier.border(1.dp, colors.accent, RoundedCornerShape(12.dp)) else Modifier)
                            .clickable { healthType = type }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(label, color = if (isSelected) colors.accent else colors.text1, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold))
                    }
                }
            }
            
            if (healthType != null) {
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = healthTarget, onValueChange = { healthTarget = it },
                    label = { Text(SortydStrings.t(language, "Target (e.g. 500)")) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.accent, unfocusedBorderColor = colors.bg3)
                )
            }
            
            Spacer(Modifier.height(20.dp))
            Text(SortydStrings.t(language, "REMINDER"), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.sp), color = colors.text2)
            Spacer(Modifier.height(8.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(colors.bg2).clickable {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        showTimePicker = true
                    }
                }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.Notifications, "Reminder", tint = colors.accent)
                Spacer(Modifier.width(12.dp))
                if (reminderTime != null) {
                    val cal = Calendar.getInstance().apply { timeInMillis = reminderTime!! }
                    Text(String.format("%02d:%02d", cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE)), style = MaterialTheme.typography.bodyLarge, color = colors.text0)
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { reminderTime = null }, modifier = Modifier.size(24.dp)) {
                        Icon(Icons.Default.Close, "Remove", tint = colors.text2, modifier = Modifier.size(16.dp))
                    }
                } else {
                    Text(SortydStrings.t(language, "Anytime"), style = MaterialTheme.typography.bodyMedium, color = colors.text2)
                }
            }

            Spacer(Modifier.height(32.dp))
            Button(
                onClick = {
                    onSave(title, healthType, healthTarget.toDoubleOrNull(), reminderTime)
                },
                enabled = title.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0)
            ) {
                Text(SortydStrings.t(language, "Save changes"), style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
            }
        }
    }
}

@Composable
fun ListDiscoveryOverlay(language: String, onDismiss: () -> Unit) {
    var step by remember { mutableStateOf(0) }
    val totalSteps = 4
    val colors = SortydColors.current
    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val screenWidth = configuration.screenWidthDp.dp
    
    data class GuideStep(val icon: String, val title: String, val message: String, val action: String)
    val steps = listOf(
        GuideStep("⚙️", SortydStrings.t(language, "Start with settings"), SortydStrings.t(language, "Use the top-right control when you want to reorder lists or clean up the view."), SortydStrings.t(language, "Settings")),
        GuideStep("🔄", SortydStrings.t(language, "Undo & Redo"), SortydStrings.t(language, "Mistakes happen. Use these to undo or redo your last actions."), SortydStrings.t(language, "History")),
        GuideStep("➕", SortydStrings.t(language, "Create or draft a list"), SortydStrings.t(language, "Use + when you know the tasks. Use AI when you only have the goal."), SortydStrings.t(language, "Add")),
        GuideStep("📊", SortydStrings.t(language, "Read progress later"), SortydStrings.t(language, "Analytics turns this active list into trends, streaks, and habit clues."), SortydStrings.t(language, "Review"))
    )
    
    val currentStep = steps[step]
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.6f))
            .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) { },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .width(screenWidth * 0.85f)
                .shadow(24.dp, RoundedCornerShape(24.dp), spotColor = Color.Black.copy(alpha = 0.4f), ambientColor = colors.accent.copy(alpha = 0.2f))
                .clip(RoundedCornerShape(24.dp))
                .background(colors.bg1.copy(alpha = 0.98f))
                .border(1.dp, colors.accent.copy(alpha = 0.18f), RoundedCornerShape(24.dp))
                .padding(20.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(listOf(colors.accent.copy(alpha = 0.18f), Color(0xFF7C6FFF).copy(alpha = 0.12f))))
                        .border(1.dp, colors.accent.copy(alpha = 0.24f), CircleShape)
                ) {
                    Text(currentStep.icon, fontSize = 20.sp)
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(currentStep.action.uppercase(), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black, fontSize = 9.sp), color = colors.accent, letterSpacing = 1.1.sp)
                        Spacer(Modifier.width(6.dp))
                        Text("${step + 1}/$totalSteps", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black, fontSize = 9.sp), color = colors.accent, letterSpacing = 1.1.sp)
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(currentStep.title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold), color = colors.text0)
                    Spacer(Modifier.height(6.dp))
                    Text(currentStep.message, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold, lineHeight = 20.sp), color = colors.text1)
                }
            }
            
            Spacer(Modifier.height(24.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (i in 0 until totalSteps) {
                        Box(modifier = Modifier
                            .height(6.dp)
                            .width(if (i == step) 20.dp else 6.dp)
                            .clip(CircleShape)
                            .background(if (i == step) colors.accent else colors.bg3)
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                Button(
                    onClick = {
                        if (step < totalSteps - 1) step++ else onDismiss()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = Color.White),
                    shape = CircleShape,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 10.dp)
                ) {
                    Text(if (step < totalSteps - 1) SortydStrings.t(language, "Next") else SortydStrings.t(language, "Done"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Black))
                    Spacer(Modifier.width(6.dp))
                    Icon(if (step < totalSteps - 1) Icons.AutoMirrored.Filled.ArrowForward else Icons.Default.Check, null, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}
