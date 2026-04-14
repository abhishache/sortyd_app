// MARK: - WidgetMonthly.swift
// systemMedium + systemLarge — Monthly heatmap calendar
// Medium shows a compact 2-week rolling view.
// Large shows the full current month grid.

import SwiftUI
import WidgetKit

struct MonthlyWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family

    private let dayLetters = ["S","M","T","W","T","F","S"]

    private var allDays: [Date?] {
        let cal   = Calendar.current
        let now   = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading: [Date?] = Array(repeating: nil,
                                     count: cal.component(.weekday, from: first) - 1)
        let filled: [Date?]  = range.map { d in
            cal.date(byAdding: .day, value: d - 1, to: first)
        }
        return leading + filled
    }

    private var recentDays: [Date] {
        (0..<14).compactMap {
            Calendar.current.date(byAdding: .day, value: -13 + $0, to: Date())
        }
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(WTheme.bg0)

            if family == .systemLarge {
                fullMonthLayout
            } else {
                compactLayout
            }
        }
    }

    // MARK: Large — full month

    private var fullMonthLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle())
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(WTheme.text0)
                    Text(data.listEmoji + "  " + data.listName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WTheme.text1)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(data.completionPercentage)%")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(WTheme.amber)
                    Text("today")
                        .font(.system(size: 9))
                        .foregroundColor(WTheme.text2)
                }
            }

            // Divider
            Rectangle().fill(WTheme.border).frame(height: 0.5)

            // Day labels
            HStack(spacing: 0) {
                ForEach(dayLetters, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(WTheme.text2)
                        .frame(maxWidth: .infinity)
                }
            }

            // Full calendar grid
            let days = allDays
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(0..<days.count, id: \.self) { idx in
                    if let date = days[idx] {
                        dayCellFull(date)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            legend
        }
        .padding(12)
    }

    // MARK: Medium — compact 14-day rolling strip

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack {
                HStack(spacing: 5) {
                    Text(data.listEmoji).font(.system(size: 12))
                    Text(data.listName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(WTheme.text0)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Last 14 days")
                        .font(.system(size: 9))
                        .foregroundColor(WTheme.text2)
                    Text("\(data.completionPercentage)%")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(WTheme.amber)
                }
            }

            // 14-day grid in 2 rows of 7
            let days = recentDays
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayLetters[Calendar.current.component(.weekday, from: days[i]) - 1])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(WTheme.text1)
                            .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in dayCellCompact(days[i]) }
                }
                HStack(spacing: 4) {
                    ForEach(7..<14, id: \.self) { i in dayCellCompact(days[i]) }
                }
            }

            HStack {
                if data.streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(WTheme.amber)
                        Text("\(data.streakDays) day streak")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(WTheme.amber)
                    }
                }
                Spacer()
                legend
            }
        }
        .padding(12)
    }

    // MARK: Day cells

    private func dayCellFull(_ date: Date) -> some View {
        let key     = WidgetData.dayKey(date)
        let frac    = data.monthlySnapshots[key] ?? 0
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date()
        let dayNum  = Calendar.current.component(.day, from: date)

        return ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isFuture ? WTheme.bg1 : WTheme.heat(frac))
            if isToday {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(WTheme.amber, lineWidth: 1.5)
            }
            if !isFuture {
                Text("\(dayNum)")
                    .font(.system(size: 9, weight: isToday ? .black : .semibold, design: .rounded))
                    .foregroundColor(frac > 0.3 ? WTheme.text0 : frac > 0 ? WTheme.text1 : WTheme.text2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dayCellCompact(_ date: Date) -> some View {
        let key     = WidgetData.dayKey(date)
        let frac    = data.monthlySnapshots[key] ?? 0
        let isToday = Calendar.current.isDateInToday(date)
        let dayNum  = Calendar.current.component(.day, from: date)

        return ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(WTheme.heat(frac))
            if isToday {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(WTheme.amber, lineWidth: 1.5)
            }
            Text("\(dayNum)")
                .font(.system(size: 10, weight: isToday ? .black : .semibold, design: .rounded))
                .foregroundColor(frac > 0.3 ? WTheme.text0 : frac > 0 ? WTheme.text1 : WTheme.text2)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([
                ("None", WTheme.heat(0)),
                ("25%",  WTheme.heat(0.25)),
                ("75%",  WTheme.heat(0.75)),
                ("100%", WTheme.heat(1.0))
            ], id: \.0) { label, color in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color).frame(width: 8, height: 8)
                    Text(label).font(.system(size: 7)).foregroundColor(WTheme.text2)
                }
            }
            Spacer()
        }
    }

    private func monthTitle() -> String {
        Date().formatted(.dateTime.month(.wide).year())
    }
}

struct SortydMonthlyWidget: Widget {
    let kind = "SortydMonthlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            MonthlyWidgetView(data: entry.data)
                .containerBackground(WTheme.bg0, for: .widget)
        }
        .configurationDisplayName("Monthly Heatmap")
        .description("See your completion history as a colour heatmap.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
