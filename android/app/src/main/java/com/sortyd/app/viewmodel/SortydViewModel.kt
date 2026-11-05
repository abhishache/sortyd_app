package com.sortyd.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import java.util.UUID
import com.sortyd.app.data.AICoach
import com.sortyd.app.data.db.SortydDatabase
import com.sortyd.app.data.model.*
import com.sortyd.app.data.preferences.UserPreferences
import com.sortyd.app.data.repository.SortydRepository
import java.util.Calendar
import com.sortyd.app.widget.WidgetManager
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class SortydViewModel(application: Application) : AndroidViewModel(application) {

    private val db = SortydDatabase.getInstance(application)
    private val repo = SortydRepository.getInstance(application)
    private val resetMutex = Mutex()

    // ── State flows ──
    val allLists: StateFlow<List<TaskList>> = repo.allLists
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val activeLists: StateFlow<List<TaskList>> = repo.activeLists
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val allSnapshots: StateFlow<List<DailySnapshot>> = repo.allSnapshots
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val activeListId: StateFlow<String?> = repo.prefs.activeListId
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val isDarkMode: StateFlow<Boolean> = repo.prefs.isDarkMode
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), true)

    val selectedFont: StateFlow<String> = repo.prefs.selectedFont
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "ROUNDED")

    val selectedLanguage: StateFlow<String> = repo.prefs.selectedLanguage
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "en")

    val hasSeenOnboarding: StateFlow<Boolean> = repo.prefs.hasSeenOnboarding
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val installDate: StateFlow<Long> = repo.prefs.installDate
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0L)

    val lastResetDate: StateFlow<Long> = repo.prefs.lastResetDate
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0L)

    // ── Derived: active list ──
    val activeList: StateFlow<TaskList?> = combine(activeLists, activeListId) { lists, id ->
        val visibleLists = lists.filter { !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
        if (id != null) visibleLists.firstOrNull { it.id == id } ?: visibleLists.firstOrNull()
        else visibleLists.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    // ── Health data ──
    private val _healthData = MutableStateFlow(HealthSnapshot())
    val healthData: StateFlow<HealthSnapshot> = _healthData.asStateFlow()

    private val _healthPermissionsGranted = MutableStateFlow(false)
    val healthPermissionsGranted: StateFlow<Boolean> = _healthPermissionsGranted.asStateFlow()

    fun checkHealthPermissions() {
        viewModelScope.launch {
            val manager = com.sortyd.app.services.HealthConnectManager(getApplication())
            val granted = manager.hasPermissions()
            _healthPermissionsGranted.value = granted
            if (granted) {
                updateHealthData(manager.fetchToday())
                com.sortyd.app.services.HealthSyncWorker.schedule(getApplication())
            }
        }
    }

    val healthProgress: StateFlow<Map<String, Double>> = combine(activeList, _healthData) { list, health ->
        if (list == null) return@combine emptyMap()
        val map = mutableMapOf<String, Double>()
        for (task in list.tasks) {
            if (!task.isHealthTask || task.healthTarget == null || task.healthTarget <= 0) continue
            val current = when (task.healthType) {
                HealthTaskType.STEPS.rawValue -> health.steps
                HealthTaskType.CALORIES.rawValue -> health.calories
                HealthTaskType.DISTANCE.rawValue -> health.distanceKm
                HealthTaskType.SCREEN_TIME.rawValue -> health.screenTime
                else -> 0.0
            }
            val progress = if (task.healthType == HealthTaskType.SCREEN_TIME.rawValue) {
                // Inverse logic: 100% if under limit, drops to 0 and goes negative immediately if over
                if (current <= task.healthTarget) 1.0
                else -(current - task.healthTarget) / task.healthTarget
            } else {
                (current / task.healthTarget).coerceIn(0.0, 1.0)
            }
            map[task.id] = progress
        }
        map
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyMap())

    // ── AI Coach state ──
    private val _coachLoading = MutableStateFlow(false)
    val coachLoading: StateFlow<Boolean> = _coachLoading.asStateFlow()

    private val _coachRecap = MutableStateFlow<CoachRecap?>(null)
    val coachRecap: StateFlow<CoachRecap?> = _coachRecap.asStateFlow()

    private val coachCachePrefs = application.getSharedPreferences("sortyd_ai_coach_cache", Application.MODE_PRIVATE)
    private val coachCacheJson = Json { ignoreUnknownKeys = true }

    private val _dailyRecap = MutableStateFlow<DailyRecapData?>(null)
    val dailyRecap: StateFlow<DailyRecapData?> = _dailyRecap.asStateFlow()

    // ── Undo/Redo ──
    private val undoStack = kotlin.collections.ArrayDeque<UndoAction>()
    private val redoStack = kotlin.collections.ArrayDeque<UndoAction>()

    private val _canUndo = MutableStateFlow(false)
    val canUndo: StateFlow<Boolean> = _canUndo.asStateFlow()

    private val _canRedo = MutableStateFlow(false)
    val canRedo: StateFlow<Boolean> = _canRedo.asStateFlow()

    // ── Best streak (all-time, cached) ──
    val cachedBestStreak: StateFlow<Int> = combine(allSnapshots, activeListId) { snaps, id ->
        if (id == null) return@combine 0
        computeBestStreak(id, snaps)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    private fun computeBestStreak(listId: String, snapshots: List<DailySnapshot>): Int {
        val snaps = snapshots.filter { it.listId == listId }.sortedBy { it.date }
        val oneDayMs = 24 * 60 * 60 * 1000L
        var best = 0; var current = 0; var prevDate: Long? = null
        for (snap in snaps) {
            if (prevDate != null && snap.date - prevDate > oneDayMs + oneDayMs / 2) current = 0
            if (snap.completionFraction >= 0.8) { current++; best = maxOf(best, current) } else current = 0
            prevDate = snap.date
        }
        return best
    }

    // ── Deep link navigation ──
    private val _pendingDeepLink = MutableStateFlow<String?>(null)
    val pendingDeepLink: StateFlow<String?> = _pendingDeepLink.asStateFlow()

    fun consumeDeepLink(uri: String?) { _pendingDeepLink.value = uri }
    fun clearPendingDeepLink() { _pendingDeepLink.value = null }

    // ── Streak calculation (current) ──
    fun calculateStreak(listId: String, snapshots: List<DailySnapshot>): Int {
        val listSnaps = snapshots
            .filter { it.listId == listId }
            .sortedByDescending { it.date }
        var streak = 0
        var prevDate: Long? = null
        val oneDayMs = 24 * 60 * 60 * 1000L
        for (snap in listSnaps) {
            if (prevDate != null && prevDate - snap.date > oneDayMs + oneDayMs / 2) break
            if (snap.completionFraction >= 0.8) streak++ else break
            prevDate = snap.date
        }
        return streak
    }

    // ── Init ──
    init {
        viewModelScope.launch {
            repo.prefs.installDate.first().let { date ->
                if (date == 0L) repo.prefs.setInstallDate(System.currentTimeMillis())
            }
            ensureTodoListExists()
            performDailyResetIfNeeded()
            com.sortyd.app.services.ReminderManager.reconcile(getApplication())
            checkForDailyRecap()
            snapshotTodayIfNeeded()
            // Cancel any previously-scheduled 4 AM TO DO reset notification (feature removed)
            com.sortyd.app.services.ReminderManager.cancelTodoResetNotification(getApplication())

            viewModelScope.launch {
                combine(activeList, repo.allSnapshots) { list, snaps -> list to snaps }
                    .collect { (list, snaps) ->
                        if (list != null) {
                            val snapshotsMap = snaps
                                .filter { it.listId == list.id }
                                .associate { it.date.toString() to it.completionFraction }
                            WidgetManager.updateWidget(getApplication(), list, snapshotsMap)
                        }
                    }
            }
            checkHealthPermissions()
        }
    }

    fun refresh() {
        viewModelScope.launch {
            performDailyResetIfNeeded()
            checkForDailyRecap()
            checkHealthPermissions()
        }
    }

    private suspend fun ensureTodoListExists() {
        val lists = repo.activeLists.first()
        if (!lists.any { it.isTodo }) createTodoList()
    }

    private suspend fun snapshotTodayIfNeeded() {
        val list = activeList.filterNotNull().first()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val todayStart = com.sortyd.app.services.ReminderPolicy.dayStart(System.currentTimeMillis())
        if (repo.getSnapshotForDate(list.id, todayStart) == null) {
            saveCurrentSnapshotForList(list)
        }
    }

    // ── Actions ──
    fun setActiveList(listId: String) {
        viewModelScope.launch { repo.prefs.setActiveListId(listId) }
    }

    fun toggleDarkMode() {
        viewModelScope.launch { repo.prefs.setDarkMode(!isDarkMode.value) }
    }

    fun setLanguage(code: String) {
        viewModelScope.launch { repo.prefs.setSelectedLanguage(code) }
    }

    fun setOnboardingSeen() {
        viewModelScope.launch { repo.prefs.setHasSeenOnboarding(true) }
    }

    fun createList(name: String, emoji: String, setActive: Boolean = true): String {
        val id = UUID.randomUUID().toString()
        viewModelScope.launch {
            repo.createListWithId(id, name, emoji)
            if (setActive) repo.prefs.setActiveListId(id)
        }
        return id
    }

    suspend fun createListSuspend(name: String, emoji: String, setActive: Boolean = true): String {
        val id = UUID.randomUUID().toString()
        repo.createListWithId(id, name, emoji)
        if (setActive) repo.prefs.setActiveListId(id)
        return id
    }

    fun createTodoList(): String {
        val id = UUID.randomUUID().toString()
        viewModelScope.launch { repo.createListWithId(id, "TO DO", "✅", isTodo = true) }
        return id
    }

    fun renameList(listId: String, name: String, emoji: String) {
        viewModelScope.launch { repo.renameList(listId, name, emoji) }
    }

    fun archiveList(listId: String) {
        viewModelScope.launch { repo.archiveList(listId) }
    }

    fun unarchiveList(listId: String) {
        viewModelScope.launch { repo.unarchiveList(listId) }
    }

    fun deleteList(listId: String) {
        viewModelScope.launch { repo.deleteList(listId) }
    }

    /** Permanently deletes an archived list and cancels all its reminders. */
    fun permanentlyDeleteList(listId: String) {
        viewModelScope.launch {
            val list = allLists.value.find { it.id == listId }
            list?.tasks?.forEach { task ->
                if (task.reminderTime != null) {
                    com.sortyd.app.services.ReminderManager.cancelReminder(getApplication(), task.id)
                }
            }
            repo.permanentlyDeleteList(listId)
        }
    }

    fun moveList(from: Int, to: Int) {
        viewModelScope.launch {
            val currentLists = activeLists.value.toMutableList()
            if (from !in currentLists.indices || to !in currentLists.indices) return@launch
            val item = currentLists.removeAt(from)
            currentLists.add(to, item)
            repo.updateListSortOrders(currentLists.map { it.id })
        }
    }

    fun addTask(
        listId: String,
        title: String,
        reminderTime: Long? = null,
        reminderIsOneTime: Boolean = false,
        notificationLeadMinutes: Int = 0,
        durationMinutes: Int? = null,
        healthType: String? = null,
        healthTarget: Double? = null,
    ) {
        viewModelScope.launch {
            val task = repo.addTask(
                listId,
                title,
                reminderTime,
                reminderIsOneTime,
                notificationLeadMinutes,
                durationMinutes,
                healthType,
                healthTarget,
            )
            if (reminderTime != null) {
                com.sortyd.app.services.ReminderManager.reconcile(getApplication())
                val hasShownRem = repo.prefs.hasShownReminderNotification.first()
                if (!hasShownRem) {
                    repo.prefs.setHasShownReminderNotification(true)
                    android.widget.Toast.makeText(
                        getApplication(),
                        com.sortyd.app.ui.localization.SortydStrings.t(selectedLanguage.value, "Reminders are now active for your tasks."),
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
            }
            if (healthType != null) {
                val healthManager = com.sortyd.app.services.HealthConnectManager(getApplication())
                if (healthManager.hasPermissions()) {
                    updateHealthData(healthManager.fetchToday())
                    com.sortyd.app.services.HealthSyncWorker.schedule(getApplication())
                    val hasShownHealth = repo.prefs.hasShownHealthNotification.first()
                    if (!hasShownHealth) {
                        repo.prefs.setHasShownHealthNotification(true)
                        android.widget.Toast.makeText(
                            getApplication(),
                            com.sortyd.app.ui.localization.SortydStrings.t(selectedLanguage.value, "Health metrics are now being tracked in the background."),
                            android.widget.Toast.LENGTH_LONG
                        ).show()
                    }
                }
            }
            pushUndo(UndoAction.AddTask(task))
        }
    }

    fun updateTask(
        taskId: String,
        listId: String,
        newTitle: String,
        newHealthType: String?,
        newHealthTarget: Double?,
        newReminderTime: Long?
    ) {
        viewModelScope.launch {
            val list = activeLists.value.find { it.id == listId } ?: allLists.value.find { it.id == listId }
            val task = list?.tasks?.find { it.id == taskId } ?: return@launch
            val updatedTask = task.copy(
                title = newTitle, healthType = newHealthType,
                healthTarget = newHealthTarget, reminderTime = newReminderTime
            )
            repo.updateTask(updatedTask)
            if (newReminderTime != null) {
                com.sortyd.app.services.ReminderManager.reconcile(getApplication())
            } else if (task.reminderTime != null) {
                com.sortyd.app.services.ReminderManager.cancelReminder(getApplication(), task.id)
            }
            if (newHealthType != null && newHealthType != task.healthType) {
                val healthManager = com.sortyd.app.services.HealthConnectManager(getApplication())
                if (healthManager.hasPermissions()) {
                    updateHealthData(healthManager.fetchToday())
                }
            }
        }
    }

    fun addTasks(listId: String, titles: List<String>) {
        viewModelScope.launch { repo.addTasks(listId, titles) }
    }

    fun toggleTask(taskId: String, listId: String) {
        viewModelScope.launch {
            val list = activeLists.value.find { it.id == listId }
                ?: allLists.value.find { it.id == listId }
            val task = list?.tasks?.find { it.id == taskId } ?: return@launch
            
            // Prevent manual toggling of Phone Usage tasks as they are strictly automatic/calculated
            if (task.healthType == HealthTaskType.SCREEN_TIME.rawValue) return@launch
            
            val newCompleted = !task.isCompleted
            repo.setTaskCompleted(taskId, newCompleted, true)
            if (newCompleted) repo.prefs.incrementTaskCompletionCount()
            val updatedList = list.copy(tasks = list.tasks.map {
                if (it.id == taskId) it.copy(isCompleted = newCompleted) else it
            })
            saveCurrentSnapshotForList(updatedList)
            pushUndo(UndoAction.ToggleTask(taskId, listId, task.isCompleted))
        }
    }

    fun deleteTask(taskId: String, listId: String) {
        viewModelScope.launch {
            val list = allLists.value.find { it.id == listId }
            val task = list?.tasks?.find { it.id == taskId } ?: return@launch
            val index = list.tasks.indexOf(task)
            repo.deleteTask(taskId, listId)
            pushUndo(UndoAction.DeleteTask(task, index))
        }
    }

    fun updateTask(task: SortydTask) {
        viewModelScope.launch { repo.updateTask(task) }
    }

    fun reorderTasks(listId: String, orderedTaskIds: List<String>) {
        viewModelScope.launch { repo.reorderTasks(listId, orderedTaskIds) }
    }

    // ── Duplicate health-type check ──
    /** Returns the conflicting HealthTaskType if `healthType` already exists in the list, else null. */
    fun duplicateHealthType(healthType: String?, listId: String): HealthTaskType? {
        val ht = HealthTaskType.fromRawValue(healthType) ?: return null
        val list = allLists.value.find { it.id == listId } ?: return null
        return if (list.tasks.any { it.healthType == healthType }) ht else null
    }

    // ── Reminder conflict detection ──
    fun findReminderConflict(
        hour: Int, minute: Int,
        inListId: String,
        excludingTaskId: String? = null
    ): ReminderConflictInfo? {
        for (list in allLists.value.filter { !it.isArchived }) {
            for (task in list.tasks) {
                if (task.id == excludingTaskId) continue
                val rt = task.reminderTime ?: continue
                if (com.sortyd.app.services.ReminderPolicy.fireTime(rt,
                    task.reminderIsOneTime || list.isTodo || task.notificationLeadMinutes > 0,
                    task.notificationLeadMinutes, completed = task.isCompleted) == null) continue
                val cal = Calendar.getInstance().apply { timeInMillis = rt }
                if (cal.get(Calendar.HOUR_OF_DAY) == hour && cal.get(Calendar.MINUTE) == minute) {
                    return ReminderConflictInfo(
                        taskTitle = task.title,
                        listName = if (list.id == inListId) null else list.name,
                        timeMs = rt
                    )
                }
            }
        }
        return null
    }

    // ── Snapshots ──
    fun getSnapshotsForList(listId: String): Flow<List<DailySnapshot>> =
        repo.getSnapshotsForList(listId)

    fun clearAllSnapshots() {
        viewModelScope.launch { repo.clearAllSnapshots() }
    }

    private suspend fun saveCurrentSnapshot(listId: String) {
        val list = allLists.value.find { it.id == listId } ?: return
        saveCurrentSnapshotForList(list)
    }

    private suspend fun saveCurrentSnapshotForList(list: TaskList) {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val todayStart = com.sortyd.app.services.ReminderPolicy.dayStart(System.currentTimeMillis())
        val fraction = list.completionFraction(healthProgress.value)
        val completedIds = list.tasks.filter { it.isCompleted }.map { it.id }
        repo.saveSnapshot(DailySnapshot(
            date = todayStart, listId = list.id,
            completionFraction = fraction, completedTaskIds = completedIds,
        ))
    }

    // ── Daily Reset ──
    private suspend fun performDailyResetIfNeeded() = resetMutex.withLock {
        val lastReset = repo.prefs.lastResetDate.first()
        val cal = Calendar.getInstance().apply {
            if (get(Calendar.HOUR_OF_DAY) < 4) add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 4); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val resetTime = cal.timeInMillis
        if (lastReset < resetTime && System.currentTimeMillis() >= resetTime) {
            repo.allLists.first().forEach { list ->
                if (!list.isArchived) {
                    if (lastReset > 0L && !list.isTodo) {
                        repo.saveSnapshot(DailySnapshot(
                            date = com.sortyd.app.services.ReminderPolicy.dayStart(lastReset),
                            listId = list.id, completionFraction = list.completionFraction,
                            completedTaskIds = list.tasks.filter { it.isCompleted }.map { it.id },
                        ))
                    }
                    if (list.isTodo) {
                        repo.getListWithTasks(list.id).first()?.tasks?.forEach { task ->
                            if (task.reminderTime != null) {
                                com.sortyd.app.services.ReminderManager.cancelReminder(getApplication(), task.id)
                            }
                            repo.deleteTask(task.id)
                        }
                    } else {
                        repo.resetTasksForList(list.id)
                    }
                }
            }
            // Prune snapshots older than 2 years
            val cutoff = System.currentTimeMillis() - 730L * 24 * 60 * 60 * 1000
            repo.pruneOldSnapshots(cutoff)
            repo.prefs.setLastResetDate(System.currentTimeMillis())
            com.sortyd.app.services.ReminderManager.scheduleCoachSummary(getApplication())
        }
    }

    // ── Health ──
    fun updateHealthData(snapshot: HealthSnapshot) {
        _healthData.value = snapshot
        viewModelScope.launch {
            val list = activeList.value ?: return@launch
            for (task in list.tasks) {
                if (!task.isHealthTask || task.isCompleted) continue
                val target = task.healthTarget ?: continue
                val current = when (task.healthType) {
                    HealthTaskType.STEPS.rawValue -> snapshot.steps
                    HealthTaskType.CALORIES.rawValue -> snapshot.calories
                    HealthTaskType.DISTANCE.rawValue -> snapshot.distanceKm
                    HealthTaskType.SCREEN_TIME.rawValue -> snapshot.screenTime
                    else -> 0.0
                }
                if (task.healthType == HealthTaskType.SCREEN_TIME.rawValue) continue
                
                if (current >= target) repo.setTaskCompleted(task.id, true, false)
            }
        }
    }

    private fun checkForDailyRecap() {
        viewModelScope.launch {
            val lastRecap = repo.prefs.lastRecapDate.first()
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            val todayStart = cal.timeInMillis
            
            // Only show once per day
            if (lastRecap >= todayStart) return@launch
            
            // Get yesterday's snapshot for the active regular list only.
            // TO DO is a planning surface, not a habit-performance list.
            cal.add(Calendar.DAY_OF_YEAR, -1)
            val yesterdayStart = cal.timeInMillis
            
            val selectedListId = repo.prefs.activeListId.first()
            val regularLists = allLists.value.filter { !it.isArchived && !it.isTodo && !it.cleanName.equals("Weekly Planner", ignoreCase = true) }
            val recapList = regularLists.firstOrNull { it.id == selectedListId }
                ?: regularLists.firstOrNull()
                ?: return@launch
            val snapshot = repo.getSnapshotForDate(recapList.id, yesterdayStart)
            
            if (snapshot != null) {
                val pct = snapshot.completionPercentage
                val listName = recapList.name
                
                val (msg, emoji) = when {
                    pct == 100 -> "Legendary! You crushed every single goal yesterday. Let's keep that momentum going today!" to "🏆"
                    pct >= 80 -> "Strong work yesterday! You were so close to perfection. Today is the day you hit 100%!" to "💪"
                    pct >= 50 -> "Good effort! You crossed the halfway mark yesterday. Let's aim even higher today!" to "✨"
                    pct > 0 -> "You made some progress yesterday. Every step counts! Let's build on that today." to "🌱"
                    else -> "A fresh start today! Yesterday didn't go as planned, but today is for growth. You've got this." to "🎯"
                }
                val localizedMsg = com.sortyd.app.ui.localization.SortydStrings.t(selectedLanguage.value, msg)
                
                val dateLabel = java.text.SimpleDateFormat("EEEE, MMM d", java.util.Locale.getDefault()).format(java.util.Date(yesterdayStart))
                
                _dailyRecap.value = DailyRecapData(pct, localizedMsg, emoji, listName, dateLabel)
                repo.prefs.setLastRecapDate(todayStart)
            }
        }
    }

    fun dismissDailyRecap() {
        _dailyRecap.value = null
    }

    // ── Undo/Redo ──
    private fun pushUndo(action: UndoAction) {
        undoStack.addLast(action)
        if (undoStack.size > 50) undoStack.removeFirst()
        redoStack.clear()
        _canUndo.value = undoStack.isNotEmpty()
        _canRedo.value = false
    }

    fun undo() {
        val action = undoStack.removeLastOrNull() ?: return
        redoStack.addLast(action)
        _canUndo.value = undoStack.isNotEmpty()
        _canRedo.value = redoStack.isNotEmpty()
        viewModelScope.launch {
            when (action) {
                is UndoAction.ToggleTask -> repo.setTaskCompleted(action.taskId, action.wasCompleted)
                is UndoAction.AddTask -> repo.deleteTask(action.task.id, action.task.listId)
                is UndoAction.DeleteTask -> repo.restoreTask(action.task)
                is UndoAction.ReorderTasks -> repo.reorderTasks(action.listId, action.previousOrder)
                is UndoAction.EditTask -> repo.updateTask(action.previousTask)
            }
        }
    }

    fun redo() {
        val action = redoStack.removeLastOrNull() ?: return
        undoStack.addLast(action)
        _canUndo.value = undoStack.isNotEmpty()
        _canRedo.value = redoStack.isNotEmpty()
        viewModelScope.launch {
            when (action) {
                is UndoAction.ToggleTask -> repo.setTaskCompleted(action.taskId, !action.wasCompleted)
                is UndoAction.AddTask -> repo.restoreTask(action.task)
                is UndoAction.DeleteTask -> repo.deleteTask(action.task.id, action.task.listId)
                is UndoAction.ReorderTasks -> { /* current order is already applied */ }
                is UndoAction.EditTask -> { /* re-apply edit */ }
            }
        }
    }

    // ── AI Coach (live) ──
    fun refreshCoach(listId: String) {
        val language = selectedLanguage.value
        loadCachedCoachRecap(listId, language)?.let { cached ->
            _coachRecap.value = cached
            _coachLoading.value = false
            return
        }
        viewModelScope.launch {
            _coachLoading.value = true
            val list = allLists.value.find { it.id == listId }
            val snapshots = allSnapshots.value.filter { it.listId == listId }
            val result = if (list != null && !list.isArchived && !list.isTodo) {
                AICoach.generateBehaviouralAnalysis(
                    tasks = list.tasks,
                    snapshots = snapshots,
                    listName = list.name,
                    languageCode = selectedLanguage.value
                )
            } else null
            if (result != null) {
                _coachRecap.value = CoachRecap(
                    grade = result.grade,
                    headline = result.headline,
                    reason = result.reason,
                    pillars = result.pillars.map {
                        Pillar(it.name, it.score, it.status, it.emoji, it.advice, it.relatedTasks)
                    },
                    overallInsight = result.overallInsight,
                    skippedTasks = result.skippedTasks,
                )
                saveCoachRecap(listId, language, _coachRecap.value!!)
            } else {
                _coachRecap.value = CoachRecap(
                    grade = "—",
                    headline = com.sortyd.app.ui.localization.SortydStrings.t(selectedLanguage.value, "Couldn't load analysis"),
                    reason = com.sortyd.app.ui.localization.SortydStrings.t(selectedLanguage.value, "Check your connection and try again."),
                    pillars = emptyList(),
                    overallInsight = "",
                    skippedTasks = emptyList(),
                )
            }
            _coachLoading.value = false
        }
    }

    private fun loadCachedCoachRecap(listId: String, language: String): CoachRecap? {
        val prefix = "coach.$listId"
        if (coachCachePrefs.getLong("$prefix.day", -1L) != currentDayStart() ||
            coachCachePrefs.getString("$prefix.language", null) != language) return null
        val raw = coachCachePrefs.getString("$prefix.data", null) ?: return null
        return runCatching { coachCacheJson.decodeFromString<CoachRecap>(raw) }.getOrNull()
    }

    private fun saveCoachRecap(listId: String, language: String, recap: CoachRecap) {
        val prefix = "coach.$listId"
        coachCachePrefs.edit()
            .putLong("$prefix.day", currentDayStart())
            .putString("$prefix.language", language)
            .putString("$prefix.data", coachCacheJson.encodeToString(recap))
            .apply()
    }

    private fun currentDayStart(): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    companion object {
        /**
         * Extracts a numeric target from a task title.
         * "Walk 10,000 steps" → 10000; "جري ٥ كم" → 5; falls back to defaultTarget.
         * Mirrors iOS AppViewModel.extractNumericTarget(from:type:).
         */
        fun extractNumericTarget(from: String, type: HealthTaskType): Double {
            var cleaned = from.replace(",", "").replace(".", "")
            val eastern = mapOf(
                '٠' to '0', '١' to '1', '٢' to '2', '٣' to '3', '٤' to '4',
                '٥' to '5', '٦' to '6', '٧' to '7', '٨' to '8', '٩' to '9'
            )
            cleaned = String(cleaned.map { eastern[it] ?: it }.toCharArray())
            val numbers = Regex("""\b([0-9]+)\b""").findAll(cleaned)
                .mapNotNull { it.groupValues[1].toDoubleOrNull() }
                .toList()
            val best = numbers.maxOrNull()
            if (best != null) {
                if (type == HealthTaskType.DISTANCE && best > 0) return best
                if (best >= 50) return best
            }
            return HealthTaskType.defaultTarget(type)
        }
    }
}

// ── Reminder conflict model ──
data class ReminderConflictInfo(
    val taskTitle: String,
    val listName: String?,
    val timeMs: Long,
)

// ── AI Coach data models ──
@Serializable
data class CoachRecap(
    val grade: String = "",
    val headline: String = "",
    val reason: String = "",
    val pillars: List<Pillar> = emptyList(),
    val overallInsight: String = "",
    val skippedTasks: List<String> = emptyList(),
)

@Serializable
data class Pillar(
    val name: String,
    val score: Int,
    val status: String,
    val emoji: String,
    val advice: List<String> = emptyList(),
    val relatedTasks: List<String> = emptyList(),
)
