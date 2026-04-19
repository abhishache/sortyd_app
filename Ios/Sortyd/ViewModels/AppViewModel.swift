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
    @Published private(set) var cachedBestStreak: Int = 0
    @Published var selectedTab: Int = 0

    // Internal source of truth — never directly observed by views.
    private var appData: AppData {
        didSet { if !_skipSync { syncPublished() } }
    }

    /// When true, appData.didSet skips syncPublished so callers
    /// can publish only the properties that actually changed.
    private var _skipSync = false

    // Sync all granular @Published properties from appData in one pass.
    // Called inside appData.didSet so views always see a consistent snapshot.
    private func syncPublished() {
        lists        = appData.lists
        activeListID = appData.activeListID
        snapshots    = appData.snapshots
    }

    // MARK: Init

    init() {
        var data = PersistenceManager.shared.load()
        for idx in data.lists.indices {
            data.lists[idx].recalculateWeights()
        }
        self.appData = data
        syncPublished()

        // FIX: resetTasksIfNewDay is NOT called here anymore.
        // It was also called in SortydApp via .onChange(of: scenePhase) { .active },
        // which fires immediately on cold launch — causing a double-call on the
        // same RunLoop tick. On cold launch the scenePhase handler is sufficient.
        // resetTasksIfNewDay is still called from scenePhase in SortydApp.swift.
        snapshotTodayIfNeeded()
        cachedBestStreak = computeBestStreak()
    }

    // MARK: - Computed

    var activeList: TaskList? {
        appData.activeList
    }
    
    

    // MARK: - Task Actions

    func toggleTask(_ task: SortydTask) {
        guard let listIdx = activeListIndex,
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        appData.lists[listIdx].tasks[taskIdx].isCompleted.toggle()
        if appData.lists[listIdx].tasks[taskIdx].isCompleted {
                Analytics.logEvent("task_completed", parameters: [
                    "list_name": appData.lists[listIdx].name
                ])
            }
        updateTodaySnapshot()
        PersistenceManager.shared.saveImmediately(appData)
    }

    private var activeListIndex: Int? {
        guard let id = appData.activeListID else { return appData.lists.isEmpty ? nil : 0 }
        return appData.lists.firstIndex(where: { $0.id == id })
    }

    // MARK: - Auto tick HealthKit
    func setupHealthAutoComplete() {
        HealthKitManager.shared.onHealthUpdate = { [weak self] steps, calories in
            guard let self else { return }
            #if DEBUG
            print("🏃 Health update fired — steps: \(steps), cal: \(calories)") // add this
            #endif
            for listIdx in self.appData.lists.indices {
                for taskIdx in self.appData.lists[listIdx].tasks.indices {
                        let task = self.appData.lists[listIdx].tasks[taskIdx]
                        guard task.isHealthTask,
                              !task.isCompleted,
                              let htStr  = task.healthType,
                              let ht     = HealthTaskType(rawValue: htStr),
                              let target = task.healthTarget,
                              target > 0
                        else { continue }
     
                        let current: Double
                        switch ht {
                        case .steps:    current = steps
                        case .calories: current = calories
                        case .none:     continue
                        }
     
                    if current >= target {
                        self.appData.lists[listIdx].tasks[taskIdx].isCompleted = true
                        self.updateTodaySnapshot()
                        self.syncPublished()  // ← add this line
                        PersistenceManager.shared.saveImmediately(self.appData)

                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                    }
                    }
                }
            }
        }
    
    
    // MARK: - List Management

    func addList(name: String, emoji: String) {
        // FIX: Batch both mutations into a single appData write.
        // Previously, append + activeListID= triggered didSet (and syncPublished)
        // twice per call, causing 2 full re-render passes.
        var updated = appData
        let list = TaskList(id: UUID(), name: name, emoji: emoji, tasks: [])
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
    func addListWithTasks(name: String, emoji: String, taskData: [(String, Date?)]) {
        var updated = appData
        let capitalizedName = name.prefix(1).uppercased() + name.dropFirst()
        var list = TaskList(id: UUID(), name: capitalizedName, emoji: emoji, tasks: [])
        for (title, reminder) in taskData {
            let capitalized = title.prefix(1).uppercased() + title.dropFirst()
            var task = SortydTask(id: UUID(), title: capitalized)
            task.reminderTime = reminder

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

        PersistenceManager.shared.save(appData)
    }

    func setActiveList(_ list: TaskList) {
        appData.activeListID = list.id
        cachedBestStreak = computeBestStreak()
        PersistenceManager.shared.saveImmediately(appData)
    }

    // MARK: - Task Management

    func addTask(to listID: UUID, title: String, reminderTime: Date? = nil,
                 healthType: String? = nil, healthTarget: Double? = nil) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        // Batch mutations into a single appData write so only one
        // objectWillChange fires with the fully-formed task (including reminder).
        _skipSync = true
        var task = SortydTask(id: UUID(), title: title)
            task.reminderTime = reminderTime
            task.healthType   = healthType
            task.healthTarget = healthTarget
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

    func deleteTask(_ task: SortydTask, from listID: UUID) {
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        Analytics.logEvent("task_deleted", parameters: nil)
        NotificationManager.shared.cancelReminder(for: task.id)
        appData.lists[listIdx].tasks.remove(at: taskIdx)
        appData.lists[listIdx].recalculateWeights()
        updateTodaySnapshot()
        PersistenceManager.shared.saveImmediately(appData)
    }

    func moveTasks(in listID: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = appData.lists.firstIndex(where: { $0.id == listID }) else { return }
        appData.lists[idx].tasks.move(fromOffsets: source, toOffset: destination)
        // Debounced save — task drag fires on every frame, not just on drop.
        PersistenceManager.shared.save(appData)
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
    func setTaskReminder(_ task: SortydTask, in listID: UUID, time: Date) async -> Bool {
        let granted = await NotificationManager.shared.requestPermissionIfNeeded()
        guard granted else { return false }

        // Re-lookup indices after the await in case data shifted
        guard let listIdx = appData.lists.firstIndex(where: { $0.id == listID }),
              let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return false }

        // Batch the mutation and force an explicit syncPublished so the
        // @Published lists update fires immediately on the main actor,
        // not deferred across the async boundary.
        Analytics.logEvent("reminder_set", parameters: nil)
        _skipSync = true
        appData.lists[listIdx].tasks[taskIdx].reminderTime = time
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

    // MARK: - Daily Reset

    func resetTasksIfNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = PersistenceManager.shared.loadLastResetDate()

        guard !calendar.isDate(lastReset, inSameDayAs: today) else { return }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        for list in appData.lists {
            let snap = DailySnapshot(
                id: UUID(),
                date: yesterday,
                listID: list.id,
                completionFraction: list.completionFraction,
                completedTaskIDs: list.tasks.filter(\.isCompleted).map(\.id)
            )
            upsertSnapshot(snap)
        }

        for listIdx in appData.lists.indices {
            for taskIdx in appData.lists[listIdx].tasks.indices {
                appData.lists[listIdx].tasks[taskIdx].isCompleted = false
            }
        }
        
        // Safe unwrap: subtracting 730 days from a valid date is always possible,
        // but guard against any edge cases (e.g. extreme DST transitions).
        if let cutoff = calendar.date(byAdding: .day, value: -730, to: today) {
            appData.snapshots = appData.snapshots.filter { $0.date >= cutoff }
        }

        PersistenceManager.shared.saveLastResetDate(today)
        PersistenceManager.shared.saveImmediately(appData)
        cachedBestStreak = computeBestStreak()
    }

    func updateTodaySnapshot() {
        guard let list = appData.activeList else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

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
        let today = calendar.startOfDay(for: Date())
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
        let snaps = snapshotsForActiveList()
        var best = 0, current = 0
        for snap in snaps {
            if snap.completionFraction >= 0.8 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    /// Cached regex — compiled once at class load; avoids try! and repeated compilation.
    private static let _numericRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\b(\\d+)\\b")

    /// Extract a numeric target from a task title (e.g. "Walk 10,000 steps" → 10000).
    /// Falls back to sensible defaults if no number is found.
    static func extractNumericTarget(from title: String, type: HealthTaskType) -> Double {
        let cleaned = title.replacingOccurrences(of: ",", with: "")
        guard let pattern = _numericRegex else {
            switch type {
            case .steps:    return 10000
            case .calories: return 500
            case .none:     return 0
            }
        }
        let matches = pattern.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
        // Pick the largest number found — "Walk 10000 steps in 60 minutes" → 10000
        let numbers = matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: cleaned) else { return nil }
            return Double(cleaned[range])
        }
        if let best = numbers.max(), best >= 50 {
            return best
        }
        // Sensible defaults
        switch type {
        case .steps:    return 10000
        case .calories: return 500
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
}


