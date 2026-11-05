import Foundation

enum CalendarDayLabel {
    /// Weekday symbol arrays always start on Sunday, regardless of firstWeekday.
    /// Resolve the label from the cell date, never from its column position.
    static func shortName(for date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let weekday = calendar.component(.weekday, from: date)
        return formatter.veryShortStandaloneWeekdaySymbols[weekday - 1].uppercased(with: locale)
    }
}
