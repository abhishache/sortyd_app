# Weekly calendar weekday correction

The iOS weekly planner chose its starting date using Calendar.current, which respects the device's first weekday. Its header independently indexed a Sunday-first weekday symbol array by column. With Monday as the first weekday, Monday's date appeared under Sunday's label and every weekday looked one day behind. Saturday-first calendars were also affected.

The header now resolves its localized weekday from the same date used for its date number and task slots, through CalendarDayLabel. Stored events, reminder times and the 4 AM habit reset are unchanged. No data migration is needed.

Android's weekly planner already resolves weekday labels from each date. The inspected iOS and Android monthly grids use Sunday-first labels and matching Sunday-first padding.

Regression coverage: 1,681 assertions covering Sunday, Monday and Saturday week starts; English, Arabic, Spanish and Chinese; Dubai, Los Angeles, London and Auckland; local midnight, daylight saving transitions and year boundaries. Swift parsing also passed for the modified planner and helper.

Run the standalone regression suite:

```sh
swiftc -module-cache-path /private/tmp/sortyd-calendar-module-cache ios/Sortyd/Utilities/CalendarDayLabel.swift tests/CalendarDayLabelTests.swift -o /private/tmp/sortyd-calendar-tests
/private/tmp/sortyd-calendar-tests
```

This app code fix needs a new iOS release before existing App Store users receive it.
