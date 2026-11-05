import Foundation

enum HistoryPolicy {
    static func bestStreak(_ entries: [(date: Date, fraction: Double)], calendar: Calendar = .current) -> Int {
        var days: [Date: Double] = [:]
        for entry in entries {
            days[calendar.startOfDay(for: entry.date)] = entry.fraction
        }
        var previous: Date?
        var current = 0
        var best = 0
        for day in days.keys.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) != day {
                current = 0
            }
            current = (days[day] ?? 0) >= 0.8 ? current + 1 : 0
            best = max(best, current)
            previous = day
        }
        return best
    }
}
