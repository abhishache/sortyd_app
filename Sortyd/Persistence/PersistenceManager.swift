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

    private var watchWorkItem: DispatchWorkItem?
    private let watchDebounceInterval: TimeInterval = 1.5

    private var widgetWorkItem: DispatchWorkItem?
    private let widgetDebounceInterval: TimeInterval = 1.5

    private init() {}

    // MARK: - Public API

    func save(_ data: AppData) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.commitToDisk(data)
        }
        saveWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    func saveImmediately(_ data: AppData, reloadWidget: Bool = true) {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        ioQueue.async { [weak self] in
            self?.commitToDisk(data, reloadWidget: reloadWidget)
        }
    }

    func load() -> AppData {
        guard
            let raw     = defaults.data(forKey: dataKey),
            let decoded = try? JSONDecoder().decode(AppData.self, from: raw)
        else {
            return AppData()
        }
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

    private func commitToDisk(_ data: AppData, reloadWidget: Bool = true) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: dataKey)
        scheduleWatchPush(data)
        if reloadWidget { scheduleWidgetReload(data) }
    }

    private func scheduleWatchPush(_ data: AppData) {
        watchWorkItem?.cancel()
        let work = DispatchWorkItem {
            DispatchQueue.main.async {
                WatchSessionManager.shared.pushToWatch(data)
            }
        }
        watchWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + watchDebounceInterval, execute: work)
    }

    private func scheduleWidgetReload(_ data: AppData) {
        widgetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hk = HealthKitManager.shared

                let tasks = data.activeList?.tasks ?? []
                var caloriesGoal: Double? = nil
                var stepGoal:     Double? = nil
                for task in tasks where task.isHealthTask {
                    guard let typeStr = task.healthType,
                          let target  = task.healthTarget, target > 0 else { continue }
                    if typeStr == HealthTaskType.calories.rawValue { caloriesGoal = target }
                    if typeStr == HealthTaskType.steps.rawValue    { stepGoal     = target }
                }

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

        // ── Active list: streak + monthly snapshots ──────────────────────
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

        let (lastCheckedID, prevCals, prevCalGoal, prevSteps, prevStepGoal): (UUID?, Double?, Double?, Double?, Double?) = {
            if let raw = defaults.data(forKey: widgetKey),
               let prev = try? JSONDecoder().decode(WidgetData.self, from: raw) {
                return (prev.lastCheckedTaskID, prev.caloriesBurned, prev.caloriesGoal, prev.stepCount, prev.stepGoal)
            }
            return (nil, nil, nil, nil, nil)
        }()


        // ── Assemble & persist ───────────────────────────────────────────
        let widgetData = WidgetData(
            listName:             list.cleanName,
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
            caloriesBurned:   caloriesBurned ?? prevCals,
            caloriesGoal:     caloriesGoal   ?? prevCalGoal,
            stepCount:        stepCount      ?? prevSteps,
            stepGoal:         stepGoal       ?? prevStepGoal,
            lastCheckedTaskID: lastCheckedID,
            allLists: data.lists.filter { !$0.isArchived }.map { l in
                let listSnaps = data.snapshots.filter { $0.listID == l.id }
                let avg = listSnaps.isEmpty ? 0 : Int((listSnaps.map(\.completionFraction).reduce(0,+) / Double(listSnaps.count) * 100).rounded())
                let grade: String = {
                    switch avg {
                    case 90...100: return "A"
                    case 80..<90:  return "A-"
                    case 75..<80:  return "B+"
                    case 70..<75:  return "B"
                    case 65..<70:  return "B-"
                    case 60..<65:  return "C+"
                    case 50..<60:  return "C"
                    default:       return "D"
                    }
                }()
                return WidgetData.MultiListEntry(
                    id: l.id,
                    name: l.cleanName,
                    emoji: l.emoji,
                    completionFraction: l.completionFraction,
                    grade: grade
                )
            }
        )

        if let encoded = try? JSONEncoder().encode(widgetData) {
            defaults.set(encoded, forKey: widgetKey)
        }
    }
}
