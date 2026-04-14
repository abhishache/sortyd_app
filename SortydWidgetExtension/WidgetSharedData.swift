// MARK: - WidgetSharedData.swift
// SortydWidgetExtension — Shared data model & store read by all widgets

import Foundation
import WidgetKit

// ─────────────────────────────────────────────────────────────
// MARK: WidgetData   (written by the main app, read by widgets)
// ─────────────────────────────────────────────────────────────

struct WidgetData: Codable {
    var listName:             String
    var listEmoji:            String
    var completionFraction:   Double
    var completionPercentage: Int
    var tasksDone:            Int
    var tasksTotal:           Int
    var tasks:                [WidgetTask]
    var streakDays:           Int
    /// Monthly snapshots keyed "YYYY-MM-DD" → fraction (0–1)
    var monthlySnapshots:     [String: Double]
    var caloriesBurned: Double?
    var caloriesGoal:   Double?
    var stepCount:      Double?
    var stepGoal:       Double?

    struct WidgetTask: Codable, Identifiable {
        var id:          UUID
        var title:       String
        var isCompleted: Bool
        var weight:      Double
    }

    static var placeholder: WidgetData {
        let cal  = Calendar.current
        let now  = Date()
        var snaps = [String: Double]()
        for d in 0..<28 {
            if let day = cal.date(byAdding: .day, value: -d, to: now) {
                let key = WidgetData.dayKey(day)
                snaps[key] = d % 3 == 0 ? 1.0 : (d % 3 == 1 ? 0.6 : 0.0)
            }
        }
        return WidgetData(
            listName: "Morning Routine", listEmoji: "🌅",
            completionFraction: 0.6, completionPercentage: 60,
            tasksDone: 3, tasksTotal: 5,
            tasks: [
                WidgetTask(id: UUID(), title: "Meditate",      isCompleted: true,  weight: 0.2),
                WidgetTask(id: UUID(), title: "Cold shower",   isCompleted: true,  weight: 0.2),
                WidgetTask(id: UUID(), title: "Read 20 pages", isCompleted: true,  weight: 0.2),
                WidgetTask(id: UUID(), title: "Workout",       isCompleted: false, weight: 0.2),
                WidgetTask(id: UUID(), title: "Journal",       isCompleted: false, weight: 0.2),
            ],
            streakDays: 7,
            monthlySnapshots: snaps,
            caloriesBurned: nil,
            caloriesGoal: nil,
            stepCount: nil,
            stepGoal: nil
        )
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: WidgetDataStore   (App Group UserDefaults bridge)
// ─────────────────────────────────────────────────────────────

struct WidgetDataStore {
    static let suiteName = "group.com.sortyd.sortyd"
    static let key       = "sortyd_widget_data"

    static func load() -> WidgetData {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let raw      = defaults.data(forKey: key),
            let data     = try? JSONDecoder().decode(WidgetData.self, from: raw)
        else { return .placeholder }
        return data
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Timeline Entry & Provider   (one provider for all widgets)
// ─────────────────────────────────────────────────────────────

struct SortydEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct SortydProvider: TimelineProvider {
    func placeholder(in context: Context) -> SortydEntry {
        SortydEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SortydEntry) -> Void) {
        completion(SortydEntry(date: .now, data: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SortydEntry>) -> Void) {
        let entry      = SortydEntry(date: .now, data: WidgetDataStore.load())
        // Reload at the top of the next hour so the heatmap date cells stay current
        let nextHour   = Calendar.current.nextDate(
            after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime
        ) ?? Date(timeIntervalSinceNow: 3600)
        completion(Timeline(entries: [entry], policy: .after(nextHour)))
    }
}
