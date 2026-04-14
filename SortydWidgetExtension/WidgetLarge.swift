
import SwiftUI
import WidgetKit
import AppIntents
// ToggleTaskIntent + AppDataWidget mirror structs are defined in WidgetMedium.swift

struct LargeWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family

    private var maxTasks: Int { family == .systemLarge ? 5 : 4 }
    private var visibleTasks: [WidgetData.WidgetTask] {
        let incomplete = data.tasks.filter { !$0.isCompleted }
        let complete   = data.tasks.filter {  $0.isCompleted }
        return Array((incomplete + complete).prefix(maxTasks))
    }
    private var extra: Int { max(0, data.tasks.count - maxTasks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .layoutPriority(1)

            progressBar
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Rectangle()
                .fill(WTheme.border)
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            taskList
                .padding(.horizontal, 14)

            Spacer(minLength: 0)

            if family == .systemLarge {
                statsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .padding(.top, 4)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WTheme.bg0)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            // Mini donut
            ZStack {
                Circle().stroke(WTheme.bg3, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: data.completionFraction)
                    .stroke(WTheme.arcGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WTheme.amber.opacity(0.3), radius: 4)
                Text("\(data.completionPercentage)%")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WTheme.amber)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.listEmoji + "  " + data.listName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(WTheme.text0)
                    .lineLimit(1)
                if data.streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(WTheme.amber)
                        Text("\(data.streakDays) day streak")
                            .font(.system(size:10, weight: .semibold))
                            .foregroundColor(WTheme.amber)
                    }
                } else {
                    Text("\(data.tasksDone) of \(data.tasksTotal) done")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WTheme.text1)
                }
            }

            Spacer()

            // ── Health mini-bars (top-right) ──────────────────────────────
            healthMiniStack
        }
    }

    // MARK: Health Mini Stack — calorie + step tanks side-by-side
    // FIX: Always show tanks if goal is non-nil (even if goal == 0)
    // FIX: Removed sparkline fallback entirely

    @ViewBuilder
    private var healthMiniStack: some View {
        let hasCalories = data.caloriesGoal != nil
        let hasSteps    = data.stepGoal     != nil

        if hasCalories || hasSteps {
            HStack(alignment: .bottom, spacing: 6) {
                if hasCalories {
                    miniHealthTank(
                        icon:     "flame.fill",
                        color:    Color(widgetHex: "#FF7043"),
                        current:  data.caloriesBurned ?? 0,
                        goal:     data.caloriesGoal   ?? 1,
                        label:    valueLabel(data.caloriesBurned ?? 0, unit: "cal")
                    )
                }
                if hasSteps {
                    miniHealthTank(
                        icon:     "figure.walk",
                        color:    Color(widgetHex: "#4FC3F7"),
                        current:  data.stepCount ?? 0,
                        goal:     data.stepGoal  ?? 1,
                        label:    valueLabel(data.stepCount ?? 0, unit: "steps")
                    )
                }
            }
        } else {
            // FIX: No fallback sparkline — show nothing when no health data
            EmptyView()
        }
    }

    /// Compact vertical fill-tank — static (no animation) for widget context.
    private func miniHealthTank(
        icon: String,
        color: Color,
        current: Double,
        goal: Double,
        label: String
    ) -> some View {
        let progress = goal > 0 ? min(current / goal, 1.0) : 0
        let tankW: CGFloat = 28
        let tankH: CGFloat = 44

        return VStack(spacing: 3) {
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(WTheme.bg3)
                    .frame(width: tankW, height: tankH)

                // Fill — grows from bottom
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(geo.size.height * progress, progress > 0 ? 4 : 0))
                    }
                }
                .frame(width: tankW, height: tankH)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                // Glow overlay
                if progress > 0 {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.10))
                        .frame(width: tankW, height: tankH)
                }

                // Icon — dim base layer
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(WTheme.text0.opacity(0.18))

                // Icon — lit where filled
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: color.opacity(0.55), radius: 3)
                    .mask(
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .frame(height: geo.size.height * progress)
                            }
                        }
                        .frame(width: tankW, height: tankH)
                    )
            }
            .frame(width: tankW, height: tankH)
            // FIX: Green checkmark badge at bottom-right when goal is reached
            .overlay(alignment: .bottomTrailing) {
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .background(Circle().fill(WTheme.bg0).padding(1))
                        .offset(x: 4, y: 4)
                }
            }

            // Value label below tank
            Text(label)
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .foregroundColor(WTheme.text1)
                .lineLimit(1)
                .frame(width: tankW + 4)
        }
    }

    /// Format a raw value into a compact string with unit.
    private func valueLabel(_ value: Double, unit: String) -> String {
        if unit == "steps" {
            if value >= 1000 {
                return String(format: "%.1fk", value / 1000)
            }
            return "\(Int(value))"
        }
        // calories
        return "\(Int(value))"
    }

    // MARK: Progress bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WTheme.bg3)
                        .frame(height: 6)
                    Capsule()
                        .fill(WTheme.barGradient)
                        .frame(width: max(geo.size.width * data.completionFraction, 0), height: 6)
                        .shadow(color: WTheme.amber.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 6)

            HStack {
                Text(motivationLabel)
                    .font(.system(size: 9))
                    .foregroundColor(WTheme.text2)
                Spacer()
                Text("\(data.tasksDone)/\(data.tasksTotal) tasks")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(WTheme.text1)
            }
        }
    }

    // MARK: Interactive task list

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { idx, task in

                Button(intent: {
                    let intent = ToggleTaskIntent()
                    intent.taskID = task.id.uuidString
                    return intent
                }()) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium))
                            .foregroundColor(task.isCompleted ? WTheme.text2 : WTheme.text0)
                            .lineLimit(1)
                            .strikethrough(task.isCompleted, color: WTheme.text2)

                        Spacer()

                        ZStack {
                            Circle()
                                .strokeBorder(
                                    task.isCompleted ? WTheme.amber : WTheme.border,
                                    lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if task.isCompleted {
                                Circle()
                                    .fill(WTheme.amber.opacity(0.15))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(WTheme.amber)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < visibleTasks.count - 1 {
                    Rectangle()
                        .fill(WTheme.border.opacity(0.6))
                        .frame(height: 0.5)
                }
            }

            if extra > 0 {
                Text("+ \(extra) more — open app to see all")
                    .font(.system(size: 9))
                    .foregroundColor(WTheme.text2)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statPill(value: "\(data.tasksDone)/\(data.tasksTotal)",
                     label: "Done", icon: "checkmark.circle.fill", color: WTheme.amber)
            Spacer()
            Rectangle().fill(WTheme.border).frame(width: 0.5, height: 28)
            Spacer()
            statPill(value: "\(data.streakDays)d",
                     label: "Streak", icon: "flame.fill", color: WTheme.coral)
            Spacer()
            Rectangle().fill(WTheme.border).frame(width: 0.5, height: 28)
            Spacer()
            statPill(value: "\(data.completionPercentage)%",
                     label: "Complete", icon: "chart.pie.fill", color: WTheme.amber)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WTheme.bg1)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(WTheme.border, lineWidth: 0.5))
        )
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(WTheme.text0)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(WTheme.text1)
        }
        .frame(maxWidth: .infinity)
    }

    private var motivationLabel: String {
        switch data.completionFraction {
        case 0:       return "Let's get started"
        case ..<0.25: return "Great beginning"
        case ..<0.5:  return "Nice momentum"
        case ..<0.75: return "More than halfway!"
        case ..<1.0:  return "Almost there!"
        default:      return "🎉 Perfect day!"
        }
    }
}

// MARK: - Widget

struct SortydLargeWidget: Widget {
    let kind = "SortydLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SortydProvider()) { entry in
            LargeWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WTheme.bg0 }
        }
        .configurationDisplayName("Full Task List")
        .description("Check off tasks directly from the widget.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    SortydLargeWidget()
} timeline: {
    SortydEntry(date: .now, data: WidgetData(
        listName: "My Tasks",
        listEmoji: "📋",
        completionFraction: 0.4,
        completionPercentage: 40,
        tasksDone: 2,
        tasksTotal: 5,
        tasks: [
            .init(id: UUID(), title: "Buy groceries",   isCompleted: true,  weight: 1.0),
            .init(id: UUID(), title: "Morning workout", isCompleted: true,  weight: 1.0),
            .init(id: UUID(), title: "Reply to emails", isCompleted: false, weight: 1.0),
            .init(id: UUID(), title: "Read 30 minutes", isCompleted: false, weight: 1.0),
            .init(id: UUID(), title: "Call mom",        isCompleted: false, weight: 1.0),
        ],
        streakDays: 3,
        monthlySnapshots: [:],
        // Health preview data
        caloriesBurned: 312,
        caloriesGoal:   500,
        stepCount:      7400,
        stepGoal:       10000
    ))
}
