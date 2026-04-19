// MARK: - WidgetLockScreen.swift
// Lock screen widgets  (accessoryCircular, accessoryRectangular, accessoryInline)
// Available on iOS 16+.
//
// • accessoryCircular  — Donut ring with percentage (the one requested)
// • accessoryRectangular — Progress bar + done/total count
// • accessoryInline    — Single line: emoji + "X% · N done"

import SwiftUI
import WidgetKit

// ─────────────────────────────────────────────────────────────
// MARK: accessoryCircular — Donut ring
// ─────────────────────────────────────────────────────────────

struct LockCircularView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 4)
            // Fill arc
            Circle()
                .trim(from: 0, to: data.completionFraction)
                .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // Centre text
            VStack(spacing: -2) {
                Text("\(data.completionPercentage)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text("%")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundColor(.primary)
        }
        // accessoryCircular always renders with the system vibrancy / tinting
        .widgetAccentable()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: accessoryRectangular — Progress bar + stats
// ─────────────────────────────────────────────────────────────

struct LockRectangularView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: emoji + list name
            HStack(spacing: 4) {
                Text(data.listEmoji).font(.system(size: 11))
                Text(data.listName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(data.completionPercentage)%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
            }
            .foregroundColor(.primary)

            // Row 2: progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.25)).frame(height: 4)
                    Capsule()
                        .fill(.primary)
                        .frame(width: geo.size.width * data.completionFraction, height: 4)
                }
            }
            .frame(height: 4)
            .widgetAccentable()

            // Row 3: done / total  +  streak
            HStack {
                Text("\(data.tasksDone) of \(data.tasksTotal) tasks done")
                    .font(.system(size: 10))
                Spacer()
                if data.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").font(.system(size: 9))
                        Text("\(data.streakDays)d")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .widgetAccentable()
                }
            }
            .foregroundColor(.secondary)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: accessoryInline — single-line summary
// ─────────────────────────────────────────────────────────────

struct LockInlineView: View {
    let data: WidgetData

    var body: some View {
        // accessoryInline renders as a single styled Text
        Label {
            Text("\(data.completionPercentage)% · \(data.tasksDone)/\(data.tasksTotal) done")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        } icon: {
            Image(systemName: "checkmark.circle.fill")
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
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Progress Ring")
        .description("Daily completion as a donut ring on your lock screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SortydLockRectangularWidget: Widget {
    let kind = "SortydLockRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LockRectangularView(data: entry.data)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Progress Bar")
        .description("See your progress bar and task count on the lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct SortydLockInlineWidget: Widget {
    let kind = "SortydLockInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LockInlineView(data: entry.data)
                .containerBackground(.clear, for: .widget)
            
        }
        .configurationDisplayName("Quick Stats")
        .description("One-line completion summary at the top of your lock screen.")
        .supportedFamilies([.accessoryInline])
        .contentMarginsDisabled()
    }
}
