// MARK: - PersistenceManager.swift
// Sortyd v4 — Fixed: ioQueue debounce, thread-safe saves, debounced widget reload

import Foundation
import WidgetKit

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let suiteName = "group.com.sortyd.sortyd"
    private let dataKey   = "sortyd_app_data_v3"
    private let widgetKey = "sortyd_widget_data"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    // Serial background queue for all disk I/O.
    private let ioQueue = DispatchQueue(label: "com.sortyd.persistence", qos: .utility)

    private var saveWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.4

    // Separate debounce for Watch push — only the settled state after a drag is sent.
    private var watchWorkItem: DispatchWorkItem?
    private let watchDebounceInterval: TimeInterval = 1.5

    // FIX: Separate debounce for widget reloads. Previously every saveImmediately
    // call (toggleTask, title edits, etc.) scheduled an unguarded
    // WidgetCenter.reloadAllTimelines() — rapid actions queued up dozens of reloads.
    private var widgetWorkItem: DispatchWorkItem?
    private let widgetDebounceInterval: TimeInterval = 1.5

    private init() {}

    // MARK: - Public API

    // FIX: Debounce now dispatches to ioQueue, NOT DispatchQueue.main.
    //
    // Previous code:
    //   DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    //
    // During a list drag onMove fires at 60fps. Each call queued a DispatchWorkItem
    // back onto the main thread. After 0.4 s the debounce fired and ran commitToDisk
    // (JSONEncoder + UserDefaults write) on the main RunLoop — exactly while the
    // UIGestureRecognizer driving the drag was still active. The main thread stalled,
    // the gesture update loop starved, and the row appeared to "stick."
    //
    // Fix: commit always runs on ioQueue, which is never the gesture's RunLoop.
    //
    // FIX: pendingData race removed. Previously pendingData was a stored var written
    // from @MainActor and read inside ioQueue — a data race. Now the AppData value
    // is captured by value into the DispatchWorkItem closure at call time, so no
    // shared mutable state crosses thread boundaries.
    func save(_ data: AppData) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.commitToDisk(data)
        }
        saveWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    // Immediate save — cancels any pending debounced save and writes now,
    // still on the background ioQueue so the main thread is never blocked.
    func saveImmediately(_ data: AppData, reloadWidget: Bool = true) {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        ioQueue.async { [weak self] in
            self?.commitToDisk(data, reloadWidget: reloadWidget)
        }
    }

    func load() -> AppData {
        #if DEBUG
        print("🔍 load called from: \(Thread.callStackSymbols[2])")
        #endif
        guard
            let raw     = defaults.data(forKey: dataKey),
            let decoded = try? JSONDecoder().decode(AppData.self, from: raw)
        else {
            #if DEBUG
            print("❌ load failed — returning empty AppData")
            #endif
            return AppData()
        }
        #if DEBUG
        print("✅ load success")
        #endif
        return decoded
    }

    func reset() { defaults.removeObject(forKey: dataKey) }

    // MARK: - Daily Reset Date

    private let lastResetKey = "sortyd_last_reset_date"

    func loadLastResetDate() -> Date {
        defaults.object(forKey: lastResetKey) as? Date ?? .distantPast
    }

    func saveLastResetDate(_ date: Date) {
        defaults.set(date, forKey: lastResetKey)
    }

    // MARK: - Private

    // Always runs on ioQueue — never on the main thread.
    private func commitToDisk(_ data: AppData, reloadWidget: Bool = true) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: dataKey)
        scheduleWatchPush(data)
        if reloadWidget { scheduleWidgetReload(data) }
    }

    // Debounce Watch pushes so only the settled state after a drag is sent.
    private func scheduleWatchPush(_ data: AppData) {
        watchWorkItem?.cancel()
        let work = DispatchWorkItem {
            DispatchQueue.main.async {              // ← returns to main thread
                WatchSessionManager.shared.pushToWatch(data)  // JSONEncoder().encode() on main
            }
        }
        watchWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + watchDebounceInterval, execute: work)
    }

    // FIX: Widget snapshot + reload are now debounced together.
    // Previously saveWidgetSnapshot called WidgetCenter.reloadAllTimelines()
    // via an un-debounced DispatchQueue.main.asyncAfter(1.5) — every save
    // (including each task toggle) independently scheduled a reload, so rapid
    // interactions queued dozens of timeline reloads that kept the widget
    // extension alive unnecessarily and caused jitter.
    private func scheduleWidgetReload(_ data: AppData) {
        widgetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            // FIX: Fetch live HealthKit totals on MainActor (HealthKitManager is @MainActor),
            // then write the snapshot and reload. Previously writeWidgetSnapshot never
            // populated caloriesBurned/caloriesGoal/stepCount/stepGoal, so the widget
            // always saw nil for all four fields and fell back to the sparkline.
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hk = HealthKitManager.shared

                // Derive goals from the active list's health tasks.
                let tasks = data.activeList?.tasks ?? []
                var caloriesGoal: Double? = nil
                var stepGoal:     Double? = nil
                for task in tasks where task.isHealthTask {
                    guard let typeStr = task.healthType,
                          let target  = task.healthTarget, target > 0 else { continue }
                    if typeStr == HealthTaskType.calories.rawValue { caloriesGoal = target }
                    if typeStr == HealthTaskType.steps.rawValue    { stepGoal     = target }
                }

                // Only include health values when a goal exists for that metric.
                let caloriesBurned: Double? = caloriesGoal != nil ? hk.todayCalories : nil
                let stepCount:      Double? = stepGoal     != nil ? hk.todaySteps    : nil

                self.writeWidgetSnapshot(
                    data,
                    caloriesBurned: caloriesBurned,
                    caloriesGoal:   caloriesGoal,
                    stepCount:      stepCount,
                    stepGoal:       stepGoal
                )
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        widgetWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + widgetDebounceInterval, execute: work)
    }

    // Runs on main thread (called from MainActor Task above).
    private func writeWidgetSnapshot(
        _ data: AppData,
        caloriesBurned: Double? = nil,
        caloriesGoal:   Double? = nil,
        stepCount:      Double? = nil,
        stepGoal:       Double? = nil
    ) {
        guard let list = data.activeList else { return }

        let snaps = data.snapshots
            .filter { $0.listID == list.id }
            .sorted { $0.date < $1.date }

        var streak = 0, best = 0
        for s in snaps {
            if s.completionFraction >= 0.8 { streak += 1; best = max(best, streak) }
            else { streak = 0 }
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var monthlySnapshots = [String: Double]()
        for snap in snaps {
            monthlySnapshots[df.string(from: snap.date)] = snap.completionFraction
        }

        let widgetData = WidgetData(
            listName:             list.name,
            listEmoji:            list.emoji,
            completionFraction:   list.completionFraction,
            completionPercentage: list.completionPercentage,
            tasksDone:            list.tasks.filter(\.isCompleted).count,
            tasksTotal:           list.tasks.count,
            tasks: list.tasks.map { t in
                WidgetData.WidgetTask(id: t.id, title: t.title,
                                     isCompleted: t.isCompleted, weight: t.weight)
            },
            streakDays:       best,
            monthlySnapshots: monthlySnapshots,
            caloriesBurned:   caloriesBurned,
            caloriesGoal:     caloriesGoal,
            stepCount:        stepCount,
            stepGoal:         stepGoal
        )

        if let encoded = try? JSONEncoder().encode(widgetData) {
            defaults.set(encoded, forKey: widgetKey)
        }
    }
}
