// MARK: - WidgetMedium.swift
// systemMedium — Donut + interactive task checklist
// iOS 17+: tasks toggle directly via ToggleTaskIntent.

import SwiftUI
import WidgetKit
import AppIntents

// ─────────────────────────────────────────────────────────────
// MARK: Mirror models — stored properties ONLY, matching Models.swift exactly
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
        outer: for li in appData.lists.indices {
            for ti in appData.lists[li].tasks.indices {
                if appData.lists[li].tasks[ti].id == uuid {
                    appData.lists[li].tasks[ti].isCompleted.toggle()
                    found = true
                    break outer
                }
            }
        }

        guard found else { return .result() }

        guard let encoded = try? JSONEncoder().encode(appData) else { return .result() }
        defaults.set(encoded, forKey: "sortyd_app_data_v3")
        defaults.synchronize()

        let activeList = appData.lists.first(where: { $0.id == appData.activeListID })
                      ?? appData.lists.first

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

            let snap = WidgetData(
                listName:             list.name,
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
                monthlySnapshots: monthly
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

    private static let maxVisible = 4

    private var sortedVisibleTasks: [WidgetData.WidgetTask] {
        let incomplete = data.tasks.filter { !$0.isCompleted }
        let complete   = data.tasks.filter {  $0.isCompleted }
        return Array((incomplete + complete).prefix(Self.maxVisible))
    }

    private var extra: Int {
        max(0, data.tasks.count - Self.maxVisible)
    }

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
                .frame(width: 100)

            Rectangle()
                .fill(WTheme.border)
                .frame(width: 0.5)
                .padding(.vertical, 10)

            rightColumn
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WTheme.bg0)
    }

    // MARK: Left — donut + streak

    private var leftColumn: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(WTheme.bg3, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: data.completionFraction)
                    .stroke(WTheme.arcGradient,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WTheme.amber.opacity(0.3), radius: 5)
                VStack(spacing: -2) {
                    Text("\(data.completionPercentage)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(WTheme.text0)
                    Text("%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(WTheme.amber)
                }
            }
            .frame(width: 58, height: 58)

            Text(data.listEmoji + " " + data.listName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(WTheme.text1)
                .lineLimit(1)
                .padding(.horizontal, 4)

            if data.streakDays > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(WTheme.amber)
                    Text("\(data.streakDays)d")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(WTheme.amber)
                }
            }

            Text("\(data.tasksDone)/\(data.tasksTotal)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(WTheme.text0)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 6)
    }

    // MARK: Right — sticky header + task list + footer

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── HEADER ───────────────────────────────────────────
            HStack {
                Text("TASKS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(WTheme.text1)
                    .tracking(1.0)
                Spacer()
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 4)
            .layoutPriority(1)

            // ── TASK LIST ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sortedVisibleTasks.enumerated()), id: \.element.id) { idx, task in
                    taskRow(task: task, isLast: idx == sortedVisibleTasks.count - 1)
                }
            }
            .clipped()

            Spacer(minLength: 0)

            // ── FOOTER ────────────────────────────────────────────
            if extra > 0 {
                Text("+ \(extra) more")
                    .font(.system(size: 9))
                    .foregroundColor(WTheme.text2)
                    .padding(.leading, 10)
                    .padding(.top, 4)
                    .layoutPriority(1)
            }
        }
    }

    // MARK: Interactive task row

    @ViewBuilder
    private func taskRow(task: WidgetData.WidgetTask, isLast: Bool) -> some View {
        Button(intent: {
            let intent = ToggleTaskIntent()
            intent.taskID = task.id.uuidString
            return intent
        }()) {
            HStack(spacing: 8) {
                Text(task.title)
                    .font(.system(size: 12, weight: task.isCompleted ? .regular : .medium))
                    .foregroundColor(task.isCompleted ? WTheme.text2 : WTheme.text0)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(task.isCompleted, color: WTheme.text2)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? WTheme.amber : WTheme.border,
                            lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if task.isCompleted {
                        Circle()
                            .fill(WTheme.amber.opacity(0.18))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(WTheme.amber)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if !isLast {
            Rectangle()
                .fill(WTheme.border.opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, 10)
        }
    }
}

struct SortydMediumWidget: Widget {
    let kind = "SortydMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            MediumWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WTheme.bg0 }
        }
        .configurationDisplayName("Tasks Today")
        .description("Check off tasks directly from the widget.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
