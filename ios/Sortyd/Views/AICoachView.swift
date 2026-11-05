// MARK: - AICoachView.swift
// Sortyd v4 — AI Coach · Redesigned
//
// Philosophy: One accent. Max two colors per card. Short sentences.
// Grade earns the screen. Pillars tell the story. Nothing decorates for decoration's sake.

import SwiftUI
import Firebase
import FirebaseAnalytics
// MARK: ── Root View ─────────────────────────────────────────────────────────

struct AICoachView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var coach = AICoach.shared
    
    @State private var selectedList: TaskList? = nil
    @State private var analysisState: AnalysisState = .idle
    @State private var isSpinning = false
    @State private var lastAnalysedListID: UUID? = nil
    @State private var analysisRequestID = UUID()
    @State private var showAbout = false
    @State private var headerAppeared = false
    @State private var failurePulse = false
    @State private var timeoutOrbit = false
    @State private var timeoutTapCount = 0
    @State private var timeoutCoreTilt = false
    
    // FIX: separate rotation state from isSpinning
    // isSpinning drives the animation trigger; spinAngle accumulates cleanly
    @State private var spinAngle: Double = 0
    
    enum AnalysisState { case idle, loading, done, failed }
    private enum CoachFailureKind { case offline, timeout, quota, generic }
    
    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        .opacity(headerAppeared ? 1 : 0)
                        .offset(y: headerAppeared ? 0 : -6)
                    
                    listPicker
                        .padding(.bottom, 18)
                    
                    Group {
                        switch analysisState {
                        case .idle:
                            idlePrompt.padding(.horizontal, 20)
                        case .loading:
                            loadingView.padding(.horizontal, 20)
                        case .done:
                            if let analysis = coach.behaviouralAnalysis {
                                doneContent(analysis: analysis)
                            } else {
                                failedView.padding(.horizontal, 20)
                            }
                        case .failed:
                            failedView.padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 110)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                if let list = selectedList { await runAnalysis(for: list) }
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "ai_coach",
                AnalyticsParameterScreenClass: "AICoachView"
            ])
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                headerAppeared = true
            }
        }
        .onDisappear { isSpinning = false }
        .task(id: vm.appLanguage) {
            lastAnalysedListID = nil
            let liveLists = vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
            if lastAnalysedListID == nil {
                let defaultList = liveLists.first(where: { $0.id == vm.activeListID }) ?? liveLists.first
                if let list = defaultList {
                    selectedList = list
                    await runAnalysis(for: list)
                } else {
                    analysisState = .idle
                }
            }
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.localized("AI COACH"))
                    .font(.system(size: 9, weight: .black))
                    .tracking(2.5)
                    .foregroundColor(Theme.accent)
                Text(vm.localized("Habit Analysis"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text0)
            }
            Spacer()
            HStack(spacing: 8) {
                // FIX: info button — glowing blue icon, no fill
                Button(action: { showAbout = true }) {
                    glowingInfoButton()
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showAbout) { AboutPrivacySheet() }
                
                // FIX: refresh button — stable rotation, no bounce/jump
                Button(action: {
                    guard let list = selectedList, !isSpinning else { return }
                    Task { await runAnalysis(for: list) }
                }) {
                    stableRefreshButton()
                }
                .buttonStyle(.plain)
                .disabled(isSpinning)
                .accessibilityLabel(vm.localized("Run habit analysis"))
                .accessibilityHint(vm.localized("Double tap to analyse your habit data with AI"))
            }
        }
    }
    
    // FIX: Info button with blue glow — no animation, purely decorative glow
    private func glowingInfoButton() -> some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Theme.accent.opacity(0.08))
                .frame(width: 40, height: 40)
                .shadow(color: Theme.accent.opacity(0.45), radius: 10, x: 0, y: 0)
                .shadow(color: Theme.accent.opacity(0.20), radius: 20, x: 0, y: 0)
            
            Circle()
                .fill(Color.clear)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.55), Theme.coral.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                )
                .frame(width: 34, height: 34)
            
            Image(systemName: "info")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent, Theme.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.accent.opacity(0.60), radius: 6, x: 0, y: 0)
        }
        .frame(width: 40, height: 40)
    }
    
    // FIX: Refresh button — rotationEffect on a fixed angle, no repeatForever bounce
    // When spinning: we increment spinAngle by 360 each time analysis starts/ends
    private func stableRefreshButton() -> some View {
        ZStack {
            Circle()
                .fill(Theme.bg2)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5))
                .frame(width: 34, height: 34)
            
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSpinning ? Theme.accent : Theme.text1)
            // FIX: use rotationEffect with explicit angle — no repeatForever, no bounce
                .rotationEffect(.degrees(spinAngle))
        }
        .frame(width: 38, height: 38)
    }
    
    // MARK: List Picker
    
    private var listPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Spacer(minLength: 20)
                ForEach(vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }) { list in
                    let isSelected = selectedList?.id == list.id
                    Button(action: {
                        guard selectedList?.id != list.id else { return }
                        selectedList = list
                        Task { await runAnalysis(for: list) }
                    }) {
                        HStack(spacing: 5) {
                            Text(list.emoji).font(.system(size: 12))
                            Text(list.cleanName)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Theme.accent : Theme.text1)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.accent.opacity(0.10) : Theme.bg2)
                                .overlay(
                                    Capsule().strokeBorder(
                                        isSelected ? Theme.accent.opacity(0.40) : Theme.border,
                                        lineWidth: isSelected ? 1 : 0.5
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
                }
                Spacer(minLength: 20)
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0))
    }
    
    // MARK: States
    
    private var idlePrompt: some View {
        VStack(spacing: 16) {
            Text("🧠")
                .font(.system(size: 36))
            VStack(spacing: 5) {
                Text(vm.localized("No lists yet"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text0)
                Text(vm.localized("Add tasks to unlock analysis."))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(cardBG())
        .cardShadow()
    }
    
    private var failedView: some View {
        let message = AICoach.shared.errorMessage
        let kind = failureKind(from: message)

        return Group {
            switch kind {
            case .offline:
                offlineFailureView
            case .timeout:
                timeoutFailureView
            case .quota, .generic:
                standardFailureView(message: message, isQuotaHit: kind == .quota)
            }
        }
        .onAppear {
            failurePulse = true
            timeoutOrbit = true
            timeoutCoreTilt = true
        }
    }

    private func failureKind(from message: String?) -> CoachFailureKind {
        let text = (message ?? "").lowercased()
        if text.contains("limit") || text.contains("resets") { return .quota }
        if text.contains("timed out")
            || text.contains("timeout")
            || text.contains("taking too long")
            || text.contains("temporarily unavailable")
            || text.contains("http 429")
            || text.contains("http 5") {
            return .timeout
        }
        if text.contains("internet") || text.contains("connection") || text.contains("offline") || text.contains("network") { return .offline }
        return .generic
    }

    private var offlineFailureView: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.accent.opacity(failurePulse ? 0.03 : 0.18), lineWidth: 1.2)
                        .frame(width: 58 + CGFloat(index * 28), height: 42 + CGFloat(index * 18))
                        .scaleEffect(failurePulse ? 1.08 + CGFloat(index) * 0.03 : 0.94)
                        .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true).delay(Double(index) * 0.12), value: failurePulse)
                }

                Image(systemName: "wifi.slash")
                    .font(.system(size: 25, weight: .black))
                    .foregroundColor(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 12)
            }
            .frame(height: 88)

            VStack(spacing: 6) {
                Text(vm.localized("Signal drift"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)

                Text(vm.localized("Your coach is listening, but this device is off the grid. Reconnect and the insight stream will come back online."))
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(2)
                    .foregroundColor(Theme.text2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 34)
        .background(cardBG())
        .cardShadow()
    }

    private var timeoutFailureView: some View {
        VStack(spacing: 18) {
            Button(action: triggerTimeoutRetryGame) {
                CoachSignalCore(
                    orbiting: timeoutOrbit,
                    tilted: timeoutCoreTilt,
                    tapCount: timeoutTapCount
                )
                .frame(height: 154)
                .contentShape(Rectangle())
            }
            .buttonStyle(CoachScaleStyle())
            .accessibilityLabel(vm.localized("Retry AI Coach"))

            VStack(spacing: 6) {
                Text(vm.localized("Server blinked"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text0)

                Text(vm.localized("Tap the pulse to send a fresh ping. If the coach answers, your insight appears right here."))
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(2)
                    .foregroundColor(Theme.text2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .background(cardBG())
        .cardShadow()
    }

    private func standardFailureView(message: String?, isQuotaHit: Bool) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.08))
                    .frame(width: 60, height: 60)
                Image(systemName: isQuotaHit ? "clock.badge.exclamationmark" : "exclamationmark.triangle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Theme.accent)
            }

            VStack(spacing: 4) {
                Text(isQuotaHit ? vm.localized("Daily limit reached") : vm.localized("Analysis failed"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text0)
                Text(message ?? vm.localized("Something went wrong. Tap retry to try again."))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text2)
                    .multilineTextAlignment(.center)
            }

            Button(action: retrySelectedList) {
                Text(vm.localized("Retry"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.bg0)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(isQuotaHit ? Theme.text2 : Theme.accent))
            }
            .buttonStyle(CoachScaleStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(cardBG())
        .cardShadow()
    }

    private func retrySelectedList() {
        guard let list = selectedList else { return }
        Task { await runAnalysis(for: list) }
    }

    private func triggerTimeoutRetryGame() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
            timeoutTapCount += 1
            timeoutCoreTilt.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            retrySelectedList()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                SkeletonPillarCard()
                    .opacity(1.0 - Double(i) * 0.18)
            }
        }
    }
    
    @ViewBuilder
    private func doneContent(analysis: BehaviouralAnalysis) -> some View {
        VStack(spacing: 12) {
            if let cacheAge = coach.cacheAge {
                let timeString = timeAgoString(from: cacheAge)
                let isStale = cacheAge.timeIntervalSinceNow < -86400
                HStack(spacing: 5) {
                    Image(systemName: isStale ? "exclamationmark.triangle.fill" : "clock")
                        .font(.system(size: 10))
                        .foregroundColor(isStale ? Color.orange : Theme.text2)
                    Text(String(format: vm.localized(isStale ? "Stale cache: updated %1$@ ago" : "Updated %1$@ ago"), timeString))
                        .font(Theme.font(size: 10, weight: .medium))
                        .foregroundColor(isStale ? Color.orange : Theme.text2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isStale ? Color.orange.opacity(0.12) : Theme.bg2)
                )
                .padding(.horizontal, 20)
            }

            if let recap = coach.weeklyRecap {
                WeeklyGradeBanner(recap: recap)
                    .padding(.horizontal, 20)
            }
            
            pillarSummaryRow(analysis: analysis)
                .padding(.horizontal, 20)
            
            let sorted = analysis.pillars.sorted { $0.score < $1.score }
            VStack(spacing: 8) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, pillar in
                    BracketCard(
                        pillar: pillar,
                        rank: index + 1,
                        totalCount: sorted.count,
                        isCritical: pillar.name == analysis.criticalPillar
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 16)),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, 20)
            
            OverallInsightBanner(text: analysis.overallInsight)
                .padding(.horizontal, 20)
            
            if !coach.procrastinationFlags.isEmpty {
                SkippedTasksSection(
                    flags: coach.procrastinationFlags,
                    onDismiss: { flag in
                        withAnimation { coach.procrastinationFlags.removeAll { $0.id == flag.id } }
                    }
                )
                .padding(.horizontal, 20)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: analysis.pillars.count)
    }
    
    // MARK: Pillar summary
    
    private func pillarSummaryRow(analysis: BehaviouralAnalysis) -> some View {
        let weakCount   = analysis.pillars.filter { $0.score < 50 }.count
        let strongCount = analysis.pillars.filter { $0.score >= 75 }.count
        let total       = analysis.pillars.count
        
        return HStack(spacing: 8) {
            pillStat(value: "\(strongCount)", label: "Strong",    color: Theme.success)
            pillStat(value: "\(weakCount)",   label: weakCount == 0 ? "All good" : "Need work",
                     color: weakCount == 0 ? Theme.success : Theme.warning)
            pillStat(value: "\(total)",       label: "Pillars",   color: Theme.text1)
        }
    }
    
    private func pillStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(vm.localized(label))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: Actions
    
    private func runAnalysis(for list: TaskList) async {
        let startedAt = Date()
        let requestID = UUID()
        analysisRequestID = requestID
        isSpinning = false
        lastAnalysedListID = list.id

        // Try load best available cache (valid or stale)
        let cacheResult = AICoach.shared.loadBestAvailableCache(for: list.id)
        if cacheResult.found {
            AppTelemetry.aiResult(feature: "coach", outcome: cacheResult.isStale ? "stale_cache" : "cache", startedAt: startedAt)
            await MainActor.run {
                analysisState = .done
            }
            
            // Check if it's stale; if it is stale, run a batch fetch silently in the background
            if cacheResult.isStale {
                Task {
                    let liveLists = vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
                    await AICoach.shared.fetchAllListsBatch(lists: liveLists, snapshots: vm.snapshots, force: false)
                    guard analysisRequestID == requestID, !Task.isCancelled else { return }
                    _ = AICoach.shared.loadBestAvailableCache(for: list.id)
                }
            }
            return
        }

        // Cache miss — show spinner and fetch
        await MainActor.run {
            analysisState = .loading
            isSpinning = true
            coach.behaviouralAnalysis = nil
            coach.weeklyRecap = nil
        }

        Analytics.logEvent("ai_coach_used", parameters: nil)

        // Spinner animation loop
        Task { @MainActor in
            while isSpinning {
                withAnimation(.linear(duration: 0.7)) {
                    spinAngle += 360
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }

        // Fetch batch for all lists in one session
        let liveLists = vm.lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
        await AICoach.shared.fetchAllListsBatch(lists: liveLists, snapshots: vm.snapshots, force: false)

        guard analysisRequestID == requestID, !Task.isCancelled else { return }
        let reloaded = AICoach.shared.loadBestAvailableCache(for: list.id)
        AppTelemetry.aiResult(feature: "coach", outcome: reloaded.found ? "success" : "failed", startedAt: startedAt)

        await MainActor.run {
            isSpinning = false
            analysisState = reloaded.found ? .done : .failed
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = vm.appLanguage.locale
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: Helpers
    
    private func cardBG(radius: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.bg1)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}

// MARK: ── Weekly Grade Banner ────────────────────────────────────────────────

struct WeeklyGradeBanner: View {
    @EnvironmentObject var vm: AppViewModel
    let recap: WeeklyRecap
    @State private var showNudge = false

    private var gradeColor: Color {
        switch recap.grade {
        case "A", "A+", "A-": return Theme.success
        case "B+", "B", "B-": return Theme.accent
        case "C+", "C":       return Theme.warning
        default:               return Theme.danger
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(recap.grade)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(gradeColor)
                Text(vm.localized("WEEK"))
                    .font(.system(size: 7, weight: .black))
                    .tracking(1.8)
                    .foregroundColor(gradeColor.opacity(0.45))
            }
            .frame(width: 60)
            .frame(maxHeight: .infinity)
            .background(gradeColor.opacity(0.07))

            Rectangle()
                .fill(gradeColor.opacity(0.12))
                .frame(width: 0.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(recap.headline)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text0)
                    .lineLimit(1)
                Text(recap.gradeReason)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.text2)
                    .lineLimit(2)
                    .lineSpacing(1.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Spacer(minLength: 0)

            Button(action: { showNudge = true }) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.accent.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .popover(isPresented: $showNudge) {
                Text(recap.nudge)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text0)
                    .padding(16)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(gradeColor.opacity(0.15), lineWidth: 0.75)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .cardShadow()
    }
}

// MARK: ── Bracket Card ───────────────────────────────────────────────────────

struct BracketCard: View {
    @EnvironmentObject var vm: AppViewModel
    let pillar: BehaviouralPillar
    let rank: Int
    let totalCount: Int
    let isCritical: Bool

    @State private var isExpanded = false
    @State private var progressAppeared = false

    private var scoreColor: Color { Theme.scoreColor(for: pillar.score) }

    private var insightBullets: [String] {
        pillar.insight
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
    }

    private var adviceBullets: [String] {
        pillar.advice
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? $0 + "." : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Button(action: {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(scoreColor.opacity(0.10), lineWidth: 2.5)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: progressAppeared ? CGFloat(pillar.score) / 100 : 0)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                                .animation(.spring(response: 0.65, dampingFraction: 0.8).delay(Double(rank) * 0.07), value: progressAppeared)
                            Text(pillar.emoji).font(.system(size: 18))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(pillar.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.text0)
                                if isCritical {
                                    Text(vm.localized("FOCUS"))
                                        .font(.system(size: 7, weight: .black))
                                        .tracking(0.8)
                                        .foregroundColor(Theme.warning)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Theme.warning.opacity(0.10)))
                                }
                            }
                            Text(localizedPillarStatus)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(scoreColor.opacity(0.75))
                        }

                        Spacer()

                        Text("\(pillar.score)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(scoreColor)
                            .contentTransition(.numericText())

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.text2)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.bg3).frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [scoreColor, scoreColor.opacity(0.45)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(
                                    width: progressAppeared ? max(3, geo.size.width * CGFloat(pillar.score) / 100) : 3,
                                    height: 3
                                )
                                .animation(.spring(response: 0.65, dampingFraction: 0.8).delay(Double(rank) * 0.07), value: progressAppeared)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 14) {
                        DrillSection(
                            icon: "eye.fill",
                            iconColor: scoreColor,
                            title: vm.localized("What's happening"),
                            bullets: insightBullets
                        )

                        if !pillar.tasks.isEmpty {
                            TaskChips(tasks: pillar.tasks, color: scoreColor)
                        }

                        DrillSection(
                            icon: "arrow.right.circle.fill",
                            iconColor: Theme.accent,
                            title: vm.localized("Next steps"),
                            bullets: adviceBullets,
                            bulletStyle: .fix
                        )
                    }
                    .padding(14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isCritical ? Theme.warning.opacity(0.25) : (isExpanded ? Theme.accent.opacity(0.14) : Theme.border),
                            lineWidth: isCritical ? 0.75 : 0.5
                        )
                )
        )
        .cardShadow()
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isExpanded)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { progressAppeared = true }
            if rank == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { isExpanded = true }
                }
            }
        }
    }

    private var localizedPillarStatus: String {
        let cleaned = pillar.status.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cleaned
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "strong", "strength", "healthy", "good", "excellent", "fuerte", "قوي", "强项":
            return vm.localized("Strong")
        case "developing", "building", "improving", "moderate", "need work", "needs work", "en desarrollo", "قيد التطوير", "发展中":
            return vm.localized("Developing")
        case "struggling", "strugglong", "strugling", "struggle", "weak", "critical", "low", "poor", "con dificultades", "متعثر", "需改善", "挣扎中":
            return vm.localized("Struggling")
        default:
            if vm.appLanguage != .english,
               normalized.range(of: #"[a-z]"#, options: .regularExpression) != nil {
                return scoreBasedStatus
            }
            return cleaned.isEmpty ? scoreBasedStatus : cleaned
        }
    }

    private var scoreBasedStatus: String {
        if pillar.score >= 75 { return vm.localized("Strong") }
        if pillar.score >= 45 { return vm.localized("Developing") }
        return vm.localized("Struggling")
    }
}

// MARK: ── Task chips ─────────────────────────────────────────────────────────

struct TaskChips: View {
    let tasks: [String]
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tasks, id: \.self) { task in
                    Text(task)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.07))
                                .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.5))
                        )
                }
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0))
    }
}

// MARK: ── Drill Section ──────────────────────────────────────────────────────

enum BulletStyle { case insight, fix }

struct DrillSection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let bullets: [String]
    var bulletStyle: BulletStyle = .insight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title.uppercased())
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.text2)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    ExpandableBulletRow(
                        bullet: bullet,
                        bulletStyle: bulletStyle,
                        iconColor: iconColor
                    )
                }
            }
        }
    }
}

// MARK: ── Expandable Bullet Row ───────────────────────────────────────────────

private struct ExpandableBulletRow: View {
    let bullet: String
    let bulletStyle: BulletStyle
    let iconColor: Color

    @State private var isExpanded = false

    private var isTruncatable: Bool { bullet.count > 60 }

    var body: some View {
        Button(action: {
            guard isTruncatable else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
        }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: bulletStyle == .fix ? "arrow.right" : "minus")
                    .flipsForRightToLeftLayoutDirection(true)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(iconColor.opacity(0.6))
                    .frame(width: 14)
                    .padding(.top, 2.5)

                Text(bullet)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.text1)
                    .lineSpacing(2.5)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)

                Spacer(minLength: 0)

                if isTruncatable {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.text2.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
                        .padding(.top, 3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
// MARK: ── Overall Insight Banner ─────────────────────────────────────────────

struct OverallInsightBanner: View {
    @EnvironmentObject var vm: AppViewModel
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.appLanguage == .arabic ? "النمط العام" : (vm.appLanguage == .spanish ? "PATRÓN GENERAL" : (vm.appLanguage == .chinese ? "总体规律" : "OVERALL PATTERN")))
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.4)
                .foregroundColor(Theme.text2)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Theme.text1)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.10), lineWidth: 0.5)
                )
        )
        .cardShadow()
    }
}

// MARK: ── Skipped Tasks Section ──────────────────────────────────────────────

struct SkippedTasksSection: View {
    @EnvironmentObject var vm: AppViewModel
    let flags: [ProcrastinationFlag]
    let onDismiss: (ProcrastinationFlag) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() }
            }) {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.warning)
                        Text(vm.appLanguage == .arabic ? "متخطى" : (vm.appLanguage == .spanish ? "SALTADO" : (vm.appLanguage == .chinese ? "已跳过" : "SKIPPED")))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Theme.text1)
                        Text("\(flags.count)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.warning.opacity(0.10)))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.text2)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.warning.opacity(0.15), lineWidth: 0.5)
                        )
                )
                .cardShadow()
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 7) {
                    ForEach(flags) { flag in
                        SkippedFlagRow(flag: flag, onDismiss: { onDismiss(flag) })
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct SkippedFlagRow: View {
    let flag: ProcrastinationFlag
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(flag.taskTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text0)
                        .lineLimit(1)
                    Text("\(flag.daysSkipped)d")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.warning)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.warning.opacity(0.10)))
                }
                Text(flag.suggestion)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.text2)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            Spacer()
            Button(action: onDismiss) {
                Text(flag.actionLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.accent.opacity(0.07))
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.15), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.warning.opacity(0.10), lineWidth: 0.5)
                )
        )
        .cardShadow()
    }
}

// MARK: ── Skeleton Loader ─────────────────────────────────────────────────────

struct SkeletonPillarCard: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(Theme.bg3).frame(width: 44, height: 44).shimmer(phase: phase)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.bg3).frame(width: 100, height: 12).shimmer(phase: phase)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.bg3).frame(width: 60, height: 9).shimmer(phase: phase)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 6).fill(Theme.bg3).frame(width: 34, height: 28).shimmer(phase: phase)
            }
            RoundedRectangle(cornerRadius: 2).fill(Theme.bg3).frame(height: 3).shimmer(phase: phase)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.bg1)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
        )
        .cardShadow()
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}

private extension View {
    func shimmer(phase: CGFloat) -> some View {
        self.overlay(
            LinearGradient(
                colors: [.clear, .white.opacity(0.04), .clear],
                startPoint: .init(x: phase - 0.3, y: 0),
                endPoint: .init(x: phase, y: 0)
            )
        )
    }
}

// MARK: ── Button Style ────────────────────────────────────────────────────────

private struct CoachScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct CoachSignalCore: View {
    let orbiting: Bool
    let tilted: Bool
    let tapCount: Int

    private var coreScale: CGFloat {
        1 + CGFloat(min(tapCount, 4)) * 0.025
    }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.accent.opacity(0.26 - Double(index) * 0.055),
                                Theme.coral.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
                    .frame(width: 124 + CGFloat(index * 20), height: 88 + CGFloat(index * 14))
                    .rotation3DEffect(
                        .degrees(tilted ? 58 : 48),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.64
                    )
                    .rotationEffect(.degrees(orbiting ? 360 : 0))
                    .animation(
                        .linear(duration: 4.2 + Double(index) * 0.65).repeatForever(autoreverses: false),
                        value: orbiting
                    )
                    .opacity(0.75 - Double(index) * 0.14)
            }

            ForEach(0..<4, id: \.self) { index in
                orbitNode(index: index)
                    .offset(y: -46)
                    .rotationEffect(.degrees(Double(index) * 90 + (orbiting ? 360 : 0)))
                    .animation(
                        .linear(duration: 2.5).repeatForever(autoreverses: false),
                        value: orbiting
                    )
                    .rotation3DEffect(.degrees(tilted ? 54 : 44), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.accent.opacity(0.32),
                                Theme.accent.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 118, height: 118)
                    .blur(radius: 2)
                    .scaleEffect(orbiting ? 1.08 : 0.92)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: orbiting)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.bg2.opacity(0.96),
                                Theme.accent.opacity(0.16),
                                Theme.bg1.opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.65), Theme.coral.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.accent.opacity(0.28), radius: 18, x: 0, y: 8)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Theme.coral.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.accent.opacity(0.42), radius: 10)

                VStack(spacing: 3) {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(index <= tapCount % 4 ? Theme.accent : Theme.border)
                                .frame(width: index == tapCount % 4 ? 18 : 7, height: 4)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: tapCount)
                        }
                    }
                    .padding(.bottom, 14)
                }
                .frame(width: 88, height: 88)
            }
            .scaleEffect(coreScale)
            .rotation3DEffect(.degrees(tilted ? -13 : 13), axis: (x: 0.4, y: 1, z: 0), perspective: 0.72)
            .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true), value: tilted)
        }
        .frame(maxWidth: .infinity)
    }

    private func orbitNode(index: Int) -> some View {
        let active = index <= tapCount % 4
        return Circle()
            .fill(active ? Theme.accent : Theme.border)
            .frame(width: active ? 9 : 6, height: active ? 9 : 6)
            .shadow(color: active ? Theme.accent.opacity(0.7) : .clear, radius: 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.68), value: tapCount)
    }
}

// MARK: ── About Sheet ─────────────────────────────────────────────────────────

private struct AboutPrivacySheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: AppViewModel
    private var privacyURL: URL {
        switch currentLanguage {
        case .spanish: return URL(string: "https://www.sortyd.com/es/privacy")!
        case .arabic:  return URL(string: "https://www.sortyd.com/ar/privacy")!
        default:       return URL(string: "https://www.sortyd.com/privacy")!
        }
    }


    @State private var localLanguage: AppLanguage?

    private var currentLanguage: AppLanguage {
        localLanguage ?? vm.appLanguage
    }

    private var languageToggles: some View {
        HStack(spacing: 12) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                let isSelected = currentLanguage == lang
                Button(action: {
                    withAnimation {
                        localLanguage = lang
                    }
                }) {
                    Text(lang.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? Theme.bg0 : Theme.text1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.accent : Theme.bg1)
                        )
                        .overlay(
                            Capsule().strokeBorder(Theme.border, lineWidth: isSelected ? 0 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func localizedText(_ key: String) -> String {
        let strings: [String: [AppLanguage: String]] = [
            "AI Coaching": [
                .english: "AI Coaching",
                .spanish: "Coaching por IA",
                .arabic: "توجيه الذكاء الاصطناعي",
                .chinese: "AI 教练"
            ],
            "AI_Coaching_Desc": [
                .english: "AI-powered analysis of your habit data. Task titles and completion rates are sent to generate insights.",
                .spanish: "Análisis impulsado por IA de tus datos de hábitos. Se envían los títulos de las tareas y las tasas de finalización para generar información.",
                .arabic: "تحليل مدعوم بالذكاء الاصطناعي لبيانات عاداتك. يتم إرسال عناوين المهام ومعدلات الإنجاز لتوليد رؤى.",
                .chinese: "AI 驱动的习惯数据分析。系统会发送任务标题和完成率以生成洞察。"
            ],
            "Privacy": [
                .english: "Privacy",
                .spanish: "Privacidad",
                .arabic: "الخصوصية",
                .chinese: "隐私"
            ],
            "Privacy_Desc": [
                .english: "Your data is never sold or shared for advertising. Health data stays on your device.",
                .spanish: "Tus datos nunca se venden ni se comparten para publicidad. Los datos de salud permanecen en tu dispositivo.",
                .arabic: "لا يتم بيع بياناتك أو مشاركتها للإعلانات. تبقى بيانات الصحة على جهازك.",
                .chinese: "你的数据绝不会被出售或用于广告。健康数据保留在设备上。"
            ],
            "Apple Health": [
                .english: "Apple Health",
                .spanish: "Apple Health",
                .arabic: "Apple Health",
                .chinese: "Apple Health"
            ],
            "Apple_Health_Desc": [
                .english: "Reads step count and active calories only. Sortyd never writes to Health.",
                .spanish: "Lee solo el recuento de pasos y las calorías activas. Sortyd nunca escribe en Salud.",
                .arabic: "يقرأ عدد الخطوات والسعرات الحرارية النشطة فقط. لا يكتب تطبيق Sortyd أبدًا إلى تطبيق الصحة.",
                .chinese: "仅读取步数和活动卡路里。Sortyd 从不写入健康数据。"
            ],
            "Notifications": [
                .english: "Notifications",
                .spanish: "Notificaciones",
                .arabic: "الإشعارات",
                .chinese: "通知"
            ],
            "Notifications_Desc": [
                .english: "Reminders are scheduled locally. Permission requested on first reminder only.",
                .spanish: "Los recordatorios se programan localmente. El permiso se solicita solo en el primer recordatorio.",
                .arabic: "تتم جدولة التذكيرات محليًا. يُطلب الإذن عند أول تذكير فقط.",
                .chinese: "提醒在本地安排。仅在第一次提醒时请求权限。"
            ],
            "Privacy Policy": [
                .english: "Privacy Policy",
                .spanish: "Política de privacidad",
                .arabic: "سياسة الخصوصية",
                .chinese: "隐私政策"
            ],
            "About & Privacy": [
                .english: "About & Privacy",
                .spanish: "Acerca de y Privacidad",
                .arabic: "حول والخصوصية",
                .chinese: "关于与隐私"
            ],
            "Done": [
                .english: "Done",
                .spanish: "Hecho",
                .arabic: "تم",
                .chinese: "完成"
            ]
        ]
        return strings[key]?[currentLanguage] ?? key
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        languageToggles

                        infoSection(icon: "brain.head.profile", title: localizedText("AI Coaching"),
                                    text: localizedText("AI_Coaching_Desc"))
                        infoSection(icon: "lock.shield.fill", title: localizedText("Privacy"),
                                    text: localizedText("Privacy_Desc"))
                        infoSection(icon: "heart.fill", title: localizedText("Apple Health"),
                                    text: localizedText("Apple_Health_Desc"))
                        infoSection(icon: "bell.fill", title: localizedText("Notifications"),
                                    text: localizedText("Notifications_Desc"))

                        Button(action: { UIApplication.shared.open(privacyURL) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text").font(.system(size: 13, weight: .semibold))
                                Text(localizedText("Privacy Policy")).font(.system(size: 13, weight: .bold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .flipsForRightToLeftLayoutDirection(true)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.accent.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.15), lineWidth: 0.5))
                            )
                        }
                        .buttonStyle(.plain)

                        Text("Sortyd v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.3")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.text2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(Text(localizedText("About & Privacy")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg0, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(localizedText("Done"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .environment(\.layoutDirection, currentLanguage == .arabic ? .rightToLeft : .leftToRight)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.bg0)
    }

    @ViewBuilder
    private func infoSection(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accent.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text0)
                    .multilineTextAlignment(currentLanguage == .arabic ? .trailing : .leading)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text1)
                    .lineSpacing(2)
                    .multilineTextAlignment(currentLanguage == .arabic ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: currentLanguage == .arabic ? .trailing : .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bg1)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
        )
    }
}

#Preview {
    AICoachView()
        .environmentObject(AppViewModel())
        .environmentObject(ThemeManager.shared)
}
