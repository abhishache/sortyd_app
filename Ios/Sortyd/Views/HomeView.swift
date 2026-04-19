// MARK: - HomeView.swift
// Sortyd v4 — HealthKit-aware completion % and SmallHealthDonut in task rows

import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var hk = HealthKitManager.shared
    @State private var showSwitcher = false
    @State private var currentTime: String = HomeView.timeString()

    private var list: TaskList? { vm.activeList }

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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, Theme.s16)
                            .padding(.top, 14)
                            .padding(.bottom, 20)

                        heroSection
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 10)

                        heatmapSection
                            .padding(.horizontal, Theme.s16)
                            .padding(.bottom, 20)

                        taskSection
                            .padding(.horizontal, Theme.s16)

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSwitcher) {
                ListSwitcherSheet().environmentObject(vm)
            }
            
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                currentTime = HomeView.timeString()
            }
            // Refresh HealthKit data whenever app comes to foreground
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                hk.fetchToday()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Text(currentTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.text2)

            Spacer()

            ThemeToggleButton()
                .environmentObject(themeManager)

            Button(action: { showSwitcher = true }) {
                HStack(spacing: 6) {
                    Text(list?.emoji ?? "📋").font(.system(size: 13))
                    Text(list?.name ?? "No list")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.text1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.bg2)
                        .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .accessibilityLabel("Switch list, currently \(list?.name ?? "no list")")
                        .accessibilityHint("Double tap to choose a different list")
        }
    }

    // MARK: - Hero (uses live health-aware %)

    private var heroSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(list?.name.uppercased() ?? "NO LIST")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(Theme.accent)
                    .padding(.bottom, 4)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(liveCompletionPct)")
                        .font(.system(size: 86, weight: .black, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("%")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(Theme.accent.opacity(0.75))
                        .offset(y: -10)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(liveCompletionPct) percent complete today")  // ← add here

                Text("Done Today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text2)
                    .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("🔥").font(.system(size: 32)).padding(.bottom, 2)
                Text("\(vm.cachedBestStreak)")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)
                    .lineLimit(1)
                Text("Day Streak")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(Theme.text2)
            }
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)          // ← add here
            .accessibilityLabel("\(vm.cachedBestStreak) day streak")  // ← add here
        }
    }

    // MARK: - Heatmap Strip

    private var heatmapSection: some View {
        VStack(spacing: 0) {
            if let id = list?.id {
                HeatmapCalendarView(listID: id)
                    .environmentObject(vm)
                    .frame(height: 120)
            } else {
                PlaceholderCalendarView().frame(height: 120)
            }
        }
        .padding(.all, 14)
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
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
        VStack(spacing: 10) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.6)
                    .foregroundColor(Theme.text2)
                Spacer()
                if let list = list {
                    let done = list.tasks.filter(\.isCompleted).count
                    let left = list.tasks.count - done
                    Text("\(done) done · \(left) left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text1)
                }
            }

            if let list = list, !list.tasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(list.tasks) { task in
                        TaskRowView(task: task, hk: hk) { vm.toggleTask(task) }
                    }
                }
            } else {
                EmptyStateView(onAddList: {
                    vm.selectedTab = 1
                })
                .padding(.top, 1)
            }
        }
    }

    private static func timeString() -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }
}

// ══════════════════════════════════════════════
// MARK: TaskRowView — with optional SmallHealthDonut
// ══════════════════════════════════════════════

struct TaskRowView: View {
    let task: SortydTask
    let hk: HealthKitManager
    let onToggle: () -> Void
    

    @State private var showHealthPermission = false

    private var resolvedHealthType: HealthTaskType? {
        guard task.isHealthTask, let str = task.healthType else { return nil }
        return HealthTaskType(rawValue: str)
    }

    /// True when this task needs HealthKit but permission hasn't been granted yet
    private var needsHealthPermission: Bool {
        resolvedHealthType != nil && !hk.isAuthorized
    }

    private var timeLabel: String? {
        guard let t = task.reminderTime else { return nil }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: t)
    }

    private var subtitleText: String {
        if needsHealthPermission { return "Tap to allow Health access" }
        if task.isCompleted { return "Completed" }
        if let t = timeLabel { return "Due \(t)" }
        if let ht = resolvedHealthType, let target = task.healthTarget {
            let current = hk.currentValue(for: ht)
            let formatted = String(format: "%.0f / %.0f", current, target)
            return "\(formatted) \(ht.label.lowercased())"
        }
        return "Anytime"
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
                                Text("Tap to enable Health tracking")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: resolvedHealthType?.accentColor ?? "#4FC3F7"))
                            }
                        }

                        Spacer()

                        // Arrow CTA
                        Image(systemName: "chevron.right")
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 15, weight: task.isCompleted ? .regular : .semibold))
                            .foregroundColor(task.isCompleted ? Theme.text2 : Theme.text0)
                            .strikethrough(task.isCompleted, color: Theme.text2)
                            .lineLimit(1)

                        Text(subtitleText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(task.isCompleted ? Theme.accent.opacity(0.6) : Theme.text2)
                    }

                    Spacer()

                    if let ht = resolvedHealthType, let target = task.healthTarget, !task.isCompleted {
                        SmallHealthBar(
                            taskType: ht,
                            target: target,
                            current: hk.currentValue(for: ht),
                            height: 44
                        )
                    } else if let t = timeLabel, !task.isCompleted {
                        Text(t)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.text1)
                    }

                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.prepare(); gen.impactOccurred()
                        onToggle()
                    }) {
                        ZStack {
                            Circle()
                                .strokeBorder(task.isCompleted ? Theme.accent : Theme.border, lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                            if task.isCompleted {
                                Circle().fill(Theme.accent).frame(width: 26, height: 26)
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
                    .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")
                    .accessibilityHint(task.isCompleted ? "Double tap to uncheck" : "Double tap to check off")
                }
                .padding(.horizontal, Theme.s16)
                .padding(.vertical, 7)
                .background(taskBackground)
                .animation(.easeInOut(duration: 0.18), value: task.isCompleted)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hk.isAuthorized)
        .sheet(isPresented: $showHealthPermission) {
            if let ht = resolvedHealthType {
                HealthPermissionSheet(
                    taskType: ht,
                    onGrant: { hk.fetchToday() },
                    onSkip:  {}
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.r32)
                .presentationBackground(Theme.bg0)
            }
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
        RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
            .fill(task.isCompleted ? Theme.accent.opacity(0.05) : Theme.bg1)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                    .strokeBorder(
                        task.isCompleted ? Theme.accent.opacity(0.15) : Theme.border,
                        lineWidth: 0.5
                    )
            )
            .cardShadow()
    }
}

// ══════════════════════════════════════════════
// MARK: EmptyStateView
// ══════════════════════════════════════════════

struct EmptyStateView: View {
    let onAddList: () -> Void

    private let line1 = "Let's get"
    private let line2 = "Tracking."
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

    private let violet = Color(hex: "#3ECFFF")
    private let cyan   = Color(hex: "#7C6FFF")
    private let letsPrefix = 6

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
                    if line1Count <= letsPrefix {
                        Text(revealedLine1)
                            .font(.system(size: 40, weight: .black, design: .serif))
                            .foregroundColor(Theme.text0)
                    } else {
                        Text("Let's ")
                            .font(.system(size: 35, weight: .black, design: .serif))
                            .foregroundColor(Theme.text0)
                        Text(String("get".prefix(line1Count - letsPrefix)))
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

            Text("Build momentum, one habit at a time.")
                .font(.system(size: 14, weight: .medium)).italic()
                .foregroundColor(Theme.text0).tracking(0.2)
                .opacity(subtitleOpacity).offset(y: subtitleOffset)

            HStack(spacing: 10) {
                statPill(icon: "checkmark.circle", label: "Track tasks",   color: violet)
                statPill(icon: "flame",            label: "Build streaks", color: cyan)
                statPill(icon: "chart.bar",        label: "See progress",  color: violet)
            }
            .padding(.top, 12).opacity(pillsOpacity).offset(y: pillsOffset)

            Button(action: onAddList) {
                HStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(hex: "#0C0D16").opacity(0.25)).frame(width: 32, height: 32)
                        Image(systemName: "plus").font(.system(size: 13, weight: .black))
                            .foregroundColor(Color(hex: "#0C0D16"))
                    }.padding(.trailing, 12)
                    Text("Create your first list")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "#0C0D16"))
                    Spacer()
                    Image(systemName: "arrow.right")
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
            .scaleEffect(btnScale).opacity(btnOpacity)
        }
        .onAppear { runEntrance() }
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
                        Text("Switch List").font(.system(size: 22, weight: .black)).foregroundColor(Theme.text0)
                        Text("Showing on Today tab").font(.system(size: 13)).foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.s20).padding(.bottom, Theme.s20)

                    let liveLists = vm.lists.filter { !$0.isArchived }
                    if liveLists.isEmpty {
                        EmptyDark(icon: "📋", title: "No lists", subtitle: "Create a list first.")
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
                                                Text("\(list.tasks.count) tasks · \(list.completionPercentage)% today")
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
                                Text("Clear completion history")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.danger)
                                Text("Deletes all snapshots and streaks. Tasks are kept.")
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
                    .accessibilityLabel("Clear completion history")
                    .accessibilityHint("Double tap to delete all habit snapshots and streaks")

                    Spacer()
                }
                .padding(Theme.s16).padding(.top, 8)
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.accent).fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    vm.clearAllSnapshots()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all completion snapshots and streaks. Your lists and tasks are not affected.")
            }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: PlaceholderCalendarView
// ══════════════════════════════════════════════

struct PlaceholderCalendarView: View {
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
                    Text(String(Calendar.current.component(.year, from: today)))
                        .font(.system(size: 10, weight: .medium)).foregroundColor(Theme.text2)
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
