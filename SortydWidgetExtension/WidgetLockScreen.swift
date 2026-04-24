// MARK: - WidgetLockScreen.swift
// Lock screen widgets (accessoryCircular, accessoryRectangular, accessoryInline)
// Tactical dials and micro analytics graphs.

import SwiftUI
import WidgetKit

// ─────────────────────────────────────────────────────────────
// MARK: accessoryCircular — Tactical Dashed Ring
// ─────────────────────────────────────────────────────────────

struct LockCircularView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            // Dashed Track ring
            Circle()
                .stroke(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 4, dash: [2, 4]))
            // Solid Fill arc
            Circle()
                .trim(from: 0, to: data.completionFraction)
                .stroke(.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Inner elements based on completion
            if data.completionFraction >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.primary)
            } else {
                VStack(spacing: -2) {
                    Text("\(data.completionPercentage)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text("%")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
            }
        }
        .widgetAccentable()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: accessoryRectangular — Progress bar + Sparkline
// ─────────────────────────────────────────────────────────────

struct LockRectangularView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: emoji + list name + streak
            HStack(spacing: 4) {
                Text(data.listEmoji).font(.system(size: 11))
                Text(data.listName.removingLeadingEmojis())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                if data.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").font(.system(size: 9))
                        Text("\(data.streakDays)d")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.primary)
                }
            }

            // Row 2: Tactical Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    
                    // Fill
                    Capsule()
                        .fill(.primary)
                        .frame(width: max(4, geo.size.width * data.completionFraction))
                }
            }
            .frame(height: 6)
            .widgetAccentable()

            // Row 3: mini sparkline + text
            HStack(spacing: 6) {
                Text("\(data.tasksDone)/\(data.tasksTotal) " + String(localized: "done"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Micro sparkline
                microSparkline
                    .frame(width: 30, height: 10)
            }
        }
    }
    
    // Sparkline for recent history on lock screen
    private var microSparkline: some View {
        GeometryReader { geo in
            let points = Array(data.monthlySnapshots.values.prefix(5))
            let maxPoints = max(points.count, 2)
            let step = geo.size.width / CGFloat(maxPoints - 1)
            
            Path { path in
                if points.isEmpty { return }
                for (i, val) in points.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height * (1.0 - CGFloat(val))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: accessoryInline — single-line summary
// ─────────────────────────────────────────────────────────────

struct LockInlineView: View {
    let data: WidgetData

    var body: some View {
        Label {
            Text("\(data.completionPercentage)% · \(data.tasksDone)/\(data.tasksTotal)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        } icon: {
            if data.completionFraction >= 1.0 {
                Image(systemName: "checkmark.seal.fill")
            } else if data.tasksDone > 0 {
                Image(systemName: "circle.circle.fill")
            } else {
                Image(systemName: "circle.dashed")
            }
        }
        .widgetAccentable()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Widget definitions
// ─────────────────────────────────────────────────────────────

struct SortydLockCircularWidget: Widget {
    let kind = "SortydLockCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LockCircularView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Tactical Ring")
        .description("Daily completion on a dashed dial.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SortydLockRectangularWidget: Widget {
    let kind = "SortydLockRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LockRectangularView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Progress Console")
        .description("Progress bar, streak, and 5-day sparkline.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct SortydLockInlineWidget: Widget {
    let kind = "SortydLockInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LockInlineView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Smart Status")
        .description("One-line status that adapts to your completion.")
        .supportedFamilies([.accessoryInline])
        .contentMarginsDisabled()
    }
}
