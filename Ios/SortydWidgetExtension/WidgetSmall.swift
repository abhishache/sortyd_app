// MARK: - WidgetSmall.swift
// 1×1  (systemSmall) — Donut progress + streak
// Shows daily completion percentage as a glowing donut ring.

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(WTheme.bg0)

            VStack(spacing: 0) {

                // ── TOP: list identity ─────────────────────────────────
                HStack(spacing: 4) {
                    Text(data.listEmoji)
                        .font(.system(size: 10))
                    Text(data.listName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(WTheme.text1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                Spacer(minLength: 6)

                // ── CENTRE: donut ring ─────────────────────────────────
                donutRing
                    .frame(width: 68, height: 68)

                Spacer(minLength: 6)

                // ── BOTTOM: done / total + streak ─────────────────────
                VStack(spacing: 2) {
                    Text("\(data.tasksDone) of \(data.tasksTotal)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(WTheme.text1)

                    if data.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7))
                                .foregroundColor(WTheme.amber)
                            Text("\(data.streakDays)d")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(WTheme.amber)
                        }
                    }
                }
                .layoutPriority(1)
            }
            .padding(10)
        }
    }

    // MARK: Donut ring

    private var donutRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(WTheme.bg3, lineWidth: 9)

            // Fill arc
            Circle()
                .trim(from: 0, to: data.completionFraction)
                .stroke(
                    WTheme.arcGradient,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: WTheme.amber.opacity(0.35), radius: 6)

            // Centre percentage
            VStack(spacing: -3) {
                Text("\(data.completionPercentage)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(WTheme.text0)
                Text("%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WTheme.amber)
            }
        }
    }
}

struct SortydSmallWidget: Widget {
    let kind = "SortydSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            SmallWidgetView(data: entry.data)
                .containerBackground(WTheme.bg0, for: .widget)
        }
        .configurationDisplayName("Daily Progress")
        .description("See today's completion at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
