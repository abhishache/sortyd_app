// MARK: - WidgetMedium.swift
// systemMedium — Dashboard + interactive task list
// iOS 17+: tasks toggle directly via ToggleTaskIntent.

import SwiftUI
import WidgetKit
import AppIntents

// ─────────────────────────────────────────────────────────────
// MARK: Mirror models
// ─────────────────────────────────────────────────────────────

struct AppDataWidget: Codable {
    var lists:        [TaskListWidget]
    var activeListID: UUID?
    var snapshots:    [DailySnapshotWidget]
}

struct TaskListWidget: Codable {
    var id:        UUID
    var name:      String
    var emoji:     String
    var tasks:     [TaskWidget]
    var createdAt: Date
    var isArchived: Bool = false
    var isTodo:     Bool = false
}

struct TaskWidget: Codable {
    var id:              UUID
    var title:           String
    var isCompleted:     Bool
    var manuallyCompleted: Bool = false
    var createdAt:       Date
    var weight:          Double
    var reminderTime:    Date?
    var healthType:      String?
    var healthTarget:    Double?
}

struct DailySnapshotWidget: Codable {
    var id:                 UUID
    var date:               Date
    var listID:             UUID
    var completionFraction: Double
    var completedTaskIDs:   [UUID]
}

// ─────────────────────────────────────────────────────────────
// MARK: ToggleTaskIntent
// ─────────────────────────────────────────────────────────────

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else { return .result() }

        guard let defaults = UserDefaults(suiteName: "group.com.sortyd.sortyd") else {
            return .result()
        }

        guard let raw = defaults.data(forKey: "sortyd_app_data_v3") else {
            return .result()
        }

        guard var appData = try? JSONDecoder().decode(AppDataWidget.self, from: raw) else {
            return .result()
        }

        var found = false
        var taskBecameCompleted = false
        outer: for li in appData.lists.indices {
            for ti in appData.lists[li].tasks.indices {
                if appData.lists[li].tasks[ti].id == uuid {
                    appData.lists[li].tasks[ti].isCompleted.toggle()
                    taskBecameCompleted = appData.lists[li].tasks[ti].isCompleted
                    found = true
                    break outer
                }
            }
        }

        guard found else { return .result() }

        guard let encoded = try? JSONEncoder().encode(appData) else { return .result() }
        defaults.set(encoded, forKey: "sortyd_app_data_v3")
        defaults.synchronize()

        let regularLists = appData.lists.filter { !$0.isArchived && !$0.isTodo }
        let activeList = regularLists.first(where: { $0.id == appData.activeListID })
                      ?? regularLists.first

        if let list = activeList {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            let listSnaps = appData.snapshots.filter { $0.listID == list.id }
            var best = 0, streak = 0
            for s in listSnaps.sorted(by: { $0.date < $1.date }) {
                if s.completionFraction >= 0.8 { streak += 1; best = max(best, streak) }
                else { streak = 0 }
            }

            var monthly = [String: Double]()
            for s in listSnaps { monthly[df.string(from: s.date)] = s.completionFraction }

            let totalWeight = list.tasks.isEmpty ? 0.0
                : list.tasks.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weight }
            let pct = Int((totalWeight * 100).rounded())

            // Persist the last-checked task ID so widgets can always show it.
            // Also preserve health stats from the previous snapshot so they don't disappear on toggle.
            let (prevLastCheckedID, prevCals, prevCalGoal, prevSteps, prevStepGoal): (UUID?, Double?, Double?, Double?, Double?) = {
                guard let existingSnap = defaults.data(forKey: "sortyd_widget_data"),
                      let prev = try? JSONDecoder().decode(WidgetData.self, from: existingSnap)
                else { return (nil, nil, nil, nil, nil) }
                return (prev.lastCheckedTaskID, prev.caloriesBurned, prev.caloriesGoal, prev.stepCount, prev.stepGoal)
            }()

            var lastCheckedID = prevLastCheckedID
            if taskBecameCompleted {
                lastCheckedID = uuid
            } else if lastCheckedID == uuid {
                lastCheckedID = list.tasks
                    .filter { $0.isCompleted && $0.id != uuid }
                    .sorted { $0.createdAt < $1.createdAt }
                    .last?.id
            }

            let snap = WidgetData(
                listName:             list.name.removingLeadingEmojis(),
                listEmoji:            list.emoji,
                completionFraction:   totalWeight,
                completionPercentage: pct,
                tasksDone:            list.tasks.filter { $0.isCompleted }.count,
                tasksTotal:           list.tasks.count,
                tasks: list.tasks.map {
                    WidgetData.WidgetTask(id: $0.id, title: $0.title,
                                         isCompleted: $0.isCompleted, weight: $0.weight)
                },
                streakDays:       best,
                monthlySnapshots: monthly,
                caloriesBurned:   prevCals,
                caloriesGoal:     prevCalGoal,
                stepCount:        prevSteps,
                stepGoal:         prevStepGoal,
                lastCheckedTaskID: lastCheckedID
            )

            if let snapEncoded = try? JSONEncoder().encode(snap) {
                defaults.set(snapEncoded, forKey: "sortyd_widget_data")
                defaults.synchronize()
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: MediumWidgetView
// ─────────────────────────────────────────────────────────────

struct MediumWidgetView: View {
    let data: WidgetData
    @Environment(\.locale) var locale

    private static let maxVisible = 3

    /// Builds the visible task list with these rules:
    /// 1. If ALL tasks are completed → show all of them (never shrink to zero).
    /// 2. Otherwise → always pin one completed task (last-checked or first completed)
    ///    so the user can uncheck it, then fill remaining slots with incomplete tasks.
    private var sortedVisibleTasks: [WidgetData.WidgetTask] {
        let allTasks   = data.tasks
        let incomplete = allTasks.filter { !$0.isCompleted }
        let completed  = allTasks.filter {  $0.isCompleted }

        // Case 1: everything is done — show only the last maxVisible completed tasks
        if incomplete.isEmpty {
            return Array(completed.suffix(Self.maxVisible))
        }

        // Case 2: mix of done/undone — pin one completed task, fill rest with incomplete.
        // If slots remain, fill with other completed tasks so it doesn't shrink.
        let pinnedTask: WidgetData.WidgetTask? = {
            if let id = data.lastCheckedTaskID,
               let t = completed.first(where: { $0.id == id }) { return t }
            return completed.first
        }()

        var result: [WidgetData.WidgetTask] = []
        if let pinned = pinnedTask {
            result.append(pinned)
        }

        // 1. Fill remaining slots with incomplete tasks
        let slotsForIncomplete = Self.maxVisible - result.count
        result += Array(incomplete.prefix(slotsForIncomplete))

        // 2. If we still have space, fill with other completed tasks
        let remainingSlots = Self.maxVisible - result.count
        if remainingSlots > 0 {
            let otherCompleted = completed.filter { t in
                !result.contains(where: { $0.id == t.id })
            }
            result += Array(otherCompleted.suffix(remainingSlots))
        }

        return result
    }

    // `extra` = total tasks minus what is actually shown
    private var extra: Int {
        max(0, data.tasks.count - sortedVisibleTasks.count)
    }

    var body: some View {
        ZStack {
            WTheme.meshGradient

            HStack(spacing: 0) {
                leftColumn
                    .frame(width: 120)

                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
        }
    }

    // MARK: Left — Dashboard Gauges & Stats

    private var leftColumn: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer Ring
                Circle()
                    .stroke(WTheme.bg3, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: data.completionFraction)
                    .stroke(WTheme.arcGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WTheme.secondary.opacity(0.4), radius: 6)

                // Inner Layered Ring (e.g. representation of energy)
                Circle()
                    .stroke(WTheme.bg3.opacity(0.5), lineWidth: 4)
                    .padding(14)
                Circle()
                    .trim(from: 0, to: min(1.0, Double(data.tasksDone) / max(1.0, Double(data.tasksTotal))))
                    .stroke(WTheme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(14)

                VStack(spacing: -2) {
                    Text("\(data.completionPercentage)%")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(WTheme.text0)
                }
            }
            .frame(width: 70, height: 70)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(data.listEmoji)
                    Text(data.listName.removingLeadingEmojis())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(WTheme.text0)
                        .lineLimit(1)
                }
                
                // Mini 5-day Bar Chart
                HStack(spacing: 4) {
                    let points = Array(data.monthlySnapshots.values.prefix(5).reversed())
                    let padded = (0..<5).map { i -> Double in
                        if i < 5 - points.count { return 0.0 }
                        return points[i - (5 - points.count)]
                    }
                    
                    ForEach(0..<5, id: \.self) { i in
                        let p = padded[i]
                        Capsule()
                            .fill(p > 0.8 ? WTheme.primary : (p > 0.4 ? WTheme.secondary : WTheme.secondaryDim))
                            .frame(width: 4, height: max(4, 16 * p))
                            .frame(height: 16, alignment: .bottom)
                    }
                }
            }
        }
    }

    // MARK: Right — Interactive Pills

    private var rightColumn: some View {
        VStack(spacing: 6) {
            ForEach(Array(sortedVisibleTasks.enumerated()), id: \.element.id) { _, task in
                taskPill(task: task)
            }
            Spacer(minLength: 0)

            if extra > 0 {
                Text(String(localized: "+ \(extra) more", locale: locale))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(WTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, 8)
    }

    // MARK: Tactile Pill Task

    @ViewBuilder
    private func taskPill(task: WidgetData.WidgetTask) -> some View {
        Button(intent: {
            let intent = ToggleTaskIntent()
            intent.taskID = task.id.uuidString
            return intent
        }()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? WTheme.primary : WTheme.glassBorder, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if task.isCompleted {
                        Circle()
                            .fill(WTheme.primary.opacity(0.2))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(WTheme.primary)
                    }
                }

                Text(task.title)
                    .font(.system(size: 12, weight: task.isCompleted ? .regular : .bold))
                    .foregroundColor(task.isCompleted ? WTheme.text1 : WTheme.text0)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted, color: WTheme.text1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(WTheme.bg1.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(WTheme.glassBorder, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SortydMediumWidget: Widget {
    let kind = "SortydMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            MediumWidgetView(data: entry.data)
                .environment(\.locale, Locale(identifier: WidgetDataStore.loadLanguage()))
                .containerBackground(for: .widget) { WTheme.bg0 }
        }
        .configurationDisplayName("Dashboard & Tasks")
        .description("Interactive task pills with layered analytics rings.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
