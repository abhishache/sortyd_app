// MARK: - AITaskEntryView.swift
// Sortyd — Natural Language Task Entry + AI Starter Lists

import SwiftUI

// ══════════════════════════════════════════════
// MARK: - SmartAddTaskSheet
// Natural language task entry with AI parsing
// ══════════════════════════════════════════════

struct SmartAddTaskSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var detectedHealthType: HealthTaskType = .none
    @State private var healthTargetText: String = ""
    @State private var showHealthPermission = false
    @StateObject private var hk = HealthKitManager.shared

    let listID: UUID

    @State private var input = ""
    @State private var parsedTask: ParsedTask?
    @State private var isParsing = false
    @State private var parseError = false
    @FocusState private var isFocused: Bool

    private var reminderPreview: String? {
        guard let p = parsedTask, p.hasReminder,
              let h = p.reminderHour, let m = p.reminderMinute else { return nil }
        let formatted = String(format: "%02d:%02d", h, m)
        return "⏰ Reminder at \(formatted)"
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
                        Text("Add Task")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text("Type naturally — AI will parse reminders & details")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Input field
                    HStack(spacing: 10) {
                        TextField("e.g. \"Call dentist at 3pm\"", text: $input)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.text0)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { parseInput() }
                            .onChange(of: input) { _, newValue in
                                parsedTask = nil
                                parseError = false
                                detectedHealthType = HealthTaskType.detect(from: newValue)
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

                    // Parsed preview
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
                        Text("Couldn't parse that — the task will be added as typed.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // Example chips — animated marquee rows
                    if input.isEmpty {
                        MarqueeChipRows(
                            chips: examplePrompts,
                            rowCount: 4,
                            onSelect: { input = $0 }
                        )
                        .padding(.bottom, 16)
                    }

                    Spacer()

                    // Add button
                    Button(action: { addTask() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .black))
                            Text(parsedTask != nil ? "Add \"\(parsedTask!.title)\"" : "Add Task")
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
    }

    // SHORT, PUNCHY, GENERIC — triggers AI to build rich multi-task lists
    private let examplePrompts = [
        "🏃 Morning Run",
        "💊 Take Vitamins",
        "💧 Stay Hydrated",
        "📖 Read Tonight",
        "🧘 Meditate",
        "🛒 Groceries",
        "✍️ Journal",
        "😴 Wind Down",
        "💻 Deep Work",
        "🎯 Plan Tomorrow",
        "🚶 Hit 10k Steps",
        "🥗 Eat Clean",
        "📞 Call Family",
        "🧹 Tidy Up",
        "💰 Check Budget",
        "🎧 Podcast Walk",
        "📝 Weekly Review",
        "🌅 Early Start",
        "🔋 Phone Detox",
        "🤸 Stretch & Move"
    ]

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
        let words = ["am", "pm", "at", "by", "before", "morning", "afternoon", "evening", "noon", "midnight"]
        let lower = text.lowercased()
        return words.contains(where: { lower.contains($0) })
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
        vm.addTask(to: listID, title: title, reminderTime: reminderDate,
                   healthType: htString, healthTarget: htTarget)

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        dismiss()
    }
}

// ══════════════════════════════════════════════
// MARK: - TypingPlaceholderField
// TextField with animated typewriter placeholder
// cycling through short punchy goal labels
// ══════════════════════════════════════════════

struct TypingPlaceholderField: View {
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState.Binding var isFocused: Bool

    private let placeholders = [
        "Get healthy",
        "Workout routine",
        "Learn Spanish",
        "Job hunting",
        "Eat clean",
        "Build a habit"
    ]

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

    private func startTyping() {
        scheduleNext()
    }

    private func scheduleNext() {
        let phrase = placeholders[phraseIndex]
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
                phraseIndex = (phraseIndex + 1) % placeholders.count
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
// AI-generated starter tasks for a new list
// ══════════════════════════════════════════════

struct StarterListSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var goalInput = ""
    @State private var starterList: StarterList?
    @State private var isGenerating = false
    @State private var editableTasks: [String] = []
    @State private var selectedIndices: Set<Int> = []
    @State private var taskReminders: [Int: Date] = [:]
    @State private var editingReminderIndex: Int? = nil
    @State private var showHealthPermission = false
    @State private var detectedHealthTypeForPermission: HealthTaskType = .none
    @StateObject private var hk = HealthKitManager.shared
    @FocusState private var isFocused: Bool

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
                        Text("AI Starter List")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text("Describe your goal — AI builds the exact tasks")
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
            get: { editingReminderIndex.map { StarterReminderEdit(index: $0) } },
            set: { editingReminderIndex = $0?.index }
        )) { item in
            InlineTimePickerSheet(
                selectedTime: taskReminders[item.index] ?? starterDefaultTime,
                onConfirm: { taskReminders[item.index] = $0 }
            )
        }
        .sheet(isPresented: $showHealthPermission, onDismiss: { dismiss() }) {
            HealthPermissionSheet(
                taskType: detectedHealthTypeForPermission,
                onGrant: { hk.fetchToday() },
                onSkip:  {}
            )
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
                Text("Try one of these")
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
        Button(action: { generate() }) {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView().tint(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white).scaleEffect(0.8)
                    Text("Building your list…")
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .black))
                    Text("Generate List")
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

    // FIX: Replaced guard + return AnyView pattern with @ViewBuilder + if let.
    // The previous pattern broke SwiftUI's structural identity system, causing
    // view recreation instead of updates, animation glitches, and diffing failures.
    @ViewBuilder
    private var generatedListSection: some View {
        if let list = starterList {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(list.emoji).font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.listName)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Theme.text0)
                        Text("\(selectedIndices.count) of \(editableTasks.count) tasks selected")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text2)
                    }
                    Spacer()
                    Button(action: {
                        starterList = nil
                        goalInput = ""
                        editableTasks = []
                        selectedIndices = []
                        taskReminders = [:]
                    }) {
                        Text("Redo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(editableTasks.indices, id: \.self) { idx in
                            let isSelected = selectedIndices.contains(idx)
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Button {
                                        if isSelected { selectedIndices.remove(idx) }
                                        else { selectedIndices.insert(idx) }
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

                                    TextField("Task name", text: $editableTasks[idx])
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Theme.text0)

                                    Spacer(minLength: 0)

                                    Button {
                                        editingReminderIndex = idx
                                    } label: {
                                        Image(systemName: taskReminders[idx] != nil ? "bell.fill" : "bell")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(taskReminders[idx] != nil ? Theme.accent : Theme.text2)
                                            .frame(width: 30, height: 30)
                                            .background(Circle().fill(taskReminders[idx] != nil ? Theme.accent.opacity(0.12) : Theme.bg3))
                                    }
                                    .buttonStyle(.plain)
                                }

                                if let time = taskReminders[idx] {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bell.fill").font(.system(size: 10)).foregroundColor(Theme.accent)
                                        Text(starterTimeFormatter.string(from: time))
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? Theme.accent.opacity(0.07) : Theme.bg1)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(isSelected ? Theme.accent.opacity(0.2) : Theme.border, lineWidth: 0.5))
                            )
                            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: taskReminders[idx] != nil)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                Button {
                    let newIndex = editableTasks.count
                    editableTasks.append("")
                    selectedIndices.insert(newIndex)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add More")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Button(action: { createList(list) }) {
                    Text("Create List with \(selectedIndices.count) Tasks")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(selectedIndices.isEmpty ? Theme.bg3 : Theme.accent)
                                .shadow(color: selectedIndices.isEmpty ? .clear : Theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedIndices.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    private var starterDefaultTime: Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    // SHORT, PUNCHY, GENERIC — AI expands each into 6–10 rich, relevant tasks
    private let goalExamples = [
        "🏋️ Workout Routine",
        "🥗 Eat Healthy",
        "🧘 Get Healthy",
        "🏃 Cardio & Fitness",
        "💤 Better Sleep",
        "🧠 Upskilling",
        "🗣️ Learn Spanish",
        "📚 Read More",
        "💼 Job Hunting",
        "🚀 Launch My App",
        "💰 Save Money",
        "🧘 Mindfulness",
        "📸 Grow on Social",
        "✍️ Writing Habit",
        "🎯 Morning Routine",
        "💧 Stay Hydrated",
        "🧹 Stay Organised",
        "💻 Learn to Code",
        "📈 Invest Smarter",
        "🌍 Travel Planning",
        "🎨 Creative Practice",
        "🤝 Networking",
        "🧴 Skincare Routine",
        "🏠 Home Improvement",
        "🎸 Learn Guitar",
        "🍳 Cook at Home",
        "🐕 Dog Training",
        "📷 Photography",
        "🧘 Stress Less",
        "⚡ Productivity"
    ]

    private func generate() {
        guard !goalInput.isEmpty else { return }
        isGenerating = true
        Task {
            let result = await AICoach.shared.generateStarterList(goal: goalInput)
            await MainActor.run {
                if let result = result {
                    starterList = result
                    editableTasks = result.tasks
                    selectedIndices = Set(result.tasks.indices)
                }
                isGenerating = false
            }
        }
    }

    private func createList(_ starter: StarterList) {
        let taskData: [(String, Date?)] = selectedIndices.sorted().compactMap { idx -> (String, Date?)? in
            guard idx < editableTasks.count else { return nil }
            let trimmed = editableTasks[idx].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return (trimmed, taskReminders[idx])
        }
        guard !taskData.isEmpty else { return }
        vm.addListWithTasks(name: starter.listName, emoji: starter.emoji, taskData: taskData)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        if !hk.isAuthorized {
            if let healthTask = taskData.first(where: { HealthTaskType.detect(from: $0.0) != .none }) {
                detectedHealthTypeForPermission = HealthTaskType.detect(from: healthTask.0)
                showHealthPermission = true
                return
            }
        }

        dismiss()
    }
}

private struct StarterReminderEdit: Identifiable {
    let index: Int
    var id: Int { index }
}

private let starterTimeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
}()

// MARK: - MarqueeChipRows
// Splits chips across N rows, each row scrolls at different speed/direction.
// Uses UIScrollView under the hood so tap targets are always accurate.

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
// UIViewRepresentable wrapping a UIScrollView.
// Tap targets are always correct because UIKit hit-testing is position-based,
// not SwiftUI-animation-frame-based.

struct MarqueeRow: UIViewRepresentable {
    let chips: [String]
    let goLeft: Bool
    let speed: Double          // points per second
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false          // we drive scrolling manually
        scrollView.clipsToBounds = true
        scrollView.backgroundColor = .clear

        // Build a stack of chip buttons inside a content view
        let contentView = UIView()
        contentView.backgroundColor = .clear

        // Triple chips so loop seam is invisible
        let allChips = chips + chips + chips
        var xOffset: CGFloat = 0
        let chipHeight: CGFloat = 36
        let hPad: CGFloat = 12
        let vPad: CGFloat = 8
        let spacing: CGFloat = 8

        for (idx, chip) in allChips.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(chip, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            btn.setTitleColor(UIColor(Theme.text1), for: .normal)
            btn.backgroundColor = UIColor(Theme.bg2)
            btn.layer.cornerRadius = chipHeight / 2
            btn.layer.borderWidth = 0.5
            btn.layer.borderColor = UIColor(Theme.border).cgColor
            btn.contentEdgeInsets = UIEdgeInsets(top: vPad, left: hPad, bottom: vPad, right: hPad)
            btn.tag = idx % chips.count   // tag maps back to original chip index
            btn.addTarget(context.coordinator, action: #selector(Coordinator.chipTapped(_:)), for: .touchUpInside)

            // Size to fit
            btn.sizeToFit()
            let w = btn.frame.width
            btn.frame = CGRect(x: xOffset, y: 0, width: w, height: chipHeight)
            contentView.addSubview(btn)
            xOffset += w + spacing
        }

        // Store original chips on coordinator so we can look up the title
        context.coordinator.chips = chips

        contentView.frame = CGRect(x: 0, y: 0, width: xOffset, height: chipHeight)
        scrollView.addSubview(contentView)
        scrollView.contentSize = CGSize(width: xOffset, height: chipHeight)

        // Store refs
        context.coordinator.scrollView = scrollView
        context.coordinator.contentWidth = xOffset / 3   // width of ONE copy
        context.coordinator.goLeft = goLeft
        context.coordinator.speed = speed

        // Start scrolling after layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.startScrolling()
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    // MARK: - Coordinator

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

            // Set offset without animation — CADisplayLink handles smoothness
            sv.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}
