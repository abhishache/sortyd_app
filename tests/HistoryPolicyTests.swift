import Foundation

@main
struct HistoryPolicyTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
        }
        func streak(_ entries: [(Date, Double)]) -> Int {
            HistoryPolicy.bestStreak(entries, calendar: calendar)
        }
        precondition(streak([]) == 0)
        precondition(streak([(date(9, 1), 1), (date(9, 3), 1)]) == 1)
        precondition(streak([(date(9, 1), 1), (date(9, 2), 0.79), (date(9, 3), 1)]) == 1)
        precondition(streak([(date(9, 3), 1), (date(9, 1), 0.8), (date(9, 2), 1)]) == 3)
        precondition(streak([(date(9, 1), 1), (date(9, 1, 12), 1)]) == 1)
        precondition(streak([(date(3, 7), 1), (date(3, 8), 1), (date(3, 9), 1)]) == 3)
        precondition(streak([(date(10, 31), 1), (date(11, 1), 1), (date(11, 2), 1)]) == 3)
        // Reset means 4 AM local wall time, not four elapsed hours after midnight.
        for (month, day) in [(3, 8), (11, 1), (9, 20)] {
            precondition(ReminderPolicy.dayStart(date(month, day, 3, 59), calendar: calendar) == calendar.date(byAdding: .day, value: -1, to: date(month, day))!)
            precondition(ReminderPolicy.dayStart(date(month, day, 4), calendar: calendar) == date(month, day))
            precondition(ReminderPolicy.dayStart(date(month, day, 4, 30), calendar: calendar) == date(month, day))
        }
        print("16 history and daylight saving regression checks passed")
    }
}
