import Foundation

@main
struct ReminderPolicyTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let iso = ISO8601DateFormatter()
        func date(_ value: String) -> Date { iso.date(from: value)! }
        let now = date("2026-09-09T12:00:00Z")
        func fire(_ reminder: Date?, once: Bool = true, weekly: Bool = false,
                  archived: Bool = false, completed: Bool = false) -> Date? {
            ReminderPolicy.fireDate(reminder: reminder, oneTime: once, weekly: weekly,
                archived: archived, completed: completed, now: now, calendar: calendar)
        }
        assert(fire(now.addingTimeInterval(-49 * 86400), weekly: true) == nil)
        assert(fire(now.addingTimeInterval(-1)) == nil)
        assert(fire(now) == nil)
        assert(fire(nil) == nil)
        let later = now.addingTimeInterval(3600)
        assert(fire(later) == later)
        assert(fire(later, completed: true) == nil)
        assert(fire(later, archived: true) == nil)
        assert(fire(later, weekly: true) == later.addingTimeInterval(-600))
        assert(fire(now.addingTimeInterval(300), weekly: true) == nil)
        assert(fire(now.addingTimeInterval(600), weekly: true) == nil)
        assert(fire(now.addingTimeInterval(-3600), once: false) == now.addingTimeInterval(23 * 3600))
        assert(ReminderPolicy.dayStart(date("2026-09-09T03:59:59Z"), calendar: calendar) == date("2026-09-08T00:00:00Z"))
        assert(ReminderPolicy.dayStart(date("2026-09-09T04:00:00Z"), calendar: calendar) == date("2026-09-09T00:00:00Z"))
        assert(ReminderPolicy.dayStart(date("2026-09-01T10:00:00Z"), calendar: calendar) == date("2026-09-01T00:00:00Z"))
        assert(ReminderPolicy.acceptsCompletion(current: false, expected: false, sentAt: now, now: now, calendar: calendar))
        assert(!ReminderPolicy.acceptsCompletion(current: true, expected: false, sentAt: now, now: now, calendar: calendar))
        assert(!ReminderPolicy.acceptsCompletion(current: false, expected: false, sentAt: now.addingTimeInterval(-86400), now: now, calendar: calendar))
        assert(!ReminderPolicy.acceptsCompletion(current: false, expected: false, sentAt: now.addingTimeInterval(3600), now: now, calendar: calendar))
        print("18 reminder, logical-day and Watch conflict regression checks passed")
    }
}
