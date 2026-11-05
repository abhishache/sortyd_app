import Foundation

/// Pure scheduling rules shared by reconciliation and regression tests.
enum ReminderPolicy {
    static func acceptsCompletion(current: Bool, expected: Bool, sentAt: Date,
                                  now: Date = Date(), calendar: Calendar = .current) -> Bool {
        current == expected && sentAt <= now.addingTimeInterval(30) &&
            dayStart(sentAt, calendar: calendar) == dayStart(now, calendar: calendar)
    }
    static func fireDate(reminder: Date?, oneTime: Bool, weekly: Bool,
                         archived: Bool, completed: Bool, now: Date = Date(),
                         calendar: Calendar = .current) -> Date? {
        guard let reminder, !archived, !completed else { return nil }
        if weekly {
            guard reminder > now else { return nil }
            let advance = reminder.addingTimeInterval(-600)
            // Never replay a missed or already-delivered advance reminder at the start.
            return advance > now ? advance : nil
        }
        if oneTime { return reminder > now ? reminder : nil }
        return calendar.nextDate(after: now,
            matching: calendar.dateComponents([.hour, .minute], from: reminder),
            matchingPolicy: .nextTime)
    }

    static func dayStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: date)
        let boundary = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: midnight)!
        return date < boundary ? calendar.date(byAdding: .day, value: -1, to: midnight)! : midnight
    }
}
