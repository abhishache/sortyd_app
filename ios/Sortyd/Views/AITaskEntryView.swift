// MARK: - AITaskEntryView.swift
// Sortyd — Natural Language Task Entry + AI Starter Lists

import SwiftUI

private let kOneTimeDateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
}()

// ══════════════════════════════════════════════
// MARK: - HealthConflictToast
// ══════════════════════════════════════════════

struct HealthConflictToast: View {
    let type: HealthTaskType
    @Binding var isVisible: Bool
    @State private var shakeOffset: CGFloat = 0

    @EnvironmentObject var vm: AppViewModel
    private var message: String {
        switch type {
        case .steps:    return vm.localized("Only one step‑counting task per list — it may conflict with your goal.")
        case .calories: return vm.localized("Only one calorie‑tracking task per list — it may conflict with your goal.")
        case .distance: return vm.localized("Only one distance‑tracking task per list — it may conflict with your goal.")
        case .none:     return ""
        }
    }

    private var icon: String {
        if type == .none { return "exclamationmark.circle" }
        return type.icon
    }

    private var accentColor: Color {
        if type == .none { return .orange }
        return Color(hex: type.accentColor)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(accentColor.opacity(0.15)))

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.text0)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.text2)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Theme.bg3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: accentColor.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .offset(x: shakeOffset)
        .onAppear { triggerShake() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func triggerShake() {
        let shakes: [(CGFloat, Double)] = [
            ( 6, 0.00), (-6, 0.07), ( 5, 0.14), (-5, 0.21),
            ( 3, 0.28), (-3, 0.35), ( 0, 0.42)
        ]
        for (offset, delay) in shakes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.5)) {
                    shakeOffset = offset
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.25)) { isVisible = false }
        }
    }
}

// ══════════════════════════════════════════════
// MARK: - SmartAddTaskSheet
// ══════════════════════════════════════════════

struct SmartAddTaskSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var detectedHealthType: HealthTaskType = .none
    @State private var healthTargetText: String = ""
    @State private var showHealthPermission = false
    @State private var manualTypeSet = false
    @StateObject private var hk = HealthKitManager.shared

    let listID: UUID

    @State private var input = ""
    @State private var parsedTask: ParsedTask?
    @State private var isParsing = false
    @State private var parseError = false
    @State private var conflictHealthType: HealthTaskType? = nil
    @State private var showConflictToast = false
    @FocusState private var isFocused: Bool

    private var reminderPreview: String? {
        guard let p = parsedTask, p.hasReminder,
              let h = p.reminderHour, let m = p.reminderMinute else { return nil }
        let formatted = String(format: "%02d:%02d", h, m)
        return "⏰ \(vm.localized("Reminder at")) \(formatted)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(vm.localized("Add Task"))
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text(vm.localized("Type naturally — AI will parse reminders & details"))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    HStack(spacing: 10) {
                        TextField(vm.localized("e.g. \"Call dentist at 3pm\""), text: $input)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.text0)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { parseInput() }
                            .onChange(of: input) { _, newValue in
                                parsedTask = nil
                                parseError = false
                                if !manualTypeSet {
                                    detectedHealthType = HealthTaskType.detect(from: newValue)
                                }
                            }

                        if isParsing {
                            ProgressView().tint(Theme.accent).scaleEffect(0.8)
                        } else if !input.isEmpty {
                            Button(action: { parseInput() }) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.bg2)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 0.5))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                typePill(type: .none, label: vm.localized("Regular"))
                                typePill(type: .steps, label: vm.localized("Steps"))
                            }
                            HStack(spacing: 8) {
                                typePill(type: .calories, label: vm.localized("Calories"))
                                typePill(type: .distance, label: vm.localized("Distance"))
                            }
                        }
                        Text(vm.localized("Only one task from step count, calorie count or distance measure is allowed."))
                            .font(.system(size: 9, weight: .bold)) // Standardized to 9pt bold
                            .foregroundColor(Theme.text2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    if let preview = reminderPreview {
                        HStack(spacing: 6) {
                            Text(preview)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.accent)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.accent)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if parseError {
                        HStack(spacing: 8) {
                            Text(vm.localized("Couldn't parse that — the task will be added as typed."))
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            
                            Button {
                                parseInput()
                            } label: {
                                Text(vm.localized("Retry AI"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    if input.isEmpty {
                        MarqueeChipRows(
                            chips: examplePrompts,
                            rowCount: 4,
                            onSelect: { input = $0 }
                        )
                        .padding(.bottom, 16)
                    }

                    if showConflictToast, let ct = conflictHealthType {
                        HealthConflictToast(type: ct, isVisible: $showConflictToast)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    Spacer()

                    Button(action: { addTask() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .black))
                            Text(parsedTask.map { vm.localized("Add \"\($0.title)\"") } ?? vm.localized("Add Task"))
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(input.isEmpty ? Theme.bg3 : Theme.accent)
                                .shadow(color: input.isEmpty ? .clear : Theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.2), value: input.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.bg0)
        .onAppear { isFocused = true }
        .sheet(isPresented: $showHealthPermission) {
            HealthPermissionSheet(
                taskType: detectedHealthType,
                onGrant: { hk.fetchToday() },
                onSkip:  {}
            )
            .environmentObject(vm)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Theme.r32)
            .presentationBackground(Theme.bg0)
        }
    }

    @ViewBuilder
    private func typePill(type: HealthTaskType, label: String) -> some View {
        let isSelected = detectedHealthType == type
        let isBlocked  = type != .none && vm.duplicateHealthType(type.rawValue, in: listID) != nil
        let accent: Color = Color(hex: type.accentColor)

        Button {
            if isBlocked {
                conflictHealthType = type
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showConflictToast = true
                }
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                detectedHealthType = type
                manualTypeSet = true
            }
        } label: {
            HStack(spacing: 6) {
                if type != .none {
                    Image(systemName: type.icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : (isBlocked ? Theme.text2.opacity(0.25) : Theme.text1))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? accent : (isBlocked ? Theme.bg2.opacity(0.3) : Theme.bg2))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? Color.white.opacity(0.2) : (isBlocked ? Color.clear : Theme.border), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .opacity(isBlocked ? 0.5 : 1.0)
    }

    private var examplePrompts: [String] {
        [
            vm.localized("🏃 Morning Run"),
            vm.localized("💊 Take Vitamins"),
            vm.localized("💧 Stay Hydrated"),
            vm.localized("📖 Read Tonight"),
            vm.localized("🧘 Meditate"),
            vm.localized("🛒 Groceries"),
            vm.localized("✍️ Journal"),
            vm.localized("😴 Wind Down"),
            vm.localized("💻 Deep Work"),
            vm.localized("🎯 Plan Tomorrow"),
            vm.localized("🚶 Hit 10k Steps"),
            vm.localized("🥗 Eat Clean"),
            vm.localized("📞 Call Family"),
            vm.localized("🧹 Tidy Up"),
            vm.localized("💰 Check Budget"),
            vm.localized("🎧 Podcast Walk"),
            vm.localized("📝 Weekly Review"),
            vm.localized("🌅 Early Start"),
            vm.localized("🔋 Phone Detox"),
            vm.localized("🤸 Stretch & Move")
        ]
    }

    private func parseInput() {
        guard !input.isEmpty else { return }
        if !input.contains(":") && !containsTimeWord(input) {
            parsedTask = ParsedTask(title: input, hasReminder: false, reminderHour: nil, reminderMinute: nil)
            return
        }
        isParsing = true
        Task {
            let result = await AICoach.shared.parseNaturalLanguageTask(input)
            await MainActor.run {
                if let result = result {
                    parsedTask = result
                } else {
                    parseError = true
                }
                isParsing = false
            }
        }
    }

    private func containsTimeWord(_ text: String) -> Bool {
        let english = ["am", "pm", "at", "by", "before", "morning", "afternoon", "evening", "noon", "midnight"]
        let arabic  = ["صباح", "مساء", "ظهر", "الساعة", "في الساعة", "ليل", "فجر", "عصر", "بعد الظهر"]
        let spanish = ["mañana", "tarde", "noche", "mediodía", "medianoche", "a las", "antes de"]
        let chinese = ["早上", "上午", "中午", "下午", "晚上", "凌晨", "点", "时", "分钟", "小时"]
        let lower = text.lowercased()
        return (english + arabic + spanish + chinese).contains(where: { lower.contains($0) })
    }

    private func addTask() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var reminderDate: Date? = nil
        if let p = parsedTask, p.hasReminder,
           let h = p.reminderHour, let m = p.reminderMinute {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = h
            comps.minute = m
            reminderDate = Calendar.current.date(from: comps)
        }

        let title = parsedTask?.title ?? trimmed
        let htString = detectedHealthType != .none ? detectedHealthType.rawValue : nil
        let htTarget: Double? = detectedHealthType != .none
            ? (Double(healthTargetText).flatMap { $0 > 0 ? $0 : nil }
               ?? AppViewModel.extractNumericTarget(from: title, type: detectedHealthType))
            : nil

        if let conflict = vm.duplicateHealthType(htString, in: listID) {
            conflictHealthType = conflict
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showConflictToast = true
            }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
            return
        }

        vm.addTask(to: listID, title: title, reminderTime: reminderDate,
                   healthType: htString, healthTarget: htTarget)

        if detectedHealthType != .none && !hk.isAuthorized {
            showHealthPermission = true
            return
        }

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        dismiss()
    }
}

// ══════════════════════════════════════════════
// MARK: - TypingPlaceholderField
// ══════════════════════════════════════════════

struct TypingPlaceholderField: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState.Binding var isFocused: Bool

    private var suggestedGoals: [String] {
        [
            vm.localized("Get healthy"),
            vm.localized("Workout routine"),
            vm.localized("Learn Spanish"),
            vm.localized("Job hunting"),
            vm.localized("Eat clean"),
            vm.localized("Build a habit")
        ]
    }

    @State private var displayedPlaceholder = ""
    @State private var phraseIndex = 0
    @State private var charIndex = 0
    @State private var isDeleting = false
    @State private var animTimer: Timer?
    @State private var cursorVisible = true
    @State private var cursorTimer: Timer?

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                HStack(spacing: 0) {
                    Text(displayedPlaceholder)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.text2.opacity(0.5))

                    if !isFocused {
                        Rectangle()
                            .fill(Theme.text2.opacity(cursorVisible ? 0.45 : 0))
                            .frame(width: 2, height: 17)
                            .padding(.leading, 1)
                    }
                }
            }

            TextField("", text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.text0)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit { onSubmit() }
        }
        .onAppear {
            startTyping()
            startCursorBlink()
        }
        .onDisappear {
            animTimer?.invalidate()
            animTimer = nil
            cursorTimer?.invalidate()
            cursorTimer = nil
        }
    }

    private func startCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }

    private func startTyping() { scheduleNext() }

    private func scheduleNext() {
        let phrase = suggestedGoals[phraseIndex]
        let delay: TimeInterval

        if !isDeleting {
            charIndex += 1
            displayedPlaceholder = String(phrase.prefix(charIndex))
            if charIndex >= phrase.count {
                isDeleting = true
                delay = 1.6
            } else {
                delay = Double.random(in: 0.055...0.095)
            }
        } else {
            if charIndex > 0 { charIndex -= 1 }
            displayedPlaceholder = String(phrase.prefix(charIndex))
            if charIndex == 0 {
                isDeleting = false
                phraseIndex = (phraseIndex + 1) % suggestedGoals.count
                delay = 0.38
            } else {
                delay = Double.random(in: 0.028...0.048)
            }
        }

        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            scheduleNext()
        }
    }
}

// ══════════════════════════════════════════════
// MARK: - StarterListSheet
// AI-generated starter tasks for a new list.
// Health tasks (steps + calories) are always
// included with editable targets.
// ══════════════════════════════════════════════

struct StarterListSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var goalInput = ""
    @State private var starterList: StarterList?
    @State private var editableListName: String = ""
    @State private var isGenerating = false
    @State private var generationFailed = false
    @State private var editableTasks: [StarterTaskDraft] = []
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var taskReminders: [UUID: Date] = [:]
    @State private var taskReminderIsOneTime: [UUID: Bool] = [:]
    @State private var editingReminderID: UUID? = nil
    @State private var showHealthPermission = false
    @State private var detectedHealthTypeForPermission: HealthTaskType = .none
    @State private var starterConflictHealthType: HealthTaskType? = nil
    @State private var showStarterConflictToast = false
    @StateObject private var hk = HealthKitManager.shared
    @FocusState private var isFocused: Bool

    // Editable health targets keyed by stable task identity
    // Steps default: 10000, Calories default: 500
    @State private var healthTargets: [UUID: String] = [:]
    @State private var taskHealthTypes: [UUID: HealthTaskType] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(vm.localized("AI Starter List"))
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text(vm.localized("Describe your goal — AI builds the exact tasks"))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    if starterList == nil {
                        ScrollView {
                            goalInputFields
                        }
                        generateButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    } else {
                        generatedListSection
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.bg0)
        .onAppear { isFocused = true }
        .sheet(item: Binding(
            get: { editingReminderID.map { StarterReminderEdit(id: $0) } },
            set: { editingReminderID = $0?.id }
        )) { item in
            ReminderPickerSheet(
                selectedTime: taskReminders[item.id] ?? starterDefaultTime,
                isOneTime: taskReminderIsOneTime[item.id] ?? false
            ) { time, oneTime in
                guard editableTasks.contains(where: { $0.id == item.id }) else { return }
                taskReminders[item.id] = time
                taskReminderIsOneTime[item.id] = oneTime
            }
        }
        .sheet(isPresented: $showHealthPermission, onDismiss: { dismiss() }) {
            HealthPermissionSheet(
                taskType: detectedHealthTypeForPermission,
                onGrant: { hk.fetchToday() },
                onSkip:  {}
            )
            .environmentObject(vm)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Theme.r32)
            .presentationBackground(Theme.bg0)
        }
    }

    private var goalInputFields: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                TypingPlaceholderField(
                    text: $goalInput,
                    onSubmit: { generate() },
                    isFocused: $isFocused
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.bg2)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5))
            )
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(vm.localized("Try one of these"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.text2)
                    .padding(.horizontal, 20)

                MarqueeChipRows(
                    chips: goalExamples,
                    rowCount: 4,
                    onSelect: { goalInput = $0 }
                )
            }
        }
    }

    private var generateButton: some View {
        VStack(spacing: 10) {
            if generationFailed {
                let errMsg = AICoach.shared.errorMessage ?? ""
                let isQuota = errMsg.contains("limit") || errMsg.contains("Resets")
                HStack(spacing: 6) {
                    Image(systemName: isQuota ? "clock.badge.exclamationmark" : "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(isQuota ? errMsg : vm.localized("Couldn't generate — check your connection and try again."))
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.warning)
                .multilineTextAlignment(.center)
            }
            Button(action: { generate() }) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().tint(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white).scaleEffect(0.8)
                        Text(vm.localized("Building your list…"))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .black))
                        Text(vm.localized(generationFailed ? "Try Again" : "Generate List"))
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(goalInput.isEmpty ? Theme.bg3 : Theme.accent)
                        .shadow(color: goalInput.isEmpty ? .clear : Theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(.plain)
            .disabled(goalInput.isEmpty || isGenerating)
        }
    }

    @ViewBuilder
    private var generatedListSection: some View {
        if let list = starterList {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.bg2)
                            .frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 0.5))
                        Text(list.emoji).font(.system(size: 24))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        TextField(vm.localized("List name"), text: $editableListName)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text(String(format: vm.localized("%lld of %lld tasks selected"),
                                    Int64(selectedTaskIDs.count),
                                    Int64(editableTasks.count)))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text2)
                    }
                    Spacer()
                    Button(action: {
                        starterList = nil
                        goalInput = ""
                        editableListName = ""
                        editableTasks = []
                        selectedTaskIDs = []
                        taskReminders = [:]
                        taskReminderIsOneTime = [:]
                        healthTargets = [:]
                        taskHealthTypes = [:]
                        editingReminderID = nil
                    }) {
                        Text(vm.localized("Redo"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(editableTasks) { task in
                            let idx = task.id
                            let isSelected = selectedTaskIDs.contains(idx)
                            let taskHealthType = taskHealthTypes[idx] ?? .none

                            HStack(spacing: 8) {
                                VStack(spacing: 0) {
                                    // ── Main task row ──
                                    HStack(spacing: 12) {
                                        Button {
                                            if isSelected { selectedTaskIDs.remove(idx) }
                                            else { selectedTaskIDs.insert(idx) }
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: 1.5)
                                                    .frame(width: 22, height: 22)
                                                if isSelected {
                                                    Circle().fill(Theme.accent).frame(width: 22, height: 22)
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 9, weight: .black))
                                                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField(vm.localized("Task name"), text: Binding(
                                                get: { editableTasks.first(where: { $0.id == idx })?.title ?? "" },
                                                set: { editableTasks.updateDraftTitle(id: idx, title: $0) }
                                            ))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.text0)

                                            if taskHealthType != .none {
                                                let accent: Color = Color(hex: taskHealthType.accentColor)
                                                let unit: String = taskHealthType.label.lowercased()
                                                let placeholder = taskHealthType == .steps ? "10000" : (taskHealthType == .distance ? "5" : "500")

                                                HStack(spacing: 6) {
                                                    Image(systemName: taskHealthType.icon)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(accent)
                                                        .frame(width: 14)

                                                    Text(vm.localized("Target:"))
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(Theme.text2)

                                                    TextField(placeholder, text: Binding(
                                                        get: { healthTargets[idx] ?? "" },
                                                        set: { healthTargets[idx] = $0 }
                                                    ))
                                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                                    .foregroundColor(Theme.text0)
                                                    .keyboardType(taskHealthType == .steps || taskHealthType == .calories ? .numberPad : .decimalPad)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 58)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(Theme.bg0.opacity(ThemeManager.shared.isDark ? 0.7 : 0.9))
                                                            .overlay(
                                                                Capsule(style: .continuous)
                                                                    .strokeBorder(accent.opacity(0.28), lineWidth: 0.6)
                                                            )
                                                    )

                                                    Button {
                                                        if taskHealthType == .distance {
                                                            hk.distanceUnit = (hk.distanceUnit == .kilometers ? .miles : .kilometers)
                                                        }
                                                    } label: {
                                                        Text(unit)
                                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                                            .foregroundColor(accent)
                                                            .padding(.horizontal, 7)
                                                            .padding(.vertical, 4)
                                                            .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .disabled(taskHealthType != .distance)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(accent.opacity(0.07))
                                                        .overlay(
                                                            Capsule(style: .continuous)
                                                                .strokeBorder(accent.opacity(0.18), lineWidth: 0.6)
                                                        )
                                                )
                                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                                            }
                                        }

                                        Spacer(minLength: 0)

                                        // Health type selector/toggle
                                        Menu {
                                            Button { setHealthType(.none, for: idx) } label: { Label(vm.localized("Regular"), systemImage: "circle") }
                                            Button { setHealthType(.steps, for: idx) } label: { Label(vm.localized("Steps"), systemImage: "figure.walk") }
                                                .disabled(isTypeBlocked(.steps, currentIdx: idx))
                                            Button { setHealthType(.calories, for: idx) } label: { Label(vm.localized("Calories"), systemImage: "flame.fill") }
                                                .disabled(isTypeBlocked(.calories, currentIdx: idx))
                                            Button { setHealthType(.distance, for: idx) } label: { Label(vm.localized("Distance"), systemImage: "figure.run") }
                                                .disabled(isTypeBlocked(.distance, currentIdx: idx))
                                        } label: {
                                            let tagColor: Color = Color(hex: taskHealthType.accentColor)
                                            ZStack {
                                                Circle()
                                                    .fill(tagColor.opacity(0.12))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: taskHealthType == .none ? "tag" : taskHealthType.icon)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(tagColor)
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            editingReminderID = idx
                                        } label: {
                                            let hasTime = taskReminders[idx] != nil
                                            Image(systemName: hasTime ? "bell.fill" : "bell")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(hasTime ? Color(hex: "#2196F3") : Theme.text2)
                                                .frame(width: 30, height: 30)
                                                .background(Circle().fill(hasTime ? Color(hex: "#2196F3").opacity(0.1) : Theme.bg3.opacity(0.5)))
                                                .shadow(color: hasTime ? .black.opacity(0.2) : .clear, radius: 1, x: 0, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // ── Reminder time row ──
                                    if let time = taskReminders[idx] {
                                        let isOT = taskReminderIsOneTime[idx] ?? false
                                        HStack(spacing: 6) {
                                            Image(systemName: "bell.fill").font(.system(size: 10))
                                                .foregroundColor(Color(hex: "#2196F3"))
                                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                            Text(isOT ? kOneTimeDateFormatter.string(from: time) : starterTimeFormatter.string(from: time))
                                                .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.text1)
                                            Spacer()
                                            Button {
                                                taskReminders.removeValue(forKey: idx)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 13)).foregroundColor(Theme.text2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.top, 8)
                                        .padding(.leading, 34)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, taskHealthType != .none || taskReminders[idx] != nil ? 10 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isSelected ? Theme.accent.opacity(0.07) : Theme.bg1)
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(isSelected ? Theme.accent.opacity(0.2) : Theme.border, lineWidth: 0.5))
                                )

                                // ── Delete button (Outside the task) ──
                                Button { removeTask(id: idx) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.text2.opacity(0.4))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Theme.bg3.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                            }
                            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: taskReminders[idx] != nil)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                Button {
                    let draft = StarterTaskDraft(title: "")
                    editableTasks.append(draft)
                    selectedTaskIDs.insert(draft.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(vm.localized("Add More"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if showStarterConflictToast, let ct = starterConflictHealthType {
                    HealthConflictToast(type: ct, isVisible: $showStarterConflictToast)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Button(action: { createList(list) }) {
                    let btnText = String(format: vm.localized("Create List with %lld Tasks"), Int64(selectedTaskIDs.count))
                    Text(btnText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(selectedTaskIDs.isEmpty ? Theme.bg3 : Theme.accent)
                                .shadow(color: selectedTaskIDs.isEmpty ? .clear : Theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedTaskIDs.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    private func setHealthType(_ type: HealthTaskType, for idx: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            guard editableTasks.contains(where: { $0.id == idx }) else { return }
            taskHealthTypes[idx] = type
            if type == .steps && (healthTargets[idx] == nil || healthTargets[idx]!.isEmpty) {
                healthTargets[idx] = "10000"
            } else if type == .calories && (healthTargets[idx] == nil || healthTargets[idx]!.isEmpty) {
                healthTargets[idx] = "500"
            } else if type == .distance && (healthTargets[idx] == nil || healthTargets[idx]!.isEmpty) {
                healthTargets[idx] = "5"
            }
        }
    }

    private func isTypeBlocked(_ type: HealthTaskType, currentIdx: UUID) -> Bool {
        guard type != .none else { return false }
        for (idx, t) in taskHealthTypes {
            if idx != currentIdx && t == type && selectedTaskIDs.contains(idx) {
                return true
            }
        }
        return false
    }

    private var starterDefaultTime: Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private var goalExamples: [String] {
        switch vm.appLanguage {
        case .chinese:
            return [
                "🏋️ 锻炼计划", "🥗 健康饮食", "🧘 保持健康", "🏃 有氧运动", "💤 改善睡眠",
                "🧠 技能提升", "🗣️ 学习普通话", "📚 多读书", "💼 求职", "🚀 上线应用",
                "💰 存钱理财", "🧘 正念冥想", "📸 社交成长", "✍️ 写作习惯", "🎯 早晨例程",
                "💧 多喝水", "🧹 保持整洁", "💻 学习编程", "📈 智慧投资", "🌍 旅行计划",
                "🎨 创意练习", "🤝 拓展人脉", "🧴 护肤例程", "🏠 家居改善", "🎸 学习吉他",
                "🍳 在家做饭", "🐕 训练宠物", "📷 摄影练习", "🧘 减少压力", "⚡ 提升效率"
            ]
        case .arabic:
            return [
                "🏋️ روتين التمرين", "🥗 الأكل الصحي", "🧘 تمتع بالصحة", "🏃 تمارين الكارديو", "💤 نوم أفضل",
                "🧠 تطوير المهارات", "🗣️ تعلم الإسبانية", "📚 القراءة أكثر", "💼 البحث عن عمل", "🚀 إطلاق تطبيقي",
                "💰 توفير المال", "🧘 اليقظة الذهنية", "📸 النمو الاجتماعي", "✍️ عادة الكتابة", "🎯 روتين الصباح",
                "💧 شرب الماء", "🧹 ابقَ منظماً", "💻 تعلم البرمجة", "📈 استثمار أذكى", "🌍 تخطيط السفر",
                "🎨 الممارسة الإبداعية", "🤝 التواصل والشبكات", "🧴 روتين العناية", "🏠 تحسين المنزل", "🎸 تعلم الجيتار",
                "🍳 الطبخ في المنزل", "🐕 تدريب الكلب", "📷 التصوير", "🧘 توتر أقل", "⚡ الإنتاجية"
            ]
        case .spanish:
            return [
                "🏋️ Rutina ejercicio", "🥗 Comer sano", "🧘 Estar saludable", "🏃 Cardio y fitness", "💤 Dormir mejor",
                "🧠 Superación", "🗣️ Aprender español", "📚 Leer más", "💼 Buscar trabajo", "🚀 Lanzar mi app",
                "💰 Ahorrar dinero", "🧘 Mindfulness", "📸 Crecer en redes", "✍️ Hábito escribir", "🎯 Rutina mañana",
                "💧 Hidratarse", "🧹 Organizarse", "💻 Aprender código", "📈 Invertir mejor", "🌍 Planear viaje",
                "🎨 Práctica creativa", "🤝 Networking", "🧴 Rutina de piel", "🏠 Mejorar casa", "🎸 Aprender guitarra",
                "🍳 Cocinar en casa", "🐕 Entrenar perro", "📷 Fotografía", "🧘 Menos estrés", "⚡ Productividad"
            ]
        default:
            return [
                "🏋️ Workout Routine", "🥗 Eat Healthy", "🧘 Get Healthy", "🏃 Cardio & Fitness", "💤 Better Sleep",
                "🧠 Upskilling", "🗣️ Learn Spanish", "📚 Read More", "💼 Job Hunting", "🚀 Launch My App",
                "💰 Save Money", "🧘 Mindfulness", "📸 Grow on Social", "✍️ Writing Habit", "🎯 Morning Routine",
                "💧 Stay Hydrated", "🧹 Stay Organised", "💻 Learn to Code", "📈 Invest Smarter", "🌍 Travel Planning",
                "🎨 Creative Practice", "🤝 Networking", "🧴 Skincare Routine", "🏠 Home Improvement", "🎸 Learn Guitar",
                "🍳 Cook at Home", "🐕 Dog Training", "📷 Photography", "🧘 Stress Less", "⚡ Productivity"
            ]
        }
    }

    private func removeTask(id: UUID) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            editableTasks.removeDraft(id: id)
            selectedTaskIDs.remove(id)
            taskReminders.removeValue(forKey: id)
            taskReminderIsOneTime.removeValue(forKey: id)
            healthTargets.removeValue(forKey: id)
            taskHealthTypes.removeValue(forKey: id)
            if editingReminderID == id { editingReminderID = nil }
        }
    }

    private func generate() {
        guard !goalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isGenerating else { return }
        isGenerating = true
        generationFailed = false
        Task {
            let result = await AICoach.shared.generateStarterList(goal: goalInput)
            await MainActor.run {
                if let result = result {
                    // Failsafe: strip chevrons if AI still includes them
                    let cleanEmoji = result.emoji
                        .replacingOccurrences(of: "<", with: "")
                        .replacingOccurrences(of: ">", with: "")
                    
                    editableListName = stripBannedListNameSuffixes(result.listName.trimmingCharacters(in: .whitespaces))
                    while !editableListName.isEmpty, editableListName.first!.isEmoji {
                        editableListName.removeFirst()
                        editableListName = editableListName.trimmingCharacters(in: .whitespaces)
                    }

                    let allowHealthTasks = isHealthRelatedStarterGoal(goalInput) || isHealthRelatedStarterGoal(editableListName)

                    // Health/phone trackers are powerful, but they must only appear when the goal asks for that domain.
                    var tasks: [String] = []
                    var foundHealthTypes = Set<HealthTaskType>()
                    
                    for t in result.tasks {
                        let type = HealthTaskType.detect(from: t)
                        if type == .none {
                            tasks.append(t)
                        } else if allowHealthTasks, !foundHealthTypes.contains(type) {
                            tasks.append(t)
                            foundHealthTypes.insert(type)
                        }
                    }

                    starterList = StarterList(
                        emoji: cleanEmoji,
                        listName: editableListName,
                        tasks: tasks
                    )

                    editableTasks = tasks.map { StarterTaskDraft(title: $0) }
                    selectedTaskIDs = Set(editableTasks.map(\.id))
                    taskReminders = [:]
                    taskReminderIsOneTime = [:]
                    healthTargets = [:]
                    taskHealthTypes = [:]
                    editingReminderID = nil

                    // Metadata follows stable task IDs when rows are removed or edited.
                    for task in editableTasks {
                        let idx = task.id
                        let ht = HealthTaskType.detect(from: task.title)
                        taskHealthTypes[idx] = ht
                        if ht == .steps    { healthTargets[idx] = "10000" }
                        if ht == .calories { healthTargets[idx] = "500" }
                        if ht == .distance { healthTargets[idx] = "5" }
                    }
                } else {
                    generationFailed = true
                }
                isGenerating = false
            }
        }
    }

    // FIX: Removed the invalid force-cast `as! [(title:reminder:isOneTime:)]`
    // that was crashing/freezing the screen. `addListWithTasks` takes a
    // 3-tuple; we now map the data correctly before calling it, and pass
    // health targets by injecting them into the task title so the existing
    // `extractNumericTarget` logic in AppViewModel picks them up cleanly.
    private func createList(_ starter: StarterList) {
        let dedupedTaskData: [(title: String, reminder: Date?, isOneTime: Bool, healthType: HealthTaskType?)] =
            editableTasks.filter { selectedTaskIDs.contains($0.id) }.compactMap { task in
                let idx = task.id
                var trimmed = task.title.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }

                let ht = taskHealthTypes[idx] ?? .none
                if ht != .none, let userTargetStr = healthTargets[idx],
                   let userTarget = Double(userTargetStr), userTarget.isFinite,
                   userTarget > 0, userTarget < Double(Int.max) {
                    // Inject target into title if needed, or just let it be handled by addListWithTasks if I update it.
                    // Actually, addListWithTasks in AppViewModel doesn't take health info directly, it detects it.
                    // WAIT, I should check AppViewModel.addListWithTasks again.
                    // It says: "Auto-detect health tasks from title keywords" (line 207)
                    // So I MUST inject the number into the title.
                    
                    let detectedNum = AppViewModel.extractNumericTarget(from: trimmed, type: ht)
                    if detectedNum.isFinite, detectedNum > 0, detectedNum < Double(Int.max) {
                        let oldNum = String(Int(detectedNum))
                        let newNum = String(Int(userTarget))
                        trimmed = trimmed.replacingOccurrences(of: oldNum, with: newNum)
                    } else {
                        trimmed += " \(Int(userTarget)) \(titleInjectionUnit(for: ht))"
                    }
                }

                return (trimmed, taskReminders[idx], taskReminderIsOneTime[idx] ?? false, ht)
            }
        guard !dedupedTaskData.isEmpty else { return }

        // Final dedup check (just in case)
        var finalTasks: [(title: String, reminder: Date?, isOneTime: Bool)] = []
        var seenHealth = Set<HealthTaskType>()
        var conflictFound: HealthTaskType? = nil

        for item in dedupedTaskData {
            if let ht = item.healthType, ht != .none {
                if seenHealth.contains(ht) {
                    conflictFound = ht
                    continue
                }
                seenHealth.insert(ht)
            }
            finalTasks.append((item.title, item.reminder, item.isOneTime))
        }

        if let conflict = conflictFound {
            starterConflictHealthType = conflict
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showStarterConflictToast = true
            }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        }

        // Safe call — no force-cast, correct tuple shape
        vm.addListWithTasks(name: editableListName.trimmingCharacters(in: .whitespaces).isEmpty ? starter.listName : editableListName, emoji: starter.emoji, taskData: finalTasks)


        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        if !hk.isAuthorized {
            if let healthTask = dedupedTaskData.first(where: {
                HealthTaskType.detect(from: $0.title) != .none
            }) {
                detectedHealthTypeForPermission = HealthTaskType.detect(from: healthTask.title)
                if detectedHealthTypeForPermission != .none {
                    showHealthPermission = true
                    return
                }
            }
        }

        if conflictFound != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
        } else {
            dismiss()
        }
    }

    private func titleInjectionUnit(for type: HealthTaskType) -> String {
        switch type {
        case .steps:
            switch vm.appLanguage {
            case .arabic:  return "خطوة"
            case .spanish: return "pasos"
            case .chinese: return "步"
            default:       return "steps"
            }
        case .calories:
            switch vm.appLanguage {
            case .arabic:  return "سعرة حرارية"
            case .spanish: return "calorías"
            case .chinese: return "卡路里"
            default:       return "calories"
            }
        case .distance:
            return hk.distanceUnit.rawValue
        case .none:
            return ""
        }
    }

    private func isHealthRelatedStarterGoal(_ text: String) -> Bool {
        let lower = text.lowercased()
        let phraseTriggers = [
            "get fit", "screen time", "phone usage", "phone use", "limit phone",
            "tiempo de pantalla", "uso del móvil", "uso del movil",
            "وقت الشاشة", "استخدام الهاتف",
            // Chinese — character-level matching (no word boundaries in Chinese)
            "健身", "步数", "卡路里", "跑步", "走路", "锻炼", "运动", "体重",
            "睡眠", "饮食", "训练", "慢跑", "健康", "营养", "热量", "水分"
        ]
        if phraseTriggers.contains(where: { lower.contains($0) }) { return true }

        let words = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        let wordTriggers: Set<String> = [
            "health", "healthy", "fitness", "gym", "workout", "exercise", "training",
            "cardio", "run", "running", "jog", "walk", "walking", "steps", "calories",
            "kcal", "weight", "diet", "nutrition", "meal", "meals", "water", "hydrate",
            "sleep", "recovery", "salud", "sano", "sana", "gimnasio", "entrenamiento",
            "ejercicio", "correr", "caminar", "pasos", "calorías", "calorias", "peso",
            "dieta", "nutrición", "nutricion", "comidas", "agua", "hidratar", "sueño",
            "sueno", "descanso", "صحة", "صحي", "صحية", "لياقة", "جيم", "رياضة",
            "تمرين", "تمارين", "جري", "ركض", "مشي", "خطوات", "سعرات", "وزن",
            "حمية", "تغذية", "وجبات", "ماء", "ترطيب", "نوم", "تعافي"
        ]
        return !words.isDisjoint(with: wordTriggers)
    }
}

private struct StarterReminderEdit: Identifiable {
    let id: UUID
}

private let starterTimeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
}()

// MARK: - MarqueeChipRows

struct MarqueeChipRows: View {
    let chips: [String]
    var rowCount: Int = 4
    let onSelect: (String) -> Void

    private func rowChips(for row: Int) -> [String] {
        chips.enumerated().filter { $0.offset % rowCount == row }.map(\.element)
    }

    private let configs: [(goLeft: Bool, speed: Double)] = [
        (true,  28),
        (false, 20),
        (true,  35),
        (false, 24)
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { row in
                let cfg = configs[row % configs.count]
                MarqueeRow(
                    chips: rowChips(for: row),
                    goLeft: cfg.goLeft,
                    speed: cfg.speed,
                    onSelect: onSelect
                )
                .frame(height: 36)
            }
        }
    }
}

// MARK: - MarqueeRow

struct MarqueeRow: UIViewRepresentable {
    let chips: [String]
    let goLeft: Bool
    let speed: Double
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = .clear

        let contentView = UIView()
        contentView.backgroundColor = .clear

        let allChips = chips + chips + chips
        var xOffset: CGFloat = 0
        let chipHeight: CGFloat = 36
        let hPad: CGFloat = 12
        let vPad: CGFloat = 8
        let spacing: CGFloat = 8

        for (idx, chip) in allChips.enumerated() {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: vPad, leading: hPad, bottom: vPad, trailing: hPad)
            
            var container = AttributeContainer()
            container.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            config.attributedTitle = AttributedString(chip, attributes: container)
            
            config.baseForegroundColor = UIColor(Theme.text1)
            
            let btn = UIButton(configuration: config)
            btn.layer.cornerRadius = chipHeight / 2
            btn.layer.borderWidth = 0.5
            btn.layer.borderColor = UIColor(Theme.border).cgColor
            btn.backgroundColor = UIColor(Theme.bg2)
            btn.clipsToBounds = true
            btn.tag = idx % chips.count
            btn.addTarget(context.coordinator, action: #selector(Coordinator.chipTapped(_:)), for: .touchUpInside)

            btn.sizeToFit()
            let w = btn.frame.width
            btn.frame = CGRect(x: xOffset, y: 0, width: w, height: chipHeight)
            contentView.addSubview(btn)
            xOffset += w + spacing
        }

        context.coordinator.chips = chips
        contentView.frame = CGRect(x: 0, y: 0, width: xOffset, height: chipHeight)
        scrollView.addSubview(contentView)
        scrollView.contentSize = CGSize(width: xOffset, height: chipHeight)

        context.coordinator.scrollView = scrollView
        context.coordinator.contentWidth = xOffset / 3
        context.coordinator.goLeft = goLeft
        context.coordinator.speed = speed

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.startScrolling()
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    class Coordinator: NSObject {
        let onSelect: (String) -> Void
        var chips: [String] = []
        weak var scrollView: UIScrollView?
        var contentWidth: CGFloat = 0
        var goLeft: Bool = true
        var speed: Double = 28
        var displayLink: CADisplayLink?
        var lastTimestamp: CFTimeInterval = 0

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        @objc func chipTapped(_ sender: UIButton) {
            let idx = sender.tag
            guard idx < chips.count else { return }
            onSelect(chips[idx])
        }

        func startScrolling() {
            displayLink?.invalidate()
            let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))
            dl.add(to: .main, forMode: .common)
            displayLink = dl
        }

        @objc func tick(_ dl: CADisplayLink) {
            guard let sv = scrollView, contentWidth > 0 else { return }

            let delta: CGFloat
            if lastTimestamp == 0 {
                lastTimestamp = dl.timestamp
                delta = 0
            } else {
                delta = CGFloat(dl.timestamp - lastTimestamp) * CGFloat(speed)
                lastTimestamp = dl.timestamp
            }

            var x = sv.contentOffset.x
            if goLeft {
                x += delta
                if x >= contentWidth { x -= contentWidth }
            } else {
                x -= delta
                if x <= 0 { x += contentWidth }
            }

            sv.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}

// Strips common AI-appended filler words from generated list names across all supported languages.
private func stripBannedListNameSuffixes(_ name: String) -> String {
    let banned: Set<String> = [
        // English
        "system", "routine", "builder", "program", "habit", "habits",
        "plan", "journey", "challenge", "framework", "guide", "protocol",
        "method", "practice", "tracker", "log", "regimen", "schedule",
        // Spanish
        "rutina", "sistema", "programa", "habitos", "hábitos", "viaje", "desafio", "desafío",
        // Arabic
        "نظام", "روتين", "برنامج", "خطة",
        // Chinese
        "系统", "计划", "程序", "旅程", "挑战"
    ]
    var words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    while let last = words.last,
          banned.contains(last.lowercased().folding(options: .diacriticInsensitive, locale: .current)) {
        words.removeLast()
    }
    return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
}
