package com.sortyd.app.ui.screens.lists

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.animation.animateColorAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.NavHostController
import com.sortyd.app.data.model.TaskList
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.ui.theme.SortydTheme
import com.sortyd.app.ui.theme.glow
import com.sortyd.app.viewmodel.SortydViewModel
import com.sortyd.app.ui.components.FingerTapOverlay
import com.sortyd.app.ui.PreviewMocks
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListsScreen(viewModel: SortydViewModel, navController: NavHostController) {
    val allLists by viewModel.allLists.collectAsState()
    val activeListId by viewModel.activeListId.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()

    ListsScreenContent(
        allLists = allLists,
        activeListId = activeListId,
        language = language,
        onCreateList = { n, e -> viewModel.createList(n, e) },
        onDeleteList = { viewModel.deleteList(it) },
        onArchiveList = { viewModel.archiveList(it) },
        onUnarchiveList = { viewModel.unarchiveList(it) },
        onRenameList = { id, n, e -> viewModel.renameList(id, n, e) },
        onMoveList = { from, to -> viewModel.moveList(from, to) },
        onSetActiveList = { viewModel.setActiveList(it) },
        onNavigateToListDetail = { navController.navigate("lists/$it") },
        onNavigateToAIService = { navController.navigate("ai_starter_list") }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListsScreenContent(
    allLists: List<TaskList>,
    activeListId: String?,
    language: String,
    onCreateList: (String, String) -> Unit,
    onDeleteList: (String) -> Unit,
    onArchiveList: (String) -> Unit,
    onUnarchiveList: (String) -> Unit,
    onRenameList: (String, String, String) -> Unit,
    onMoveList: (Int, Int) -> Unit,
    onSetActiveList: (String) -> Unit,
    onNavigateToListDetail: (String) -> Unit,
    onNavigateToAIService: () -> Unit,
    initialShowFirstListHint: Boolean = false
) {
    val colors = SortydColors.current
    val activeLists = allLists.filter { !it.isArchived && !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
    val archivedLists = allLists.filter { it.isArchived && !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
    var showAddSheet by remember { mutableStateOf(false) }
    var showArchived by remember { mutableStateOf(false) }
    var isEditMode by remember { mutableStateOf(false) }

    // Onboarding States
    var onboardingStep by remember { mutableIntStateOf(-1) }
    var isManualPressing by remember { mutableStateOf(false) }
    var isAIPressing by remember { mutableStateOf(false) }

    LaunchedEffect(activeLists.isEmpty()) {
        if (activeLists.isEmpty()) {
            delay(1000)
            onboardingStep = 1 // AI first
            delay(3500)
            onboardingStep = 0 // Manual second
            delay(3500)
            onboardingStep = -1
        }
    }

    val context = androidx.compose.ui.platform.LocalContext.current
    val prefs = context.getSharedPreferences("sortyd_hints", android.content.Context.MODE_PRIVATE)
    var showFirstListHint by remember { mutableStateOf(initialShowFirstListHint) }
    var firstListHintStep by remember { mutableIntStateOf(if (initialShowFirstListHint) 0 else -1) }

    LaunchedEffect(activeLists.size) {
        if (activeLists.isNotEmpty() && !prefs.getBoolean("has_seen_first_list_hint", false) && !initialShowFirstListHint) {
            delay(600)
            firstListHintStep = 0
            showFirstListHint = true
        }
    }

    Box(Modifier.fillMaxSize().background(colors.bg0)) {
        // Subtle Background Glows
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Color(0xFF3ECFFF).copy(alpha = 0.04f), Color.Transparent),
                    center = Offset(size.width * 0.7f, 0f),
                    radius = size.width * 0.8f
                )
            )
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Color(0xFF7C6FFF).copy(alpha = 0.03f), Color.Transparent),
                    center = Offset(size.width * 0.1f, size.height * 0.4f),
                    radius = size.width * 0.7f
                )
            )
        }

        LazyColumn(
            contentPadding = PaddingValues(bottom = 32.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            // ── Top bar ──
            item {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp)) {
                    // Settings Gear
                    Box(
                        modifier = Modifier.size(40.dp).clip(CircleShape).background(colors.bg1).border(0.5.dp, colors.borderSubtle, CircleShape).clickable { isEditMode = !isEditMode },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            if (isEditMode) Icons.Default.Check else Icons.Default.Settings,
                            contentDescription = "Edit",
                            tint = if (isEditMode) colors.success else colors.accent,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    
                    Spacer(Modifier.weight(1f))
                    Text("S O R T Y D", style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 4.sp, fontWeight = FontWeight.Bold, fontSize = 9.sp).glow(colors.accent, 4f), color = colors.text2.copy(0.4f))
                    Spacer(Modifier.weight(1f))
                    
                    // Help, AI and Add Group
                    Row(
                        modifier = Modifier.clip(RoundedCornerShape(24.dp)).background(colors.bg1).border(0.85.dp, colors.borderSubtle, RoundedCornerShape(24.dp)).padding(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Help Icon
                        Box(
                            modifier = Modifier.size(32.dp).clip(CircleShape).background(colors.bg2).clickable { 
                                firstListHintStep = 0
                                showFirstListHint = true
                            },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.HelpOutline, "Help", tint = colors.accent, modifier = Modifier.size(16.dp))
                        }
                        Spacer(Modifier.width(4.dp))
                        // AI Pill with sparkles
                        Box(Modifier.height(32.dp).clip(RoundedCornerShape(20.dp))
                            .background(Brush.linearGradient(listOf(colors.accent, Color(0xFF00E5FF))))
                            .clickable { onNavigateToAIService() }.padding(horizontal = 12.dp),
                            contentAlignment = Alignment.Center) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text("✦", color = colors.bg0, fontSize = 10.sp)
                                Text("AI", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black, fontSize = 10.sp).glow(colors.bg0, 4f), color = colors.bg0)
                            }
                        }
                        Spacer(Modifier.width(4.dp))
                        Box(
                            modifier = Modifier.size(32.dp).clip(CircleShape).background(colors.bg2).clickable { showAddSheet = true },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Add, "Add", tint = colors.accent, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }

            if (activeLists.isEmpty()) {
                // ── Empty State ──
                item { 
                    ListsEmptyState(
                        language = language,
                        onboardingStep = onboardingStep,
                        isAIPressing = isAIPressing,
                        isManualPressing = isManualPressing,
                        setAIPressing = { isAIPressing = it },
                        setManualPressing = { isManualPressing = it },
                        onGenerate = { onNavigateToAIService() }, 
                        onManual = { showAddSheet = true }
                    ) 
                }
            } else {
                // ── Header ──
                item {
                    val totalTasks = activeLists.sumOf { it.tasks.size }
                    val doneTasks = activeLists.sumOf { it.tasks.count { t -> t.isCompleted } }
                    val leftTasks = totalTasks - doneTasks
                    
                    Column(Modifier.padding(horizontal = 16.dp)) {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                            Column(Modifier.weight(1f)) {
                                Text(SortydStrings.t(language, "Lists"), style = MaterialTheme.typography.displayMedium.copy(fontWeight = FontWeight.Black), color = colors.text0)
                                Text(SortydStrings.t(language, "Active list would be default across widgets and\nthe analysis."), style = MaterialTheme.typography.bodySmall, color = colors.text2, modifier = Modifier.padding(top = 2.dp, end = 16.dp))
                            }
                            
                            // Summary Pill
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(colors.bg1)
                                    .border(0.5.dp, colors.borderSubtle, RoundedCornerShape(16.dp))
                                    .padding(horizontal = 16.dp, vertical = 12.dp)
                            ) {
                                Text("${activeLists.size}", style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Black, color = colors.accent))
                                Text(SortydStrings.t(language, "Lists").lowercase(), style = MaterialTheme.typography.labelSmall, color = colors.text2)
                            }
                        }
                        
                        Spacer(Modifier.height(12.dp))
                        
                        // Task counters
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.clip(RoundedCornerShape(8.dp)).background(colors.todoGreen.copy(0.1f)).border(0.5.dp, colors.todoGreen.copy(0.3f), RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 4.dp)) {
                                Text("$doneTasks ${SortydStrings.t(language, "done")}", style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold), color = colors.todoGreen)
                            }
                            Box(Modifier.clip(RoundedCornerShape(8.dp)).background(colors.accent.copy(0.1f)).border(0.5.dp, colors.accent.copy(0.3f), RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 4.dp)) {
                                Text("$leftTasks ${SortydStrings.t(language, "left")}", style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold), color = colors.accent)
                            }
                        }
                    }
                    
                    Spacer(Modifier.height(20.dp))
                }
                itemsIndexed(activeLists, key = { _, it -> it.id }) { index, list ->
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = {
                            if (it == SwipeToDismissBoxValue.EndToStart) {
                                onDeleteList(list.id)
                                true
                            } else false
                        }
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        enableDismissFromStartToEnd = false,
                        backgroundContent = {
                            Box(
                                Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 4.dp).clip(RoundedCornerShape(16.dp)).background(colors.danger).padding(end = 24.dp),
                                contentAlignment = Alignment.CenterEnd
                            ) {
                                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.White)
                            }
                        },
                        content = {
                            ListCardItem(
                                list = list,
                                language = language,
                                isActive = list.id == activeListId,
                                isEditMode = isEditMode,
                                onTap = { 
                                    if (!isEditMode) {
                                        onSetActiveList(list.id)
                                        onNavigateToListDetail(list.id) 
                                    }
                                },
                                onArchive = { onArchiveList(list.id) },
                                onDelete = { onDeleteList(list.id) },
                                onRename = { n, e -> onRenameList(list.id, n, e) },
                                onMoveUp = if (index > 0) { { onMoveList(index, index - 1) } } else null,
                                onMoveDown = if (index < activeLists.size - 1) { { onMoveList(index, index + 1) } } else null,
                                modifier = Modifier
                                    .padding(horizontal = 16.dp, vertical = 4.dp)
                            )
                        }
                    )
                }
            }

            // Archived section
            if (archivedLists.isNotEmpty()) {
                item {
                    Row(Modifier.fillMaxWidth().clickable { showArchived = !showArchived }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(SortydStrings.t(language, "ARCHIVED"), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.5.sp, fontWeight = FontWeight.Bold).glow(colors.text2.copy(0.4f), 4f), color = colors.text2)
                        Spacer(Modifier.width(8.dp))
                        Text("${archivedLists.size}", style = MaterialTheme.typography.labelSmall, color = colors.accent,
                            modifier = Modifier.background(colors.accent.copy(0.1f), RoundedCornerShape(10.dp)).padding(horizontal = 8.dp, vertical = 2.dp))
                        Spacer(Modifier.weight(1f))
                        Text(if (showArchived) "▲" else "▼", color = colors.text2, fontSize = 10.sp)
                    }
                }
                if (showArchived) {
                    items(archivedLists, key = { it.id }, contentType = { "archived_list" }) { list ->
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = {
                                if (it == SwipeToDismissBoxValue.EndToStart) {
                                    onDeleteList(list.id)
                                    true
                                } else false
                            }
                        )
                        SwipeToDismissBox(
                            state = dismissState,
                            enableDismissFromStartToEnd = false,
                            backgroundContent = {
                                Box(
                                    Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 4.dp).clip(RoundedCornerShape(16.dp)).background(colors.danger).padding(end = 24.dp),
                                    contentAlignment = Alignment.CenterEnd
                                ) {
                                    Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.White)
                                }
                            },
                            content = {
                                ListCardItem(
                                    list = list,
                                    language = language,
                                    isActive = false,
                                    isEditMode = false,
                                    onTap = { onNavigateToListDetail(list.id) },
                                    onArchive = { onUnarchiveList(list.id) },
                                    onDelete = { onDeleteList(list.id) },
                                    onRename = { n, e -> onRenameList(list.id, n, e) },
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                            }
                        )
                    }
                }
            }
        }
    }
    if (showAddSheet) {
        AddListBottomSheet(language, { showAddSheet = false }, { n, e -> onCreateList(n, e); showAddSheet = false })
    }

    if (showFirstListHint) {
        FirstListHintOverlay(
            language = language,
            step = firstListHintStep,
            onNext = {
                if (firstListHintStep < 3) firstListHintStep++
                else {
                    showFirstListHint = false
                    prefs.edit().putBoolean("has_seen_first_list_hint", true).apply()
                }
            },
            onDismiss = {
                showFirstListHint = false
                prefs.edit().putBoolean("has_seen_first_list_hint", true).apply()
            }
        )
    }
}

// ── Lists Empty State (matching iOS concentric ring screenshot) ──
@Composable
private fun ListsEmptyState(
    language: String,
    onboardingStep: Int,
    isAIPressing: Boolean,
    isManualPressing: Boolean,
    setAIPressing: (Boolean) -> Unit,
    setManualPressing: (Boolean) -> Unit,
    onGenerate: () -> Unit, 
    onManual: () -> Unit
) {
    val colors = SortydColors.current
    val infinite = rememberInfiniteTransition(label = "rings")
    val pulseAlpha by infinite.animateFloat(0.3f, 0.7f, infiniteRepeatable(tween(3000, easing = EaseInOut), RepeatMode.Reverse), label = "rPulse")
    val rotation by infinite.animateFloat(0f, 360f, infiniteRepeatable(tween(20000, easing = LinearEasing)), label = "rRot")

    val aiBtnScale by animateFloatAsState(if (isAIPressing) 0.94f else 1f, spring(dampingRatio = 0.6f), label = "aiS")
    val aiBtnRot by animateFloatAsState(if (isAIPressing) -4f else 0f, spring(dampingRatio = 0.6f), label = "aiR")
    
    val manualBtnScale by animateFloatAsState(if (isManualPressing) 0.94f else 1f, spring(dampingRatio = 0.6f), label = "manS")
    val manualBtnRot by animateFloatAsState(if (isManualPressing) -4f else 0f, spring(dampingRatio = 0.6f), label = "manR")

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(top = 48.dp)) {
        // Concentric rings with center icon
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(200.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                val cx = size.width / 2; val cy = size.height / 2
                // 3 concentric rings
                for (i in 1..3) {
                    val r = size.minDimension / 2 * (0.4f + i * 0.2f)
                    drawCircle(colors.accent.copy(alpha = pulseAlpha * 0.08f * (4 - i)), r, style = Stroke(1.dp.toPx()))
                }
                // Orbital dots
                val dotR = 3.dp.toPx()
                for ((angle, ring) in listOf(0f to 0.6f, 72f to 0.8f, 144f to 0.6f, 216f to 1.0f, 288f to 0.8f, 36f to 1.0f)) {
                    val rad = Math.toRadians((angle + rotation / 3).toDouble())
                    val r = size.minDimension / 2 * ring
                    drawCircle(colors.accent.copy(0.35f), dotR,
                        center = Offset(cx + r * kotlin.math.cos(rad).toFloat(), cy + r * kotlin.math.sin(rad).toFloat()))
                }
            }
            // Center clipboard icon
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(56.dp).clip(RoundedCornerShape(14.dp))
                    .background(colors.accent.copy(0.08f))
                    .border(0.8.dp, colors.accent.copy(0.25f), RoundedCornerShape(14.dp)),
            ) {
                Text("📋", fontSize = 28.sp)
            }
        }

        Spacer(Modifier.height(32.dp))
        Text(SortydStrings.t(language, "Your canvas is empty"), style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold), color = colors.text0)
        Spacer(Modifier.height(6.dp))
        Text(SortydStrings.t(language, "Let AI build your first list,\nor create one yourself."), style = MaterialTheme.typography.bodyMedium, color = colors.text2, textAlign = TextAlign.Center)
        Spacer(Modifier.height(28.dp))

        // "Generate with AI" gradient button
        Box(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 32.dp).height(56.dp)
                .graphicsLayer {
                    this.scaleX = aiBtnScale
                    this.scaleY = aiBtnScale
                    this.rotationX = aiBtnRot
                }
                .clip(RoundedCornerShape(16.dp))
                .background(Brush.horizontalGradient(listOf(colors.accent, Color(0xFF00E5FF))))
                .clickable { onGenerate() }.padding(horizontal = 20.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Box(Modifier.size(32.dp).clip(CircleShape).background(colors.bg0.copy(0.2f)), Alignment.Center) {
                    Text("✦", fontSize = 16.sp, color = colors.bg0)
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(SortydStrings.t(language, "Generate with AI"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold), color = colors.bg0)
                    Text(SortydStrings.t(language, "Describe your goal, AI builds it"), style = MaterialTheme.typography.labelSmall, color = colors.bg0.copy(0.7f))
                }
                Spacer(Modifier.weight(1f))
                Icon(Icons.AutoMirrored.Filled.ArrowForward, "Go", tint = colors.bg0)
            }
        }
        
        if (onboardingStep == 1) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                FingerTapOverlay(onPressState = { setAIPressing(it) })
            }
        }

        Spacer(Modifier.height(16.dp))
        // OR divider
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 48.dp)) {
            HorizontalDivider(Modifier.weight(1f), color = colors.bg3)
            Text(SortydStrings.t(language, "OR"), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold), color = colors.danger, modifier = Modifier.padding(horizontal = 12.dp))
            HorizontalDivider(Modifier.weight(1f), color = colors.bg3)
        }
        Spacer(Modifier.height(16.dp))

        // "Create manually" button
        Box(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 32.dp).height(48.dp)
                .graphicsLayer {
                    this.scaleX = manualBtnScale
                    this.scaleY = manualBtnScale
                    this.rotationX = manualBtnRot
                }
                .clip(RoundedCornerShape(14.dp))
                .background(colors.bg1)
                .border(0.7.dp, colors.bg3, RoundedCornerShape(14.dp))
                .clickable { onManual() },
            contentAlignment = Alignment.Center
        ) {
            Text("✏️  ${SortydStrings.t(language, "Create manually")}", style = MaterialTheme.typography.bodyMedium, color = colors.text1)
        }
        
        if (onboardingStep == 0) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                FingerTapOverlay(onPressState = { setManualPressing(it) })
            }
        }
    }
}

// ── List Card ──
@Composable
private fun ListCardItem(
    list: TaskList, 
    language: String,
    isActive: Boolean, 
    isEditMode: Boolean,
    onTap: () -> Unit, 
    onArchive: () -> Unit, 
    onDelete: () -> Unit, 
    onRename: (String, String) -> Unit,
    onMoveUp: (() -> Unit)? = null,
    onMoveDown: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val colors = SortydColors.current; val done = list.tasks.count { it.isCompleted }; val total = list.tasks.size
    var showMenu by remember { mutableStateOf(false) }
    var showRenameSheet by remember { mutableStateOf(false) }
    
    Row(verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.bg1)
            .then(if (isActive) Modifier.border(0.8.dp, Brush.linearGradient(listOf(colors.accent, colors.coral)), RoundedCornerShape(16.dp))
            else Modifier.border(0.5.dp, colors.borderSubtle, RoundedCornerShape(16.dp)))
            .clickable { onTap() }) {
        if (isActive) Box(Modifier.width(3.5.dp).height(72.dp).clip(RoundedCornerShape(2.dp)).background(Brush.verticalGradient(listOf(colors.accent, colors.coral))))
        Spacer(Modifier.width(if (isActive) 12.dp else 16.dp))
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(if (isActive) colors.accent.copy(0.08f) else colors.bg2)) {
            Text(list.emoji, fontSize = 22.sp)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f).padding(vertical = 14.dp)) {
            if (isActive) Text(SortydStrings.t(language, "ACTIVE LIST"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.5.sp, letterSpacing = 1.2.sp, fontWeight = FontWeight.Black), color = colors.accent,
                modifier = Modifier.padding(bottom = 2.dp))
            Text(list.cleanName, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold, fontSize = 17.sp), color = colors.text0)
            Text("$done / $total ${SortydStrings.t(language, "TASKS COMPLETED")}", style = MaterialTheme.typography.labelSmall.copy(fontSize = 8.5.sp, letterSpacing = 0.5.sp, fontWeight = FontWeight.Bold), color = colors.text2.copy(0.6f), modifier = Modifier.padding(top = 2.dp))
            if (total > 0) Row(horizontalArrangement = Arrangement.spacedBy(3.dp), modifier = Modifier.padding(top = 8.dp)) {
                repeat(minOf(total, 12)) { i -> Box(Modifier.width(18.dp).height(3.5.dp).clip(CircleShape).background(if (i < done) colors.accent else colors.bg3.copy(0.5f))) }
            }
        }
        Spacer(Modifier.width(12.dp))
        
        if (isEditMode) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(end = 8.dp)) {
                IconButton(onClick = { onMoveUp?.invoke() }, enabled = onMoveUp != null) {
                    Icon(Icons.Default.KeyboardArrowUp, "Move Up", tint = if (onMoveUp != null) colors.accent else colors.text2.copy(0.3f))
                }
                IconButton(onClick = { onMoveDown?.invoke() }, enabled = onMoveDown != null) {
                    Icon(Icons.Default.KeyboardArrowDown, "Move Down", tint = if (onMoveDown != null) colors.accent else colors.text2.copy(0.3f))
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .padding(end = 16.dp)
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(colors.bg2)
                    .clickable { showMenu = true },
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.MoreHoriz, "Options", tint = colors.text2, modifier = Modifier.size(20.dp))
                
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false },
                    modifier = Modifier.background(colors.bg1).border(0.5.dp, colors.borderSubtle)
                ) {
                    DropdownMenuItem(
                        text = { Text(SortydStrings.t(language, "Rename"), color = colors.text0) },
                        leadingIcon = { Icon(Icons.Default.Edit, null, tint = colors.accent) },
                        onClick = { showMenu = false; showRenameSheet = true }
                    )
                    DropdownMenuItem(
                        text = { Text(SortydStrings.t(language, "Archive"), color = colors.text0) },
                        leadingIcon = { Icon(Icons.Default.Archive, null, tint = colors.accent) },
                        onClick = { showMenu = false; onArchive() }
                    )
                    DropdownMenuItem(
                        text = { Text(SortydStrings.t(language, "Delete List"), color = colors.danger) },
                        leadingIcon = { Icon(Icons.Default.Delete, null, tint = colors.danger) },
                        onClick = { showMenu = false; onDelete() }
                    )
                }
            }
        }
    }
    
    if (showRenameSheet) {
        RenameListBottomSheet(
            currentName = list.name,
            currentEmoji = list.emoji,
            language = language,
            onDismiss = { showRenameSheet = false },
            onRename = { n, e -> onRename(n, e); showRenameSheet = false }
        )
    }
}

// ── Rename List Sheet ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RenameListBottomSheet(currentName: String, currentEmoji: String, language: String, onDismiss: () -> Unit, onRename: (String, String) -> Unit) {
    val colors = SortydColors.current; var name by remember { mutableStateOf(currentName) }; var emoji by remember { mutableStateOf(currentEmoji) }
    val emojis = listOf("💪", "📚", "🌅", "🧘", "🏃", "💤", "🍎", "✍️", "🎯", "💼", "🎵", "📋")
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = colors.bg1,
        dragHandle = { Box(Modifier.padding(top = 12.dp).width(36.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(colors.bg3)) }) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp)) {
            Text(SortydStrings.t(language, "Rename List"), style = MaterialTheme.typography.headlineSmall, color = colors.text0)
            Spacer(Modifier.height(16.dp))
            Text(SortydStrings.t(language, "CHOOSE AN EMOJI"), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.5.sp), color = colors.text2)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                emojis.take(6).forEach { e ->
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (e == emoji) colors.accent.copy(0.15f) else colors.bg2)
                        .then(if (e == emoji) Modifier.border(1.dp, colors.accent, RoundedCornerShape(10.dp)) else Modifier)
                        .clickable { emoji = e }) { Text(e, fontSize = 20.sp) }
                }
            }
            Spacer(Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                emojis.drop(6).forEach { e ->
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (e == emoji) colors.accent.copy(0.15f) else colors.bg2)
                        .then(if (e == emoji) Modifier.border(1.dp, colors.accent, RoundedCornerShape(10.dp)) else Modifier)
                        .clickable { emoji = e }) { Text(e, fontSize = 20.sp) }
                }
            }
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(name, { name = it }, label = { Text(SortydStrings.t(language, "List name")) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.accent, unfocusedBorderColor = colors.bg3, cursorColor = colors.accent))
            Spacer(Modifier.height(20.dp))
            Button({ if (name.isNotBlank()) onRename(name.trim(), emoji) }, enabled = name.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(48.dp), shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0, disabledContainerColor = colors.bg3)) {
                Text(SortydStrings.t(language, "Save Changes"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
            }
        }
    }
}

// ── Add List Sheet ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddListBottomSheet(language: String, onDismiss: () -> Unit, onCreate: (String, String) -> Unit) {
    val colors = SortydColors.current; var name by remember { mutableStateOf("") }; var emoji by remember { mutableStateOf("📋") }
    val emojis = listOf("💪", "📚", "🌅", "🧘", "🏃", "💤", "🍎", "✍️", "🎯", "💼", "🎵", "📋")
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = colors.bg1,
        dragHandle = { Box(Modifier.padding(top = 12.dp).width(36.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(colors.bg3)) }) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp)) {
            Text(SortydStrings.t(language, "New List"), style = MaterialTheme.typography.headlineSmall, color = colors.text0)
            Spacer(Modifier.height(16.dp))
            Text(SortydStrings.t(language, "CHOOSE AN EMOJI"), style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.5.sp), color = colors.text2)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                emojis.take(6).forEach { e ->
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (e == emoji) colors.accent.copy(0.15f) else colors.bg2)
                        .then(if (e == emoji) Modifier.border(1.dp, colors.accent, RoundedCornerShape(10.dp)) else Modifier)
                        .clickable { emoji = e }) { Text(e, fontSize = 20.sp) }
                }
            }
            Spacer(Modifier.height(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                emojis.drop(6).forEach { e ->
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (e == emoji) colors.accent.copy(0.15f) else colors.bg2)
                        .then(if (e == emoji) Modifier.border(1.dp, colors.accent, RoundedCornerShape(10.dp)) else Modifier)
                        .clickable { emoji = e }) { Text(e, fontSize = 20.sp) }
                }
            }
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(name, { name = it }, label = { Text(SortydStrings.t(language, "List name")) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = colors.accent, unfocusedBorderColor = colors.bg3, cursorColor = colors.accent))
            Spacer(Modifier.height(20.dp))
            Button({ if (name.isNotBlank()) onCreate(name.trim(), emoji) }, enabled = name.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(48.dp), shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0, disabledContainerColor = colors.bg3)) {
                Text(SortydStrings.t(language, "Create List"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
            }
        }
    }
}

// ── First-List Discovery Hint Components ──

@Composable
private fun FirstListHintOverlay(language: String, step: Int, onNext: () -> Unit, onDismiss: () -> Unit) {
    val config = androidx.compose.ui.platform.LocalConfiguration.current
    val isRtl = androidx.compose.ui.platform.LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl
    val w = config.screenWidthDp.toFloat()
    val h = config.screenHeightDp.toFloat()
    val compact = h < 760f

    val cardY = if (compact) minOf(h * 0.36f, 300f) else minOf(h * 0.34f, 330f)
    val leadingToolbarX = if (isRtl) maxOf(w - 76f, 18f) else 18f
    val trailingToolbarX = if (isRtl) 18f else maxOf(w - 132f, 220f)
    
    val panelHeight = 178f

    var targetRectX = 0f
    var targetRectY = 0f
    var targetRectW = 0f
    var targetRectH = 0f
    var targetRadius = 0f
    var panelCenterY = 0f
    var pointerEdgeIsTop = true
    var iconStr = ""
    var title = ""
    var message = ""
    var action = ""

    when (step) {
        0 -> {
            iconStr = "⚙️"
            title = SortydStrings.t(language, "Start with settings")
            message = SortydStrings.t(language, "Use the top-left control when you want to reorder lists or clean up the view.")
            action = SortydStrings.t(language, "Settings")
            targetRectX = leadingToolbarX
            targetRectY = 61f
            targetRectW = 44f
            targetRectH = 44f
            targetRadius = 22f
            panelCenterY = if (compact) 204f else 220f
            pointerEdgeIsTop = true
        }
        1 -> {
            iconStr = "↕️"
            title = SortydStrings.t(language, "Choose what leads")
            message = SortydStrings.t(language, "Move a list higher to make it the active priority for widgets and analytics.")
            action = SortydStrings.t(language, "Priority")
            targetRectX = 18f
            targetRectY = cardY - 20f
            targetRectW = w - 36f
            targetRectH = 96f
            targetRadius = 24f
            panelCenterY = minOf(cardY + 174f, h - 292f)
            pointerEdgeIsTop = true
        }
        2 -> {
            iconStr = "➕"
            title = SortydStrings.t(language, "Create or draft a list")
            message = SortydStrings.t(language, "Use + when you know the tasks. Use AI when you only have the goal.")
            action = SortydStrings.t(language, "Add")
            targetRectX = trailingToolbarX
            targetRectY = 54f
            targetRectW = 118f
            targetRectH = 54f
            targetRadius = 27f
            panelCenterY = if (compact) 204f else 220f
            pointerEdgeIsTop = true
        }
        else -> {
            iconStr = "📈"
            title = SortydStrings.t(language, "Read progress later")
            message = SortydStrings.t(language, "Analytics turns this active list into trends, streaks, and habit clues.")
            action = SortydStrings.t(language, "Review")
            val analyticsCenterX = if (isRtl) w * 0.375f else w * 0.625f
            val tabHighlightWidth = minOf(w * 0.20f, 86f)
            val tabHighlightHeight = if (compact) 70f else 76f
            val tabBarCenterY = h + if (compact) 100f else 112f
            targetRectX = analyticsCenterX - tabHighlightWidth / 2f
            targetRectY = tabBarCenterY - tabHighlightHeight / 2f
            targetRectW = tabHighlightWidth
            targetRectH = tabHighlightHeight
            targetRadius = 26f
            panelCenterY = minOf(maxOf(tabBarCenterY - panelHeight / 2f - 84f, 420f), h - 128f)
            pointerEdgeIsTop = false
        }
    }

    val targetMidX = targetRectX + targetRectW / 2f
    val panelWidth = minOf(w - 36f, 360f)
    val inset = 18f
    val screenClampedMidX = minOf(maxOf(targetMidX, inset + panelWidth / 2f), w - inset - panelWidth / 2f)
    val panelFrameX = screenClampedMidX - panelWidth / 2f
    val panelFrameY = panelCenterY - panelHeight / 2f

    val maxOffset = (panelWidth / 2f) - 36f
    val pointerX = minOf(maxOf(targetMidX - screenClampedMidX, -maxOffset), maxOffset)

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.56f))
            .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) { } // block touches
    ) {
        // Spotlight
        HintSpotlight(targetRectX, targetRectY, targetRectW, targetRectH, targetRadius)

        // Action Panel
        Box(
            Modifier
                .offset(x = panelFrameX.dp, y = panelFrameY.dp)
                .width(panelWidth.dp)
                .height(panelHeight.dp)
        ) {
            HintActionPanel(
                icon = iconStr,
                title = title,
                message = message,
                action = action,
                step = step + 1,
                total = 4,
                nextLabel = SortydStrings.t(language, "Next"),
                doneLabel = SortydStrings.t(language, "Done"),
                pointerEdgeIsTop = pointerEdgeIsTop,
                pointerX = pointerX,
                onNext = onNext,
                onDismiss = onDismiss
            )
        }
    }
}

@Composable
private fun HintSpotlight(x: Float, y: Float, w: Float, h: Float, r: Float) {
    val colors = SortydColors.current
    val infiniteTransition = rememberInfiniteTransition()
    val pulse by infiniteTransition.animateFloat(
        initialValue = 10f,
        targetValue = 24f,
        animationSpec = infiniteRepeatable(tween(1200, easing = EaseInOut), RepeatMode.Reverse)
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.24f,
        targetValue = 0.06f,
        animationSpec = infiniteRepeatable(tween(1200, easing = EaseInOut), RepeatMode.Reverse)
    )

    Box(Modifier.offset(x = x.dp, y = y.dp).size(w.dp, h.dp)) {
        Box(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(r.dp))
                .background(Color.White.copy(0.08f))
                .border(
                    2.5.dp,
                    Brush.linearGradient(listOf(colors.accent.copy(0.88f), colors.coral.copy(0.72f))),
                    RoundedCornerShape(r.dp)
                )
        )
        Box(
            Modifier
                .offset(x = (-pulse/2).dp, y = (-pulse/2).dp)
                .size((w + pulse).dp, (h + pulse).dp)
                .border(7.dp, colors.accent.copy(pulseAlpha), RoundedCornerShape((r + 8).dp))
        )
    }
}

@Composable
private fun HintActionPanel(
    icon: String, title: String, message: String, action: String,
    step: Int, total: Int, nextLabel: String, doneLabel: String,
    pointerEdgeIsTop: Boolean, pointerX: Float,
    onNext: () -> Unit, onDismiss: () -> Unit
) {
    val colors = SortydColors.current
    val isFinal = step == total

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(22.dp))
                .background(colors.bg1.copy(0.98f))
                .border(1.dp, colors.accent.copy(0.18f), RoundedCornerShape(22.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                // Icon Badge
                Box(
                    Modifier.size(46.dp).clip(CircleShape).background(
                        Brush.linearGradient(listOf(colors.accent.copy(0.18f), colors.coral.copy(0.12f)))
                    ).border(1.dp, colors.accent.copy(0.24f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(icon, fontSize = 17.sp)
                }

                // Text Content
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(action.uppercase(), style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Black, letterSpacing = 1.1.sp), color = colors.accent)
                        Text("$step/$total", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.Black, letterSpacing = 1.1.sp), color = colors.accent)
                    }
                    Text(title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold), color = colors.text0)
                    Text(message, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold, lineHeight = 18.sp), color = colors.text1)
                }
            }

            // Bottom Row
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    for (i in 1..total) {
                        Box(
                            Modifier.size(if (i == step) 24.dp else 7.dp, 7.dp).clip(CircleShape).background(if (i == step) colors.accent else colors.borderSubtle.copy(0.5f))
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                Button(
                    onClick = if (isFinal) onDismiss else onNext,
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent),
                    contentPadding = PaddingValues(horizontal = 15.dp, vertical = 10.dp),
                    shape = CircleShape
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(if (isFinal) doneLabel else nextLabel, style = MaterialTheme.typography.labelSmall.copy(fontSize = 13.sp, fontWeight = FontWeight.Black), color = colors.bg0)
                        Icon(if (isFinal) Icons.Default.Check else Icons.AutoMirrored.Filled.ArrowForward, null, tint = colors.bg0, modifier = Modifier.size(12.dp))
                    }
                }
            }
        }

        // Pointer
        Canvas(Modifier.offset(x = pointerX.dp, y = if (pointerEdgeIsTop) (-12).dp else 12.dp).size(28.dp, 14.dp).align(if (pointerEdgeIsTop) Alignment.TopCenter else Alignment.BottomCenter)) {
            val path = androidx.compose.ui.graphics.Path().apply {
                if (pointerEdgeIsTop) {
                    moveTo(size.width / 2, 0f)
                    lineTo(size.width, size.height)
                    lineTo(0f, size.height)
                } else {
                    moveTo(size.width / 2, size.height)
                    lineTo(0f, 0f)
                    lineTo(size.width, 0f)
                }
                close()
            }
            drawPath(path, colors.bg1.copy(0.98f))
            drawPath(path, colors.accent.copy(0.18f), style = Stroke(1.dp.toPx()))
        }
    }
}

@Preview(name = "Step 0 - Settings", showBackground = true)
@Composable
private fun PreviewFirstListHintOverlayStep0() {
    SortydTheme {
        FirstListHintOverlay(language = "en", step = 0, onNext = {}, onDismiss = {})
    }
}

@Preview(name = "Step 1 - Priority", showBackground = true)
@Composable
private fun PreviewFirstListHintOverlayStep1() {
    SortydTheme {
        FirstListHintOverlay(language = "en", step = 1, onNext = {}, onDismiss = {})
    }
}

@Preview(name = "Step 2 - Add", showBackground = true)
@Composable
private fun PreviewFirstListHintOverlayStep2() {
    SortydTheme {
        FirstListHintOverlay(language = "en", step = 2, onNext = {}, onDismiss = {})
    }
}

@Preview(name = "Step 3 - Review", showBackground = true)
@Composable
private fun PreviewFirstListHintOverlayStep3() {
    SortydTheme {
        FirstListHintOverlay(language = "en", step = 3, onNext = {}, onDismiss = {})
    }
}

@Preview(showBackground = true, name = "Lists Screen Content")
@Composable
private fun PreviewListsScreenContent() {
    SortydTheme {
        ListsScreenContent(
            allLists = PreviewMocks.mockLists,
            activeListId = "list1",
            language = "en",
            onCreateList = { _, _ -> },
            onDeleteList = { _ -> },
            onArchiveList = { _ -> },
            onUnarchiveList = { _ -> },
            onRenameList = { _, _, _ -> },
            onMoveList = { _, _ -> },
            onSetActiveList = { _ -> },
            onNavigateToListDetail = { _ -> },
            onNavigateToAIService = {}
        )
    }
}

@Preview(showBackground = true, name = "Lists Screen Empty")
@Composable
private fun PreviewListsScreenEmpty() {
    SortydTheme {
        ListsScreenContent(
            allLists = emptyList(),
            activeListId = null,
            language = "en",
            onCreateList = { _, _ -> },
            onDeleteList = { _ -> },
            onArchiveList = { _ -> },
            onUnarchiveList = { _ -> },
            onRenameList = { _, _, _ -> },
            onMoveList = { _, _ -> },
            onSetActiveList = { _ -> },
            onNavigateToListDetail = { _ -> },
            onNavigateToAIService = {}
        )
    }
}
