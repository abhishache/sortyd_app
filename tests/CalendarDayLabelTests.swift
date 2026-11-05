import Foundation

@main
struct CalendarDayLabelTests {
    static func main() {
        let iso = ISO8601DateFormatter()
        let instants = ["2026-09-20T23:30:00Z", "2026-09-21T00:30:00Z",
                        "2026-03-08T08:30:00Z", "2026-11-01T08:30:00Z",
                        "2026-01-01T00:30:00Z"]
        var checks = 0
        for zone in ["Asia/Dubai", "America/Los_Angeles", "Europe/London", "Pacific/Auckland"] {
            for firstWeekday in [1, 2, 7] {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: zone)!
                calendar.firstWeekday = firstWeekday
                for instant in instants {
                    let now = iso.date(from: instant)!
                    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                    let start = calendar.date(from: components)!
                    for column in 0..<7 {
                        let date = calendar.date(byAdding: .day, value: column, to: start)!
                        for language in ["en_GB", "ar", "es_MX", "zh_Hans"] {
                            let locale = Locale(identifier: language)
                            let formatter = DateFormatter()
                            formatter.locale = locale
                            formatter.calendar = calendar
                            formatter.timeZone = calendar.timeZone
                            formatter.dateFormat = "ccccc"
                            let expected = formatter.string(from: date).uppercased(with: locale)
                            let actual = CalendarDayLabel.shortName(for: date, locale: locale, calendar: calendar)
                            precondition(actual == expected, "Wrong weekday for \(zone), \(language), column \(column)")
                            checks += 1
                        }
                    }
                }
            }
        }
        // The reported regression: Monday's date used to receive Sunday's label.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let monday = iso.date(from: "2026-09-21T00:00:00Z")!
        precondition(CalendarDayLabel.shortName(for: monday, locale: Locale(identifier: "en_GB"), calendar: calendar) == "M")
        print("\(checks + 1) calendar label checks passed")
    }
}
