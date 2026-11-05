package com.sortyd.app.ui.screens.lists

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.Manifest
import android.app.TimePickerDialog
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import java.util.Calendar
import java.util.UUID
import com.sortyd.app.data.AICoach
import com.sortyd.app.data.StarterList
import com.sortyd.app.data.model.HealthTaskType
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.viewmodel.SortydViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items

data class DraftTask(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val isSelected: Boolean = true,
    val reminderTime: Long? = null,
    val healthType: String? = null,
    val healthTarget: Double? = null
)

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun AIStarterListScreen(
    viewModel: SortydViewModel,
    onBack: () -> Unit,
    onListCreated: () -> Unit
) {
    val colors = SortydColors.current
    val scope = rememberCoroutineScope()
    val healthPermissionsGranted by viewModel.healthPermissionsGranted.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val context = LocalContext.current
    var pendingNavigation by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        androidx.health.connect.client.PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        viewModel.checkHealthPermissions()
        if (pendingNavigation) {
            pendingNavigation = false
            onListCreated()
        }
    }
    
    var goalInput by remember { mutableStateOf("") }
    var isGenerating by remember { mutableStateOf(false) }
    var generatedList by remember { mutableStateOf<StarterList?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val examplePromptsRows = listOf(
        listOf("💪 ${SortydStrings.t(language, "Routine")}", "🌙 ${SortydStrings.t(language, "Better Sleep")}", "💼 ${SortydStrings.t(language, "Job Hunting")}", "📈 ${SortydStrings.t(language, "Grow on Social")}"),
        listOf("🥗 ${SortydStrings.t(language, "Eat Healthy")}", "🚀 ${SortydStrings.t(language, "Upskilling")}", "📱 ${SortydStrings.t(language, "Launch My App")}", "🇪🇸 ${SortydStrings.t(language, "Learn Spanish")}"),
        listOf("💰 ${SortydStrings.t(language, "Save Money")}", "☀️ ${SortydStrings.t(language, "Morning Routine")}", "🏃🏽 ${SortydStrings.t(language, "Cardio & Fitness")}", "📚 ${SortydStrings.t(language, "Read More")}"),
        listOf("🧘🏽‍♀️ ${SortydStrings.t(language, "Mindfulness")}", "🧠 ${SortydStrings.t(language, "Deep Work")}", "💵 ${SortydStrings.t(language, "Financial Freedom")}", "⚡️ ${SortydStrings.t(language, "Productivity")}")
    )
    
    val examplePrompts = examplePromptsRows.flatten()

    Scaffold(
        containerColor = colors.bg0,
        topBar = {
            CenterAlignedTopAppBar(
                title = { },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Close, "Close", tint = colors.text2)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Transparent)
            )
        }
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
            ) {
                Spacer(Modifier.height(16.dp))
                
                // Header
                Text(
                    text = SortydStrings.t(language, "AI Starter List"),
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black),
                    color = colors.text0
                )
                Text(
                    text = SortydStrings.t(language, "Describe your goal — AI builds the exact tasks"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.text2,
                    modifier = Modifier.padding(top = 4.dp)
                )

                Spacer(Modifier.height(32.dp))

                if (generatedList == null) {
                    // Input Field
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(colors.bg2)
                            .border(0.5.dp, colors.bg3, RoundedCornerShape(16.dp))
                            .padding(16.dp)
                    ) {
                        if (goalInput.isEmpty()) {
                            TypingPlaceholder(language)
                        }
                        BasicTextField(
                            value = goalInput,
                            onValueChange = { goalInput = it },
                            textStyle = MaterialTheme.typography.bodyLarge.copy(color = colors.text0),
                            modifier = Modifier.fillMaxWidth(),
                            cursorBrush = Brush.verticalGradient(listOf(colors.accent, colors.accent))
                        )
                    }

                    Spacer(Modifier.height(24.dp))

                    Text(
                        text = SortydStrings.t(language, "Try one of these"),
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                        color = colors.text2
                    )
                    
                    Spacer(Modifier.height(12.dp))

                    // Example Chips
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                    ) {
                        MarqueeChipRow(examplePromptsRows, onChipClick = { goalInput = it })
                    }
                    
                    if (errorMessage != null) {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = errorMessage!!,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.danger,
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.Center
                        )
                    }
                    
                    Spacer(Modifier.height(100.dp)) // Space for button
                } else {
                    // Result Section
                    GeneratedListContent(
                        starterList = generatedList!!,
                        language = language,
                        onRedo = { generatedList = null },
                        onConfirm = { draftTasks ->
                            val selectedDrafts = draftTasks.filter { it.isSelected }
                            val hasHealth = selectedDrafts.any { it.healthType != null }
                            // Add tasks to the newly created list inside the coroutine to prevent foreign key errors
                            scope.launch {
                                val newListId = viewModel.createListSuspend(generatedList!!.listName, generatedList!!.emoji)
                                selectedDrafts.forEach { draft ->
                                    viewModel.addTask(
                                        listId = newListId,
                                        title = draft.title,
                                        reminderTime = draft.reminderTime,
                                        healthType = draft.healthType,
                                        healthTarget = draft.healthTarget
                                    )
                                }
                                if (hasHealth && !healthPermissionsGranted) {
                                    pendingNavigation = true
                                    try {
                                        permissionLauncher.launch(com.sortyd.app.services.HealthConnectManager(context).permissions)
                                    } catch (_: Exception) {
                                        com.sortyd.app.services.HealthConnectManager.startHealthConnectSettings(context)
                                        pendingNavigation = false
                                        onListCreated()
                                    }
                                } else {
                                    onListCreated()
                                }
                            }
                        }
                    )
                }
            }

            // Bottom Button
            if (generatedList == null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(24.dp)
                ) {
                    Button(
                        onClick = {
                            if (goalInput.isNotBlank()) {
                                isGenerating = true
                                errorMessage = null
                                scope.launch {
                                    val (result, error) = AICoach.generateStarterList(goalInput, SortydStrings.languageName(language))
                                    if (result != null) {
                                        generatedList = result
                                    } else {
                                        errorMessage = error ?: SortydStrings.t(language, "Failed to generate list. Please try again.")
                                    }
                                    isGenerating = false
                                }
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (goalInput.isNotBlank()) colors.accent else colors.bg3,
                            contentColor = if (goalInput.isNotBlank()) colors.bg0 else colors.text2
                        ),
                        enabled = goalInput.isNotBlank() && !isGenerating
                    ) {
                        if (isGenerating) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp), color = colors.bg0, strokeWidth = 2.dp)
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.AutoAwesome, null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(SortydStrings.t(language, "Generate List"), style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MarqueeChipRow(prompts: List<List<String>>, onChipClick: (String) -> Unit) {
    val colors = SortydColors.current
    
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        prompts.forEachIndexed { index, rowPrompts ->
            val scrollState = rememberScrollState()
            val speed = if (index % 2 == 0) 1 else -1
            
            LaunchedEffect(Unit) {
                while (true) {
                    scrollState.scrollTo(scrollState.value + speed)
                    if (scrollState.value >= scrollState.maxValue && speed > 0) {
                        scrollState.scrollTo(0)
                    } else if (scrollState.value <= 0 && speed < 0) {
                        scrollState.scrollTo(scrollState.maxValue)
                    }
                    delay(20)
                }
            }
            
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(scrollState, enabled = false),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Repeat to make it feel infinite
                (rowPrompts + rowPrompts + rowPrompts).forEach { prompt ->
                    Box(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(colors.bg2)
                            .clickable { onChipClick(prompt) }
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    ) {
                        Text(
                            text = prompt,
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                            color = colors.text1
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun TypingPlaceholder(language: String) {
    val colors = SortydColors.current
    val phrases = listOf("Get healthy", "Workout routine", "Learn Spanish", "Job hunting", "Eat clean", "Build a habit").map { SortydStrings.t(language, it) }
    var currentPhraseIndex by remember { mutableStateOf(0) }
    var displayedText by remember { mutableStateOf("") }
    var isDeleting by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        while (true) {
            val phrase = phrases[currentPhraseIndex]
            if (!isDeleting) {
                for (i in 0..phrase.length) {
                    displayedText = phrase.substring(0, i)
                    delay(100)
                }
                delay(1500)
                isDeleting = true
            } else {
                for (i in phrase.length downTo 0) {
                    displayedText = phrase.substring(0, i)
                    delay(50)
                }
                isDeleting = false
                currentPhraseIndex = (currentPhraseIndex + 1) % phrases.size
                delay(500)
            }
        }
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = displayedText,
            style = MaterialTheme.typography.bodyLarge,
            color = colors.text2.copy(alpha = 0.5f)
        )
        // Cursor
        Box(
            modifier = Modifier
                .width(2.dp)
                .height(20.dp)
                .background(colors.accent.copy(alpha = 0.5f))
        )
    }
}

@Composable
fun GeneratedListContent(
    starterList: StarterList,
    language: String,
    onRedo: () -> Unit,
    onConfirm: (List<DraftTask>) -> Unit
) {
    val colors = SortydColors.current
    val context = LocalContext.current
    
    // ── Detect & deduplicate health tasks, matching iOS generate() logic ──────
    val draftTasks = remember {
        mutableStateListOf<DraftTask>().apply {
            var foundSteps    = false
            var foundCalories = false
            var foundDistance = false
            for (title in starterList.tasks) {
                val ht = HealthTaskType.detect(title)
                // Keep only the first of each health type (iOS dedup)
                if (ht == HealthTaskType.STEPS    && foundSteps)    continue
                if (ht == HealthTaskType.CALORIES  && foundCalories) continue
                if (ht == HealthTaskType.DISTANCE  && foundDistance) continue
                if (ht == HealthTaskType.STEPS)    foundSteps    = true
                if (ht == HealthTaskType.CALORIES) foundCalories = true
                if (ht == HealthTaskType.DISTANCE) foundDistance = true
                add(DraftTask(
                    title        = title,
                    healthType   = ht?.rawValue,
                    healthTarget = ht?.let { SortydViewModel.extractNumericTarget(title, it) }
                ))
            }
        }
    }
    
    var showHealthDialogFor by remember { mutableStateOf<DraftTask?>(null) }
    var healthTypeSelection by remember { mutableStateOf<String?>(null) }
    var healthTargetSelection by remember { mutableStateOf("") }
    
    val selectedCount = draftTasks.count { it.isSelected }

    if (showHealthDialogFor != null) {
        AlertDialog(
            onDismissRequest = { showHealthDialogFor = null },
            title = { Text(SortydStrings.t(language, "Health Metric")) },
            text = {
                Column {
                    Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val types = listOf(null to SortydStrings.t(language, "None"), HealthTaskType.STEPS.rawValue to SortydStrings.t(language, "Steps"), HealthTaskType.CALORIES.rawValue to SortydStrings.t(language, "Calories"), HealthTaskType.DISTANCE.rawValue to SortydStrings.t(language, "Distance"))
                        types.forEach { (type, label) ->
                            val isSelected = healthTypeSelection == type
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (isSelected) colors.accent.copy(0.15f) else colors.bg2)
                                    .then(if (isSelected) Modifier.border(1.dp, colors.accent, RoundedCornerShape(12.dp)) else Modifier)
                                    .clickable { healthTypeSelection = type }
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(label, color = if (isSelected) colors.accent else colors.text1, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold))
                            }
                        }
                    }
                    if (healthTypeSelection != null) {
                        Spacer(Modifier.height(16.dp))
                        OutlinedTextField(
                            value = healthTargetSelection,
                            onValueChange = { healthTargetSelection = it },
                            label = { Text(SortydStrings.t(language, "Target value")) },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val idx = draftTasks.indexOfFirst { it.id == showHealthDialogFor!!.id }
                    if (idx != -1) {
                        draftTasks[idx] = draftTasks[idx].copy(
                            healthType = healthTypeSelection,
                            healthTarget = healthTargetSelection.toDoubleOrNull()
                        )
                    }
                    showHealthDialogFor = null
                }) { Text(SortydStrings.t(language, "Save")) }
            },
            dismissButton = {
                TextButton(onClick = { showHealthDialogFor = null }) { Text(SortydStrings.t(language, "Cancel")) }
            }
        )
    }
    
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.bg2),
                contentAlignment = Alignment.Center
            ) {
                Text(starterList.emoji.takeIf { it.isNotBlank() } ?: "💡", fontSize = 28.sp)
            }
            Spacer(Modifier.width(16.dp))
            Column {
                Text(
                    text = starterList.listName,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black),
                    color = colors.text0
                )
                Text(
                    text = String.format(SortydStrings.t(language, "%d of %d tasks selected"), selectedCount, draftTasks.size),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.text2
                )
            }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onRedo) {
                Text(SortydStrings.t(language, "Redo"), color = colors.accent, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
            }
        }

        Spacer(Modifier.height(24.dp))

        draftTasks.forEachIndexed { index, draftTask ->
            val isSelected = draftTask.isSelected
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.accent.copy(alpha = 0.06f))
                    .border(0.5.dp, colors.accent.copy(alpha = 0.15f), RoundedCornerShape(16.dp))
                    .clickable { 
                        draftTasks[index] = draftTask.copy(isSelected = !isSelected)
                    }
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                // Checkbox
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) colors.accent else Color.Transparent)
                        .border(1.5.dp, if (isSelected) colors.accent else colors.bg3, CircleShape)
                ) {
                    if (isSelected) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = colors.bg0, modifier = Modifier.size(14.dp))
                    }
                }
                
                Spacer(Modifier.width(14.dp))
                
                // Task Title
                Text(
                    text = draftTask.title, 
                    color = colors.text0, 
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    maxLines = 1,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                
                Spacer(Modifier.width(12.dp))
                
                // Utility Icons (Tag, Bell, Cross)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    // ── Health type badge: auto-detected or manually set ──────
                    val (tagColor, tagBg, tagIcon, tagLabel) = when (draftTask.healthType) {
                        HealthTaskType.STEPS.rawValue    -> listOf(
                            Color(0xFF4FC3F7), Color(0xFF4FC3F7).copy(0.15f),
                            Icons.Default.DirectionsWalk, SortydStrings.t(language, "Steps")
                        )
                        HealthTaskType.CALORIES.rawValue -> listOf(
                            colors.healthCalories, colors.healthCalories.copy(0.15f),
                            Icons.Default.Whatshot, SortydStrings.t(language, "Cal")
                        )
                        HealthTaskType.DISTANCE.rawValue -> listOf(
                            Color(0xFF43A047), Color(0xFF43A047).copy(0.15f),
                            Icons.Default.DirectionsRun, SortydStrings.t(language, "Km")
                        )
                        else -> listOf(
                            Color(0xFFE2B93B), Color(0xFFE2B93B).copy(0.15f),
                            Icons.Default.Sell, null
                        )
                    }
                    @Suppress("UNCHECKED_CAST")
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(tagBg as Color)
                            .clickable {
                                healthTypeSelection = draftTask.healthType
                                healthTargetSelection = draftTask.healthTarget?.toString() ?: ""
                                showHealthDialogFor = draftTask
                            }
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            imageVector = tagIcon as androidx.compose.ui.graphics.vector.ImageVector,
                            contentDescription = "Health type",
                            tint = tagColor as Color,
                            modifier = Modifier.size(11.dp)
                        )
                        if (tagLabel != null) {
                            Spacer(Modifier.width(3.dp))
                            Text(
                                text = tagLabel as String,
                                color = tagColor,
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                fontSize = 9.sp
                            )
                        }
                    }

                    var showTimePicker by remember { mutableStateOf(false) }
                    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
                        if (isGranted) showTimePicker = true
                    }
                    
                    if (showTimePicker) {
                        val cal = Calendar.getInstance()
                        draftTask.reminderTime?.let { cal.timeInMillis = it }
                        TimePickerDialog(context, { _, hour, minute ->
                            val newCal = Calendar.getInstance()
                            newCal.set(Calendar.HOUR_OF_DAY, hour)
                            newCal.set(Calendar.MINUTE, minute)
                            newCal.set(Calendar.SECOND, 0)
                            if (newCal.before(Calendar.getInstance())) newCal.add(Calendar.DAY_OF_YEAR, 1)
                            draftTasks[index] = draftTask.copy(reminderTime = newCal.timeInMillis)
                            showTimePicker = false
                        }, cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE), false).apply {
                            setOnCancelListener { showTimePicker = false }
                            show()
                        }
                    }

                    val bellColor = if (draftTask.reminderTime != null) colors.accent else colors.text2
                    val bellBg = if (draftTask.reminderTime != null) colors.accent.copy(0.15f) else colors.bg3.copy(0.3f)
                    Box(modifier = Modifier.size(24.dp).clip(CircleShape).background(bellBg).clickable {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            if (draftTask.reminderTime != null) draftTasks[index] = draftTask.copy(reminderTime = null)
                            else showTimePicker = true
                        }
                    }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.NotificationsNone, contentDescription = "Reminder", tint = bellColor, modifier = Modifier.size(14.dp))
                    }
                    
                    Box(
                        modifier = Modifier.size(24.dp).clip(CircleShape).background(colors.bg2).clickable { 
                            draftTasks[index] = draftTask.copy(isSelected = !isSelected)
                        }, 
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.Close, contentDescription = "Remove", tint = colors.text2, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        
        // Add More text button
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { /* no-op for now */ }.padding(8.dp)) {
                Icon(Icons.Default.AddCircleOutline, contentDescription = null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(SortydStrings.t(language, "Add More"), color = colors.accent, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
            }
        }

        Spacer(Modifier.height(16.dp))

        // Large CTA Button
        Button(
            onClick = { onConfirm(draftTasks.toList()) },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0),
            enabled = selectedCount > 0
        ) {
            Text(String.format(SortydStrings.t(language, "Create List with %d Tasks"), selectedCount), style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
        }
        
        Spacer(Modifier.height(16.dp))
    }
}
