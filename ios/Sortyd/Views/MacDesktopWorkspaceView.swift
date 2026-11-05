// MARK: - MacDesktopWorkspaceView.swift
// Sortyd for macOS — Impeccable Glassmorphic Desktop Command Center, Analytics Studio & MenuBarExtra Popover
// Crafted with zero-shift desktop task rows, clean clipped glass elevation (no straight shadow lines),
// interactive Daily Completion Line Graph, and deep "Where You're Lacking" diagnostic analytics.

#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Static Zero-Lag Ambient Glass Backdrop

struct SortydGlassBackdrop: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: themeManager.isDark
                    ? [
                        Color(red: 0.035, green: 0.045, blue: 0.082),
                        Color(red: 0.052, green: 0.068, blue: 0.118),
                        Color(red: 0.028, green: 0.038, blue: 0.072)
                    ]
                    : [
                        Color(red: 0.94, green: 0.96, blue: 0.99),
                        Color(red: 0.90, green: 0.93, blue: 0.98),
                        Color(red: 0.95, green: 0.96, blue: 0.99)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient cyan orb (static GPU-cached composition — 0% idle CPU/GPU)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.accent.opacity(themeManager.isDark ? 0.18 : 0.12),
                            Theme.accent.opacity(0.02),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 320
                    )
                )
                .frame(width: 640, height: 460)
                .offset(x: -210, y: -150)

            // Ambient indigo orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.indigo.opacity(themeManager.isDark ? 0.20 : 0.12),
                            Theme.indigo.opacity(0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 340
                    )
                )
                .frame(width: 620, height: 500)
                .offset(x: 250, y: 140)

            // Subtle coral warmth orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.coral.opacity(themeManager.isDark ? 0.09 : 0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 240
                    )
                )
                .frame(width: 440, height: 340)
                .offset(x: 90, y: -180)
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

// MARK: - Glassmorphic Card Modifier (Clean Clipped Elevation — Zero Straight Shadow Lines)

struct SortydMacGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(
                        themeManager.isDark
                            ? Color(red: 0.075, green: 0.095, blue: 0.155).opacity(0.72)
                            : Color.white.opacity(0.76)
                    )
                    if let tint {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(themeManager.isDark ? 0.13 : 0.09),
                                    tint.opacity(themeManager.isDark ? 0.03 : 0.02),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    // Smooth vertical top sheen (never stops at center so there is never a straight diagonal line)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(themeManager.isDark ? 0.07 : 0.42),
                                Color.white.opacity(themeManager.isDark ? 0.015 : 0.10),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .clipShape(shape)
                .shadow(
                    color: Color.black.opacity(themeManager.isDark ? 0.24 : 0.06),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            (tint ?? Color.white).opacity(themeManager.isDark ? 0.26 : 0.55),
                            Color.white.opacity(themeManager.isDark ? 0.08 : 0.22),
                            Color.white.opacity(themeManager.isDark ? 0.04 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
    }
}

extension View {
    func sortydMacGlass(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        modifier(SortydMacGlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Clips a ScrollView and feathers its top 6pt so scrolled cards glide smoothly underneath a pinned top header without overlapping.
    func sortydScrollUnderneath() -> some View {
        self
            .clipped()
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 6)
                    Color.black
                }
            )
    }
}

// MARK: - Desktop Navigation Section

enum MacWorkspaceSection: Int, CaseIterable, Identifiable {
    case today = 0
    case weeklyPlanner = 4
    case lists = 1
    case analytics = 2
    case coach = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today's Focus"
        case .weeklyPlanner: return "Weekly Planner"
        case .lists: return "Habit Lists"
        case .analytics: return "Analytics & Gaps"
        case .coach: return "AI Habit Coach"
        }
    }

    var subtitle: String {
        switch self {
        case .today: return "Checklist, line trend & diagnostics"
        case .weeklyPlanner: return "5-panel weekly architecture"
        case .lists: return "Create, reorder & manage lists"
        case .analytics: return "Daily line graph & where you lack"
        case .coach: return "Personalized AI insights & recaps"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sparkles.rectangle.stack.fill"
        case .weeklyPlanner: return "calendar.day.timeline.left"
        case .lists: return "checklist"
        case .analytics: return "chart.xyaxis.line"
        case .coach: return "brain.head.profile"
        }
    }
}

// MARK: - Daily Trend Point Model for Line Graphs

struct MacDailyTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let fullDateLabel: String
    let completionFraction: Double
    let completedCount: Int
    let totalCount: Int

    var percentage: Int {
        Int((min(max(completionFraction, 0), 1) * 100).rounded())
    }
}

// MARK: - Habit Gap / Lack Diagnostic Item

struct MacHabitLackItem: Identifiable {
    let id: UUID
    let task: SortydTask
    let listID: UUID
    let listName: String
    let listEmoji: String
    let completionRate: Double     // 0.0 ... 1.0 over selected period
    let missRate: Double           // 1.0 - completionRate
    let missedDaysCount: Int
    let totalDaysCount: Int
    let daysSinceLastDone: Int
    let last7DaysHits: [Bool]      // Oldest -> Today (7 booleans)
    let scoreDragPercent: Int      // How much % of its list this task represents

    var completionPct: Int { Int((completionRate * 100).rounded()) }
    var missPct: Int { Int((missRate * 100).rounded()) }
}

// MARK: - Main macOS Desktop Workspace View

struct MacDesktopWorkspaceView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var auth = AuthService.shared
    @StateObject private var hk = HealthKitManager.shared

    @State private var activeSection: MacWorkspaceSection = .today
    @State private var quickTaskTitle: String = ""
    @State private var showAccountSheet = false
    @State private var showAddTaskSheet = false
    @State private var showNewListSheet = false
    @State private var newListName = ""
    @State private var newListEmoji = "⚡️"
    @State private var editingTask: SortydTask? = nil
    @State private var editingTaskListID: UUID? = nil
    @State private var hoveredListID: UUID? = nil

    // Line Graph Horizon on Today Command Center
    @State private var todayGraphDays: Int = 7

    private let quickEmojis = ["⚡️", "🌅", "💪", "📚", "🧘", "🎯", "💧", "🚀", "🌿", "🧠"]

    private var activeList: TaskList? { vm.activeList }
    private var regularLists: [TaskList] {
        vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
    }

    private var liveCompletionPct: Int {
        guard let list = activeList else { return 0 }
        let hv = hk.healthValues(for: list.tasks)
        return Int((list.completionFraction(healthValues: hv) * 100).rounded())
    }

    private var liveCompletionFraction: Double {
        guard let list = activeList else { return 0 }
        let hv = hk.healthValues(for: list.tasks)
        return list.completionFraction(healthValues: hv)
    }

    var body: some View {
        GeometryReader { rootGeo in
            let sidebarWidth: CGFloat = rootGeo.size.width >= 1080 ? 248 : (rootGeo.size.width >= 820 ? 216 : 194)
            let isCompactHeight = rootGeo.size.height < 670

            ZStack {
                SortydGlassBackdrop()

                HStack(spacing: 12) {
                    // ── Left Frosted Glass Sidebar ──
                    sidebarColumn(isCompactHeight: isCompactHeight, sidebarWidth: sidebarWidth)
                        .frame(width: sidebarWidth)

                    // ── Main Desktop Workspace Canvas ──
                    mainWorkspaceColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if let recap = vm.dailyRecap {
                    DailyRecapBanner(data: recap) {
                        vm.dailyRecap = nil
                    }
                    .frame(maxWidth: 520, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
                    .zIndex(100)
                }
            }
        }
        .onChange(of: vm.selectedTab) { _, newTab in
            if let mapped = MacWorkspaceSection(rawValue: newTab), activeSection != mapped {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    activeSection = mapped
                }
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet()
                .environmentObject(vm)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showAddTaskSheet) {
            if let listID = activeList?.id ?? vm.todoList?.id {
                AddTaskSheet(listID: listID)
                    .environmentObject(vm)
            }
        }
        .sheet(item: $editingTask) { task in
            if let listID = editingTaskListID ?? activeList?.id {
                EditTaskSheet(task: task, listID: listID)
                    .environmentObject(vm)
            }
        }
        .sheet(isPresented: $showNewListSheet) {
            quickNewListSheet
        }
    }

    // MARK: - Left Sidebar Column

    private func sidebarColumn(isCompactHeight: Bool, sidebarWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 11) {
            // Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 5) {
                        Text("Sortyd")
                            .font(.system(size: 17.5, weight: .black, design: .rounded))
                            .foregroundColor(Theme.text0)

                        Text("MAC")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.18)))
                            .foregroundColor(Theme.accent)
                    }

                    Text(auth.isAuthenticated ? "sortyd.com • Cloud Synced" : "Local Workspace • Offline Ready")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text2)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .fixedSize(horizontal: false, vertical: true)

            // Primary Navigation Sections
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.localized("WORKSPACE"))
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Theme.text2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 1)

                ForEach(MacWorkspaceSection.allCases) { section in
                    sidebarNavButton(section, showSubtitle: !isCompactHeight && sidebarWidth >= 210)
                }
            }
            .padding(.horizontal, 8)
            .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.white.opacity(themeManager.isDark ? 0.07 : 0.18))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Habit Lists Switcher in Sidebar (Strictly Clipped so it NEVER overlaps WORKSPACE or Account Footer)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vm.localized("YOUR HABIT LISTS"))
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(Theme.text2)
                        .lineLimit(1)

                    Spacer()

                    Button(action: { showNewListSheet = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(vm.localized("New"))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent.opacity(0.16)))
                        .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(regularLists) { list in
                            sidebarListRow(list)
                        }

                        if let todo = vm.todoList {
                            sidebarListRow(todo, isInbox: true)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .sortydScrollUnderneath()
            }
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Color.white.opacity(themeManager.isDark ? 0.08 : 0.18))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Pinned Non-Overlapping Account & Cloud Sync Dock Card ("Sortyd Team / Synced via sortyd.com")
            sidebarAccountFooter
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
                .zIndex(10)
        }
        .sortydMacGlass(cornerRadius: 24)
    }

    private func sidebarNavButton(_ section: MacWorkspaceSection, showSubtitle: Bool = true) -> some View {
        let isSelected = activeSection == section
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                activeSection = section
                if section.rawValue <= 3 {
                    vm.selectedTab = section.rawValue
                }
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Theme.accent.opacity(0.22) : Color.white.opacity(0.04))
                        .frame(width: 28, height: 28)

                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? Theme.accent : Theme.text1)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.localized(section.title))
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? Theme.text0 : Theme.text1)
                        .lineLimit(1)

                    if showSubtitle {
                        Text(vm.localized(section.subtitle))
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundColor(Theme.text2)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, showSubtitle ? 6 : 5)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.14) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Theme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarListRow(_ list: TaskList, isInbox: Bool = false) -> some View {
        let isSelected = vm.activeListID == list.id && (activeSection == .today)
        let isHovered = hoveredListID == list.id
        let hv = hk.healthValues(for: list.tasks)
        let fraction = list.completionFraction(healthValues: hv)
        let doneCount = list.tasks.filter(\.isCompleted).count
        let totalCount = list.tasks.count

        return Button(action: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                vm.setActiveList(list)
                activeSection = .today
                vm.selectedTab = 0
            }
        }) {
            HStack(spacing: 10) {
                Text(isInbox ? "📥" : list.emoji)
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Theme.accent.opacity(0.2) : Color.white.opacity(0.05))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(isInbox ? vm.localized("TO DO Inbox") : list.cleanName)
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? Theme.text0 : Theme.text1)
                        .lineLimit(1)

                    Text("\(doneCount)/\(totalCount) \(vm.localized("completed"))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.text2)
                        .monospacedDigit()
                }

                Spacer()

                // Mini Completion Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2.5)
                        .frame(width: 22, height: 22)

                    Circle()
                        .trim(from: 0, to: CGFloat(fraction))
                        .stroke(
                            fraction >= 1.0 ? Theme.success : Theme.accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 22, height: 22)

                    Text("\(Int((fraction * 100).rounded()))")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text1)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? Theme.accent.opacity(0.14)
                            : (isHovered ? Color.white.opacity(0.05) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Theme.accent.opacity(0.35) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredListID = hovering ? list.id : nil
        }
    }

    private var sidebarAccountFooter: some View {
        VStack(spacing: 7) {
            Button(action: { showAccountSheet = true }) {
                HStack(spacing: 9) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.38), Theme.indigo.opacity(0.32)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1))

                        if auth.isSyncing {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: auth.isAuthenticated ? "icloud.fill" : "person.crop.circle.badge.plus")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(auth.isAuthenticated ? Theme.accent : Theme.text1)
                                .frame(width: 34, height: 34)
                        }

                        if auth.isAuthenticated {
                            Circle()
                                .fill(Theme.success)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let user = auth.currentUser, auth.isAuthenticated {
                            Text(user.name.isEmpty ? user.email : user.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text0)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text("Synced via sortyd.com")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } else {
                            Text(vm.localized("Sign In to Cloud Sync"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text0)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text("Sync via sortyd.com")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.accent)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.accent.opacity(themeManager.isDark ? 0.14 : 0.10),
                                    Theme.indigo.opacity(themeManager.isDark ? 0.08 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Theme.accent.opacity(0.45), Theme.indigo.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                ThemeToggleButton()
                    .environmentObject(themeManager)

                Spacer(minLength: 4)

                if auth.isAuthenticated {
                    Button(action: {
                        Task { await vm.syncWithCloud() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(vm.localized("Sync Now"))
                                .font(.system(size: 10.5, weight: .bold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.30), lineWidth: 0.75))
                        .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Main Workspace Column

    @ViewBuilder
    private var mainWorkspaceColumn: some View {
        switch activeSection {
        case .today:
            todayCommandCenterView
        case .weeklyPlanner:
            VStack(spacing: 10) {
                sectionTopBanner(
                    title: vm.localized("Weekly Planner"),
                    subtitle: vm.localized("Design your week's focus theme, must-do priorities, and daily blocks"),
                    icon: "calendar.day.timeline.left"
                )
                .zIndex(20)

                WeeklyPlannerSection()
                    .environmentObject(vm)
                    .environmentObject(themeManager)
                    .sortydMacGlass(cornerRadius: 24)
                    .clipped()
            }
        case .lists:
            ListManagementView()
                .environmentObject(vm)
                .environmentObject(themeManager)
                .sortydMacGlass(cornerRadius: 24)
                .clipped()
        case .analytics:
            MacDesktopAnalyticsStudioView(
                onEditTask: { task, listID in
                    editingTaskListID = listID
                    editingTask = task
                }
            )
            .environmentObject(vm)
            .environmentObject(themeManager)
        case .coach:
            AICoachView()
                .environmentObject(vm)
                .environmentObject(themeManager)
                .sortydMacGlass(cornerRadius: 24)
                .clipped()
        }
    }

    private func sectionTopBanner(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text0)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text2)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .sortydMacGlass(cornerRadius: 18)
    }

    // MARK: - Today Command Center (Adaptive Multi-Screen & Aspect-Ratio Layout with Underneath Scrolling)

    private var todayCommandCenterView: some View {
        VStack(spacing: 10) {
            // Pinned Top Glass Command Bar (ScrollViews glide cleanly underneath)
            topDesktopCommandBar
                .zIndex(20)

            GeometryReader { geo in
                let isTwoColumn = geo.size.width >= 700
                let leftWidth = max(320, min(geo.size.width * 0.49, geo.size.width - 330))
                let rightWidth = max(310, geo.size.width - leftWidth - 12)

                if isTwoColumn {
                    HStack(alignment: .top, spacing: 12) {
                        // Middle/Left Column: Scrolls cleanly UNDERNEATH topDesktopCommandBar
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                desktopHeroCard
                                desktopTaskChecklistCard
                                desktopWhereYouLackSummaryCard
                            }
                            .padding(.horizontal, 3)
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        }
                        .sortydScrollUnderneath()
                        .frame(width: leftWidth)

                        // Right Column: Scrolls cleanly UNDERNEATH topDesktopCommandBar
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                desktopHeatmapCard
                                desktopDailyCompletionLineGraphCard
                                if rightWidth >= 360 {
                                    HStack(alignment: .top, spacing: 10) {
                                        desktopAllListsMatrixCard
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                        desktopWeeklyFocusPreviewCard
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    }
                                } else {
                                    desktopAllListsMatrixCard
                                    desktopWeeklyFocusPreviewCard
                                }
                            }
                            .padding(.horizontal, 3)
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        }
                        .sortydScrollUnderneath()
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Compact / Split-Screen / Narrow Aspect-Ratio Single-Column Scroll (Underneath Top Bar)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            desktopHeroCard
                            desktopTaskChecklistCard
                            desktopHeatmapCard
                            desktopDailyCompletionLineGraphCard
                            HStack(alignment: .top, spacing: 10) {
                                desktopAllListsMatrixCard
                                    .frame(maxWidth: .infinity, alignment: .top)
                                desktopWeeklyFocusPreviewCard
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                            desktopWhereYouLackSummaryCard
                        }
                        .padding(.horizontal, 3)
                        .padding(.top, 4)
                        .padding(.bottom, 14)
                    }
                    .sortydScrollUnderneath()
                }
            }
        }
    }

    private var topDesktopCommandBar: some View {
        HStack(spacing: 10) {
            // Active List Badge
            if let list = activeList {
                HStack(spacing: 9) {
                    Text(list.isTodo ? "📥" : list.emoji)
                        .font(.system(size: 19))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.accent.opacity(0.16))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(list.isTodo ? vm.localized("TO DO Inbox") : list.cleanName)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Theme.text0)
                            .lineLimit(1)

                        Text(vm.dateFormatter(format: "EEEE, MMMM d").string(from: Date()))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.text2)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
            }

            Spacer(minLength: 6)

            // Inline Desktop Quick-Add Bar (Flexible width for all screen sizes)
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)

                TextField(
                    activeList.map { "Quick add habit to \($0.cleanName)..." } ?? "Quick add habit...",
                    text: $quickTaskTitle
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text0)
                .onSubmit {
                    submitQuickTask()
                }

                if !quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submitQuickTask) {
                        Text(vm.localized("Add"))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(Theme.accent))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minWidth: 160, maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )

            // Detailed Add Task Modal Button
            Button(action: { showAddTaskSheet = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(vm.localized("With Reminder / Health"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.accent.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.38), lineWidth: 1)
                        )
                )
                .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .sortydMacGlass(cornerRadius: 16)
    }

    private var desktopHeroCard: some View {
        let doneCount = activeList?.tasks.filter(\.isCompleted).count ?? 0
        let totalCount = activeList?.tasks.count ?? 0
        let leftCount = max(0, totalCount - doneCount)

        return HStack(spacing: 16) {
            // Left: Compact Tabular Completion Readout
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(liveCompletionPct == 100 ? Theme.success : Theme.accent)
                        .frame(width: 6, height: 6)
                    Text((activeList?.cleanName ?? "TODAY").uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.4)
                        .foregroundColor(Theme.accent)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(liveCompletionPct)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.accent)
                }

                Text(liveCompletionPct == 100 ? vm.localized("All goals completed today!") : "\(doneCount) \(vm.localized("done")) · \(leftCount) \(vm.localized("remaining today"))")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.text2)
            }

            Spacer()

            // Center: Compact Orbital Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                    .frame(width: 62, height: 62)

                Circle()
                    .trim(from: 0, to: CGFloat(liveCompletionFraction))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent, Theme.indigo, Theme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 62, height: 62)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: liveCompletionFraction)

                VStack(spacing: 0) {
                    Text("\(doneCount)/\(totalCount)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .monospacedDigit()
                    Text(vm.localized("TASKS"))
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(Theme.text2)
                }
            }

            // Right: Compact Streak Pillar
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("🔥")
                        .font(.system(size: 17))
                    Text("\(vm.cachedBestStreak)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .monospacedDigit()
                }

                Text(vm.localized("DAY STREAK"))
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(Theme.text2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.accent)
    }

    // MARK: - Zero-Shift Desktop Task Checklist Card

    private var desktopTaskChecklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text(activeList?.isTodo == true ? vm.localized("INBOX TASKS") : vm.localized("TODAY'S HABIT CHECKLIST"))
                        .font(.system(size: 10.5, weight: .heavy))
                        .tracking(1.3)
                        .foregroundColor(Theme.text1)
                }

                Spacer()

                Text(vm.localized("Click checkbox or row to complete"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.text2)

                Button(action: { showAddTaskSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text(vm.localized("Add Task"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.16)))
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if let list = activeList, !list.tasks.isEmpty {
                VStack(spacing: 5) {
                    ForEach(list.tasks) { task in
                        MacDesktopTaskRow(
                            task: task,
                            hk: hk,
                            isTodoStyle: list.isTodo,
                            onToggle: {
                                vm.toggleTask(task)
                            },
                            onEdit: {
                                editingTaskListID = list.id
                                editingTask = task
                            },
                            onDeleteConfirmed: {
                                vm.deleteTask(task, from: list.id)
                            }
                        )
                        .environmentObject(vm)
                        .environmentObject(themeManager)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.accent)
                    Text(vm.localized("No tasks in this list yet"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)
                    Text(vm.localized("Type in the Quick Add bar above or click Add Task to build your routine."))
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(14)
        .sortydMacGlass(cornerRadius: 18)
    }

    // MARK: - Daily Completion Line Graph Card (Compact & Date-Based, Directly Below Consistency Heatmap)

    private var todayLineGraphPoints: [MacDailyTrendPoint] {
        guard let list = activeList else { return [] }
        return Self.buildDailyTrendPoints(
            for: [list],
            snapshots: vm.snapshots,
            hk: hk,
            daysCount: todayGraphDays,
            locale: vm.appLanguage.locale
        )
    }

    private var desktopDailyCompletionLineGraphCard: some View {
        let points = todayLineGraphPoints
        let avgPct: Int = {
            guard !points.isEmpty else { return 0 }
            let sum = points.map(\.completionFraction).reduce(0, +)
            return Int(((sum / Double(points.count)) * 100).rounded())
        }()
        let hitTargetDays = points.filter { $0.completionFraction >= 0.8 }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.localized("DAILY COMPLETION LINE GRAPH"))
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(1.3)
                            .foregroundColor(Theme.text1)
                        Text("\(activeList?.cleanName ?? "Active List") • \(avgPct)% avg • \(hitTargetDays)/\(points.count) dates ≥ 80%")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                }

                Spacer()

                // Horizon Switcher: 7D / 14D / 30D
                HStack(spacing: 3) {
                    ForEach([7, 14, 30], id: \.self) { days in
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                todayGraphDays = days
                            }
                        }) {
                            Text("\(days)D")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(todayGraphDays == days ? Theme.accent : Color.white.opacity(0.05))
                                )
                                .foregroundColor(todayGraphDays == days ? .black : Theme.text2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            MacInteractiveDailyLineChart(
                points: points,
                targetFraction: 0.80,
                chartHeight: 84
            )

            HStack {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                        Text(vm.localized("Completion % by Date"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }

                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.success.opacity(0.75))
                            .frame(width: 10, height: 2)
                        Text(vm.localized("80% Target"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        activeSection = .analytics
                        vm.selectedTab = 2
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(vm.localized("Deep Analysis & Gaps"))
                            .font(.system(size: 10.5, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.accent)
    }

    // MARK: - "Where You're Lacking" Quick Diagnostic Card on Today's Focus

    private var activeListLackItems: [MacHabitLackItem] {
        guard let list = activeList else { return [] }
        return Self.computeLackDiagnostics(
            for: [list],
            snapshots: vm.snapshots,
            daysCount: 14
        )
    }

    private var desktopWhereYouLackSummaryCard: some View {
        let items = activeListLackItems
        let laggingItems = items.filter { !$0.task.isCompleted || $0.completionRate < 0.85 }
        let topLagging = Array(laggingItems.prefix(2))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Theme.warning)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.localized("WHERE YOU'RE LACKING • GAP DIAGNOSTIC"))
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(1.3)
                            .foregroundColor(Theme.text1)
                        Text(topLagging.isEmpty
                             ? vm.localized("Every habit in this list is on track above 85% consistency!")
                             : vm.localized("Highest-drag habits pulling down your daily completion score"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        activeSection = .analytics
                        vm.selectedTab = 2
                    }
                }) {
                    Text(vm.localized("Full Report →"))
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if topLagging.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.success)
                    Text(vm.localized("Zero consistency bottlenecks detected in this list. Keep the streak alive!"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Theme.text1)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.success.opacity(0.10))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(topLagging) { gap in
                        HStack(spacing: 8) {
                            // Status badge
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill((gap.task.isCompleted ? Theme.accent : Theme.warning).opacity(0.16))
                                    .frame(width: 28, height: 26)
                                Text("\(gap.completionPct)%")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                    .foregroundColor(gap.task.isCompleted ? Theme.accent : Theme.warning)
                                    .monospacedDigit()
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(gap.task.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.text0)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text("Missed \(gap.missedDaysCount)/\(gap.totalDaysCount)d")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.coral)
                                    Text("•")
                                        .foregroundColor(Theme.text2)
                                    Text("-\(gap.scoreDragPercent)% list drag")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.text2)
                                }
                            }

                            Spacer()

                            // 7-Day mini spark dots
                            HStack(spacing: 2.5) {
                                ForEach(Array(gap.last7DaysHits.enumerated()), id: \.offset) { _, hit in
                                    Circle()
                                        .fill(hit ? Theme.accent : Color.white.opacity(0.12))
                                        .frame(width: 5.5, height: 5.5)
                                }
                            }

                            if !gap.task.isCompleted {
                                Button(action: {
                                    vm.toggleTask(gap.task)
                                }) {
                                    Text(vm.localized("Complete"))
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3.5)
                                        .background(Capsule().fill(Theme.accent.opacity(0.18)))
                                        .foregroundColor(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.warning)
    }

    private var desktopHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text(vm.localized("CONSISTENCY HEATMAP CALENDAR"))
                        .font(.system(size: 10.5, weight: .heavy))
                        .tracking(1.3)
                        .foregroundColor(Theme.text1)
                }
                Spacer()
                Text(vm.dateFormatter(format: "MMMM yyyy").string(from: Date()))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.text2)
            }

            if let id = activeList?.id {
                HeatmapCalendarView(listID: id)
                    .environmentObject(vm)
                    .frame(height: 110)
            } else {
                PlaceholderCalendarView()
                    .frame(height: 100)
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18)
    }

    private var desktopAllListsMatrixCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.indigo)
                    Text(vm.localized("ALL LISTS PULSE"))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Theme.text1)
                }
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        activeSection = .lists
                        vm.selectedTab = 1
                    }
                }) {
                    Text(vm.localized("Manage →"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                ForEach(regularLists) { l in
                    let hv = hk.healthValues(for: l.tasks)
                    let frac = l.completionFraction(healthValues: hv)
                    let pct = Int((frac * 100).rounded())
                    let isCurrent = vm.activeListID == l.id

                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            vm.setActiveList(l)
                        }
                    }) {
                        VStack(spacing: 4) {
                            HStack {
                                Text("\(l.emoji) \(l.cleanName)")
                                    .font(.system(size: 11.5, weight: isCurrent ? .bold : .semibold))
                                    .foregroundColor(Theme.text0)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(pct)%")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(frac >= 1.0 ? Theme.success : Theme.accent)
                                    .monospacedDigit()
                            }

                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.accent, Theme.indigo],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(5, barGeo.size.width * CGFloat(frac)), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isCurrent ? Theme.accent.opacity(0.11) : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isCurrent ? Theme.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.indigo)
    }

    private var desktopWeeklyFocusPreviewCard: some View {
        let northStar = vm.weeklyPlan.northStar.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = vm.weeklyPlan.weeklyTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        let focusTheme = !northStar.isEmpty ? northStar : theme
        let mustDos = vm.weeklyPlan.mustDoTasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.coral)
                    Text(vm.localized("WEEKLY COMPASS"))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Theme.text1)
                }
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        activeSection = .weeklyPlanner
                    }
                }) {
                    Text(vm.localized("Planner →"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            Text(focusTheme.isEmpty ? vm.localized("Set your North Star theme for this week in the Weekly Planner.") : focusTheme)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(focusTheme.isEmpty ? Theme.text2 : Theme.text0)
                .lineLimit(2)

            if !mustDos.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(mustDos.prefix(3).enumerated()), id: \.offset) { idx, goal in
                        HStack(spacing: 6) {
                            Text("\(idx + 1)")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.black)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Theme.accent))
                            Text(goal)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(Theme.text1)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.coral)
    }

    // MARK: - Quick New List Sheet

    private var quickNewListSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(vm.localized("Create New Habit List"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text0)

                Spacer()

                Button {
                    showNewListSheet = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(vm.localized("Cancel"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Theme.text1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.bg2).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.localized("CHOOSE ICON"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.text2)

                HStack(spacing: 6) {
                    ForEach(quickEmojis, id: \.self) { emoji in
                        Button(action: { newListEmoji = emoji }) {
                            Text(emoji)
                                .font(.system(size: 18))
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(newListEmoji == emoji ? Theme.accent.opacity(0.25) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .strokeBorder(newListEmoji == emoji ? Theme.accent : Color.clear, lineWidth: 1.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.localized("LIST NAME"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.text2)

                TextField(vm.localized("e.g. Deep Work Routine, Evening Wind-down"), text: $newListName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .onSubmit {
                        createNewList()
                    }
            }

            HStack(spacing: 10) {
                Button {
                    showNewListSheet = false
                } label: {
                    Text(vm.localized("Cancel"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Theme.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.bg2)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.8))
                        )
                }
                .buttonStyle(.plain)

                Button(action: createNewList) {
                    Text(vm.localized("Create List"))
                        .font(.system(size: 13.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.bg0)
    }

    // MARK: - Actions

    private func submitQuickTask() {
        let trimmed = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let listID = activeList?.id ?? vm.todoList?.id else { return }
        let detected = HealthTaskType.detect(from: trimmed)
        let target: Double? = detected != .none ? AppViewModel.extractNumericTarget(from: trimmed, type: detected) : nil
        vm.addTask(
            to: listID,
            title: trimmed,
            healthType: detected != .none ? detected.rawValue : nil,
            healthTarget: target
        )
        quickTaskTitle = ""
    }

    private func createNewList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        vm.addList(name: trimmed, emoji: newListEmoji)
        if let created = vm.lists.last {
            vm.setActiveList(created)
        }
        newListName = ""
        showNewListSheet = false
    }

    // MARK: - Shared Analytics Builders

    static func buildDailyTrendPoints(
        for lists: [TaskList],
        snapshots: [DailySnapshot],
        hk: HealthKitManager,
        daysCount: Int,
        locale: Locale
    ) -> [MacDailyTrendPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let listIDs = Set(lists.map(\.id))

        let shortFmt = DateFormatter()
        shortFmt.locale = locale
        // Always format X-axis labels as calendar dates (e.g., "Oct 30", "Nov 1", "Nov 5") instead of weekday names
        shortFmt.dateFormat = "MMM d"

        let fullFmt = DateFormatter()
        fullFmt.locale = locale
        fullFmt.dateFormat = "MMM d, yyyy"

        var snapLookup: [Date: [DailySnapshot]] = [:]
        for s in snapshots where listIDs.contains(s.listID) {
            let day = cal.startOfDay(for: s.date)
            snapLookup[day, default: []].append(s)
        }

        let totalTasksAcrossLists = max(1, lists.reduce(0) { $0 + $1.tasks.count })

        return (0..<daysCount).compactMap { idx in
            let offset = -(daysCount - 1 - idx)
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let isToday = offset == 0

            if isToday && !lists.isEmpty {
                // Live today completion across the target lists
                var totalWeight = 0.0
                var doneWeight = 0.0
                var doneCount = 0
                var totalCount = 0
                for l in lists {
                    let hv = hk.healthValues(for: l.tasks)
                    let frac = l.completionFraction(healthValues: hv)
                    let w = Double(max(1, l.tasks.count))
                    totalWeight += w
                    doneWeight += frac * w
                    doneCount += l.tasks.filter(\.isCompleted).count
                    totalCount += l.tasks.count
                }
                let liveFrac = totalWeight > 0 ? (doneWeight / totalWeight) : 0
                return MacDailyTrendPoint(
                    date: date,
                    dayLabel: shortFmt.string(from: date),
                    fullDateLabel: "\(shortFmt.string(from: date)) (Today)",
                    completionFraction: min(max(liveFrac, 0), 1),
                    completedCount: doneCount,
                    totalCount: max(1, totalCount)
                )
            }

            let daySnaps = snapLookup[date] ?? []
            if daySnaps.isEmpty {
                return MacDailyTrendPoint(
                    date: date,
                    dayLabel: shortFmt.string(from: date),
                    fullDateLabel: fullFmt.string(from: date),
                    completionFraction: 0,
                    completedCount: 0,
                    totalCount: totalTasksAcrossLists
                )
            }

            // Average across lists that have snapshots on that day
            let avgFrac = daySnaps.map(\.completionFraction).reduce(0, +) / Double(daySnaps.count)
            let uniqueDoneIDs = Set(daySnaps.flatMap(\.completedTaskIDs))
            return MacDailyTrendPoint(
                date: date,
                dayLabel: shortFmt.string(from: date),
                fullDateLabel: fullFmt.string(from: date),
                completionFraction: min(max(avgFrac, 0), 1),
                completedCount: uniqueDoneIDs.count,
                totalCount: max(uniqueDoneIDs.count, totalTasksAcrossLists)
            )
        }
    }

    static func computeLackDiagnostics(
        for lists: [TaskList],
        snapshots: [DailySnapshot],
        daysCount: Int
    ) -> [MacHabitLackItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var results: [MacHabitLackItem] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }
            var snapByDay: [Date: DailySnapshot] = [:]
            for s in listSnaps {
                snapByDay[cal.startOfDay(for: s.date)] = s
            }

            // Effective evaluation window: from earliest snapshot or list creation up to daysCount
            let earliestSnapDay = snapByDay.keys.min() ?? today
            let spanDays = max(1, min(daysCount, (cal.dateComponents([.day], from: earliestSnapDay, to: today).day ?? 0) + 1))

            let totalListWeight = max(1.0, list.tasks.reduce(0.0) { $0 + ($1.weight > 0 ? $1.weight : 1.0) })

            for task in list.tasks {
                var hits = 0
                for dOffset in 0..<spanDays {
                    guard let day = cal.date(byAdding: .day, value: -dOffset, to: today) else { continue }
                    if dOffset == 0 {
                        if task.isCompleted || (snapByDay[day]?.completedTaskIDs.contains(task.id) == true) {
                            hits += 1
                        }
                    } else if snapByDay[day]?.completedTaskIDs.contains(task.id) == true {
                        hits += 1
                    }
                }

                let last7: [Bool] = (0..<7).map { idx in
                    let offset = -(6 - idx)
                    guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return false }
                    if offset == 0 {
                        return task.isCompleted || (snapByDay[day]?.completedTaskIDs.contains(task.id) == true)
                    }
                    return snapByDay[day]?.completedTaskIDs.contains(task.id) == true
                }

                let lastDoneDate: Date? = {
                    if task.isCompleted { return today }
                    return listSnaps
                        .filter { $0.completedTaskIDs.contains(task.id) }
                        .map { cal.startOfDay(for: $0.date) }
                        .max()
                }()

                let refDate = lastDoneDate ?? earliestSnapDay
                let daysSince = max(0, cal.dateComponents([.day], from: refDate, to: today).day ?? 0)

                let rate = Double(hits) / Double(spanDays)
                let taskW = task.weight > 0 ? task.weight : 1.0
                let dragPct = Int(((taskW / totalListWeight) * 100).rounded())

                results.append(
                    MacHabitLackItem(
                        id: task.id,
                        task: task,
                        listID: list.id,
                        listName: list.cleanName,
                        listEmoji: list.emoji,
                        completionRate: rate,
                        missRate: max(0, 1.0 - rate),
                        missedDaysCount: max(0, spanDays - hits),
                        totalDaysCount: spanDays,
                        daysSinceLastDone: task.isCompleted ? 0 : max(1, daysSince),
                        last7DaysHits: last7,
                        scoreDragPercent: dragPct
                    )
                )
            }
        }

        // Sort so unfinished/lowest completion rate & highest weight impact appear first
        return results.sorted { a, b in
            if a.task.isCompleted != b.task.isCompleted {
                return !a.task.isCompleted
            }
            if abs(a.completionRate - b.completionRate) > 0.01 {
                return a.completionRate < b.completionRate
            }
            return a.scoreDragPercent > b.scoreDragPercent
        }
    }
}

// MARK: - Zero-Shift, Safe-Delete macOS Desktop Task Row

struct MacDesktopTaskRow: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager

    let task: SortydTask
    let hk: HealthKitManager
    let isTodoStyle: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDeleteConfirmed: () -> Void

    @State private var isHovered = false
    @State private var confirmingDelete = false

    private var resolvedHealthType: HealthTaskType? {
        guard task.isHealthTask, let str = task.healthType else { return nil }
        return HealthTaskType(rawValue: str)
    }

    private var timeLabel: String? {
        guard let t = task.reminderTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = vm.appLanguage.locale
        return f.string(from: t)
    }

    private var accentColor: Color {
        isTodoStyle ? Color(hex: "#4CAF50") : Theme.accent
    }

    var body: some View {
        HStack(spacing: 12) {
            // ── 1. Primary Completion Checkbox on the LEFT (Never shifts!) ──
            Button(action: {
                confirmingDelete = false
                onToggle()
            }) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? accentColor : (isHovered ? accentColor.opacity(0.75) : Theme.borderAccent),
                            lineWidth: 1.8
                        )
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(themeManager.isDark ? .black : .white)
                    } else if isHovered {
                        Circle()
                            .fill(accentColor.opacity(0.14))
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? vm.localized("Mark incomplete") : vm.localized("Complete habit"))

            // ── 2. Clickable Task Title & Metadata Body (Clicking also completes!) ──
            Button(action: {
                confirmingDelete = false
                onToggle()
            }) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 14.5, weight: task.isCompleted ? .medium : .semibold))
                            .foregroundColor(task.isCompleted ? Theme.text2 : Theme.text0)
                            .strikethrough(task.isCompleted, color: Theme.text2.opacity(0.7))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if task.isCompleted {
                                Label(vm.localized("Completed today"), systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(accentColor.opacity(0.85))
                            } else if let t = timeLabel {
                                Label("Due \(t)", systemImage: "bell.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(accentColor)
                            } else {
                                Text(vm.localized("Anytime"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.text2)
                            }

                            if let dur = task.durationMinutes, dur > 0 {
                                Text("• \(dur)m")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.text2)
                            }

                            if let ht = resolvedHealthType, let target = task.healthTarget {
                                let current = hk.currentValue(for: ht)
                                Text("• \(Int(current))/\(Int(target)) \(ht.label)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: ht.accentColor))
                            }
                        }
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── 3. Fixed-Width Trailing Actions Slot (NEVER shifts task title or checkbox!) ──
            HStack(spacing: 6) {
                if confirmingDelete {
                    Button(action: {
                        onDeleteConfirmed()
                    }) {
                        Text(vm.localized("Delete"))
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.danger))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            confirmingDelete = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.text2)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Theme.text1)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .help(vm.localized("Edit habit"))
                    .opacity(isHovered ? 1.0 : 0.0)
                    .allowsHitTesting(isHovered)

                    Menu {
                        Button {
                            onToggle()
                        } label: {
                            Label(
                                task.isCompleted ? vm.localized("Mark Incomplete") : vm.localized("Mark Completed"),
                                systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                            )
                        }

                        Button {
                            onEdit()
                        } label: {
                            Label(vm.localized("Edit Habit Details…"), systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                confirmingDelete = true
                            }
                        } label: {
                            Label(vm.localized("Delete Habit…"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.text2)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 28, height: 28)
                    .opacity(isHovered ? 1.0 : 0.35)
                }
            }
            .frame(width: confirmingDelete ? 92 : 60, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6.5)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    task.isCompleted
                        ? accentColor.opacity(themeManager.isDark ? 0.09 : 0.08)
                        : (isHovered ? Color.white.opacity(themeManager.isDark ? 0.065 : 0.55) : Color.white.opacity(themeManager.isDark ? 0.035 : 0.38))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            task.isCompleted
                                ? accentColor.opacity(0.28)
                                : (isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.07)),
                            lineWidth: 1
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
                if !hovering {
                    confirmingDelete = false
                }
            }
        }
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(
                    task.isCompleted ? vm.localized("Mark Incomplete") : vm.localized("Mark Completed"),
                    systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill"
                )
            }

            Button {
                onEdit()
            } label: {
                Label(vm.localized("Edit Habit"), systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDeleteConfirmed()
            } label: {
                Label(vm.localized("Delete Habit"), systemImage: "trash")
            }
        }
    }
}

// MARK: - Interactive Daily Completion Line Graph Component (Compact & Calendar-Date Based)

struct MacInteractiveDailyLineChart: View {
    let points: [MacDailyTrendPoint]
    var targetFraction: Double = 0.80
    var chartHeight: CGFloat = 90

    @State private var hoveredIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Hover Callout Pill
            HStack {
                if let idx = hoveredIndex, points.indices.contains(idx) {
                    let pt = points[idx]
                    HStack(spacing: 6) {
                        Text(pt.fullDateLabel)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Theme.text0)

                        Text("\(pt.percentage)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(pt.completionFraction >= targetFraction ? Theme.success : Theme.accent)
                            .monospacedDigit()

                        Text("(\(pt.completedCount)/\(pt.totalCount) completed)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                } else if let latest = points.last {
                    HStack(spacing: 5) {
                        Text("Latest:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.text2)
                        Text("\(latest.fullDateLabel) • \(latest.percentage)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                        Text("— Hover any date node for breakdown")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.text2)
                    }
                }
                Spacer()
            }
            .frame(height: 18)

            GeometryReader { geo in
                let leftAxisWidth: CGFloat = 32
                let plotWidth = max(60, geo.size.width - leftAxisWidth)
                let plotHeight = max(44, geo.size.height - 4)
                let coords = plotCoordinates(width: plotWidth, height: plotHeight, xOffset: leftAxisWidth)

                ZStack(alignment: .topLeading) {
                    // Horizontal reference lines (50%, 100%)
                    ForEach([0.50, 1.0], id: \.self) { level in
                        let y = plotHeight - CGFloat(level) * (plotHeight * 0.86)
                        Path { p in
                            p.move(to: CGPoint(x: leftAxisWidth, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        Text("\(Int(level * 100))%")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.text2)
                            .monospacedDigit()
                            .position(x: 14, y: y)
                    }

                    // 80% Target Consistency Line
                    let targetY = plotHeight - CGFloat(targetFraction) * (plotHeight * 0.86)
                    Path { p in
                        p.move(to: CGPoint(x: leftAxisWidth, y: targetY))
                        p.addLine(to: CGPoint(x: geo.size.width, y: targetY))
                    }
                    .stroke(Theme.success.opacity(0.55), style: StrokeStyle(lineWidth: 1.1, dash: [5, 4]))

                    if coords.count >= 2 {
                        // Area Gradient Fill under smooth curve
                        Path { p in
                            p.move(to: CGPoint(x: coords[0].x, y: plotHeight))
                            p.addLine(to: coords[0])
                            addSmoothCurve(coords: coords, to: &p)
                            p.addLine(to: CGPoint(x: coords[coords.count - 1].x, y: plotHeight))
                            p.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.accent.opacity(0.26),
                                    Theme.indigo.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Smooth Cubic Bezier Line
                        Path { p in
                            p.move(to: coords[0])
                            addSmoothCurve(coords: coords, to: &p)
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Theme.coral, Theme.accent, Theme.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                        )

                        // Vertical Hover Guide Line
                        if let idx = hoveredIndex, coords.indices.contains(idx) {
                            let pt = coords[idx]
                            Path { p in
                                p.move(to: CGPoint(x: pt.x, y: 2))
                                p.addLine(to: CGPoint(x: pt.x, y: plotHeight))
                            }
                            .stroke(Theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }

                        // Data Nodes
                        ForEach(Array(coords.enumerated()), id: \.offset) { idx, pt in
                            let isHovered = hoveredIndex == idx
                            let isLast = idx == coords.count - 1
                            let frac = points[idx].completionFraction
                            let nodeColor = frac >= targetFraction ? Theme.success : (frac >= 0.5 ? Theme.accent : Theme.coral)

                            ZStack {
                                if isHovered || isLast {
                                    Circle()
                                        .fill(nodeColor.opacity(0.26))
                                        .frame(width: isHovered ? 13 : 10, height: isHovered ? 13 : 10)
                                }
                                Circle()
                                    .fill(nodeColor)
                                    .frame(width: isHovered ? 7 : (points.count <= 14 ? 5.5 : 4), height: isHovered ? 7 : (points.count <= 14 ? 5.5 : 4))
                            }
                            .position(pt)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let usableX = max(0, loc.x - leftAxisWidth)
                        guard points.count > 1 else {
                            hoveredIndex = points.isEmpty ? nil : 0
                            return
                        }
                        let step = plotWidth / CGFloat(points.count - 1)
                        let idx = Int((usableX / step).rounded())
                        hoveredIndex = min(max(idx, 0), points.count - 1)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
            .frame(height: chartHeight)

            // X-Axis Calendar Date Labels (e.g. Oct 30, Oct 31, Nov 1 ... Nov 5)
            if points.count >= 2 {
                HStack(spacing: 0) {
                    Spacer().frame(width: 32)
                    if points.count <= 7 {
                        ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                            Text(pt.dayLabel)
                                .font(.system(size: 9, weight: idx == points.count - 1 ? .bold : .medium, design: .rounded))
                                .foregroundColor(idx == points.count - 1 ? Theme.accent : Theme.text2)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        let tickIndices: [Int] = [
                            0,
                            max(1, points.count / 4),
                            max(2, points.count / 2),
                            max(3, (points.count * 3) / 4),
                            points.count - 1
                        ]
                        ForEach(Array(tickIndices.enumerated()), id: \.offset) { pos, ptIdx in
                            if points.indices.contains(ptIdx) {
                                Text(points[ptIdx].dayLabel)
                                    .font(.system(size: 9, weight: ptIdx == points.count - 1 ? .bold : .medium, design: .rounded))
                                    .foregroundColor(ptIdx == points.count - 1 ? Theme.accent : Theme.text2)
                                if pos < tickIndices.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func plotCoordinates(width: CGFloat, height: CGFloat, xOffset: CGFloat) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        if points.count == 1 {
            let y = height - CGFloat(points[0].completionFraction) * (height * 0.86)
            return [CGPoint(x: xOffset, y: y), CGPoint(x: xOffset + width, y: y)]
        }
        let step = width / CGFloat(points.count - 1)
        return points.enumerated().map { idx, pt in
            let x = xOffset + CGFloat(idx) * step
            let y = height - CGFloat(min(max(pt.completionFraction, 0), 1)) * (height * 0.86)
            return CGPoint(x: x, y: y)
        }
    }

    private func addSmoothCurve(coords: [CGPoint], to path: inout Path) {
        guard coords.count >= 2 else { return }
        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let curr = coords[i]
            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.38, y: prev.y)
            let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) * 0.38, y: curr.y)
            path.addCurve(to: curr, control1: cp1, control2: cp2)
        }
    }
}

// MARK: - Single-Screen macOS Desktop Analytics & "Where You're Lacking" Diagnostic Studio

struct MacDesktopAnalyticsStudioView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var hk = HealthKitManager.shared

    let onEditTask: (SortydTask, UUID) -> Void

    enum Horizon: Int, CaseIterable, Identifiable {
        case week = 7
        case twoWeeks = 14
        case month = 30

        var id: Int { rawValue }
        var label: String { "\(rawValue) Days" }
    }

    // nil = All Regular Habit Lists Combined
    @State private var selectedListID: UUID? = nil
    @State private var horizon: Horizon = .twoWeeks

    private var regularLists: [TaskList] {
        vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
    }

    private var scopedLists: [TaskList] {
        if let id = selectedListID, let found = regularLists.first(where: { $0.id == id }) {
            return [found]
        }
        return regularLists
    }

    private var trendPoints: [MacDailyTrendPoint] {
        MacDesktopWorkspaceView.buildDailyTrendPoints(
            for: scopedLists,
            snapshots: vm.snapshots,
            hk: hk,
            daysCount: horizon.rawValue,
            locale: vm.appLanguage.locale
        )
    }

    private var lackDiagnostics: [MacHabitLackItem] {
        MacDesktopWorkspaceView.computeLackDiagnostics(
            for: scopedLists,
            snapshots: vm.snapshots,
            daysCount: horizon.rawValue
        )
    }

    private var averagePct: Int {
        guard !trendPoints.isEmpty else { return 0 }
        let avg = trendPoints.map(\.completionFraction).reduce(0, +) / Double(trendPoints.count)
        return Int((avg * 100).rounded())
    }

    private var consistencyDaysCount: Int {
        trendPoints.filter { $0.completionFraction >= 0.80 }.count
    }

    private var unfinishedTodayCount: Int {
        scopedLists.reduce(0) { $0 + $1.tasks.filter { !$0.isCompleted }.count }
    }

    private var overallGrade: (letter: String, subtitle: String, color: Color) {
        switch averagePct {
        case 90...100: return ("A", "Elite Consistency", Theme.success)
        case 80..<90:  return ("A-", "Strong Momentum", Theme.accent)
        case 70..<80:  return ("B+", "Solid Foundation", Theme.accent)
        case 60..<70:  return ("B-", "Room to Tighten", Theme.warning)
        default:       return ("C", "Needs Attention", Theme.coral)
        }
    }

    // Day-of-week breakdown (Mon...Sun)
    private struct WeekdayPerformance: Identifiable {
        let id: Int
        let shortName: String
        let fullName: String
        let averagePct: Int
        let fraction: Double
    }

    private var weekdayStats: [WeekdayPerformance] {
        let cal = Calendar.current
        let order = [2, 3, 4, 5, 6, 7, 1] // Mon -> Sun
        let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let fullNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        var buckets: [Int: [Double]] = [:]
        for pt in trendPoints {
            let wd = cal.component(.weekday, from: pt.date)
            buckets[wd, default: []].append(pt.completionFraction)
        }

        return order.enumerated().map { idx, wd in
            let vals = buckets[wd] ?? []
            let frac = vals.isEmpty ? 0.0 : (vals.reduce(0, +) / Double(vals.count))
            return WeekdayPerformance(
                id: wd,
                shortName: shortNames[idx],
                fullName: fullNames[idx],
                averagePct: Int((frac * 100).rounded()),
                fraction: frac
            )
        }
    }

    private var weakestWeekday: WeekdayPerformance? {
        weekdayStats.filter { $0.fraction > 0 }.min(by: { $0.fraction < $1.fraction }) ?? weekdayStats.first
    }

    private var strongestWeekday: WeekdayPerformance? {
        weekdayStats.max(by: { $0.fraction < $1.fraction })
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top Studio Filter & Horizon Bar (Pinned on top of scroll content)
            studioHeaderBar
                .zIndex(20)

            GeometryReader { studioGeo in
                let isWideStudio = studioGeo.size.width >= 780

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // 1. Compact Executive Scorecard Row
                        executiveScorecardRow

                        // 2. Compact Daily Completion Line Graph Card (with Calendar Dates)
                        studioLineGraphCard

                        // 3. Adaptive 2-Column / 1-Column Deep Diagnostic Section
                        if isWideStudio {
                            HStack(alignment: .top, spacing: 12) {
                                whereYouLackDetailedTableCard
                                    .frame(maxWidth: .infinity)

                                VStack(spacing: 10) {
                                    weekdayVulnerabilityCard
                                    crossListBottleneckCard
                                    recoveryPrescriptionCard
                                }
                                .frame(width: min(370, max(290, studioGeo.size.width * 0.36)))
                            }
                        } else {
                            VStack(spacing: 10) {
                                whereYouLackDetailedTableCard
                                weekdayVulnerabilityCard
                                crossListBottleneckCard
                                recoveryPrescriptionCard
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .sortydScrollUnderneath()
            }
        }
    }

    // MARK: - 1. Studio Header Bar

    private var studioHeaderBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accent.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.localized("Analytics & Gap Diagnostic Studio"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Theme.text0)
                    Text(vm.localized("Date-by-date completion trajectory & where your routine is lacking"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
            }

            Spacer()

            // List Scope Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedListID = nil
                        }
                    }) {
                        Text(vm.localized("All Lists"))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selectedListID == nil ? Theme.accent : Color.white.opacity(0.06))
                            )
                            .foregroundColor(selectedListID == nil ? .black : Theme.text1)
                    }
                    .buttonStyle(.plain)

                    ForEach(regularLists) { list in
                        let isSelected = selectedListID == list.id
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                selectedListID = list.id
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(list.emoji)
                                    .font(.system(size: 11))
                                Text(list.cleanName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Theme.accent : Color.white.opacity(0.06))
                            )
                            .foregroundColor(isSelected ? .black : Theme.text1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 420)

            // Horizon Selector (7D / 14D / 30D)
            HStack(spacing: 4) {
                ForEach(Horizon.allCases) { h in
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            horizon = h
                        }
                    }) {
                        Text(h.label)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(horizon == h ? Theme.indigo : Color.white.opacity(0.05))
                            )
                            .foregroundColor(horizon == h ? .white : Theme.text2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .sortydMacGlass(cornerRadius: 16)
    }

    // MARK: - 2. Executive Scorecard Row

    private var executiveScorecardRow: some View {
        let grade = overallGrade
        let weakDay = weakestWeekday

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 175), spacing: 10)],
            spacing: 10
        ) {
            // Grade Tile
            HStack(spacing: 10) {
                Text(grade.letter)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(grade.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.localized("OVERALL GRADE"))
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Theme.text2)
                    Text(grade.subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                    Text("\(horizon.label) average")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 68)
            .sortydMacGlass(cornerRadius: 14, tint: grade.color)

            // Average Completion Tile
            metricTile(
                kicker: vm.localized("DAILY AVERAGE"),
                value: "\(averagePct)%",
                subtitle: "\(consistencyDaysCount)/\(trendPoints.count) dates hit ≥80%",
                icon: "chart.line.uptrend.xyaxis",
                tint: Theme.accent
            )

            // Unfinished Today Tile
            metricTile(
                kicker: vm.localized("UNFINISHED TODAY"),
                value: "\(unfinishedTodayCount)",
                subtitle: unfinishedTodayCount == 0 ? "All habits done today!" : "Habits remaining right now",
                icon: "exclamationmark.circle.fill",
                tint: unfinishedTodayCount == 0 ? Theme.success : Theme.warning
            )

            // Weakest Day Tile
            metricTile(
                kicker: vm.localized("WEAKEST DAY"),
                value: weakDay?.fullName ?? "—",
                subtitle: weakDay != nil ? "\(weakDay!.averagePct)% avg completion" : "Build more history",
                icon: "calendar.badge.exclamationmark",
                tint: Theme.coral
            )
        }
    }

    private func metricTile(kicker: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(kicker)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(Theme.text2)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(tint)
            }

            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundColor(Theme.text0)
                .monospacedDigit()
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .sortydMacGlass(cornerRadius: 14, tint: tint)
    }

    // MARK: - 3. Studio Full-Width Daily Completion Line Graph Card (Compact & Calendar-Date Based)

    private var studioLineGraphCard: some View {
        let peakPoint = trendPoints.max(by: { $0.completionFraction < $1.completionFraction })
        let lowestPoint = trendPoints.min(by: { $0.completionFraction < $1.completionFraction })

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.localized("DAILY COMPLETION TRAJECTORY (BY DATE)"))
                        .font(.system(size: 10.5, weight: .heavy))
                        .tracking(1.3)
                        .foregroundColor(Theme.text1)
                    Text(vm.localized("Date-by-date completion curve with 80% consistency benchmark"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                }

                Spacer()

                if let peak = peakPoint, let low = lowestPoint {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.success)
                            Text("Peak: \(peak.dayLabel) (\(peak.percentage)%)")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.text1)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.coral)
                            Text("Dip: \(low.dayLabel) (\(low.percentage)%)")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.text1)
                        }
                    }
                }
            }

            MacInteractiveDailyLineChart(
                points: trendPoints,
                targetFraction: 0.80,
                chartHeight: 96
            )
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.accent)
    }

    // MARK: - 4. "Where You're Lacking" Detailed Habit Breakdown Table

    private var whereYouLackDetailedTableCard: some View {
        let items = lackDiagnostics

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.warning)
                        Text(vm.localized("WHERE YOU'RE LACKING • HABIT-BY-HABIT GAP ANALYSIS"))
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(1.3)
                            .foregroundColor(Theme.text1)
                    }
                    Text(vm.localized("Habits ranked by miss rate and score drag so you know what to fix first"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Theme.text2)
                }

                Spacer()

                Text("\(items.count) habits")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .foregroundColor(Theme.text2)
            }

            if items.isEmpty {
                Text(vm.localized("No habits found in the selected scope."))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text2)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 5) {
                    ForEach(items.prefix(8)) { item in
                        diagnosticHabitRow(item)
                    }
                }
            }
        }
        .padding(13)
        .sortydMacGlass(cornerRadius: 18, tint: Theme.warning)
    }

    private func diagnosticHabitRow(_ item: MacHabitLackItem) -> some View {
        let statusColor: Color = item.completionRate >= 0.80
            ? Theme.success
            : (item.completionRate >= 0.55 ? Theme.warning : Theme.danger)

        return HStack(spacing: 10) {
            // Completion Rate Badge
            Text("\(item.completionPct)%")
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundColor(statusColor)
                .monospacedDigit()
                .frame(width: 40, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(statusColor.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(statusColor.opacity(0.32), lineWidth: 1)
                        )
                )

            // Habit Name + List & Drag Diagnosis
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 5) {
                    Text("\(item.listEmoji) \(item.listName)")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                        .foregroundColor(Theme.text2)

                    Text(item.task.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if item.missedDaysCount > 0 {
                        Text("Missed \(item.missedDaysCount)/\(item.totalDaysCount)d (\(item.missPct)% miss)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(statusColor)
                    } else {
                        Text("Perfect \(item.totalDaysCount)-day streak")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.success)
                    }

                    Text("•")
                        .foregroundColor(Theme.text2)

                    Text("Drag: \(item.scoreDragPercent)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text2)
                }
            }

            Spacer(minLength: 4)

            // Last 7 Days Spark Strip
            HStack(spacing: 3) {
                ForEach(Array(item.last7DaysHits.enumerated()), id: \.offset) { _, hit in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(hit ? Theme.accent : Color.white.opacity(0.10))
                        .frame(width: 7, height: 11)
                }
            }

            // Quick Action: Complete Today or Edit
            HStack(spacing: 5) {
                Button(action: {
                    if let targetList = vm.lists.first(where: { $0.id == item.listID }) {
                        vm.setActiveList(targetList)
                        vm.toggleTask(item.task)
                    }
                }) {
                    Text(item.task.isCompleted ? "Done" : "Complete")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(item.task.isCompleted ? Theme.success.opacity(0.18) : Theme.accent.opacity(0.18))
                        )
                        .foregroundColor(item.task.isCompleted ? Theme.success : Theme.accent)
                }
                .buttonStyle(.plain)

                Button(action: {
                    onEditTask(item.task, item.listID)
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.text2)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6.5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            !item.task.isCompleted ? statusColor.opacity(0.25) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - 5. Day-of-Week Vulnerability Card

    private var weekdayVulnerabilityCard: some View {
        let stats = weekdayStats
        let worst = weakestWeekday
        let best = strongestWeekday

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.coral)
                Text(vm.localized("DAY-OF-WEEK DROP-OFF PATTERN"))
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(Theme.text1)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(stats) { day in
                    let isWorst = day.id == worst?.id
                    let isBest = day.id == best?.id && day.fraction > 0
                    let barColor: Color = isWorst ? Theme.coral : (isBest ? Theme.success : Theme.accent)

                    VStack(spacing: 4) {
                        Text("\(day.averagePct)%")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(isWorst ? Theme.coral : Theme.text1)
                            .monospacedDigit()

                        GeometryReader { g in
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [barColor, barColor.opacity(0.45)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: max(6, g.size.height * CGFloat(day.fraction)))
                            }
                        }
                        .frame(height: 46)
                        .padding(.horizontal, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )

                        Text(day.shortName)
                            .font(.system(size: 9.5, weight: (isWorst || isBest) ? .black : .semibold))
                            .foregroundColor(isWorst ? Theme.coral : (isBest ? Theme.success : Theme.text2))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .sortydMacGlass(cornerRadius: 16, tint: Theme.coral)
    }

    // MARK: - 6. Cross-List Bottleneck Comparison Card

    private var crossListBottleneckCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.indigo)
                Text(vm.localized("LIST BOTTLENECK COMPARISON"))
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(Theme.text1)
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(regularLists) { list in
                    let hv = hk.healthValues(for: list.tasks)
                    let todayPct = Int((list.completionFraction(healthValues: hv) * 100).rounded())
                    let missingTasks = list.tasks.filter { !$0.isCompleted }
                    let topMissing = missingTasks.first

                    HStack {
                        Text("\(list.emoji) \(list.cleanName)")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(Theme.text0)
                            .lineLimit(1)
                        Spacer()
                        if let bottleneck = topMissing {
                            Text("Next: \(bottleneck.title)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.warning)
                                .lineLimit(1)
                        }
                        Text("\(todayPct)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(todayPct == 100 ? Theme.success : Theme.accent)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                    )
                }
            }
        }
        .padding(12)
        .sortydMacGlass(cornerRadius: 16, tint: Theme.indigo)
    }

    // MARK: - 7. Actionable Recovery Prescription Card

    private var recoveryPrescriptionCard: some View {
        let unfinished = lackDiagnostics.filter { !$0.task.isCompleted }
        let topTwo = Array(unfinished.prefix(2))

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text(vm.localized("RECOVERY PRESCRIPTION"))
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(Theme.text1)
            }

            if topTwo.isEmpty {
                Text(vm.localized("100% of habits in this scope completed today!"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.text1)
            } else {
                let totalGain = topTwo.reduce(0) { $0 + $1.scoreDragPercent }
                Text("Finish top \(topTwo.count) habit\(topTwo.count > 1 ? "s" : "") for +\(totalGain)% score boost:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.text1)

                ForEach(topTwo) { gap in
                    HStack {
                        Text("• \(gap.task.title)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text0)
                            .lineLimit(1)
                        Spacer()
                        Text("+\(gap.scoreDragPercent)%")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .padding(12)
        .sortydMacGlass(cornerRadius: 16, tint: Theme.accent)
    }
}

// MARK: - macOS MenuBarExtra Popover View (Inspired by HOUR5)

struct SortydMenuBarPopoverView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var auth = AuthService.shared
    @StateObject private var hk = HealthKitManager.shared
    @State private var quickTask = ""

    private var activeList: TaskList? { vm.activeList }
    private var regularLists: [TaskList] {
        vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
    }

    private var completionPct: Int {
        guard let list = activeList else { return 0 }
        let hv = hk.healthValues(for: list.tasks)
        return Int((list.completionFraction(healthValues: hv) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.accent, Theme.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sortyd")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text(auth.isAuthenticated ? "sortyd.com synced" : "Local workspace")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("🔥 \(vm.cachedBestStreak)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.16)))

                    Text("\(completionPct)%")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .monospacedDigit()
                }
            }

            // List Selector Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(regularLists) { list in
                        let selected = vm.activeListID == list.id
                        Button(action: { vm.setActiveList(list) }) {
                            HStack(spacing: 4) {
                                Text(list.emoji)
                                    .font(.system(size: 12))
                                Text(list.cleanName)
                                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selected ? Theme.accent.opacity(0.22) : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Tasks Checklist
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    if let list = activeList, !list.tasks.isEmpty {
                        ForEach(list.tasks) { task in
                            Button(action: { vm.toggleTask(task) }) {
                                HStack(spacing: 9) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(task.isCompleted ? Theme.accent : .secondary)

                                    Text(task.title)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .strikethrough(task.isCompleted)
                                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("No habits in this list yet.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    }
                }
            }
            .frame(maxHeight: 210)

            // Quick Add Task in Menu Bar
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Theme.accent)
                TextField("Quick add habit...", text: $quickTask)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        let t = quickTask.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty, let id = activeList?.id else { return }
                        vm.addTask(to: id, title: t)
                        quickTask = ""
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Divider()

            // Footer Actions
            HStack {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                    }
                }) {
                    Label("Open Sortyd Window", systemImage: "macwindow")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accent)

                Spacer()

                if auth.isAuthenticated {
                    Button(action: {
                        Task { await vm.syncWithCloud() }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Sync with sortyd.com")
                }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
#endif
