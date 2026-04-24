
// MARK: - WidgetMonthly.swift
// systemMedium ONLY — Full month heatmap calendar.
// Uniform circles, date numbers inside, generous padding, larger day-of-week initials.

import SwiftUI
import WidgetKit

struct MonthlyWidgetView: View {
    let data: WidgetData
    @Environment(\.locale) var locale

    private let columns = 7
    private var dayLetters: [String] {
        let f = DateFormatter()
        f.locale = locale
        return f.veryShortStandaloneWeekdaySymbols
    }

    private var allDays: [Date?] {
        var cal = Calendar.current
        cal.locale = locale
        let now = Date()
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

    private var rows: [[Date?]] {
        var result: [[Date?]] = []
        var row: [Date?]      = []
        for day in allDays {
            row.append(day)
            if row.count == columns { result.append(row); row = [] }
        }
        if !row.isEmpty {
            while row.count < columns { row.append(nil) }
            result.append(row)
        }
        return result
    }

    var body: some View {
        ZStack {
            WTheme.meshGradient

            GeometryReader { geo in
                let totalW = geo.size.width
                let totalH = geo.size.height

                // Generous padding so nothing touches edges
                let hPad:    CGFloat = 14
                let vPad:    CGFloat = 10

                // Fixed vertical allocations
                let headerH: CGFloat = 20
                let sepGap:  CGFloat = 6    // space around the divider line
                let labelsH: CGFloat = 14   // taller to fit larger day initials
                let gapGrid: CGFloat = 5    // gap between labels and grid

                let usedV  = vPad * 2 + headerH + sepGap + labelsH + gapGrid
                let gridH  = totalH - usedV
                let gridW  = totalW - hPad * 2

                let rowCount = CGFloat(rows.count)

                // Circle size: slightly smaller to give breathing room
                let maxByW   = floor((gridW - 4 * CGFloat(columns - 1)) / CGFloat(columns))
                let maxByH   = floor((gridH - 3 * CGFloat(rows.count - 1)) / rowCount)
                // Apply a reduction factor so circles are not crammed
                let circleDia = min(maxByW, maxByH) * 0.88

                // Distribute leftover space evenly as spacing
                let totalCircleW = circleDia * CGFloat(columns)
                let hSpacing     = floor((gridW - totalCircleW) / CGFloat(columns - 1))
                let totalCircleH = circleDia * rowCount
                let vSpacing     = floor((gridH - totalCircleH) / (rowCount - 1))

                // Date number font: smaller than before
                let dateFontSize = floor(circleDia * 0.30).clamped(to: 5...9)
                // Day initial font: larger and prominent
                let dayFontSize  = floor(circleDia * 0.52).clamped(to: 8...13)

                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header — clean, not touching edges
                    HStack(alignment: .center, spacing: 0) {
                        Text(data.listEmoji + "  " + monthTitle())
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(WTheme.text0)
                            .lineLimit(1)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(data.completionPercentage)%")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(WTheme.primary)
                            Text(String(localized: "done", locale: locale))
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(WTheme.text2)
                        }
                    }
                    .frame(height: headerH)

                    // Divider with breathing room
                    Spacer().frame(height: sepGap * 0.5)
                    Rectangle()
                        .fill(WTheme.glassBorder)
                        .frame(height: 0.5)
                    Spacer().frame(height: sepGap * 0.5)

                    // MARK: Day-of-week initials — larger and centred over circles
                    HStack(spacing: hSpacing) {
                        ForEach(0..<columns, id: \.self) { i in
                            Text(dayLetters[i])
                                .font(.system(size: dayFontSize, weight: .heavy))
                                .foregroundColor(WTheme.text1)
                                .frame(width: circleDia, height: labelsH)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer().frame(height: gapGrid)

                    // MARK: Calendar grid
                    VStack(spacing: vSpacing) {
                        ForEach(0..<rows.count, id: \.self) { r in
                            HStack(spacing: hSpacing) {
                                ForEach(0..<columns, id: \.self) { c in
                                    if let date = rows[r][c] {
                                        circleCell(date: date,
                                                   size: circleDia,
                                                   fontSize: dateFontSize)
                                    } else {
                                        Circle()
                                            .fill(Color.clear)
                                            .frame(width: circleDia, height: circleDia)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
            }
        }
    }

    // MARK: Circle Cell

    private func circleCell(date: Date, size: CGFloat, fontSize: CGFloat) -> some View {
        let key      = WidgetData.dayKey(date)
        let frac     = data.monthlySnapshots[key] ?? 0
        var cal      = Calendar.current
        cal.locale   = locale
        let isToday  = cal.isDateInToday(date)
        let isFuture = date > Date()
        let dayNum   = cal.component(.day, from: date)

        let fill: Color = isFuture ? WTheme.bg2 : WTheme.bubbleHeat(frac)

        let labelColor: Color = {
            if isFuture    { return WTheme.text2 }
            if frac > 0.65 { return WTheme.bg0   }
            return WTheme.text1
        }()

        return ZStack {
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
                .shadow(
                    color: (!isFuture && frac > 0.25) ? fill.opacity(0.45) : .clear,
                    radius: 2.5, x: 0, y: 1
                )

            if isToday {
                Circle()
                    .strokeBorder(WTheme.text0, lineWidth: 1.2)
                    .frame(width: size + 2.5, height: size + 2.5)
            }

            Text("\(dayNum)")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(labelColor)
        }
        .frame(width: size, height: size)
    }

    private func monthTitle() -> String {
        Date().formatted(.dateTime.month(.wide).year().locale(locale))
    }
}

// MARK: - Utility

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Widget Declaration

struct SortydMonthlyWidget: Widget {
    let kind = "SortydMonthlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            MonthlyWidgetView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(WTheme.bg0, for: .widget)
        }
        .configurationDisplayName("Bubble Heatmap")
        .description("Visualize your full month completion intensity at a glance.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
