import SwiftUI
import WidgetKit
import AppIntents
// ToggleTaskIntent + AppDataWidget mirror structs are defined in WidgetMedium.swift

struct LargeWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family
    @Environment(\.locale) var locale

    private var maxTasks: Int { 4 }

    /// Always shows exactly maxTasks rows so the widget never shrinks:
    /// 1. All done     → show last maxTasks completed tasks (most recently checked).
    /// 2. All undone   → show first maxTasks incomplete tasks.
    /// 3. Mixed        → completed tasks sit at the TOP (easy to see progress),
    ///                   incomplete tasks fill the BOTTOM slots (easy tap access).
    private var visibleTasks: [WidgetData.WidgetTask] {
        let allTasks   = data.tasks
        let incomplete = allTasks.filter { !$0.isCompleted }
        let completed  = allTasks.filter {  $0.isCompleted }

        // Case 1: everything done — show last maxTasks completed.
        if incomplete.isEmpty {
            return Array(completed.suffix(maxTasks))
        }

        // Case 2: all incomplete — fill all slots with unchecked tasks.
        if completed.isEmpty {
            return Array(incomplete.prefix(maxTasks))
        }

        // Case 3: mixed — pin the single last-checked task at the top.
        // Then fill with incomplete tasks. If slots remain, fill with other completed tasks.
        let pinnedTask: WidgetData.WidgetTask = {
            if let id = data.lastCheckedTaskID,
               let t = completed.first(where: { $0.id == id }) { return t }
            return completed.last! // fallback: most recently completed
        }()

        var result: [WidgetData.WidgetTask] = [pinnedTask]
        
        // 1. Fill with incomplete tasks
        let slotsForIncomplete = maxTasks - result.count
        result += Array(incomplete.prefix(slotsForIncomplete))
        
        // 2. If we still have space (because there weren't enough incomplete tasks),
        // fill the remaining slots with other completed tasks so the widget doesn't shrink.
        let remainingSlots = maxTasks - result.count
        if remainingSlots > 0 {
            let otherCompleted = completed.filter { $0.id != pinnedTask.id }
            // Take the most recently completed ones (suffix)
            result += Array(otherCompleted.suffix(remainingSlots))
        }
        
        return result
    }

    // `extra` = total tasks minus what is actually shown
    private var extra: Int { max(0, data.tasks.count - visibleTasks.count) }

    var body: some View {
        ZStack {
            WTheme.meshGradient

            VStack(spacing: 0) {
                topAnalyticsZone
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                glassTasksZone
                    .padding(.horizontal, 12)
                    .layoutPriority(1)
                
                bottomHealthZone
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: Top Analytics (7-day Bar Chart + Header)

    private var topAnalyticsZone: some View {
        HStack {
            // Text Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(data.listEmoji)
                    Text(data.listName)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(WTheme.text0)
                }
                Text(String(localized: "\(data.completionPercentage)% Complete", locale: locale))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(WTheme.statusColor(fraction: data.completionFraction))
            }

            Spacer()

            // 7-day Bar Chart
            HStack(alignment: .bottom, spacing: 4) {
                let points = Array(data.monthlySnapshots.values.prefix(7).reversed())
                let padded = (0..<7).map { i -> Double in
                    if i < 7 - points.count { return 0.0 }
                    return points[i - (7 - points.count)]
                }
                
                ForEach(0..<7, id: \.self) { i in
                    let p = padded[i]
                    let isToday = i == 6
                    Capsule()
                        .fill(isToday ? WTheme.statusColor(fraction: data.completionFraction) : WTheme.bg2)
                        .frame(width: 8, height: max(6, 32 * p))
                        .overlay(
                            Capsule().strokeBorder(isToday ? WTheme.glassBorder : Color.clear, lineWidth: 1)
                        )
                }
            }
            .frame(height: 32, alignment: .bottom)
        }
    }

    // MARK: Glass Tasks

    private var glassTasksZone: some View {
        VStack(spacing: 6) {
            ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { _, task in
                taskGlassPill(task: task)
            }
            if extra > 0 {
                Text(String(localized: "+ \(extra) more items", locale: locale))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(WTheme.text1)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func taskGlassPill(task: WidgetData.WidgetTask) -> some View {
        Button(intent: {
            let intent = ToggleTaskIntent()
            intent.taskID = task.id.uuidString
            return intent
        }()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? WTheme.primary : WTheme.glassBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if task.isCompleted {
                        Circle()
                            .fill(WTheme.primary.opacity(0.25))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(WTheme.primary)
                    }
                }

                Text(task.title)
                    .font(.system(size: 13, weight: task.isCompleted ? .medium : .bold))
                    .foregroundColor(task.isCompleted ? WTheme.text1 : WTheme.text0)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted, color: WTheme.text1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WTheme.bg1.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(WTheme.glassBorder, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Bottom Health Dials

    private var bottomHealthZone: some View {
        HStack(spacing: 20) {
            
            // Streak
            dialStat(
                icon: "bolt.fill",
                color: WTheme.yellow,
                value: "\(data.streakDays)d",
                label: String(localized: "Streak", locale: locale),
                progress: min(1.0, Double(data.streakDays)/30.0)
            )

            // Calories
            if let burned = data.caloriesBurned, let calGoal = data.caloriesGoal {
                let p = calGoal > 0 ? burned / calGoal : 0
                dialStat(
                    icon: "flame.fill",
                    color: WTheme.orange,
                    value: "\(Int(burned))",
                    label: String(localized: "Cals", locale: locale),
                    progress: p
                )
            } else {
                // Placeholder if no health
                dialStat(icon: "flame.fill", color: WTheme.bg3, value: "--", label: String(localized: "Cals", locale: locale), progress: 0)
            }

            // Steps
            if let steps = data.stepCount, let stepGoal = data.stepGoal {
                let p = stepGoal > 0 ? steps / stepGoal : 0
                dialStat(
                    icon: "figure.walk",
                    color: WTheme.skyBlue,
                    value: steps >= 1000 ? String(format: "%.1fk", steps/1000) : "\(Int(steps))",
                    label: String(localized: "Steps", locale: locale),
                    progress: p
                )
            } else {
                dialStat(icon: "figure.walk", color: WTheme.bg3, value: "--", label: String(localized: "Steps", locale: locale), progress: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func dialStat(icon: String, color: Color, value: String, label: String, progress: Double) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(WTheme.bg2, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(WTheme.text0)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(WTheme.text1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct SortydLargeWidget: Widget {
    let kind = "SortydLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LargeWidgetView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(for: .widget) { WTheme.bg0 }
        }
        .configurationDisplayName("Analytics Control Center")
        .description("Track tasks, historical analytics, and health dials.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
