// MARK: - AppViewModel.swift
// Sortyd v4 — Fixed: granular @Published lists, batched moveList, single cold-launch reset

import Foundation
import SwiftUI
import Combine
import FirebaseAnalytics

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published State

    // FIX: appData is now private. External observers use the granular
    // @Published properties below (lists, activeListID, snapshots).
    //
    // Previous code exposed @Published var appData: AppData directly.
    // Because appData is a large struct (lists + snapshots + activeListID),
    // ANY mutation — including moveList, toggleTask, addTask — fired
    // objectWillChange and forced every view subscribed to vm to re-render.
    // During a drag that is 60 re-renders/second of HomeView, AnalyticsView,
    // AICoachView, and ListManagementView simultaneously.
    //
    // Now each property publishes independently, so:
    //   - A drag (list reorder) only re-renders views that observe `lists`.
    //   - A tab switch only re-renders views that observe `selectedTab`.
    //   - HomeView does not re-render when a list is renamed in ListManagementView.
    @Published private(set) var lists: [TaskList] = []
    @Published private(set) var activeListID: UUID?
    @Published private(set) var snapshots: [DailySnapshot] = []
    @Published var weeklyPlan: WeeklyPlan = WeeklyPlan(weekStartDate: WeeklyPlan.currentWeekStart())
    @Published private(set) var cachedBestStreak: Int = 0
    @Published var dailyRecap: DailyRecapData? = nil
    @Published var selectedTab: Int = 0
    @Published var showReviewPrompt = false
    private var reviewPromptExposureRecorded = false
    private let sharedDefaults = UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? UserDefaults.standard

    @Published var appLanguage: AppLanguage = .english {
        didSet {
            sharedDefaults.set(appLanguage.rawValue, forKey: "sortyd_app_language")
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "sortyd_app_language") // fallback
            // Also set AppleLanguages for system-wide effect on next launch
            UserDefaults.standard.set([appLanguage.rawValue], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            sharedDefaults.synchronize()
            
            WatchSessionManager.shared.pushLanguageToWatch(appLanguage.rawValue)
            // Re-trigger computed best streak if language impacts anything
            cachedBestStreak = computeBestStreak()
        }
    }

    func setLanguage(_ lang: AppLanguage) {
        appLanguage = lang
    }

    /// Helper for resolving localized strings manually using the app's selected language.
    /// Used for TextFields, AI Prompts, and arrays where LocalizedStringKey isn't sufficient.
    func localized(_ key: String) -> String {
        AppLocalization.string(key, languageCode: appLanguage.rawValue)
    }
    
    var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = appLanguage.locale
        return cal
    }
    
    func dateFormatter(format: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = appLanguage.locale
        return df
    }

    // Internal source of truth — never directly observed by views.
    private var appData: AppData {
        didSet { if !_skipSync { syncPublished() } }
    }

    /// When true, appData.didSet skips syncPublished so callers
    /// can publish only the properties that actually changed.
    private var _skipSync = false
    private var reminderRefresh: Task<Void, Never>?

    private func refreshNotifications() {
        NotificationManager.shared.updateTaskState(lists: appData.lists)
        reminderRefresh?.cancel()
        reminderRefresh = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self else { return }
            await NotificationManager.shared.resyncTaskReminders(lists: self.appData.lists)
            guard !Task.isCancelled else { return }
            await NotificationManager.shared.scheduleColdTaskNudgeIfPermitted(
                lists: self.appData.lists, snapshots: self.appData.snapshots)
        }
    }

    // Sync all granular @Published properties from appData in one pass.
    // Called inside appData.didSet so views always see a consistent snapshot.
    private func syncPublished() {
        self.lists        = appData.lists
        self.activeListID = appData.activeListID
        self.snapshots    = appData.snapshots
        if let plan = appData.weeklyPlan {
            self.weeklyPlan = plan
        }
        
        cachedBestStreak = computeBestStreak()
        refreshNotifications()
    }

    // MARK: Init

    /// Pull-to-Refresh logic: reloads from disk and refreshes HealthKit.
    func refresh() async {
        // 1. Refresh HealthKit
        HealthKitManager.shared.fetchToday()
        
        // 2. Delay for visual feedback
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        // 3. Reload from persistence
        let loaded = PersistenceManager.shared.load()
        
        // 4. Update UI
        self.appData = loaded
        syncPublished()
        cachedBestStreak = computeBestStreak()
        Analytics.logEvent("manual_refresh", parameters: nil)
    }

    init() {
        var data = PersistenceManager.shared.load()
        for idx in data.lists.indices {
            data.lists[idx].recalculateWeights()
        }
        self.appData = data
        syncPublished()

        // Load language
        let defaults = UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? UserDefaults.standard
        if let langRaw = defaults.string(forKey: "sortyd_app_language") ?? UserDefaults.standard.string(forKey: "sortyd_app_language"),
           let lang = AppLanguage(rawValue: langRaw) {
            self.appLanguage = lang
        }

        ensureTodoListExists()
        ensureWeeklyListExists()
        resetTasksIfNewDay()
        snapshotTodayIfNeeded()
        checkForDailyRecap()
        cachedBestStreak = computeBestStreak()
        WatchSessionManager.shared.onCompletion = { [weak self] message in
            self?.applyWatchCompletion(message)
        }
    }

    // MARK: - Computed

    var todoList: TaskList? { appData.lists.first(where: { $0.isTodo }) }
    var weeklyList: TaskList? { appData.lists.first(where: { $0.isWeekly }) }

    var activeList: TaskList? {
        appData.activeList
    }
    
    func updateWeeklyPlan(_ update: (inout WeeklyPlan) -> Void) {
        var plan = weeklyPlan
        update(&plan)
        plan.mustDoTasks = Array((plan.mustDoTasks + ["", "", ""]).prefix(3))
        plan.antiGoals = Array((plan.antiGoals + ["", ""]).prefix(2))
        plan.recoveryDay = min(max(plan.recoveryDay, 1), 7)
        weeklyPlan = plan
        appData.weeklyPlan = plan
        PersistenceManager.shared.save(appData)
    }

    private func checkForDailyRecap() {
        let defaults = sharedDefaults
        let lastRecap = defaults.object(forKey: "last_recap_date") as? Date ?? Date.distantPast
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastRecap) { return }
        
        // Find yesterday's snapshot for the active regular list only.
        // TO DO and Weekly Planner are planning surfaces, not habit-performance lists.
        guard let activeList = appData.activeRegularList else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        if let snapshot = appData.snapshots.first(where: { 
            $0.listID == activeList.id && calendar.isDate($0.date, inSameDayAs: yesterday)
        }) {
            let pct = snapshot.completionPercentage
            let listName = activeList.name
            
            var msg = ""
            var emoji = ""
            
            switch pct {
            case 100:
                msg = localized("Legendary! You crushed every single goal yesterday. Let's keep that momentum going today!")
                emoji = "🏆"
            case 80...99:
                msg = localized("Strong work yesterday! You were so close to perfection. Today is the day you hit 100%!")
                emoji = "💪"
            case 50...79:
                msg = localized("Good effort! You crossed the halfway mark yesterday. Let's aim even higher today!")
                emoji = "✨"
            case 1...49:
                msg = localized("You made some progress yesterday. Every step counts! Let's build on that today.")
                emoji = "🌱"
            default:
                msg = localized("A fresh start today! Yesterday didn't go as planned, but today is for growth. You've got this.")
                emoji = "🎯"
            }
            
            let dateLabel = dateFormatter(format: "EEEE, MMM d").string(from: yesterday)
            
            self.dailyRecap = DailyRecapData(percentage: pct, message: msg, emoji: emoji, listName: listName, dateLabel: dateLabel)
            defaults.set(Date(), forKey: "last_recap_date")
            defaults.synchronize()
        }
    }
    
    

    // MARK: - Task Actions

    func toggleTask(_ task: SortydTask) {
        resetTasksIfNewDay()
        guard let listIdx = activeListIndex,
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        appData.lists[listIdx].tasks[taskIdx].isCompleted.toggle()
        if appData.lists[listIdx].tasks[taskIdx].isCompleted {
            Analytics.logEvent("task_completed", parameters: nil)
            checkReviewPromptAfterPositiveMoment()
        }
        updateTodaySnapshot()
        PersistenceManager.shared.saveImmediately(appData)
    }

    /// Watch writes are narrow, conditional operations, never whole-store replacement.
    func applyWatchCompletion(_ message: [String: Any]) {
        defer { WatchSessionManager.shared.pushToWatch(appData) }
        guard let operationID = message["operationID"] as? String,
              UUID(uuidString: operationID) != nil else { return }
        var processed = sharedDefaults.stringArray(forKey: "watch_completion_operations") ?? []
        guard !processed.contains(operationID) else { return }
        processed.append(operationID)
        sharedDefaults.set(Array(processed.suffix(1000)), forKey: "watch_completion_operations")
        guard let rawID = message["taskID"] as? String, let id = UUID(uuidString: rawID),
              let completed = message["completed"] as? Bool,
              let expected = message["expectedCompleted"] as? Bool,
              let sentAt = message["sentAt"] as? Date else { return }
        resetTasksIfNewDay()
        guard let li = appData.lists.firstIndex(where: { !$0.isArchived && $0.tasks.contains(where: { $0.id == id }) }),
              let ti = appData.lists[li].tasks.firstIndex(where: { $0.id == id }),
              ReminderPolicy.acceptsCompletion(current: appData.lists[li].tasks[ti].isCompleted,
                  expected: expected, sentAt: sentAt) else { return }
        appData.lists[li].tasks[ti].isCompleted = completed
        appData.lists[li].tasks[ti].manuallyCompleted = completed
        let list = appData.lists[li]
        upsertSnapshot(DailySnapshot(id: UUID(), date: ReminderPolicy.dayStart(Date()),
            listID: list.id, completionFraction: list.completionFraction,
            completedTaskIDs: list.tasks.filter(\.isCompleted).map(\.id)))
        PersistenceManager.shared.saveImmediately(appData)
    }

    private var activeListIndex: Int? {
        guard let id = appData.activeListID else { return appData.lists.isEmpty ? nil : 0 }
        return appData.lists.firstIndex(where: { $0.id == id })
    }

    // MARK: - Auto tick HealthKit
    func setupHealthAutoComplete() {
        HealthKitManager.shared.onHealthUpdate = { [weak self] steps, calories, distance in
            guard let self else { return }
            for listIdx in self.appData.lists.indices {
                for taskIdx in self.appData.lists[listIdx].tasks.indices {
                    let task = self.appData.lists[listIdx].tasks[taskIdx]
                    guard task.isHealthTask,
                          let htStr  = task.healthType,
                          let ht     = HealthTaskType(rawValue: htStr),
                          let target = task.healthTarget,
                          target > 0
                    else { continue }

                    let current: Double
                    switch ht {
                    case .steps:    current = steps
                    case .calories: current = calories
                    case .distance: current = distance
                    case .none:     continue
                    }

                    if current >= target && !task.isCompleted {
                        self.appData.lists[listIdx].tasks[taskIdx].isCompleted = true
                        self.updateTodaySnapshot()
                        self.syncPublished()
                        PersistenceManager.shared.saveImmediately(self.appData)

                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    
    // MARK: - List Management

    private func ensureTodoListExists() {
        guard !appData.lists.contains(where: { $0.isTodo }) else { return }
        let todo = TaskList(name: "TO DO", emoji: "✅", isTodo: true)
        appData.lists.insert(todo, at: 0)
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    private func ensureWeeklyListExists() {
        if let idx = appData.lists.firstIndex(where: { $0.isWeekly || $0.name == "Weekly Planner" }) {
            if !appData.lists[idx].isWeekly {
                appData.lists[idx].isWeekly = true
                appData.lists[idx].emoji = "📅"
                syncPublished()
                PersistenceManager.shared.saveImmediately(appData)
            }
            return
        }
        guard !appData.lists.contains(where: { $0.isWeekly }) else { return }
        let weekly = TaskList(name: "Weekly Planner", emoji: "📅", isWeekly: true)
        appData.lists.append(weekly)
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func addList(name: String, emoji: String) {
        var updated = appData
        let cleanName = name.removingLeadingEmojis()
        let list = TaskList(id: UUID(), name: cleanName, emoji: emoji, tasks: [])
        updated.lists.append(list)
        if updated.activeListID == nil {
            updated.activeListID = list.id
        }
        appData = updated   // single assignment → single syncPublished
        PersistenceManager.shared.saveImmediately(appData)
        Analytics.logEvent("list_created", parameters: nil)
    }

    /// Batch-create a list with multiple tasks in a single mutation.
    /// Used by AI Starter Lists to avoid N separate objectWillChange + save calls.
    /// taskData: array of (title, optional reminderTime) tuples.
    func addListWithTasks(name: String, emoji: String, taskData: [(title: String, reminder: Date?, isOneTime: Bool)]) {
        var updated = appData
        let cleanName = name.removingLeadingEmojis()
        let capitalizedName = cleanName.prefix(1).uppercased() + cleanName.dropFirst()
        var list = TaskList(id: UUID(), name: capitalizedName, emoji: emoji, tasks: [])
        for (title, reminder, isOneTime) in taskData {
            let capitalized = title.prefix(1).uppercased() + title.dropFirst()
            var task = SortydTask(id: UUID(), title: capitalized)
            task.reminderTime      = reminder
            task.reminderIsOneTime = isOneTime

            // Auto-detect health tasks from title keywords
            let detected = HealthTaskType.detect(from: title)
            if detected != .none {
                task.healthType = detected.rawValue
                task.healthTarget = Self.extractNumericTarget(from: title, type: detected)
            }

            list.tasks.append(task)
        }
        list.recalculateWeights()
        updated.lists.append(list)
        updated.activeListID = list.id
        appData = updated

        // Schedule reminders for tasks that have them.
        // FIX: requestPermissionIfNeeded() is called FIRST before any scheduling.
        // Previously addListWithTasks skipped permission and called scheduleReminder
        // directly — iOS silently dropped the request because the app had no
        // authorisation yet. The permission prompt never appeared until the user
        // manually set a reminder a second time via setTaskReminder, which does
        // call requestPermissionIfNeeded. Now both paths request permission first.
        // The Task is wrapped in a small async hop so the sheet/view that triggered
        // this call is fully dismissed before the system alert appears — this
        // prevents iOS from suppressing the alert due to an active presentation.
        let capturedList = appData.lists.first(where: { $0.id == list.id })!
        let tasksNeedingReminders = capturedList.tasks.filter { $0.reminderTime != nil }

        if !tasksNeedingReminders.isEmpty {
            let listCopy = capturedList
            Task {
                // Small delay so any presenting sheet is fully dismissed first,
                // which ensures iOS does not suppress the permission alert.
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
                let granted = await NotificationManager.shared.requestPermissionIfNeeded()
                guard granted else { return }
                for task in tasksNeedingReminders {
                    await NotificationManager.shared.scheduleReminder(for: task, in: listCopy)
                }
            }
        }

        PersistenceManager.shared.saveImmediately(appData)
    }

    func deleteList(at offsets: IndexSet) {
        let removedIDs = offsets.map { appData.lists[$0].id }
        for offset in offsets {
            let taskIDs = appData.lists[offset].tasks.map(\.id)
            NotificationManager.shared.cancelReminders(for: taskIDs)
        }
        Analytics.logEvent("list_deleted", parameters: ["count": offsets.count])
        appData.lists.remove(atOffsets: offsets)
        if removedIDs.contains(appData.activeListID ?? UUID()) {
            appData.activeListID = appData.lists.first(where: { !$0.isArchived })?.id
        }
        PersistenceManager.shared.saveImmediately(appData)
    }

    // MARK: - Archive Management

    func archiveList(_ list: TaskList) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == list.id }) else { return }
        // Cancel all reminders for tasks in the archived list
        let taskIDs = appData.lists[idx].tasks.map(\.id)
        NotificationManager.shared.cancelReminders(for: taskIDs)

        Analytics.logEvent("list_archived", parameters: nil)
        _skipSync = true
        appData.lists[idx].isArchived = true
        // If the archived list was active, switch to the first non-archived list
        if appData.activeListID == list.id {
            appData.activeListID = appData.lists.first(where: { !$0.isArchived })?.id
        }
        _skipSync = false
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func restoreList(_ list: TaskList) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == list.id }) else { return }
        _skipSync = true
        appData.lists[idx].isArchived = false
        // If no active list, make the restored list active
        if appData.activeListID == nil {
            appData.activeListID = list.id
        }
        _skipSync = false
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func permanentlyDeleteList(_ list: TaskList) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == list.id }) else { return }
        let taskIDs = appData.lists[idx].tasks.map(\.id)
        NotificationManager.shared.cancelReminders(for: taskIDs)
        appData.lists.remove(at: idx)
        PersistenceManager.shared.saveImmediately(appData)
    }
    
    // ← ADD HERE
    func clearAllSnapshots() {
        appData.snapshots = []
        cachedBestStreak = 0
        PersistenceManager.shared.saveImmediately(appData)
    }

    func renameList(_ list: TaskList, name: String, emoji: String) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == list.id }) else { return }
        let trimmed = name.removingLeadingEmojis()
        guard !trimmed.isEmpty else { return }
        appData.lists[idx].name  = trimmed
        appData.lists[idx].emoji = emoji
        PersistenceManager.shared.saveImmediately(appData)
    }

    func updateHealthTarget(_ task: SortydTask, in listID: UUID, target: Double?) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        appData.lists[listIdx].tasks[taskIdx].healthTarget = target
        PersistenceManager.shared.saveImmediately(appData, reloadWidget: false)
    }

    func moveList(from source: IndexSet, to destination: Int) {
        // Batch mutations, skip full syncPublished.
        // During drag this fires every frame — only publish lists + activeListID.
        // Skipping snapshots avoids unnecessary objectWillChange for
        // AnalyticsView / AICoachView on every drag frame.
        _skipSync = true
        var updated = appData
        updated.lists.move(fromOffsets: source, toOffset: destination)
        // Top list is always the active list.
        updated.activeListID = updated.lists.first?.id
        appData = updated
        _skipSync = false

        // Targeted publish — only what changed during a move.
        lists = appData.lists
        let newActiveID = appData.activeListID
        if activeListID != newActiveID {
            activeListID = newActiveID
            cachedBestStreak = computeBestStreak()
        }

        PersistenceManager.shared.save(AppData(
            lists: lists,
            activeListID: activeListID,
            snapshots: snapshots,
            weeklyPlan: weeklyPlan
        ))
    }

    func setActiveList(_ list: TaskList) {
        guard !list.isWeekly else {
            if let fallback = appData.activeRegularList ?? appData.lists.first(where: { $0.isTodo && !$0.isArchived }) {
                appData.activeListID = fallback.id
                cachedBestStreak = computeBestStreak()
                PersistenceManager.shared.saveImmediately(appData)
            }
            return
        }
        appData.activeListID = list.id
        cachedBestStreak = computeBestStreak()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "sortyd" else { return }
        
        // Handle sortyd://list/<UUID> and sortyd://lists/<UUID>.
        if (url.host == "list" || url.host == "lists"), let listID = UUID(uuidString: url.lastPathComponent) {
            if let list = lists.first(where: { $0.id == listID && !$0.isWeekly }) {
                setActiveList(list)
                selectedTab = 0 // Switch to Today tab
                Analytics.logEvent("widget_list_opened", parameters: nil)
            }
            return
        }

        switch url.host {
        case "analytics": selectedTab = 2
        case "coach": selectedTab = 3
        case "open", "home", "quick-add": selectedTab = 0
        default: break
        }
    }

    // MARK: - Task Management

    /// Returns the HealthTaskType that already exists in the list if adding
    /// another task of `healthType` would create a duplicate, otherwise nil.
    /// Used by AddTaskSheet / SmartAddTaskSheet to block & surface the conflict
    /// before calling addTask.
    func duplicateHealthType(_ healthType: String?, in listID: UUID) -> HealthTaskType? {
        guard let htStr = healthType,
              let ht = HealthTaskType(rawValue: htStr),
              ht != .none,
              let idx = appData.lists.firstIndex(where: { $0.id == listID })
        else { return nil }
        let alreadyExists = appData.lists[idx].tasks.contains { task in
            task.healthType == htStr
        }
        return alreadyExists ? ht : nil
    }

    struct ReminderConflictInfo {
        let taskTitle: String
        let listName: String?
        let time: Date
    }

    func findReminderConflict(hour: Int, minute: Int, in listID: UUID, excludingTaskID: UUID? = nil,
                              date: Date? = nil, isOneTime: Bool = false) -> ReminderConflictInfo? {
        let cal = Calendar.current
        for list in appData.lists where !list.isArchived {
            for task in list.tasks {
                guard let rt = task.reminderTime else { continue }
                let once = task.reminderIsOneTime || list.isTodo || list.isWeekly
                guard ReminderPolicy.fireDate(reminder: rt, oneTime: once, weekly: list.isWeekly,
                    archived: false, completed: task.isCompleted) != nil else { continue }
                if once, let date, (isOneTime || appData.lists.first(where: { $0.id == listID })?.isTodo == true),
                   !cal.isDate(rt, inSameDayAs: date) { continue }
                if let excludeID = excludingTaskID, task.id == excludeID { continue }
                if cal.component(.hour, from: rt) == hour && cal.component(.minute, from: rt) == minute {
                    return ReminderConflictInfo(
                        taskTitle: task.title,
                        listName: list.id == listID ? nil : list.name,
                        time: rt
                    )
                }
            }
        }
        return nil
    }

    func addTask(to listID: UUID, title: String, reminderTime: Date? = nil,
                 reminderIsOneTime: Bool = false,
                 healthType: String? = nil, healthTarget: Double? = nil) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        // Batch mutations into a single appData write so only one
        // objectWillChange fires with the fully-formed task (including reminder).
        _skipSync = true
        var task = SortydTask(id: UUID(), title: title)
            task.reminderTime      = reminderTime
            task.reminderIsOneTime = reminderIsOneTime || appData.lists[idx].isTodo || appData.lists[idx].isWeekly
            task.healthType        = healthType
            task.healthTarget      = healthTarget
        appData.lists[idx].tasks.append(task)
        appData.lists[idx].recalculateWeights()
        _skipSync = false
        syncPublished()

        if healthType != nil {
            Analytics.logEvent("health_task_added", parameters: ["type": healthType ?? ""])
        }

        if reminderTime != nil {
            let capturedTask = task
            let list = appData.lists[idx]
            // Schedule BEFORE save — notification is registered with the system
            // before the persistence save (which triggers widget reload and can
            // stall the main thread).
            Task {
                await NotificationManager.shared.scheduleReminder(for: capturedTask, in: list)
            }
        }

        PersistenceManager.shared.saveImmediately(appData)
    }
    func createTaskAtTime(title: String, date: Date, durationMinutes: Int? = nil, soundName: String? = nil, hexColor: String? = nil) {
        ensureWeeklyListExists()
        guard let listID = weeklyList?.id else { return }
        
        let newTask = SortydTask(
            title: title,
            reminderTime: date,
            reminderIsOneTime: true,
            soundName: soundName,
            hexColor: hexColor,
            durationMinutes: durationMinutes
        )
        
        addTask(newTask, to: listID)
        
        Task {
            let granted = await NotificationManager.shared.requestPermissionIfNeeded()
            if granted, let list = lists.first(where: { $0.id == listID }) {
                await NotificationManager.shared.scheduleReminder(for: newTask, in: list)
            }
        }
    }


    func addTask(_ task: SortydTask, to listID: UUID) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        _skipSync = true
        appData.lists[idx].tasks.append(task)
        appData.lists[idx].recalculateWeights()
        _skipSync = false
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func deleteTask(_ task: SortydTask, from listID: UUID, undoManager: UndoManager? = nil) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        let snapshot = task
        Analytics.logEvent("task_deleted", parameters: nil)
        NotificationManager.shared.cancelReminder(for: task.id)
        appData.lists[listIdx].tasks.remove(at: taskIdx)
        appData.lists[listIdx].recalculateWeights()
        updateTodaySnapshot()
        PersistenceManager.shared.saveImmediately(appData)
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.insertTask(snapshot, at: taskIdx, in: listID, undoManager: undoManager)
        }
        undoManager?.setActionName("Delete Task")
    }

    func insertTask(_ task: SortydTask, at index: Int, in listID: UUID, undoManager: UndoManager? = nil) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        let safeIndex = min(index, appData.lists[listIdx].tasks.count)
        appData.lists[listIdx].tasks.insert(task, at: safeIndex)
        if task.reminderTime != nil {
            let list = appData.lists[listIdx]
            Task { await NotificationManager.shared.scheduleReminder(for: task, in: list) }
        }
        PersistenceManager.shared.saveImmediately(appData)
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.deleteTask(task, from: listID, undoManager: undoManager)
        }
        undoManager?.setActionName("Add Task")
    }

    func moveTasks(in listID: UUID, from source: IndexSet, to destination: Int, undoManager: UndoManager? = nil) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        let tasksBefore = appData.lists[idx].tasks
        appData.lists[idx].tasks.move(fromOffsets: source, toOffset: destination)
        // Debounced save — task drag fires on every frame, not just on drop.
        PersistenceManager.shared.save(appData)
        undoManager?.registerUndo(withTarget: self) { vm in
            guard let undoIdx = vm.appData.lists.firstIndex(where: { $0.id == listID }) else { return }
            vm.appData.lists[undoIdx].tasks = tasksBefore
            PersistenceManager.shared.save(vm.appData)
            undoManager?.registerUndo(withTarget: vm) { vm2 in
                vm2.moveTasks(in: listID, from: source, to: destination, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Move Task")
    }
    func updateTask(_ taskID: UUID, in listID: UUID, transform: (inout SortydTask) -> Void) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == taskID })
        else { return }
        
        transform(&appData.lists[listIdx].tasks[taskIdx])
        
        let updatedTask = appData.lists[listIdx].tasks[taskIdx]
        let list = appData.lists[listIdx]
        
        if updatedTask.reminderTime != nil {
            Task {
                await NotificationManager.shared.scheduleReminder(for: updatedTask, in: list)
            }
        }
        
        PersistenceManager.shared.saveImmediately(appData)
    }


    func updateTaskTitle(_ task: SortydTask, in listID: UUID, newTitle: String) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        appData.lists[listIdx].tasks[taskIdx].title = newTitle
        PersistenceManager.shared.saveImmediately(appData, reloadWidget: false)

        let updatedTask = appData.lists[listIdx].tasks[taskIdx]
        let list = appData.lists[listIdx]
        if updatedTask.reminderTime != nil {
            Task {
                await NotificationManager.shared.scheduleReminder(for: updatedTask, in: list)
            }
        }
    }

    @discardableResult
    func setTaskReminder(_ task: SortydTask, in listID: UUID, time: Date, isOneTime: Bool = false) async -> Bool {
        let granted = await NotificationManager.shared.requestPermissionIfNeeded()
        guard granted else { return false }

        // Re-lookup indices after the await in case data shifted
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return false }

        // Batch the mutation and force an explicit syncPublished so the
        // @Published lists update fires immediately on the main actor,
        // not deferred across the async boundary.
        // TO DO tasks must always use a one-time trigger — the canvas wipes at 4 AM and
        // a repeating trigger would keep firing on tasks that no longer exist.
        let effectiveOneTime = isOneTime || appData.lists[listIdx].isTodo

        Analytics.logEvent("reminder_set", parameters: nil)
        _skipSync = true
        appData.lists[listIdx].tasks[taskIdx].reminderTime      = time
        appData.lists[listIdx].tasks[taskIdx].reminderIsOneTime = effectiveOneTime
        _skipSync = false
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)

        let updatedTask = appData.lists[listIdx].tasks[taskIdx]
        let list = appData.lists[listIdx]
        await NotificationManager.shared.scheduleReminder(for: updatedTask, in: list)
        return true
    }

    func clearTaskReminder(_ task: SortydTask, in listID: UUID) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        NotificationManager.shared.cancelReminder(for: task.id)
        _skipSync = true
        appData.lists[listIdx].tasks[taskIdx].reminderTime = nil
        _skipSync = false
        syncPublished()
        PersistenceManager.shared.saveImmediately(appData)
    }

    // MARK: - Legacy Cleanup

    func cancelLegacyNotifications() {
        NotificationManager.shared.cancelLegacyTodoResetNotification()
        // Immediately sweep any stale repeating TO DO notifications from before the fix.
        let knownIDs = Set(appData.lists.flatMap { $0.tasks.map(\.id) })
        let liveLists = appData.lists
        Task {
            await NotificationManager.shared.cancelOrphanedNotifications(knownTaskIDs: knownIDs)
            await NotificationManager.shared.resyncTaskReminders(lists: liveLists)
        }
    }

    // MARK: - Daily Reset

    func resetTasksIfNewDay() {
        let calendar = Calendar.current
        let now = Date()

        // Reset boundary is 4 AM. Before 4 AM the boundary is 4 AM the previous day,
        // so tasks remain visible until the true rollover time rather than wiping at midnight.
        var dc = calendar.dateComponents([.year, .month, .day], from: now)
        dc.hour = 4; dc.minute = 0; dc.second = 0
        guard let fourAMToday = calendar.date(from: dc) else { return }
        let resetBoundary = now < fourAMToday
            ? calendar.date(byAdding: .day, value: -1, to: fourAMToday)!
            : fourAMToday

        let lastReset = PersistenceManager.shared.loadLastResetDate()
        guard lastReset < resetBoundary else { return }

        // State belongs to the last active logical day, not automatically yesterday.
        let previousDay = ReminderPolicy.dayStart(lastReset)
        for list in appData.lists where !list.isArchived && !list.isWeekly && lastReset != .distantPast {
            let snap = DailySnapshot(
                id: UUID(),
                date: previousDay,
                listID: list.id,
                completionFraction: list.completionFraction,
                completedTaskIDs: list.tasks.filter(\.isCompleted).map(\.id)
            )
            upsertSnapshot(snap)
        }

        for listIdx in appData.lists.indices {
            if appData.lists[listIdx].isTodo {
                // Cancel all pending reminders before wiping so no stale alerts fire
                let taskIDs = appData.lists[listIdx].tasks.map(\.id)
                NotificationManager.shared.cancelReminders(for: taskIDs)
                appData.lists[listIdx].tasks = []
            } else if !appData.lists[listIdx].isWeekly && !appData.lists[listIdx].isArchived {
                for taskIdx in appData.lists[listIdx].tasks.indices {
                    appData.lists[listIdx].tasks[taskIdx].isCompleted = false
                    appData.lists[listIdx].tasks[taskIdx].manuallyCompleted = false
                }
            }
        }

        // Safe unwrap: subtracting 730 days from a valid date is always possible,
        // but guard against any edge cases (e.g. extreme DST transitions).
        if let cutoff = calendar.date(byAdding: .day, value: -730, to: calendar.startOfDay(for: now)) {
            appData.snapshots = appData.snapshots.filter { $0.date >= cutoff }
        }

        // Sweep any stale TO DO notifications that survived as repeating triggers
        // from builds prior to the one-time-only fix.
        let knownIDs = Set(appData.lists.flatMap { $0.tasks.map(\.id) })
        Task { await NotificationManager.shared.cancelOrphanedNotifications(knownTaskIDs: knownIDs) }

        PersistenceManager.shared.saveImmediately(appData)
        PersistenceManager.shared.saveLastResetDate(now)
        cachedBestStreak = computeBestStreak()
    }

    func updateTodaySnapshot() {
        guard let list = appData.activeList else { return }
        let calendar = Calendar.current
        let today = ReminderPolicy.dayStart(Date())

        let snapshot = DailySnapshot(
            id: UUID(),
            date: today,
            listID: list.id,
            completionFraction: list.completionFraction,
            completedTaskIDs: list.tasks.filter(\.isCompleted).map(\.id)
        )

        if let existingIdx = appData.snapshots.firstIndex(where: {
            $0.listID == list.id && calendar.isDate($0.date, inSameDayAs: today)
        }) {
            appData.snapshots[existingIdx] = snapshot
        } else {
            appData.snapshots.append(snapshot)
        }
        cachedBestStreak = computeBestStreak()
    }

    private func snapshotTodayIfNeeded() {
        guard let list = appData.activeList else { return }
        let calendar = Calendar.current
        let today = ReminderPolicy.dayStart(Date())
        let hasToday = appData.snapshots.contains(where: {
            $0.listID == list.id && calendar.isDate($0.date, inSameDayAs: today)
        })
        if !hasToday { updateTodaySnapshot() }
    }

    func upsertSnapshot(_ snapshot: DailySnapshot) {
        let cal = Calendar.current
        if let idx = appData.snapshots.firstIndex(where: {
            $0.listID == snapshot.listID &&
            cal.isDate($0.date, inSameDayAs: snapshot.date)
        }) {
            appData.snapshots[idx] = snapshot
        } else {
            appData.snapshots.append(snapshot)
        }
        PersistenceManager.shared.save(appData)
    }

    // MARK: - Analytics Helpers

    func snapshotsForActiveList() -> [DailySnapshot] {
        guard let id = appData.activeList?.id else { return [] }
        return appData.snapshots
            .filter { $0.listID == id }
            .sorted { $0.date < $1.date }
    }

    func snapshotsForList(id listID: UUID) -> [DailySnapshot] {
        appData.snapshots
            .filter { $0.listID == listID }
            .sorted { $0.date < $1.date }
    }

    func listForID(_ id: UUID) -> TaskList? {
        lists.first { $0.id == id }
    }

    func completionFraction(for date: Date, listID: UUID) -> Double {
        let calendar = Calendar.current
        return appData.snapshots
            .first(where: { $0.listID == listID && calendar.isDate($0.date, inSameDayAs: date) })?
            .completionFraction ?? 0
    }

    var weeklyAverage: Double {
        let snaps = snapshotsForActiveList()
        let lastSeven = Array(snaps.suffix(7))
        guard !lastSeven.isEmpty else { return 0 }
        return lastSeven.map(\.completionFraction).reduce(0, +) / Double(lastSeven.count)
    }

    private func computeBestStreak() -> Int {
        HistoryPolicy.bestStreak(snapshotsForActiveList().map { ($0.date, $0.completionFraction) })
    }

    /// Cached regex — compiled once at class load; avoids try! and repeated compilation.
    /// Matches both Western Arabic (0-9) and Eastern Arabic (٠-٩) numerals.
    private static let _numericRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\b([0-9٠-٩]+)\\b")

    /// Extract a numeric target from a task title (e.g. "Walk 10,000 steps" → 10000).
    /// Falls back to sensible defaults if no number is found.
    static func extractNumericTarget(from title: String, type: HealthTaskType) -> Double {
        // Clean common thousands separators (comma for EN, dot for ES)
        var cleaned = title.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        
        // Convert Eastern Arabic numerals to Western Arabic for parsing
        let easternToWestern: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
        ]
        let mapped = String(cleaned.map { easternToWestern[$0] ?? $0 })

        guard let pattern = _numericRegex else {
            switch type {
            case .steps:    return 10000
            case .calories: return 500
            case .distance: return 5
            case .none:     return 0
            }
        }
        let matches = pattern.matches(in: mapped, range: NSRange(mapped.startIndex..., in: mapped))
        // Pick the largest number found
        let numbers = matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: mapped) else { return nil }
            return Double(mapped[range])
        }
        if let best = numbers.max() {
            if type == .distance && best > 0 { return best }
            if best >= 50 { return best }
        }
        // Sensible defaults
        switch type {
        case .steps:    return 10000
        case .calories: return 500
        case .distance: return 5
        case .none:     return 0
        }
    }
    // Call on foreground — picks up any changes ToggleTaskIntent wrote to disk.
    func reloadFromDisk() {
        var data = PersistenceManager.shared.load()
        for idx in data.lists.indices {
            data.lists[idx].recalculateWeights()
        }
        appData = data
    }

    // Call on background — flushes debounced saves before iOS suspends.
    func flushToDisk() {
        PersistenceManager.shared.saveImmediately(appData)
    }

    // MARK: - Review Prompt

    /// A review ask belongs after a real win, never on launch.
    func checkReviewPromptAfterPositiveMoment() {
        guard !showReviewPrompt else { return }
        guard ReviewPromptManager.shared.shouldShowPrompt() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            guard !self.showReviewPrompt, ReviewPromptManager.shared.shouldShowPrompt() else { return }
            self.reviewPromptExposureRecorded = false
            showReviewPrompt = true
        }
    }

    func recordReviewPromptDisplayed() {
        guard showReviewPrompt, !reviewPromptExposureRecorded else { return }
        reviewPromptExposureRecorded = true
        ReviewPromptManager.shared.recordShown()
        Analytics.logEvent("review_prompt_shown", parameters: ["trigger": "task_completed"])
    }

    func handleReviewNow() {
        showReviewPrompt = false
        Analytics.logEvent("review_prompt_tapped", parameters: ["destination": "app_store"])
        if let url = ReviewPromptManager.reviewURL {
            UIApplication.shared.open(url) { opened in
                Task { @MainActor in
                    if opened {
                        ReviewPromptManager.shared.recordReviewLinkOpened()
                    }
                    Analytics.logEvent(opened ? "review_link_opened" : "review_link_failed", parameters: nil)
                }
            }
        }
    }

    func handleReviewRemindLater() {
        showReviewPrompt = false
        Analytics.logEvent("review_prompt_deferred", parameters: nil)
    }
}
