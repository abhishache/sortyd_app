// MARK: - WidgetSmall.swift
// 1×1  (systemSmall) — Segmented gauge + 7-day sparkline
// Shows daily completion percentage as a segmented radial arch, with history behind it.
// Health tanks: steps tank bottom-left, calories tank bottom-right, task count centred.

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    // True when the list has a steps goal set
    private var hasSteps: Bool    { (data.stepGoal    ?? 0) > 0 }
    // True when the list has a calories goal set
    private var hasCalories: Bool { (data.caloriesGoal ?? 0) > 0 }
    // Either health type present → show the health bottom bar instead of plain stats
    private var hasHealth: Bool   { hasSteps || hasCalories }

    var body: some View {
        ZStack {
            // Glassmorphic mesh background
            WTheme.meshGradient

            // Sparkline in background — shifts up a little when health bar is visible
            VStack {
                Spacer()
                sparklineGraph
                    .frame(height: 40)
                    .padding(.bottom, hasHealth ? 48 : 20)
                    .opacity(0.4)
            }

            VStack(spacing: 0) {
                // ── TOP: list identity ─────────────────────────────────
                HStack(spacing: 4) {
                    Text(data.listEmoji)
                        .font(.system(size: 11))
                    Text(data.listName.removingLeadingEmojis())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(WTheme.text0)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Spacer(minLength: 2)

                // ── CENTRE: Segmented Radial — nudged down ─────────────
                segmentedArc
                    .frame(width: 62, height: 62)
                    .padding(.top, 4)

                Spacer(minLength: 4)

                // ── BOTTOM row ────────────────────────────────────────
                if hasHealth {
                    healthBottomBar
                        .layoutPriority(1)
                } else {
                    defaultStatsRow
                        .layoutPriority(1)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Default stats row (no health tasks)

    private var defaultStatsRow: some View {
        HStack(spacing: 2) {
            Text("\(data.tasksDone)/\(data.tasksTotal)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WTheme.text1)

            Spacer()

            if data.streakDays > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(WTheme.primary)
                    Text("\(data.streakDays)d")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(WTheme.primary)
                }
            }
        }
    }

    // MARK: - Health bottom bar
    // Steps tank     → bottom-left
    // completed/total → centre (with streak beneath if present)
    // Calories tank  → bottom-right
    // If only one health type is present, its opposite side is empty
    // and the count/streak shifts naturally.

    private var healthBottomBar: some View {
        HStack(alignment: .bottom, spacing: 0) {

            // Left: Steps tank (or ghost spacer)
            Group {
                if hasSteps {
                    WidgetTank(
                        icon: "figure.walk",
                        accentHex: "#4FC3F7",
                        progress: stepProgress
                    )
                } else {
                    Color.clear.frame(width: tankW, height: tankH)
                }
            }

            Spacer(minLength: 0)

            // Centre: task count + optional streak
            VStack(spacing: 1) {
                Text("\(data.tasksDone)/\(data.tasksTotal)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WTheme.text1)
                if data.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                            .foregroundColor(WTheme.primary)
                        Text("\(data.streakDays)d")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(WTheme.primary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Right: Calories tank (or ghost spacer)
            Group {
                if hasCalories {
                    WidgetTank(
                        icon: "flame.fill",
                        accentHex: "#FF7043",
                        progress: calorieProgress
                    )
                } else {
                    Color.clear.frame(width: tankW, height: tankH)
                }
            }
        }
    }

    private let tankW: CGFloat = 28
    private let tankH: CGFloat = 36

    private var stepProgress: Double {
        guard let count = data.stepCount,
              let goal  = data.stepGoal, goal > 0 else { return 0 }
        return min(count / goal, 1.0)
    }

    private var calorieProgress: Double {
        guard let burned = data.caloriesBurned,
              let goal   = data.caloriesGoal, goal > 0 else { return 0 }
        return min(burned / goal, 1.0)
    }

    // MARK: Sparkline

    private var sparklineGraph: some View {
        GeometryReader { geo in
            let points   = Array(data.monthlySnapshots.values.prefix(7))
            let maxPts   = max(points.count, 2)
            let step     = geo.size.width / CGFloat(maxPts - 1)

            Path { path in
                guard !points.isEmpty else { return }
                for (i, val) in points.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height * (1.0 - CGFloat(val))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevX = CGFloat(i - 1) * step
                        let prevY = geo.size.height * (1.0 - CGFloat(points[i - 1]))
                        let midX  = (prevX + x) / 2
                        path.addCurve(to: CGPoint(x: x, y: y),
                                      control1: CGPoint(x: midX, y: prevY),
                                      control2: CGPoint(x: midX, y: y))
                    }
                }
            }
            .stroke(WTheme.secondary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Segmented Arc

    private var segmentedArc: some View {
        ZStack {
            let segments        = 24
            let gap: Double     = 0.02
            let filledSegments  = Int(Double(segments) * data.completionFraction)

            ForEach(0..<segments, id: \.self) { i in
                let start = Double(i) / Double(segments)
                let end   = start + (1.0 / Double(segments)) - gap

                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        i < filledSegments
                            ? WTheme.arcGradient
                            : AngularGradient(colors: [WTheme.bg3], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            // Glow on filled arc
            Circle()
                .trim(from: 0, to: max(0, data.completionFraction - gap))
                .stroke(WTheme.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .blur(radius: 8)

            // Centre percentage
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(data.completionPercentage)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(WTheme.text0)
                Text("%")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(WTheme.statusColor(fraction: data.completionFraction))
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: - WidgetTank
// Static (no @State / no animation) vertical fill tank.
// Mirrors SmallHealthBar's visual language for the widget
// snapshot context where animations are not available.
// ══════════════════════════════════════════════

private struct WidgetTank: View {
    let icon: String
    let accentHex: String
    let progress: Double          // 0–1

    private var accent: Color { Color(widgetHex: accentHex) }

    // The minimum fill height shown so the icon is always legible
    private var effectiveProgress: Double { max(progress, 0.12) }

    private let w: CGFloat = 28
    private let h: CGFloat = 36

    var body: some View {
        ZStack {
            // ── Tank track ──────────────────────────────────────────
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(WTheme.bg3)
                .frame(width: w, height: h)

            // ── Liquid fill (bottom-anchored) ───────────────────────
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.72)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: geo.size.height * effectiveProgress)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // ── Soft glow overlay ───────────────────────────────────
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(progress > 0 ? 0.16 : 0))
                .frame(width: w, height: h)
                .blur(radius: 4)

            // ── Icon: dim base (unfilled portion) ───────────────────
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(WTheme.text0.opacity(0.22))
                .frame(width: w, height: h)

            // ── Icon: bright fill-reveal via bottom mask ─────────────
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.90))
                .shadow(color: accent.opacity(0.55), radius: 3, x: 0, y: 0)
                .mask(
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: geo.size.height * effectiveProgress)
                        }
                    }
                )
                .frame(width: w, height: h)
        }
        .frame(width: w, height: h)
    }
}

// ══════════════════════════════════════════════
// MARK: - Widget entry point
// ══════════════════════════════════════════════

struct SortydSmallWidget: Widget {
    let kind = "SortydSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            SmallWidgetView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(WTheme.bg0, for: .widget)
        }
        .configurationDisplayName("Daily Insights")
        .description("See today's completion and history at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
