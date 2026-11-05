// MARK: - HomeView.swift
// Sortyd v4 — HealthKit-aware completion % and SmallHealthDonut in task rows

import SwiftUI
import Combine
import FirebaseAnalytics

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showWeeklyPlanner = false
    
    @StateObject private var hk = HealthKitManager.shared
    @State private var showSwitcher = false
    @State private var showAddTodoTask = false
    @State private var showTodoEdit = false
    @State private var editingTodoTask: SortydTask? = nil

    private var list: TaskList? { vm.activeList }
    private var isTodoActive: Bool { list?.isTodo == true }
    /// True when the user has at least one non-todo, non-archived list
    private var hasRealLists: Bool {
        vm.lists.contains(where: { !$0.isTodo && !$0.isArchived && !$0.isWeekly })
    }

    /// Live health-aware completion % for the active list
    private var liveCompletionPct: Int {
        guard let list = list else { return 0 }
        let hv = hk.healthValues(for: list.tasks)
        return Int((list.completionFraction(healthValues: hv) * 100).rounded())
    }


    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.bg0.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, Theme.s16)
                        .padding(.top, 0)
                        .padding(.bottom, 8)

                    if !showWeeklyPlanner {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                if !isTodoActive {
                                    heroSection
                                        .padding(.horizontal, Theme.s16)
                                        .padding(.bottom, 10)

                                    heatmapSection
                                        .padding(.horizontal, Theme.s16)
                                        .padding(.bottom, 10)
                                } else {
                                    todoHeaderSection
                                        .padding(.horizontal, Theme.s16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 10)
                                }

                                taskSection
                                    .padding(.horizontal, Theme.s16)
                                    .padding(.bottom, 100)
                            }
                        }
                        .refreshable { await vm.refresh() }
                    } else {
                        WeeklyPlannerSection()
                            .padding(.horizontal, 8)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)

                if let recap = vm.dailyRecap {
                    DailyRecapBanner(data: recap) {
                        vm.dailyRecap = nil
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSwitcher) {
                ListSwitcherSheet().environmentObject(vm)
            }
            .sheet(isPresented: $showAddTodoTask) {
                if let id = vm.todoList?.id {
                    AddTaskSheet(listID: id).environmentObject(vm)
                }
            }
            .sheet(isPresented: $showTodoEdit) {
                if let id = vm.todoList?.id {
                    NavigationStack {
                        ListDetailView(listID: id).environmentObject(vm)
                    }
                }
            }
            .sheet(item: $editingTodoTask) { task in
                if let id = vm.todoList?.id {
                    EditTaskSheet(task: task, listID: id).environmentObject(vm)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                hk.fetchToday()
            }
            .onAppear {
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                    AnalyticsParameterScreenName: "home",
                    AnalyticsParameterScreenClass: "HomeView"
                ])
            }
        }
    }
    
    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Theme Toggle (Left)
            ThemeToggleButton()
                .environmentObject(themeManager)
                .frame(width: 40, alignment: .leading)
                .padding(.leading, 2)

            // Scrollable Lists
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        let activeLists = vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
                        ForEach(activeLists) { l in
                            let hv = hk.healthValues(for: l.tasks)
                            let fraction = l.completionFraction(healthValues: hv)

                            OrbitalDonutPill(
                                list: l,
                                isActive: vm.activeListID == l.id,
                                fraction: fraction,
                                onTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        vm.setActiveList(l)
                                    }
                                }
                            )
                            .id(l.id)
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 24)
                    .padding(.vertical, 12) // Extra room for glow & shadow falloff
                }
                .onChange(of: vm.activeListID) { _, newID in
                    if let id = newID {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            proxy.scrollTo(id, anchor: .leading)
                        }
                    }
                }
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.97),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .init(x: 0, y: 0.5),
                    endPoint: .init(x: 1, y: 0.5)
                )
            )

            // TO DO Pill (fixed, right side) — only show when user has real lists
            if hasRealLists {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.accent.opacity(0.08),
                                Theme.accent.opacity(0.42),
                                Theme.accent.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.2, height: 22)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 6, x: 0, y: 0)
                    .padding(.leading, 6)
                    .padding(.trailing, 10)

                HStack(spacing: 8) {
                    if let todo = vm.todoList {
                        TodoPill(
                            isActive: vm.activeListID == todo.id && !showWeeklyPlanner,
                            fraction: todo.completionFraction,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    showWeeklyPlanner = false
                                    vm.setActiveList(todo)
                                }
                            },
                            onDoubleTap: { showTodoEdit = true }
                        )
                    }

                    WeekCalendarPill(
                        weekNumber: currentWeekNumber,
                        isActive: showWeeklyPlanner,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                showWeeklyPlanner.toggle()
                            }
                        }
                    )
                }
                .padding(.trailing, 0)
            }
        }
        .background(
            Capsule()
                .fill(Theme.bg1.opacity(0.3))
                .blur(radius: 20)
                .offset(y: 10)
        )
    }

    private var currentWeekNumber: Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }


    // MARK: - Hero (uses live health-aware %)

    private var heroSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text((!hasRealLists && isTodoActive) ? "" : (list?.cleanName.uppercased() ?? vm.localized("NO LIST")))
                    .font(Theme.font(size: 12, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(Theme.accent)
                    .padding(.bottom, 4)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(liveCompletionPct)%")
                        .font(Theme.font(size: 86, weight: .black, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(vm.localized("\(liveCompletionPct) percent complete today"))

                Text(vm.localized("Done Today"))
                    .font(Theme.font(size: 14, weight: .medium))
                    .foregroundColor(Theme.text2)
                    .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 24))
                    
                    Text("\(vm.cachedBestStreak)")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                }
                
                    Text(vm.localized("Day Streak"))
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(Theme.text2)
            }
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(vm.localized("\(vm.cachedBestStreak) day streak"))
        }
    }

    // MARK: - Heatmap Strip

    private var heatmapSection: some View {
        VStack(spacing: 0) {
            if let id = list?.id, !(!hasRealLists && isTodoActive) {
                HeatmapCalendarView(listID: id)
                    .environmentObject(vm)
                    .frame(height: 124)
            } else {
                PlaceholderCalendarView().frame(height: 108)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        )
        .cardShadow()
    }

    // MARK: - Task Section

    @ViewBuilder
    private var taskSection: some View {
        VStack(spacing: 12) {
            HStack {
                if isTodoActive {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#4CAF50"))
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(Color(hex: "#4CAF50").opacity(0.4))
                                .frame(width: 14, height: 14)
                                .blur(radius: 2)
                        }
                        Text(vm.localized("INBOX TASKS"))
                            .font(Theme.font(size: 12, weight: .black))
                            .kerning(1.8)
                            .foregroundColor(Theme.text1)
                    }
                } else {
                    Text(vm.localized("TASKS"))
                        .font(Theme.font(size: 11, weight: .bold))
                        .kerning(1.6)
                        .foregroundColor(Theme.text2)
                }
                Spacer()
                if let list = list, !list.isTodo {
                    let done = list.tasks.filter(\.isCompleted).count
                    let left = list.tasks.count - done
                    Text("\(done) \(vm.localized("done")) · \(left) \(vm.localized("left"))")
                        .font(Theme.font(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text1)
                }
            }

            if !hasRealLists && (list == nil || isTodoActive) {
                // No real lists yet — show onboarding empty state
                EmptyStateView(onAddList: {
                    vm.selectedTab = 1
                })
                .padding(.top, 1)
            } else if let list = list, !list.tasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(list.tasks) { task in
                        if isTodoActive {
                            TodoSwipeRow(
                                task: task,
                                onEdit: {
                                    editingTodoTask = task
                                },
                                onDelete: {
                                    vm.deleteTask(task, from: list.id)
                                }
                            ) {
                                TaskRowView(
                                    task: task,
                                    hk: hk,
                                    isTodoStyle: true,
                                    onEdit: nil
                                ) {
                                    vm.toggleTask(task)
                                }
                            }
                        } else {
                            TaskRowView(
                                task: task,
                                hk: hk,
                                isTodoStyle: false,
                                onEdit: nil
                            ) {
                                vm.toggleTask(task)
                            }
                        }
                    }
                }
                if isTodoActive {
                    HStack {
                        Spacer()
                        todoAddButton
                    }
                        .padding(.top, 6)
                }
            } else if isTodoActive {
                HStack {
                    Spacer()
                    todoAddButton
                }
                    .padding(.top, 1)
            } else {
                EmptyStateView(onAddList: {
                    vm.selectedTab = 1
                })
                .padding(.top, 1)
            }

            if isTodoActive && hasRealLists {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 9))
                    Text(vm.localized("Resets at 4 AM daily"))
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.text2.opacity(0.6))
                .padding(.top, 4)
            }
        }
    }

    private var todoHeaderSection: some View {
        HStack(alignment: .center) {
            // Left Icon with Glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4CAF50"), Color(hex: "#2E7D32")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: Color(hex: "#4CAF50").opacity(0.4), radius: 6, x: 0, y: 3)

                Image(systemName: "tray.full.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.localized("TO DO"))
                    .font(Theme.font(size: 14, weight: .black))
                    .kerning(1.5)
                    .foregroundColor(Theme.text0)
                    .shadow(color: Theme.text0.opacity(0.2), radius: 1, x: 0, y: 1)

                Text(vm.localized("Stress-Free Zone"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#4CAF50").opacity(0.9))
            }
            .padding(.leading, 6)

            Spacer()

            // Time Badge
            VStack(spacing: 2) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#7C6FFF"))
                Text(vm.localized("Resets 4 AM"))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.text1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.bg0.opacity(0.7))
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Deep background base
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.bg1)
                
                // Gradient mesh overlay
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#4CAF50").opacity(0.06),
                                Theme.bg1.opacity(0.5),
                                Color(hex: "#7C6FFF").opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner glow ring
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.01), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            // Multi-layered shadows for depth
            .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 8)
            .shadow(color: Color(hex: "#4CAF50").opacity(0.12), radius: 10, x: 0, y: 4)
        )
    }

    private func todoPremiumChip(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.5)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
        // Subtle glow for chips
        .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    private var todoAddButton: some View {
        Button { showAddTodoTask = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#4CAF50"))
                Text(vm.localized("Add Task"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.text0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Theme.bg2)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color(hex: "#4CAF50").opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(showAddTodoTask ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAddTodoTask)
    }
}

// ══════════════════════════════════════════════
// MARK: ListDoughnutPill
// ══════════════════════════════════════════════

// ══════════════════════════════════════════════
// MARK: OrbitalDonutPill
// ══════════════════════════════════════════════

struct OrbitalDonutPill: View {
    let list: TaskList
    let isActive: Bool
    let fraction: Double
    let onTap: () -> Void
    
    @State private var pulse = false
    @State private var showName = true
    @State private var hideTask: Task<Void, Never>? = nil
    
    var body: some View {
        Button(action: {
            onTap()
            revealName()
        }) {
            HStack(spacing: (isActive && showName) ? 10 : 0) {
                ZStack {
                    // ── Orbital Glow ──
                    if isActive {
                        Circle()
                            .fill(Color(hex: "#3ECFFF").opacity(0.18))
                            .frame(width: 34, height: 34)
                            .blur(radius: 4)
                            .scaleEffect(pulse ? 1.08 : 0.92)
                    }
                    
                    // ── Background Ring ──
                    Circle()
                        .stroke(Theme.bg3.opacity(0.5), lineWidth: 3.2)
                        .frame(width: 26, height: 26)
                    
                    // ── Progress Arcs ──
                    Circle()
                        .trim(from: 0, to: max(0.001, fraction))
                        .stroke(
                            Color.black.opacity(0.2),
                            style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 26, height: 26)
                        .blur(radius: 1).offset(y: 1)
                    
                    Circle()
                        .trim(from: 0, to: max(0.001, fraction))
                        .stroke(
                            LinearGradient(colors: [Theme.accent, Theme.coral], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 26, height: 26)
                    
                    if fraction > 0 && fraction < 1 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .shadow(color: Theme.accent, radius: 3)
                            .offset(y: -13)
                            .rotationEffect(.degrees(360 * fraction - 90))
                    }
                    
                    Text(list.emoji)
                        .font(.system(size: 14))
                        .scaleEffect(isActive ? 1.1 : 1.0)
                }
                .frame(width: 34, height: 34)
                
                if isActive && showName {
                    Text(list.cleanName.replacingOccurrences(of: " System", with: "", options: .caseInsensitive))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, (isActive && showName) ? 12 : 4)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Theme.bg1)
                            .shadow(color: Theme.accent.opacity(0.45), radius: 8, x: 0, y: 3)
                    } else {
                        Circle()
                            .fill(Theme.bg2.opacity(0.4))
                    }
                }
            )
            .overlay(
                Group {
                    if isActive {
                        Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.0)
                    } else {
                        Circle().strokeBorder(Theme.border, lineWidth: 0.5)
                    }
                }
            )
            .scaleEffect(isActive ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isActive {
                revealName()
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                revealName()
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                hideTask?.cancel()
                showName = false
                pulse = false
            }
        }
    }
    
    private func revealName() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showName = true
        }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showName = false
                }
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: TodoPill
// ══════════════════════════════════════════════

struct TodoPill: View {
    @EnvironmentObject var vm: AppViewModel
    let isActive: Bool
    let fraction: Double
    let onTap: () -> Void
    var onDoubleTap: (() -> Void)? = nil

    @State private var pulse = false
    private let green = Color(hex: "#4CAF50")

    var body: some View {
        pillContent
            .onTapGesture(count: 2) { onDoubleTap?() }
            .onTapGesture(count: 1) { onTap() }
            .onAppear { if isActive { startPulse() } }
            .onChange(of: isActive) { _, v in if v { startPulse() } else { pulse = false } }
    }

    private var pillContent: some View {
        VStack(spacing: 3) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(green.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .blur(radius: 4)
                        .scaleEffect(pulse ? 1.1 : 0.9)
                }
                Circle()
                    .stroke(Theme.bg3.opacity(0.5), lineWidth: 3.2)
                    .frame(width: 26, height: 26)
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(green, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 26, height: 26)
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isActive ? green : Theme.text1)
            }
            .frame(width: 34, height: 34)

            Text(vm.localized("TO DO"))
                .font(.system(size: 7, weight: .bold))
                .tracking(0.4)
                .foregroundColor(isActive ? green : Theme.text2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? Theme.bg1 : Theme.bg2.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? green.opacity(0.5) : Theme.border, lineWidth: isActive ? 1.0 : 0.5))
                .shadow(color: isActive ? green.opacity(0.28) : .clear, radius: 5, x: 0, y: 2)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .contentShape(Rectangle())
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
    }
}

struct WeekCalendarPill: View {
    let weekNumber: Int
    let isActive: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .top) {
                if isActive {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.24), Theme.coral.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 36)
                        .blur(radius: 5)
                        .scaleEffect(pulse ? 1.06 : 0.94)
                }

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isActive
                                ? [Color(hex: "#3ECFFF"), Color(hex: "#7C6FFF"), Color(hex: "#FF8A5B")]
                                : [Theme.bg1, Theme.bg2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isActive ? Color.white.opacity(0.42) : Theme.border, lineWidth: isActive ? 1.0 : 0.5)
                    )

                Capsule()
                    .fill(Color.black.opacity(isActive ? 0.18 : 0.08))
                    .frame(width: 24, height: 4)
                    .offset(y: 5)

                VStack(spacing: 1) {
                    Text("WK")
                        .font(.system(size: 7, weight: .black))
                        .kerning(0.4)
                        .foregroundColor(isActive ? Color.white.opacity(0.9) : Theme.text2)
                    Text("\(weekNumber)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(isActive ? .white : Theme.text0)
                }
                .offset(y: 9)
            }
            .frame(width: 40, height: 36)

            Text("WEEK")
                .font(.system(size: 7, weight: .bold))
                .tracking(0.4)
                .foregroundColor(isActive ? Theme.accent : Theme.text2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? Theme.bg1 : Theme.bg2.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isActive ? Theme.accent.opacity(0.52) : Theme.border, lineWidth: isActive ? 1.0 : 0.5)
                )
                .shadow(color: isActive ? Theme.accent.opacity(0.22) : .clear, radius: 6, x: 0, y: 2)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear { if isActive { startPulse() } }
        .onChange(of: isActive) { _, active in
            if active { startPulse() } else { pulse = false }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// ══════════════════════════════════════════════
// MARK: TodoSwipeRow — Custom Swipe-to-Reveal
// ══════════════════════════════════════════════

struct TodoSwipeRow<Content: View>: View {
    @EnvironmentObject var vm: AppViewModel
    let task: SortydTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    private let buttonWidth: CGFloat = 70
    private let maxOffset: CGFloat = -140 // 2 buttons: Edit (70) + Delete (70)

    var body: some View {
        ZStack {
            // Background Action Buttons
            HStack(spacing: 0) {
                Spacer()
                
                // Edit Button
                Button(action: {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                        isSwiped = false
                    }
                    onEdit()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#4CAF50").opacity(0.12))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(hex: "#4CAF50").opacity(0.4), lineWidth: 1)
                            )
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#4CAF50"))
                    }
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                
                // Delete Button
                Button(action: {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.warning)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                        isSwiped = false
                    }
                    onDelete()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                            )
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.red)
                    }
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
            
            // Foreground Content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { gesture in
                            let dragAmount = gesture.translation.width
                            // Only allow swipe left (negative offset)
                            if isSwiped {
                                let newOffset = maxOffset + dragAmount
                                offset = min(0, max(maxOffset - 40, newOffset))
                            } else {
                                if dragAmount < 0 {
                                    offset = max(maxOffset - 40, dragAmount)
                                }
                            }
                        }
                        .onEnded { gesture in
                            let dragAmount = gesture.translation.width
                            let velocity = gesture.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if velocity < -50 || offset < maxOffset / 2 || dragAmount < -80 {
                                    offset = maxOffset
                                    isSwiped = true
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// ══════════════════════════════════════════════
// MARK: TaskRowView — with optional SmallHealthDonut
// ══════════════════════════════════════════════

struct TaskRowView: View {
    @EnvironmentObject var vm: AppViewModel
    let task: SortydTask
    let hk: HealthKitManager
    var isTodoStyle: Bool = false
    var onEdit: (() -> Void)? = nil
    let onToggle: () -> Void
    

    @State private var showHealthPermission = false
    @State private var showHealthConfirm = false

    private var resolvedHealthType: HealthTaskType? {
        guard task.isHealthTask, let str = task.healthType else { return nil }
        return HealthTaskType(rawValue: str)
    }

    /// True when this task needs HealthKit but permission hasn't been granted yet
    private var needsHealthPermission: Bool {
        guard let ht = resolvedHealthType, ht != .none else { return false }
        return !hk.isAuthorized
    }

    private var timeLabel: String? {
        guard let t = task.reminderTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = vm.appLanguage.locale
        return f.string(from: t)
    }

    private var subtitleText: String {
        if needsHealthPermission { return vm.localized("Tap to allow Health access") }
        if task.isCompleted { return vm.localized("Completed") }
        
        if let t = timeLabel { return vm.localized("Due \(t)") }
        
        // Removed health measure from subtitle - shown vertically next to tank
        return vm.localized("Anytime")
    }

    var body: some View {
        Group {
            if needsHealthPermission {
                // ── Health permission required — prominent CTA row ──
                Button(action: { showHealthPermission = true }) {
                    HStack(spacing: 12) {
                        // Pulsing icon badge
                        ZStack {
                            Circle()
                                .fill(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7").opacity(0.18))
                                .frame(width: 38, height: 38)
                            Image(systemName: resolvedHealthType?.icon ?? "heart.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7"))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.text0)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7"))
                                Text(vm.localized("Tap to enable Health tracking"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7"))
                            }
                        }

                        Spacer()

                        // Arrow CTA
                        Image(systemName: "chevron.right")
                            .flipsForRightToLeftLayoutDirection(true)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7").opacity(0.7))
                    }
                    .padding(.horizontal, Theme.s16)
                    .padding(.vertical, 10)
                    .background(healthPermissionBackground)
                }
                .buttonStyle(.plain)
            } else {
                // ── Normal task row ──
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 1) { // Reduced spacing
                        Text(task.title)
                            .font(.system(size: 15, weight: task.isCompleted ? .regular : .semibold))
                            .foregroundColor(task.isCompleted ? Theme.text2.opacity(0.68) : Theme.text0)
                            .strikethrough(task.isCompleted, color: isTodoStyle ? Theme.text2.opacity(0.55) : Theme.text2)
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            if timeLabel != nil && !task.isCompleted {
                                Image(systemName: "bell.fill").font(.system(size: 7))
                                    .foregroundColor(isTodoStyle ? Color(hex: "#4CAF50").opacity(0.82) : Color(hex: "#00E5FF"))
                            }
                            Text(subtitleText)
                                .font(.system(size: 9, weight: .bold)) // Matches alert size
                                .foregroundColor(
                                    timeLabel != nil && !task.isCompleted
                                    ? (isTodoStyle ? Color(hex: "#4CAF50").opacity(0.82) : Color(hex: "#00E5FF"))
                                    : (task.isCompleted ? Theme.text2.opacity(0.62) : (isTodoStyle ? Color(hex: "#4CAF50").opacity(0.72) : Theme.text2))
                                )
                        }
                    }

                    Spacer()

                    if let ht = resolvedHealthType, let target = task.healthTarget, !task.isCompleted {
                        HStack(spacing: 8) {
                            let current = hk.currentValue(for: ht)
                            // Vertical Measure (Achieved / Target)
                            VStack(spacing: 2) {
                                Text(ht == .distance ? String(format: "%.1f", current) : String(format: "%.0f", current))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                
                                Rectangle()
                                    .fill(Color(hex: ht.accentColor).opacity(0.4))
                                    .frame(width: 14, height: 1.5)
                                
                                Text("\(Int(target))")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .opacity(0.8)
                            }
                            .foregroundColor(Color(hex: ht.accentColor))
                            .frame(minWidth: 24)

                            SmallHealthBar(
                                taskType: ht,
                                target: target,
                                current: current,
                                height: 38,
                                tankWidth: 32
                            )
                        }
                    }



                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.prepare(); gen.impactOccurred()
                        if shouldConfirmHealthToggle {
                            showHealthConfirm = true
                        } else {
                            onToggle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .strokeBorder(task.isCompleted ? (isTodoStyle ? Color(hex: "#4CAF50") : Theme.accent) : (isTodoStyle ? Color(hex: "#4CAF50").opacity(0.35) : Theme.border), lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                            if task.isCompleted {
                                Circle().fill(isTodoStyle ? Color(hex: "#4CAF50") : Theme.accent).frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(ThemeManager.shared.isDark ? Theme.bg0 : .white)
                            }
                        }
                        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: task.isCompleted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isCompleted
                                        ? String(format: vm.localized("Mark %@ incomplete"), task.title)
                                        : String(format: vm.localized("Mark %@ complete"), task.title))
                    .accessibilityHint(task.isCompleted ? vm.localized("Double tap to uncheck") : vm.localized("Double tap to check off"))
                }
                .padding(.horizontal, Theme.s16)
                .padding(.vertical, 7)
                .background(taskBackground)
                .animation(.easeInOut(duration: 0.18), value: task.isCompleted)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hk.isAuthorized)
        .alert(vm.localized("Target Not Reached"), isPresented: $showHealthConfirm) {
            Button(vm.localized("Yes, I completed it"), role: .none) { onToggle() }
            Button(vm.localized("No"), role: .cancel) {}
        } message: {
            Text(healthConfirmMessage + "\n\n" + vm.localized("We recommend using a tracking device or keeping your phone on you so Sortyd auto-detects and never doubts."))
        }
        .sheet(isPresented: $showHealthPermission) {
            if let ht = resolvedHealthType {
                HealthPermissionSheet(
                    taskType: ht,
                    onGrant: { hk.fetchToday() },
                    onSkip:  {}
                )
                .environmentObject(vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.r32)
                .presentationBackground(Theme.bg0)
            }
        }
    }

    private var shouldConfirmHealthToggle: Bool {
        guard !task.isCompleted,
              let ht = resolvedHealthType,
              let target = task.healthTarget,
              hk.isAuthorized
        else { return false }
        return hk.currentValue(for: ht) < target
    }

    private var healthConfirmMessage: String {
        guard let ht = resolvedHealthType, let target = task.healthTarget else { return "" }
        let current = hk.currentValue(for: ht)
        switch ht {
        case .steps:
            return String(format: vm.localized("You've logged %lld steps, but your target is %lld steps. Are you sure you completed this?"), Int64(current), Int64(target))
        case .calories:
            return String(format: vm.localized("You've burned %lld kcal, but your target is %lld kcal. Are you sure you completed this?"), Int64(current), Int64(target))
        case .distance:
            let label = ht.label.lowercased()
            return String(format: vm.localized("You've covered %.1f %@, but your target is %.1f %@. Are you sure you completed this?"), current, label, target, label)
        case .none:
            return ""
        }
    }

    @ViewBuilder
    private var healthPermissionBackground: some View {
        let accent = Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7")
        RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
            .fill(accent.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                    .strokeBorder(accent.opacity(0.4), lineWidth: 1)
            )
            .cardShadow()
    }

    @ViewBuilder
    private var taskBackground: some View {
        let fillStyle: AnyShapeStyle = {
            if isTodoStyle {
                return AnyShapeStyle(Theme.bg2)
            } else {
                return AnyShapeStyle(task.isCompleted ? Theme.accent.opacity(0.05) : Theme.bg1)
            }
        }()

        let strokeStyle: AnyShapeStyle = {
            if isTodoStyle {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                return AnyShapeStyle(task.isCompleted ? Theme.accent.opacity(0.15) : Theme.border)
            }
        }()

        RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
            .fill(fillStyle)
            .shadow(color: isTodoStyle ? Color.black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                    .strokeBorder(strokeStyle, lineWidth: isTodoStyle ? 1.0 : 0.5)
            )
            .overlay(alignment: .leading) {
                if isTodoStyle {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: task.isCompleted
                                    ? [Color(hex: "#4CAF50").opacity(0.5), Color(hex: "#2E7D32").opacity(0.5)]
                                    : [Color(hex: "#4CAF50"), Color(hex: "#2E7D32")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 36)
                        .shadow(color: task.isCompleted ? .clear : Color(hex: "#4CAF50").opacity(0.4), radius: 6, x: 0, y: 0)
                        .padding(.leading, 8)
                }
            }
            .cardShadow()
    }
}


// MARK: EmptyStateView
// ══════════════════════════════════════════════

struct EmptyStateView: View {
    @EnvironmentObject var vm: AppViewModel
    let onAddList: () -> Void

    private var line1: String {
        switch vm.appLanguage {
        case .arabic:   return "لنبدأ"
        case .spanish:  return "Vamos a"
        case .chinese:  return "开始"
        default:        return "Let's get"
        }
    }
    private var line2: String {
        switch vm.appLanguage {
        case .arabic:   return "التتبع"
        case .spanish:  return "Rastrear"
        case .chinese:  return "追踪"
        default:        return "Tracking"
        }
    }
    @State private var line1Count: Int = 0
    @State private var line2Count: Int = 0
    @State private var typingLine: Int = 1
    @State private var cursorVisible: Bool = true

    @State private var gridOpacity: Double    = 0
    @State private var orbOpacity: Double     = 0
    @State private var orbScale: CGFloat      = 0.5
    @State private var glowPulse: Bool        = false
    @State private var orb2Float: CGFloat     = 0
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 10
    @State private var pillsOpacity: Double   = 0
    @State private var pillsOffset: CGFloat   = 10
    @State private var btnOpacity: Double     = 0
    @State private var btnScale: CGFloat      = 0.94
    @State private var showFingerTap: Bool    = false
    @State private var isHandPressing: Bool   = false

    private let violet = Color(hex: "#3ECFFF")
    private let cyan   = Color(hex: "#7C6FFF")
    private var letsPrefix: Int {
        switch vm.appLanguage {
        case .arabic:  return 0
        case .chinese: return 0
        case .spanish: return 6 // 'Vamos ' is 6
        default:       return 6 // 'Let's ' is 6
        }
    }

    private var revealedLine1: String { String(line1.prefix(line1Count)) }
    private var revealedLine2: String { String(line2.prefix(line2Count)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Canvas { ctx, size in
                    let cols = 9; let rows = 5
                    let spacingX = size.width / CGFloat(cols)
                    let spacingY = size.height / CGFloat(rows)
                    for row in 0...rows {
                        for col in 0...cols {
                            let x = CGFloat(col) * spacingX
                            let y = CGFloat(row) * spacingY
                            let p = CGFloat(row) / CGFloat(rows)
                            let ds = 1.2 + p * 1.4
                            ctx.fill(Path(ellipseIn: CGRect(x: x - ds/2, y: y - ds/2, width: ds, height: ds)),
                                     with: .color(violet.opacity(0.08 + p * 0.18)))
                        }
                    }
                }
                .frame(height: 90).opacity(gridOpacity)

                Ellipse()
                    .fill(RadialGradient(colors: [violet.opacity(0.28), violet.opacity(0.08), .clear],
                                         center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 140).blur(radius: 30)
                    .scaleEffect(orbScale).opacity(orbOpacity).offset(x: -30, y: 10)

                Ellipse()
                    .fill(RadialGradient(colors: [cyan.opacity(0.22), cyan.opacity(0.05), .clear],
                                         center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 140, height: 100).blur(radius: 24)
                    .opacity(orbOpacity * 0.85).offset(x: 60, y: orb2Float)
            }
            .frame(height: 0).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    if vm.appLanguage == .arabic || vm.appLanguage == .chinese {
                         Text(revealedLine1)
                            .font(.system(size: 40, weight: .black, design: .serif))
                            .foregroundColor(Theme.text0)
                    } else if line1Count <= letsPrefix {
                        Text(String(vm.appLanguage == .spanish ? "Vamos " : "Let's "))
                            .font(.system(size: 40, weight: .black, design: .serif))
                            .foregroundColor(Theme.text0)
                    } else {
                        Text(String(vm.appLanguage == .spanish ? "Vamos " : "Let's "))
                            .font(.system(size: 35, weight: .black, design: .serif))
                            .foregroundColor(Theme.text0)
                        let base = vm.appLanguage == .spanish ? "a" : "get"
                        Text(String(base.prefix(line1Count - letsPrefix)))
                            .font(.system(size: 35, weight: .black, design: .serif).italic())
                            .foregroundColor(Theme.text0)
                    }
                    if typingLine == 1 { cursorBar(height: 30, color: violet) }
                }
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    if !revealedLine2.isEmpty {
                        Text(revealedLine2)
                            .font(.system(size: 50, weight: .black, design: .serif))
                            .foregroundStyle(LinearGradient(colors: [violet, cyan],
                                                             startPoint: .leading, endPoint: .trailing))
                            .shadow(color: violet.opacity(glowPulse ? 0.65 : 0.28), radius: glowPulse ? 22 : 10)
                            .shadow(color: cyan.opacity(glowPulse ? 0.40 : 0.15), radius: glowPulse ? 14 : 6)
                    }
                    if typingLine == 2 { cursorBar(height: 30, color: violet) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(LinearGradient(colors: [violet.opacity(0.7), cyan.opacity(0.5), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1).padding(.top, 10).padding(.bottom, 10).opacity(subtitleOpacity)

            Text(vm.localized("Build momentum, one habit at a time."))
                .font(.system(size: 14, weight: .medium)).italic()
                .foregroundColor(Theme.text0).tracking(0.2)
                .opacity(subtitleOpacity).offset(y: subtitleOffset)

            HStack(spacing: 10) {
                statPill(icon: "checkmark.circle", label: vm.localized("Track tasks"),   color: violet)
                statPill(icon: "flame",            label: vm.localized("Build streaks"), color: cyan)
                statPill(icon: "chart.bar",        label: vm.localized("See progress"),  color: violet)
            }
            .padding(.top, 12).opacity(pillsOpacity).offset(y: pillsOffset)

            Button(action: {
                UserDefaults.standard.set(true, forKey: "has_seen_create_list_onboarding")
                withAnimation { showFingerTap = false }
                onAddList()
            }) {
                HStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(hex: "#0C0D16").opacity(0.25)).frame(width: 32, height: 32)
                        Image(systemName: "plus").font(.system(size: 13, weight: .black))
                            .foregroundColor(Color(hex: "#0C0D16"))
                    }.padding(.trailing, 12)
                    Text(vm.localized("Create your first list"))
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "#0C0D16"))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .flipsForRightToLeftLayoutDirection(true)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#0C0D16").opacity(0.55)).padding(.trailing, 2)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                            .fill(LinearGradient(colors: [violet, cyan],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.18), .clear],
                                                 startPoint: .top, endPoint: .center))
                    }
                )
                .shadow(color: violet.opacity(glowPulse ? 0.55 : 0.32), radius: glowPulse ? 22 : 14, x: 0, y: 6)
                .shadow(color: cyan.opacity(glowPulse ? 0.35 : 0.18), radius: glowPulse ? 14 : 8, x: 0, y: 3)
            }
            .buttonStyle(.plain).padding(.top, 20)
            .scaleEffect(isHandPressing ? 0.96 : btnScale)
            .rotation3DEffect(.degrees(isHandPressing ? -6 : 0), axis: (x: 1, y: 0, z: 0))
            .opacity(btnOpacity)
            .overlay(alignment: .center) {
                if showFingerTap {
                    FingerTapView(isPressing: $isHandPressing)
                        .offset(x: 110, y: 22)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear { 
            // DEBUG: Force onboarding to show every time
            UserDefaults.standard.set(false, forKey: "has_seen_create_list_onboarding")
            runEntrance() 
        }
    }

    @ViewBuilder
    private func cursorBar(height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color)
            .frame(width: 3, height: height)
            .opacity(cursorVisible ? 1 : 0)
            .shadow(color: color.opacity(0.9), radius: 8).padding(.leading, 4)
    }

    @ViewBuilder
    private func statPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(color)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text1)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(Theme.bg2)
            .overlay(Capsule(style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 0.8)))
    }

    private func runEntrance() {
        withAnimation(.easeInOut(duration: 0.48).repeatForever(autoreverses: true)) { cursorVisible.toggle() }
        withAnimation(.easeOut(duration: 0.7)) { gridOpacity = 1 }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.6).delay(0.1)) { orbScale = 1.0; orbOpacity = 1.0 }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.4)) { orb2Float = -14 }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.0)) { glowPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            typeString(line1) { line1Count = $0 } onDone: {
                typingLine = 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    typeString(line2) { line2Count = $0 } onDone: { typingLine = 3; revealRest() }
                }
            }
        }
    }

    private func typeString(_ str: String, onChar: @escaping (Int) -> Void, onDone: @escaping () -> Void) {
        for i in Array(str).indices {
            let delay = Double(i) * 0.065 + Double.random(in: 0...0.018)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onChar(i + 1)
                if i == Array(str).count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDone() }
                }
            }
        }
    }

    private func revealRest() {
        withAnimation(.easeOut(duration: 0.45)) { subtitleOpacity = 1; subtitleOffset = 0 }
        withAnimation(.easeOut(duration: 0.45).delay(0.15)) { pillsOpacity = 1; pillsOffset = 0 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.3)) { btnOpacity = 1; btnScale = 1.0 }
        
        // Show onboarding finger tap if first time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // DEBUG: Force onboarding
            UserDefaults.standard.set(false, forKey: "has_seen_create_list_onboarding")
            
            let key = "has_seen_create_list_onboarding"
            if !UserDefaults.standard.bool(forKey: key) {
                withAnimation(.spring()) {
                    showFingerTap = true
                }
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: ListSwitcherSheet
// ══════════════════════════════════════════════

struct ListSwitcherSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                VStack(spacing: 0) {
                    Capsule().fill(Theme.bg3).frame(width: 36, height: 4)
                        .padding(.top, 12).padding(.bottom, Theme.s20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vm.appLanguage == .arabic ? "تبديل القائمة" : (vm.appLanguage == .spanish ? "Cambiar lista" : (vm.appLanguage == .chinese ? "切换列表" : "Switch List"))).font(.system(size: 22, weight: .black)).foregroundColor(Theme.text0)
                        Text(vm.appLanguage == .arabic ? "تظهر في علامة تبويب اليوم" : (vm.appLanguage == .spanish ? "Mostrando en la pestaña Hoy" : (vm.appLanguage == .chinese ? "显示在今天标签" : "Showing on Today tab"))).font(.system(size: 13)).foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.s20).padding(.bottom, Theme.s20)

                    let liveLists = vm.lists.filter { !$0.isArchived && !$0.isWeekly }
                    if liveLists.isEmpty {
                        EmptyDark(icon: "📋", title: vm.localized("No lists"), subtitle: vm.localized("Create a list first."))
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(liveLists) { list in
                                    Button(action: { vm.setActiveList(list); dismiss() }) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(vm.activeListID == list.id ? Theme.accent.opacity(0.15) : Theme.bg2)
                                                    .frame(width: 46, height: 46)
                                                Text(list.emoji).font(.title3)
                                            }
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(list.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text0)
                                                Text("\(list.tasks.count) \(vm.localized("tasks")) · \(list.completionPercentage)% \(vm.localized("today"))")
                                                    .font(.system(size: 12)).foregroundColor(Theme.text1)
                                            }
                                            Spacer()
                                            if vm.activeListID == list.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20)).foregroundColor(Theme.accent).amberGlow(intensity: 0.25)
                                            }
                                        }
                                        .padding(Theme.s16)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                                                .fill(vm.activeListID == list.id ? Theme.accent.opacity(0.07) : Theme.bg1)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: Theme.r20, style: .continuous)
                                                        .strokeBorder(vm.activeListID == list.id ? Theme.accent.opacity(0.3) : Theme.border, lineWidth: 0.5)
                                                )
                                                .cardShadow()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Theme.s16)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Theme.r32)
        .presentationBackground(Theme.bg0)
    }
}

// ══════════════════════════════════════════════
// MARK: SettingsSheet
// ══════════════════════════════════════════════

struct SettingsSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                VStack(spacing: 12) {
                    ThemeToggleRow().environmentObject(ThemeManager.shared)

                    // ── Clear history ────────────────────────────────
                    Button(action: { showClearConfirm = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.appLanguage == .arabic ? "مسح سجل الإنجاز" : (vm.appLanguage == .spanish ? "Borrar historial de completado" : (vm.appLanguage == .chinese ? "清除完成记录" : "Clear completion history")))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.danger)
                                Text(vm.appLanguage == .arabic ? "يحذف جميع اللقطات والنشاطات. يتم الاحتفاظ بالمهام." : (vm.appLanguage == .spanish ? "Borra todas las capturas y rachas. Las tareas se mantienen." : (vm.appLanguage == .chinese ? "删除所有快照和连续记录，任务保留。" : "Deletes all snapshots and streaks. Tasks are kept.")))
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.text2)
                            }
                            Spacer()
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.danger)
                        }
                        .padding(Theme.s16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                                .fill(Theme.danger.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                                        .strokeBorder(Theme.danger.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(vm.localized("Clear completion history"))
                    .accessibilityHint(vm.localized("Double tap to delete all habit snapshots and streaks"))

                    Spacer()
                }
                .padding(Theme.s16).padding(.top, 8)
            }
            .navigationTitle(vm.appLanguage == .arabic ? "الإعدادات" : (vm.appLanguage == .spanish ? "Ajustes" : (vm.appLanguage == .chinese ? "设置" : "Settings"))).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(vm.localized("Done")) { dismiss() }.foregroundColor(Theme.accent).fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                vm.localized("Clear all history?"),
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button(vm.localized("Clear History"), role: .destructive) {
                    vm.clearAllSnapshots()
                    dismiss()
                }
                Button(vm.localized("Cancel"), role: .cancel) {}
            } message: {
                Text(vm.appLanguage == .arabic ? "سيؤدي هذا إلى حذف جميع لقطات الإكمال والنشاطات بشكل دائم. لن تتأثر قوائمك ومهامك." : (vm.appLanguage == .spanish ? "Esto borra permanentemente todas las capturas y rachas. Tus listas y tareas no se verán afectadas." : (vm.appLanguage == .chinese ? "这将永久删除所有完成快照和连续记录，列表和任务不受影响。" : "This permanently deletes all completion snapshots and streaks. Your lists and tasks are not affected.")))
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: PlaceholderCalendarView
// ══════════════════════════════════════════════

struct PlaceholderCalendarView: View {
    @EnvironmentObject var vm: AppViewModel
    private let dayLetters = ["S","M","T","W","T","F","S"]
    private let today = Date()
    private let colGap: CGFloat = 0
    private let vSpacing: CGFloat = 1

    private var currentMonth: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: today)
    }

    private var rows: [[Date?]] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let first = cal.date(from: comps), let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        var slots: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in range { slots.append(cal.date(byAdding: .day, value: day - 1, to: first)) }
        return slots.chunked(into: 7)
    }

    var body: some View {
        GeometryReader { geo in
            let availW = geo.size.width; let availH = geo.size.height
            let cellByW = (availW - colGap * 6) / 7
            let nRows: CGFloat = 7
            let cellByH = (availH - 15 - vSpacing * nRows) / nRows
            let cs = min(cellByW, cellByH) * 1.2



            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(currentMonth).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text1)
                    Spacer()
                    HStack(spacing: 3) {
                        Text(vm.appLanguage == .arabic ? "منخفض" : (vm.appLanguage == .spanish ? "Bajo" : (vm.appLanguage == .chinese ? "低" : "Low")))
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(Theme.text2)
                        HStack(spacing: 1) {
                            ForEach([0.15, 0.35, 0.55, 0.75, 1.0], id: \.self) { f in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Theme.heatColor(fraction: f))
                                    .frame(width: 7, height: 7)
                            }
                        }
                        Text(vm.appLanguage == .arabic ? "الأفضل" : (vm.appLanguage == .spanish ? "Mejor" : (vm.appLanguage == .chinese ? "最佳" : "Best")))
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(Theme.text2)
                    }
                }.frame(height: 15)
                Spacer(minLength: vSpacing)
                HStack(spacing: 0) {
                    ForEach(dayLetters.indices, id: \.self) { i in
                        Text(dayLetters[i]).font(.system(size: max(7, cs * 0.34), weight: .medium))
                            .foregroundColor(Theme.text2).frame(width: cs, height: cs)
                        if i < 6 { Spacer(minLength: 0) }
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    Spacer(minLength: vSpacing)
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            if row < rows.count, col < rows[row].count, let date = rows[row][col] {
                                placeholderCell(date: date, size: cs)
                            } else {
                                Color.clear.frame(width: cs, height: cs)
                            }
                            if col < 6 { Spacer(minLength: 0) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: availW, height: availH)
        }
    }

    @ViewBuilder
    private func placeholderCell(date: Date, size: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let day = Calendar.current.component(.day, from: date)
        ZStack {
            Circle().fill(Theme.text0.opacity(0.08)).frame(width: size, height: size)
            if isToday { Circle().strokeBorder(Theme.accent, lineWidth: 1.5).frame(width: size, height: size) }
            Text("\(day)").font(.system(size: max(size * 0.36, 7), weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? Theme.accent : Theme.text0.opacity(0.4))
        }
        .frame(width: size, height: size)
    }
}

// ══════════════════════════════════════════════
// MARK: Notification names
// ══════════════════════════════════════════════

extension Notification.Name {
    static let bounceCreateButton = Notification.Name("bounceCreateButton")
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

#Preview { HomeView().environmentObject(AppViewModel()).environmentObject(ThemeManager.shared) }

// MARK: - Tab Shape

struct PlannerTabShape: Shape {
    let waveOnTrailingEdge: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY
        let bottom = rect.maxY
        let mid = rect.midY
        
        if waveOnTrailingEdge {
            path.move(to: CGPoint(x: rect.minX, y: bottom))
            path.addLine(to: CGPoint(x: rect.minX, y: top + 6))
            path.addCurve(
                to: CGPoint(x: rect.minX + 14, y: top),
                control1: CGPoint(x: rect.minX, y: top + 2),
                control2: CGPoint(x: rect.minX + 4, y: top)
            )
            path.addLine(to: CGPoint(x: rect.maxX - 34, y: top))
            path.addCurve(
                to: CGPoint(x: rect.maxX - 8, y: mid - 4),
                control1: CGPoint(x: rect.maxX - 18, y: top + 1),
                control2: CGPoint(x: rect.maxX - 12, y: top + 7)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX - 31, y: bottom),
                control1: CGPoint(x: rect.maxX + 3, y: mid + 12),
                control2: CGPoint(x: rect.maxX - 11, y: bottom - 1)
            )
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: top))
            path.addLine(to: CGPoint(x: rect.maxX, y: bottom - 6))
            path.addCurve(
                to: CGPoint(x: rect.maxX - 14, y: bottom),
                control1: CGPoint(x: rect.maxX, y: bottom - 2),
                control2: CGPoint(x: rect.maxX - 4, y: bottom)
            )
            path.addLine(to: CGPoint(x: rect.minX + 34, y: bottom))
            path.addCurve(
                to: CGPoint(x: rect.minX + 8, y: mid + 4),
                control1: CGPoint(x: rect.minX + 18, y: bottom - 1),
                control2: CGPoint(x: rect.minX + 12, y: bottom - 7)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + 31, y: top),
                control1: CGPoint(x: rect.minX - 3, y: mid - 12),
                control2: CGPoint(x: rect.minX + 11, y: top + 1)
            )
            path.closeSubpath()
        }
        
        return path
    }
}
