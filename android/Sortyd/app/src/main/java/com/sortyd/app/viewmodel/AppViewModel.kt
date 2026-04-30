package com.sortyd.app.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sortyd.app.ai.AICoach
import com.sortyd.app.data.repository.AppRepository
import com.sortyd.app.health.HealthConnectManager
import com.sortyd.app.model.*
import com.sortyd.app.notifications.NotificationHelper
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.*
import javax.inject.Inject

@HiltViewModel
class AppViewModel @Inject constructor(
    private val repository: AppRepository,
    private val aiCoach: AICoach,
    val healthConnect: HealthConnectManager,
    private val notificationHelper: NotificationHelper
) : ViewModel() {

    private val TAG = "AppViewModel"

    // ── State Flows (granular, like iOS @Published) ───────────────────────────

    private val _lists = MutableStateFlow<List<TaskList>>(emptyList())
    val lists: StateFlow<List<TaskList>> = _lists.asStateFlow()

    private val _activeListId = MutableStateFlow<String?>(null)
    val activeListId: StateFlow<String?> = _activeListId.asStateFlow()

    private val _snapshots = MutableStateFlow<List<DailySnapshot>>(emptyList())
    val snapshots: StateFlow<List<DailySnapshot>> = _snapshots.asStateFlow()

    private val _selectedTab = MutableStateFlow(0)
    val selectedTab: StateFlow<Int> = _selectedTab.asStateFlow()

    private val _dataLoaded = MutableStateFlow(false)
    val dataLoaded: StateFlow<Boolean> = _dataLoaded.asStateFlow()

    private val _appLanguage = MutableStateFlow(AppLanguage.ENGLISH)
    val appLanguage: StateFlow<AppLanguage> = _appLanguage.asStateFlow()

    private val _isDarkTheme = MutableStateFlow(true)
    val isDarkTheme: StateFlow<Boolean> = _isDarkTheme.asStateFlow()

    private val _installDate = MutableStateFlow(System.currentTimeMillis())
    val installDate: StateFlow<Long> = _installDate.asStateFlow()

    // ── AI Results ────────────────────────────────────────────────────────────

    private val _weeklyRecap = MutableStateFlow<WeeklyRecap?>(null)
    val weeklyRecap: StateFlow<WeeklyRecap?> = _weeklyRecap.asStateFlow()

    private val _behaviouralAnalysis = MutableStateFlow<BehaviouralAnalysis?>(null)
    val behaviouralAnalysis: StateFlow<BehaviouralAnalysis?> = _behaviouralAnalysis.asStateFlow()

    private val _isAILoading = MutableStateFlow(false)
    val isAILoading: StateFlow<Boolean> = _isAILoading.asStateFlow()

    private val _starterList = MutableStateFlow<StarterList?>(null)
    val starterList: StateFlow<StarterList?> = _starterList.asStateFlow()

    private val _isGeneratingList = MutableStateFlow(false)
    val isGeneratingList: StateFlow<Boolean> = _isGeneratingList.asStateFlow()

    private val _parsedTask = MutableStateFlow<ParsedTask?>(null)
    val parsedTask: StateFlow<ParsedTask?> = _parsedTask.asStateFlow()

    // ── Derived Computed Properties ───────────────────────────────────────────

    val activeList: StateFlow<TaskList?> = combine(_lists, _activeListId) { lists, id ->
        val regular = lists.filter { !it.isArchived && !it.isTodo }
        // Todo list is NEVER the main active list — only regular lists appear in the hero.
        // Explicit id is honoured only when it points to a regular list; otherwise fall back
        // to the first regular list (or null → "Let's Get Tracking" empty state).
        regular.firstOrNull { it.id == id } ?: regular.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val activeRegularList: StateFlow<TaskList?> = combine(_lists, _activeListId) { lists, id ->
        val live = lists.filter { !it.isArchived && !it.isTodo }
        live.firstOrNull { it.id == id } ?: live.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val todoList: StateFlow<TaskList?> = _lists.map { lists ->
        lists.firstOrNull { it.isTodo && !it.isArchived }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val regularLists: StateFlow<List<TaskList>> = _lists.map { lists ->
        lists.filter { !it.isArchived && !it.isTodo }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    // ── Initialization ────────────────────────────────────────────────────────

    init {
        viewModelScope.launch {
            loadFromDisk()
            observePreferences()
            resetTasksIfNewDay()
            ensureTodoListExists()
            healthConnect.initialize()
            healthConnect.checkPermissions()
            setupHealthAutoComplete()
            notificationHelper.scheduleDailyReset()
        }
    }

    private fun observePreferences() {
        viewModelScope.launch {
            repository.languageFlow.collect { _appLanguage.value = it }
        }
        viewModelScope.launch {
            repository.isDarkThemeFlow.collect { _isDarkTheme.value = it }
        }
        viewModelScope.launch {
            repository.installDateFlow.collect { _installDate.value = it }
        }
    }

    private suspend fun loadFromDisk() {
        val data = repository.load()
        _lists.value = data.lists
        _activeListId.value = data.activeListId
        _snapshots.value = data.snapshots
        _dataLoaded.value = true
    }

    fun reloadFromDisk() {
        viewModelScope.launch { loadFromDisk() }
    }

    fun setTab(tab: Int) { _selectedTab.value = tab }

    // ── Language & Theme ──────────────────────────────────────────────────────

    fun setLanguage(lang: AppLanguage) {
        viewModelScope.launch {
            repository.setLanguage(lang)
            _appLanguage.value = lang
        }
    }

    fun toggleTheme() {
        viewModelScope.launch {
            val newVal = !_isDarkTheme.value
            repository.setDarkTheme(newVal)
            _isDarkTheme.value = newVal
        }
    }

    // ── TODO List Management ──────────────────────────────────────────────────

    private fun ensureTodoListExists() {
        if (_lists.value.none { it.isTodo }) {
            val todoList = TaskList(
                name = "TO DO",
                emoji = "✅",
                isTodo = true
            )
            _lists.value = listOf(todoList) + _lists.value
            save()
        }
    }

    // ── Daily Reset ───────────────────────────────────────────────────────────

    private suspend fun resetTasksIfNewDay() {
        val lastReset = repository.loadLastResetDate()
        val today = startOfToday()
        if (lastReset < today) {
            val yesterday = today - 24 * 60 * 60 * 1000L
            snapshotDay(yesterday)

            val updated = _lists.value.map { list ->
                if (list.isTodo) {
                    list.copy(tasks = emptyList())
                } else {
                    list.copy(tasks = list.tasks.map { it.copy(isCompleted = false) })
                }
            }
            _lists.value = updated

            // Prune snapshots older than 730 days
            val cutoff = System.currentTimeMillis() - 730L * 24 * 60 * 60 * 1000L
            _snapshots.value = _snapshots.value.filter { it.date >= cutoff }

            repository.saveLastResetDate(today)
            save()
        }
    }

    private fun snapshotDay(timestamp: Long) {
        val activeReg = activeRegularList.value ?: return
        val healthVals = healthConnect.healthValues(activeReg.tasks)
        val fraction = activeReg.completionFraction(healthVals)

        upsertSnapshot(
            DailySnapshot(
                date = timestamp,
                listId = activeReg.id,
                completionFraction = fraction,
                completedTaskIds = activeReg.tasks.filter { it.isCompleted }.map { it.id }
            )
        )
    }

    fun updateTodaySnapshot() {
        val activeReg = activeRegularList.value ?: return
        val healthVals = healthConnect.healthValues(activeReg.tasks)
        val fraction = activeReg.completionFraction(healthVals)
        val today = startOfToday()

        upsertSnapshot(
            DailySnapshot(
                date = today,
                listId = activeReg.id,
                completionFraction = fraction,
                completedTaskIds = activeReg.tasks.filter { it.isCompleted }.map { it.id }
            )
        )
    }

    private fun upsertSnapshot(snapshot: DailySnapshot) {
        val existing = _snapshots.value.toMutableList()
        val idx = existing.indexOfFirst {
            it.listId == snapshot.listId && isSameDay(it.date, snapshot.date)
        }
        if (idx >= 0) existing[idx] = snapshot else existing.add(snapshot)
        _snapshots.value = existing
    }

    // ── Task Management ───────────────────────────────────────────────────────

    fun toggleTask(taskId: String, listId: String) {
        updateList(listId) { list ->
            list.copy(tasks = list.tasks.map { task ->
                if (task.id == taskId) task.copy(isCompleted = !task.isCompleted) else task
            })
        }
        updateTodaySnapshot()
    }

    fun addTask(
        listId: String,
        title: String,
        reminderTime: Long? = null,
        reminderIsOneTime: Boolean = false,
        healthType: String? = null,
        healthTarget: Double? = null
    ) {
        val newTask = SortydTask(
            title = title,
            reminderTime = reminderTime,
            reminderIsOneTime = reminderIsOneTime,
            healthType = healthType,
            healthTarget = healthTarget
        )
        updateList(listId) { list ->
            val updated = list.copy(tasks = list.tasks + newTask).recalculateWeights()
            if (newTask.reminderTime != null) {
                notificationHelper.scheduleTaskReminder(newTask, updated)
            }
            updated
        }
    }

    fun deleteTask(taskId: String, listId: String) {
        val task = _lists.value.find { it.id == listId }?.tasks?.find { it.id == taskId }
        task?.let { notificationHelper.cancelTaskReminder(it.id) }
        updateList(listId) { list ->
            list.copy(tasks = list.tasks.filter { it.id != taskId }).recalculateWeights()
        }
    }

    fun updateTaskTitle(taskId: String, listId: String, newTitle: String) {
        updateList(listId) { list ->
            list.copy(tasks = list.tasks.map { task ->
                if (task.id == taskId) task.copy(title = newTitle) else task
            })
        }
    }

    fun setTaskReminder(taskId: String, listId: String, time: Long, isOneTime: Boolean) {
        updateList(listId) { list ->
            val updated = list.copy(tasks = list.tasks.map { task ->
                if (task.id == taskId) task.copy(reminderTime = time, reminderIsOneTime = isOneTime) else task
            })
            val updatedTask = updated.tasks.find { it.id == taskId }
            updatedTask?.let { notificationHelper.scheduleTaskReminder(it, updated) }
            updated
        }
    }

    fun clearTaskReminder(taskId: String, listId: String) {
        notificationHelper.cancelTaskReminder(taskId)
        updateList(listId) { list ->
            list.copy(tasks = list.tasks.map { task ->
                if (task.id == taskId) task.copy(reminderTime = null) else task
            })
        }
    }

    fun moveTasks(listId: String, fromIndex: Int, toIndex: Int) {
        updateList(listId) { list ->
            val tasks = list.tasks.toMutableList()
            val item = tasks.removeAt(fromIndex)
            tasks.add(toIndex, item)
            list.copy(tasks = tasks)
        }
    }

    fun findReminderConflict(hour: Int, minute: Int, listId: String, excludeTaskId: String? = null): ReminderConflictInfo? {
        val list = _lists.value.find { it.id == listId } ?: return null
        val cal = Calendar.getInstance()
        return list.tasks
            .filter { it.id != excludeTaskId && it.reminderTime != null }
            .firstOrNull { task ->
                cal.timeInMillis = task.reminderTime!!
                cal.get(Calendar.HOUR_OF_DAY) == hour && cal.get(Calendar.MINUTE) == minute
            }?.let {
                ReminderConflictInfo(it.title, hour, minute)
            }
    }

    // ── List Management ───────────────────────────────────────────────────────

    fun addList(name: String, emoji: String) {
        val newList = TaskList(name = name, emoji = emoji)
        _lists.value = _lists.value + newList
        _activeListId.value = newList.id
        save()
    }

    fun addListWithTasks(name: String, emoji: String, tasks: List<StarterListTask>) {
        val sortydTasks = tasks.map { t ->
            SortydTask(
                title = t.title,
                healthType = t.healthType.takeIf { it != HealthTaskType.NONE.rawValue },
                healthTarget = t.healthTarget,
                reminderTime = buildReminderTime(t.reminderHour, t.reminderMinute)
            )
        }
        var newList = TaskList(name = name, emoji = emoji, tasks = sortydTasks).recalculateWeights()

        // Schedule reminders
        sortydTasks.forEach { task ->
            if (task.reminderTime != null) {
                notificationHelper.scheduleTaskReminder(task, newList)
            }
        }

        _lists.value = _lists.value + newList
        _activeListId.value = newList.id
        save()
    }

    fun renameList(listId: String, name: String, emoji: String) {
        updateList(listId) { it.copy(name = name, emoji = emoji) }
    }

    fun deleteList(listId: String) {
        _lists.value = _lists.value.filter { it.id != listId }
        if (_activeListId.value == listId) {
            _activeListId.value = _lists.value.firstOrNull { !it.isArchived && !it.isTodo }?.id
        }
        save()
    }

    fun archiveList(listId: String) {
        updateList(listId) { it.copy(isArchived = true) }
        if (_activeListId.value == listId) {
            _activeListId.value = _lists.value.firstOrNull { !it.isArchived && !it.isTodo }?.id
        }
    }

    fun restoreList(listId: String) {
        updateList(listId) { it.copy(isArchived = false) }
    }

    fun setActiveList(listId: String) {
        _activeListId.value = listId
        save()
    }

    fun moveList(fromIndex: Int, toIndex: Int) {
        val nonTodo = _lists.value.filter { !it.isTodo }
        val todo = _lists.value.filter { it.isTodo }
        val mutable = nonTodo.toMutableList()
        val item = mutable.removeAt(fromIndex)
        mutable.add(toIndex, item)
        _lists.value = todo + mutable
        save()
    }

    // ── Analytics Helpers ──────────────────────────────────────────────────────

    fun snapshotsForList(listId: String): List<DailySnapshot> =
        _snapshots.value.filter { it.listId == listId }

    fun computeCurrentStreak(listId: String): Int {
        val snaps = snapshotsForList(listId).sortedByDescending { it.date }
        val today = startOfToday()
        var streak = 0
        
        // Check today's snapshot
        val todaySnap = snaps.find { isSameDay(it.date, today) }
        if (todaySnap != null && todaySnap.completionFraction >= 0.8) {
            streak++
        }

        var dayOffset = 1
        while (true) {
            val targetDate = today - dayOffset * 24 * 60 * 60 * 1000L
            val snap = snaps.find { isSameDay(it.date, targetDate) }
            if (snap != null && snap.completionFraction >= 0.8) {
                streak++
                dayOffset++
            } else {
                break
            }
        }
        return streak
    }

    fun computeBestStreak(listId: String): Int {
        val snaps = snapshotsForList(listId).sortedBy { it.date }
        var streak = 0
        var best = 0
        for (snap in snaps) {
            if (snap.completionFraction >= 0.8) { streak++; best = maxOf(best, streak) }
            else streak = 0
        }
        return best
    }

    fun computeTaskStreak(listId: String, taskId: String): Int {
        val snaps = snapshotsForList(listId).sortedByDescending { it.date }
        val today = startOfToday()
        var streak = 0

        val todaySnap = snaps.find { isSameDay(it.date, today) }
        if (todaySnap != null && taskId in todaySnap.completedTaskIds) {
            streak++
        }

        var dayOffset = 1
        while (dayOffset < 365) {
            val targetDate = today - dayOffset * 24 * 60 * 60 * 1000L
            val snap = snaps.find { isSameDay(it.date, targetDate) }
            if (snap != null && taskId in snap.completedTaskIds) {
                streak++
                dayOffset++
            } else {
                break
            }
        }
        return streak
    }

    fun weeklyAverage(listId: String): Double {
        val snaps = snapshotsForList(listId).takeLast(7)
        return if (snaps.isEmpty()) 0.0 else snaps.map { it.completionFraction }.average()
    }

    fun gradeFor(avg: Double): String = when ((avg * 100).toInt()) {
        in 90..100 -> "A"
        in 80..89 -> "A-"
        in 75..79 -> "B+"
        in 70..74 -> "B"
        in 65..69 -> "B-"
        in 60..64 -> "C+"
        in 50..59 -> "C"
        else -> "D"
    }

    // ── AI Functions ──────────────────────────────────────────────────────────

    fun loadAIInsights() {
        viewModelScope.launch {
            _isAILoading.value = true
            try {
                _weeklyRecap.value = aiCoach.generateWeeklyRecap(
                    _lists.value, _snapshots.value, _appLanguage.value
                )
                _behaviouralAnalysis.value = aiCoach.analyseBehaviouralPillars(
                    _lists.value, _snapshots.value, _appLanguage.value
                )
            } catch (e: Exception) {
                Log.e(TAG, "AI insights failed", e)
            } finally {
                _isAILoading.value = false
            }
        }
    }

    fun generateStarterList(goal: String) {
        viewModelScope.launch {
            _isGeneratingList.value = true
            try {
                _starterList.value = aiCoach.generateStarterList(goal, _appLanguage.value)
            } catch (e: Exception) {
                Log.e(TAG, "Starter list failed", e)
            } finally {
                _isGeneratingList.value = false
            }
        }
    }

    fun clearStarterList() { _starterList.value = null }

    fun parseTask(input: String) {
        viewModelScope.launch {
            try {
                _parsedTask.value = aiCoach.parseNaturalLanguageTask(input, _appLanguage.value)
            } catch (e: Exception) {
                _parsedTask.value = ParsedTask(title = input, hasReminder = false, reminderHour = null, reminderMinute = null)
            }
        }
    }

    fun clearParsedTask() { _parsedTask.value = null }

    // ── Health Auto-Complete ──────────────────────────────────────────────────

    private fun setupHealthAutoComplete() {
        healthConnect.onHealthUpdate = {
            viewModelScope.launch(Dispatchers.Main) {
                val list = activeRegularList.value ?: return@launch
                val healthVals = healthConnect.healthValues(list.tasks)
                var changed = false

                val updatedTasks = list.tasks.map { task ->
                    if (task.isHealthTask && !task.isCompleted && !task.manuallyCompleted) {
                        val progress = healthVals[task.id] ?: 0.0
                        if (progress >= 1.0) {
                            changed = true
                            task.copy(isCompleted = true)
                        } else task
                    } else task
                }

                if (changed) {
                    updateList(list.id) { it.copy(tasks = updatedTasks) }
                    updateTodaySnapshot()
                }
            }
        }
    }

    fun refreshHealthData() {
        viewModelScope.launch { healthConnect.fetchToday() }
    }

    // ── Settings ──────────────────────────────────────────────────────────────

    fun clearHistory() {
        _snapshots.value = emptyList()
        save()
    }

    // ── Private Helpers ───────────────────────────────────────────────────────

    private fun updateList(listId: String, transform: (TaskList) -> TaskList) {
        _lists.value = _lists.value.map { if (it.id == listId) transform(it) else it }
        save()
    }

    private fun save() {
        repository.save(
            AppData(
                lists = _lists.value,
                activeListId = _activeListId.value,
                snapshots = _snapshots.value
            )
        )
    }

    fun flushToDisk() {
        viewModelScope.launch {
            repository.saveImmediately(
                AppData(
                    lists = _lists.value,
                    activeListId = _activeListId.value,
                    snapshots = _snapshots.value
                )
            )
        }
    }

    private fun startOfToday(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun isSameDay(a: Long, b: Long): Boolean {
        val calA = Calendar.getInstance().apply { timeInMillis = a }
        val calB = Calendar.getInstance().apply { timeInMillis = b }
        return calA.get(Calendar.YEAR) == calB.get(Calendar.YEAR) &&
                calA.get(Calendar.DAY_OF_YEAR) == calB.get(Calendar.DAY_OF_YEAR)
    }

    private fun buildReminderTime(hour: Int?, minute: Int?): Long? {
        hour ?: return null
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute ?: 0)
        cal.set(Calendar.SECOND, 0)
        if (cal.before(Calendar.getInstance())) cal.add(Calendar.DAY_OF_MONTH, 1)
        return cal.timeInMillis
    }
}
